const std = @import("std");
const expect = std.testing.expect;
const Entry = @import("entry.zig");
const KnownList = @import("known_list.zig");
const BaseDirectory = @import("base_directory.zig");
const IO = @import("io.zig");
const Memory = @import("memory.zig");

pub fn reinit_root(allocator: std.mem.Allocator, root: *Entry, known_list: *KnownList, home_path: []const u8) !*Entry {
    root.deinit();
    return try Entry.init(
        allocator,
        known_list,
        home_path,
        Entry.Kind.directory,
        null,
    );
}

pub fn get_deepest_child(root: *Entry, io: IO) !*Entry {
    var child: *Entry = root;
    while (true) {
        if (child.count > 1) {
            child = child.children.items[0];
            try io.println("{s} - {}", .{ child.path, child.count });
        } else break;
    }
    return child;
}

pub fn main() !void {
    // Arena - start
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();
    // Arena - end

    // GeneralPurposeAllocator - start
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) expect(false) catch @panic("TEST FAIL");
    }
    const allocator = gpa.allocator();
    // GeneralPurposeAllocator - end

    const io = IO.init(allocator);
    defer io.deinit();

    var base_directory = BaseDirectory.init(allocator);
    defer base_directory.deinit();

    var known_list = try KnownList.init(allocator, &base_directory);
    defer known_list.deinit();

    var root = try Entry.init(
        allocator,
        &known_list,
        base_directory.get_home(),
        Entry.Kind.directory,
        null,
    );
    defer root.deinit();

    // Get the deepest child
    var child: *Entry = try get_deepest_child(root, io);

    // Keep track of allcated categories and path inside loop
    var categories = std.ArrayList([]const u8).init(allocator);
    var paths = std.ArrayList([]const u8).init(allocator);

    // UI
    while (true) {
        try io.print(
            "Add (a), Next (n), Up (u), Down (d), Quit (q): ",
            .{},
        );

        const action = io.get_char() catch |err|
            if (err == error.InputMoreThanOneChar) continue else return err;
        switch (action) {
            // Add
            'a' => {
                const default = child.get_parent_name().?;
                try io.print("Enter category name ({s}): ", .{default});
                var category = try io.get_string();
                if (std.mem.eql(u8, category, "")) {
                    allocator.free(category);
                    category = try allocator.dupe(u8, default);
                }
                try categories.append(category);
                const path = try allocator.dupe(u8, child.path);
                try paths.append(path);
                try known_list.add(category, path);
                try known_list.save();
                root = try reinit_root(allocator, root, &known_list, base_directory.get_home());
                child = try get_deepest_child(root, io);
            },
            // Next
            'n' => {
                const path = try allocator.dupe(u8, child.path);
                try paths.append(path);
                try known_list.skip(path);
                root = try reinit_root(allocator, root, &known_list, base_directory.get_home());
                child = try get_deepest_child(root, io);
            },
            // Up
            'u' => {
                child = child.parent orelse root;
                try io.println("{s} - {}", .{ child.path, child.count });
            },
            // Down
            'd' => {
                if (child.count > 1) {
                    child = child.children.items[0];
                } else continue;
                try io.println("{s} - {}", .{ child.path, child.count });
            },
            // Quit
            'q' => break,
            // Non existing action
            else => continue,
        }
    }
    defer Memory.free_array_list_of_strings(allocator, &categories);
    defer Memory.free_array_list_of_strings(allocator, &paths);
}
