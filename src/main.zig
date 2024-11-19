const std = @import("std");

const print = std.debug.print;

const Entry = struct {
    path: []const u8,
    kind: std.fs.File.Kind,
    count: i32,
    children: std.ArrayList(*Entry),
    parent: ?*Entry,

    pub fn init(allocator: std.mem.Allocator, path: []const u8, kind: std.fs.File.Kind, parent: ?*Entry) !*Entry {
        var self = try allocator.create(Entry);

        self.* = Entry{
            .path = path,
            .kind = kind,
            .count = 1,
            .children = std.ArrayList(*Entry).init(allocator),
            .parent = parent,
        };

        if (self.kind != std.fs.File.Kind.directory) {
            return self;
        }

        var dir = std.fs.openDirAbsolute(self.path, .{ .iterate = true }) catch return self;
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |item| {
            // print("{}\n", .{&self});
            const child = try Entry.init(allocator, try std.fs.path.join(allocator, &[_][]const u8{ self.path, item.name }), item.kind, self);
            try self.children.append(child);
            self.count += child.count;
        }

        // print("{}\n", .{self});

        std.mem.sort(*Entry, self.children.items, {}, cmp);

        return self;
    }

    fn cmp(_: void, self: *Entry, other: *Entry) bool {
        return self.count > other.count;
    }

    pub fn deinit(self: *Entry, allocator: std.mem.Allocator) void {
        for (self.children.items) |item| {
            item.deinit(allocator);
        }
        self.children.deinit();
        allocator.destroy(self);
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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const home_path = std.posix.getenv("HOME").?;

    var structure = try Entry.init(allocator, home_path, std.fs.File.Kind.directory, null);
    defer structure.deinit(allocator);
    var child: *Entry = structure;
    // try stdout.writer().print("{}\n", .{child});
    // child = child.children.items[0];
    // try stdout.writer().print("{}\n", .{child});
    // child = child.children.items[0];
    // try stdout.writer().print("{}\n", .{child});
    while (true) {
        if (child.count > 1) {
            child = child.children.items[0];
            try stdout.writer().print("{s}\n", .{child});
        } else {
            break;
        }
    }
    while (true) {
        try stdout.writer().writeAll("What to do. Move up (u), Add (a): ");
        // var buffer: [100]u8 = undefined;
        const input = try stdin.reader().readByte();
        switch (input) {
            'a' => {
                try stdout.writer().print("Add {s} to ignore list\n", .{child.path});
                break;
            },
            'u' => {
                // try stdout.writer().print("Move up {s}\n", .{child.path});
                child = child.parent orelse continue;
                try stdout.writer().print("Move up {s}\n", .{child});
            },
            else => {},
        }
    }
    // try stdout.writer().writeByte(a);
    // for (structure.children.items) |item| {
    //     print("{}\n", .{item});
    // }
    // print("{any}\n", .{structure});

    // defer home_dir.close();
    // var iter = home_dir.iterate();
    //
    // while (try iter.next()) |item| {
    //     // var new_entry = Entry{ .path = undefined, .kind = entry.kind };
    //     try structure.append(Entry.init(allocator, try std.fs.path.join(allocator, &[_][]const u8{ home_path, item.name }), item.kind));
    //
    //     // print("{s} {}\n", .{ entry.name, entry.kind });
    // }
    //
    // print("{any}\n", .{structure.items});
    //
    // for (structure.items) |item| {
    //     item.deinit();
    // }
}
