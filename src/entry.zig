const std = @import("std");

const Entry = @This();

path: []const u8,
kind: std.fs.File.Kind,
count: i32,
children: std.ArrayList(*Entry),
parent: ?*Entry,
allocator: std.mem.Allocator,

fn is_string_in_array(array: std.ArrayList([]u8), string: []const u8) bool {
    for (array.items) |item| {
        if (std.mem.eql(u8, item, string)) {
            return true;
        }
    }
    return false;
}

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
            // std.debug.print("Skip {s}\n", .{child_path});
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
