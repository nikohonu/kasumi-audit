const std = @import("std");

const KnownList = @import("known_list.zig");
const Memory = @import("memory.zig");

pub const Kind = std.fs.File.Kind;

const Entry = @This();

path: []const u8,
kind: Kind,
parent: ?*Entry,
children: std.ArrayList(*Entry),
count: i32,
allocator: std.mem.Allocator,
// Keep track of all paths that was allocated, by Entry
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
        if (known_list.skip_needed(item_path)) {
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
    Memory.free_array_list_of_strings(self.allocator, &self.paths);
    // Free all children
    Memory.free_array_list_of_item(*Entry, &self.children);

    // Free youself
    self.allocator.destroy(self);
}

fn less_than(_: void, self: *Entry, other: *Entry) bool {
    return self.count > other.count;
}

pub fn get_parent_name(self: Entry) ?[]const u8 {
    const dirname = std.fs.path.dirname(self.path) orelse return null;
    return std.fs.path.basename(dirname);
}
