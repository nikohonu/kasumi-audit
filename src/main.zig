const std = @import("std");
const expect = std.testing.expect;

const print = std.debug.print;

fn is_string_in_array(array: std.ArrayList([]u8), string: []const u8) bool {
    for (array.items) |item| {
        if (std.mem.eql(u8, item, string)) {
            return true;
        }
    }
    return false;
}

const Entry = struct {
    path: []const u8,
    kind: std.fs.File.Kind,
    count: i32,
    children: std.ArrayList(*Entry),
    parent: ?*Entry,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, path: []const u8, kind: std.fs.File.Kind, parent: ?*Entry, ignore_list: std.ArrayList([]u8)) !*Entry {
        var self = try allocator.create(Entry);

        self.* = Entry{
            .path = path,
            .kind = kind,
            .count = 1,
            .children = std.ArrayList(*Entry).init(allocator),
            .parent = parent,
            .allocator = allocator,
        };

        if (self.kind != std.fs.File.Kind.directory) {
            return self;
        }

        var dir = std.fs.openDirAbsolute(self.path, .{ .iterate = true }) catch return self;
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |item| {
            // _ = ignore_list;
            const child_path = try std.fs.path.join(allocator, &[_][]const u8{ self.path, item.name });
            if (is_string_in_array(ignore_list, child_path)) {
                std.debug.print("Skip {s}\n", .{child_path});
                allocator.free(child_path);
                continue;
            }
            const child = try Entry.init(allocator, child_path, item.kind, self, ignore_list);
            try self.children.append(child);
            self.count += child.count;
        }

        std.mem.sort(*Entry, self.children.items, {}, cmp);

        return self;
    }

    fn cmp(_: void, self: *Entry, other: *Entry) bool {
        return self.count > other.count;
    }

    pub fn deinit(self: *Entry) void {
        for (self.children.items) |item| {
            item.deinit();
        }
        self.children.deinit();
        self.allocator.free(self.path);
        self.allocator.destroy(self);
    }

    pub fn format(
        self: Entry,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = try writer.print("{{ path: {s}, kind: {}, count: {}}}", .{ self.path, self.kind, self.count });
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer arena.deinit();
    defer {
        const deinit_status = gpa.deinit();
        // _ = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) expect(false) catch @panic("TEST FAIL");
    }
    // const allocator = arena.allocator();
    const allocator = gpa.allocator();

    const home_path = std.posix.getenv("HOME").?;

    var ignore_list = try IgnoreList.init(allocator, home_path);
    defer ignore_list.deinit();
    const flat_ignore_list = try ignore_list.get_flat_ignore_list(allocator);
    defer flat_ignore_list.deinit();

    // I need to copy home_path to the heap because other paths are stored
    // there, and I can't free them if one of them is not on the heap.
    var root = try Entry.init(allocator, try allocator.dupe(u8, home_path), std.fs.File.Kind.directory, null, flat_ignore_list);
    defer root.deinit();
    var child: *Entry = root;
    //
    while (true) {
        if (child.count > 1) {
            child = child.children.items[0];
            try stdout.writer().print("{s}\n", .{child});
        } else {
            break;
        }
    }
    // defer allocator.free(category);
    while (true) {
        try stdout.writer().print("What to do. Move up (u), Add (a), Skip(s): ", .{});
        const input = try stdin.reader().readByte();
        while (try stdin.reader().readByte() != '\n') {}
        switch (input) {
            'a' => {
                try stdout.writer().print("Add {s} to ignore list\n", .{child.path});
                var buf: [128]u8 = undefined;
                try stdout.writer().print("Enter category of ignored path: ", .{});
                const user_input = try stdin.reader().readUntilDelimiterOrEof(&buf, '\n');
                const category = try allocator.dupe(u8, user_input.?);
                const existing_category = ignore_list.is_category_exist(category);
                const child_path = try allocator.dupe(u8, child.path);
                if (existing_category != null) {
                    try ignore_list.add(existing_category.?, child_path);
                    allocator.free(category);
                } else {
                    try ignore_list.add(category, child_path);
                }
                try ignore_list.commit_changes();
                // try stdin.writer().print("|{s}|", .{category.?});
                break;
            },
            'u' => {
                child = child.parent orelse root;
                try stdout.writer().print("Move up {s}\n", .{child});
            },
            's' => {
                break;
            },
            else => {},
        }
    }
    // const x = Result{ .path = "a" };
    // var map = std.ArrayHashMap([]u8, std.ArrayList([]u8), , false).init(allocator);
    // map.put("kde", .{ "test1", "test2" });
    // std.json.
    // std.json.stringify(value: anytype, options: StringifyOptions, out_stream: anytype)
    // const map = std.StringHashMap([]u8).init(allocator);
    // defer map.deinit();
    // map.put("a", "b");
    // map.ctx
    // try ignore_list.add("kde", "fuck");
    // try ignore_list.add("kde", "test");
    // try ignore_list.add("xorg", "test");
    // try ignore_list.print(stdout.writer());
}

