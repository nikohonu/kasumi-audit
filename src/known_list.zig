const std = @import("std");
const BaseDirectory = @import("base_directory.zig");
const Memory = @import("memory.zig");

const KnownList = @This();

allocator: std.mem.Allocator,
hash_map: std.StringHashMap(std.ArrayList([]const u8)),
skip_list: std.ArrayList([]const u8),
known_file_path: []const u8,
home_path: []const u8,
// Keep track of all categories and paths that was allocated, by Entry
categories: std.ArrayList([]const u8),
paths: std.ArrayList([]const u8),

pub fn init(allocator: std.mem.Allocator, base_directory: *BaseDirectory) !KnownList {
    const hash_map = std.StringHashMap(std.ArrayList([]const u8)).init(allocator);

    const data_home_app = try base_directory.get_data_home_app("kasumi-audit");
    defer allocator.free(data_home_app);
    const known_file_path = try std.fs.path.join(
        allocator,
        &[_][]const u8{ data_home_app, "known.json" },
    );

    var self: KnownList = .{
        .allocator = allocator,
        .hash_map = hash_map,
        .skip_list = std.ArrayList([]const u8).init(allocator),
        .known_file_path = known_file_path,
        .categories = std.ArrayList([]const u8).init(allocator),
        .paths = std.ArrayList([]const u8).init(allocator),
        .home_path = base_directory.get_home(),
    };

    const content = std.fs.cwd().readFileAlloc(allocator, known_file_path, 10000) catch |err| switch (err) {
        error.FileNotFound => return self,
        else => return err,
    };
    defer allocator.free(content);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{});
    defer parsed.deinit();

    var iterator = parsed.value.object.iterator();
    while (iterator.next()) |entry| {
        const category = try std.fmt.allocPrint(
            allocator,
            "{s}",
            .{entry.key_ptr.*},
        );
        try self.categories.append(category);
        for (entry.value_ptr.array.items) |value| {
            const path = try std.fmt.allocPrint(
                allocator,
                "{s}{s}",
                .{ self.home_path, value.string[1..] },
            ); // free
            try self.paths.append(path);
            try self.add(category, path);
        }
    }
    return self;
}

pub fn deinit(self: *KnownList) void {
    // Free all categories
    Memory.free_array_list_of_strings(self.allocator, &self.categories);
    // Free all paths
    Memory.free_array_list_of_strings(self.allocator, &self.paths);
    // Free ArrayLists inside hash_map
    var iterator = self.hash_map.iterator();
    while (iterator.next()) |entry| {
        entry.value_ptr.deinit();
    }
    // Fre skip_list
    self.skip_list.deinit();
    self.allocator.free(self.known_file_path);
    self.hash_map.deinit();
}

pub fn add(self: *KnownList, category: []const u8, path: []const u8) !void {
    var entry = try self.hash_map.getOrPutValue(category, std.ArrayList([]const u8).init(self.allocator));
    return entry.value_ptr.append(path);
}

pub fn skip(self: *KnownList, path: []const u8) !void {
    try self.skip_list.append(path);
}

pub fn skip_needed(self: KnownList, path: []const u8) bool {
    var iterator = self.hash_map.iterator();
    const is_known = outer: while (iterator.next()) |entry| {
        for (entry.value_ptr.items) |item_path| {
            if (std.mem.eql(u8, item_path, path)) {
                break :outer true;
            }
        }
    } else false;
    const in_skip_list = for (self.skip_list.items) |item| {
        if (std.mem.eql(u8, item, path)) {
            break true;
        }
    } else false;
    return is_known or in_skip_list;
}

pub fn jsonStringify(self: KnownList, jws: anytype) !void {
    try jws.beginObject();
    var iterator = self.hash_map.iterator();
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

pub fn save(self: KnownList) !void {
    const parent = std.fs.path.dirname(self.known_file_path).?;
    std.fs.makeDirAbsolute(parent) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
    const file = try std.fs.createFileAbsolute(self.known_file_path, .{});
    defer file.close();
    try std.json.stringify(self, .{ .whitespace = .indent_2 }, file.writer());
}
