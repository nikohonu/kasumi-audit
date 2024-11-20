const std = @import("std");

const KnownList = @This();
data: std.StringHashMap(std.ArrayList([]u8)),
allocator: std.mem.Allocator,
home_path: []const u8,

pub fn init(allocator: std.mem.Allocator, home_path: []const u8) !KnownList {
    const data = std.StringHashMap(std.ArrayList([]u8)).init(allocator);
    var self: KnownList = .{ .data = data, .allocator = allocator, .home_path = home_path };
    const content = try std.fs.cwd().readFileAlloc(allocator, "ignore.json", 10000);
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
    defer parsed.deinit();

    var iterator = parsed.value.object.iterator();
    while (iterator.next()) |entry| {
        const category = try std.fmt.allocPrint(allocator, "{s}", .{entry.key_ptr.*});
        for (entry.value_ptr.array.items) |value| {
            const result = try std.fmt.allocPrint(allocator, "{s}{s}", .{ self.home_path, value.string[1..] });
            try self.add(category, result);
        }
    }
    return self;
}

pub fn add(self: *KnownList, category: []const u8, path: []u8) !void {
    // std.debug.print("{} {s}\n", .{ &category, category });
    var entry = try self.data.getOrPutValue(category, std.ArrayList([]u8).init(self.allocator));
    return entry.value_ptr.append(path);
}

fn print(self: KnownList, writer: anytype) !void {
    var iterator = self.data.iterator();
    while (iterator.next()) |entry| {
        try writer.print("{s}:\n", .{entry.key_ptr.*});
        for (entry.value_ptr.items) |value| {
            try writer.print("\t{s}\n", .{value});
        }
    }
}

pub fn jsonStringify(self: KnownList, jws: anytype) !void {
    try jws.beginObject();
    var iterator = self.data.iterator();
    while (iterator.next()) |entry| {
        try jws.objectField(entry.key_ptr.*);
        try jws.beginArray();
        for (entry.value_ptr.items) |value| {
            try jws.print("\"~{s}\"", .{value[self.home_path.len..]});
        }
        try jws.endArray();
    }
    try jws.endObject();
}

pub fn commit_changes(self: KnownList) !void {
    const file = try std.fs.cwd().createFile("ignore.json", .{});
    defer file.close();
    try std.json.stringify(self, .{ .whitespace = .indent_2 }, file.writer());
}

pub fn is_category_exist(self: KnownList, string: []const u8) ?[]const u8 {
    var iterator = self.data.iterator();
    while (iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, string)) {
            return entry.key_ptr.*;
        }
    }
    return null;
}

pub fn deinit(self: *KnownList) void {
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
pub fn get_flat_ignore_list(self: KnownList, allocator: std.mem.Allocator) !std.ArrayList([]u8) {
    var result = std.ArrayList([]u8).init(allocator);
    var iterator = self.data.iterator();
    while (iterator.next()) |entry| {
        for (entry.value_ptr.items) |value| {
            try result.append(value);
        }
    }
    return result;
}