const IgnoreList = struct {
    data: std.StringHashMap(std.ArrayList([]u8)),
    allocator: std.mem.Allocator,
    home_path: []const u8,

    fn init(allocator: std.mem.Allocator, home_path: []const u8) !IgnoreList {
        const data = std.StringHashMap(std.ArrayList([]u8)).init(allocator);
        var self: IgnoreList = .{ .data = data, .allocator = allocator, .home_path = home_path };
        const content = try std.fs.cwd().readFileAlloc(allocator, "ignore.json", 10000);
        defer allocator.free(content);

        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
        defer parsed.deinit();

        var iterator = parsed.value.object.iterator();
        while (iterator.next()) |entry| {
            // std.debug.print("{s}:\n", .{entry.key_ptr.*});
            // std.debug.print("{}", .{@TypeOf(entry.value_ptr.array)});
            const category = try std.fmt.allocPrint(allocator, "{s}", .{entry.key_ptr.*});
            for (entry.value_ptr.array.items) |value| {
                // std.debug.print("\t{s}\n", .{value.string});
                // _ = home_path;
                const result = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.home_path, value.string[1..] });
                try self.add(category, result);
            }
        }
        return self;
    }

    fn add(self: *IgnoreList, category: []const u8, path: []u8) !void {
        std.debug.print("{} {s}\n", .{ &category, category });
        var entry = try self.data.getOrPutValue(category, std.ArrayList([]u8).init(self.allocator));
        return entry.value_ptr.append(path);
    }

    fn print(self: IgnoreList, writer: anytype) !void {
        var iterator = self.data.iterator();
        while (iterator.next()) |entry| {
            try writer.print("{s}:\n", .{entry.key_ptr.*});
            for (entry.value_ptr.items) |value| {
                try writer.print("\t{s}\n", .{value});
            }
        }
    }

    pub fn jsonStringify(self: IgnoreList, jws: anytype) !void {
        try jws.beginObject();
        var iterator = self.data.iterator();
        while (iterator.next()) |entry| {
            // try jws.beginObject();
            try jws.objectField(entry.key_ptr.*);
            // try jw.beginArray();
            // try jws.write(123);
            // try jws.objectField(entry.key_ptr.*);
            // try jws.write("a");
            // try writer.print("{s}:\n", .{entry.key_ptr.*});
            // try jws.valueStart();
            try jws.beginArray();
            for (entry.value_ptr.items) |value| {
                try jws.print("\"~{s}\"", .{value[self.home_path.len..]});
            }
            try jws.endArray();
            // try jws.valueEnd();
            // try jws.endObject();
        }
        // try jws.objectField(self.);
        // _ = self;
        // var it = self.map.iterator();
        // while (it.next()) |kv| {
        //     try jws.objectField(kv.key_ptr.*);
        //     try jws.write(kv.value_ptr.*);
        // }
        try jws.endObject();
    }

    fn commit_changes(self: IgnoreList) !void {
        const file = try std.fs.cwd().createFile("ignore.json", .{});
        defer file.close();
        try std.json.stringify(self, .{ .whitespace = .indent_2 }, file.writer());
    }

    fn is_category_exist(self: IgnoreList, string: []const u8) ?[]const u8 {
        var iterator = self.data.iterator();
        while (iterator.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, string)) {
                return entry.key_ptr.*;
            }
        }
        return null;
    }

    fn deinit(self: *IgnoreList) void {
        var iterator = self.data.iterator();
        while (iterator.next()) |entry| {
            for (entry.value_ptr.items) |item| {
                self.allocator.free(item);
            }
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit();
        }
        self.data.deinit();
    }

    /// You need deinit ArrayList it by youself
    fn get_flat_ignore_list(self: IgnoreList, allocator: std.mem.Allocator) !std.ArrayList([]u8) {
        var result = std.ArrayList([]u8).init(allocator);
        var iterator = self.data.iterator();
        while (iterator.next()) |entry| {
            for (entry.value_ptr.items) |value| {
                try result.append(value);
            }
        }
        return result;
    }
};
