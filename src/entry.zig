const std = @import("std");

const KnownList = @import("known_list.zig");

pub const Kind = std.fs.File.Kind;

const Entry = @This();

path: []const u8,
kind: Kind,
parent: ?*Entry,
children: std.ArrayList(*Entry),
count: i32,
allocator: std.mem.Allocator,
// Keep track of all path that was allocated, by Entry
paths: std.ArrayList([]const u8),

pub fn init(allocator: std.mem.Allocator, known_list: *KnownList, path: []const u8, kind: Kind, parent: ?*Entry) !*Entry {
    const self = try allocator.create(Entry);
    self.* = Entry{
        .allocator = allocator,
        .path = path,
        .kind = kind,
        .parent = parent,
        .children = std.ArrayList(*Entry).init(allocator),
        .count = 1,
        .paths = std.ArrayList([]const u8).init(allocator),
    };

    if (self.kind != Kind.directory) {
        return self;
    }

    var dir = std.fs.openDirAbsolute(self.path, .{ .iterate = true }) catch return self;
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |item| {
        const item_path = try std.fs.path.join(allocator, &[_][]const u8{ self.path, item.name });
        if (known_list.is_path_know(item_path)) {
            allocator.free(item_path);
            continue;
        } else {
            try self.paths.append(item_path);
            const child = try Entry.init(allocator, known_list, item_path, item.kind, self);
            try self.children.append(child);
            self.count += child.count;
        }
    }

    std.mem.sort(*Entry, self.children.items, {}, less_than);

    return self;
}

pub fn deinit(self: *Entry) void {
    // Free all paths
    for (self.paths.items) |path| {
        self.allocator.free(path);
    }
    self.paths.deinit();

    // Free all children
    for (self.children.items) |child| {
        child.deinit();
    }
    self.children.deinit();

    // Free youself
    self.allocator.destroy(self);
}

fn less_than(_: void, self: *Entry, other: *Entry) bool {
    return self.count > other.count;
}

// pub fn format(
//     self: Entry,
//     comptime _: []const u8,
//     _: std.fmt.FormatOptions,
//     writer: anytype,
// ) !void {
//     _ = try writer.print("{{ path: {s}, kind: {}, count: {}}}", .{ self.path, self.kind, self.count });
// }
