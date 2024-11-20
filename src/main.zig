const std = @import("std");
const expect = std.testing.expect;
const Entry = @import("entry.zig");
const KnownList = @import("known_list.zig");
const BaseDirectory = @import("base_directory.zig");

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

    var base_directory = BaseDirectory.init(allocator);
    defer base_directory.deinit();

    // std.debug.print("{s}\n", .{base_directory.get_data_home()});
    // std.debug.print("{s}\n", .{base_directory.get_data_home()});
    try oldmain(allocator);
}

pub fn oldmain(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    const home_path = std.posix.getenv("HOME").?;

    var ignore_list = try KnownList.init(allocator, home_path);
    defer ignore_list.deinit();

    const flat_ignore_list = try ignore_list.get_flat_ignore_list(allocator);
    defer flat_ignore_list.deinit();

    // I need to copy home_path to the heap because other paths are stored
    // there, and I can't free them if one of them is not on the heap.
    var root = try Entry.init(
        allocator,
        try allocator.dupe(u8, home_path),
        std.fs.File.Kind.directory,
        null,
        flat_ignore_list,
    );
    defer root.deinit();

    var child: *Entry = root;

    // Find first child of first child and so on, until reach end
    while (true) {
        if (child.count > 1) {
            child = child.children.items[0];
            try stdout.print("{s}\n", .{child});
        } else {
            break;
        }
    }

    // UI
    while (true) {
        try stdout.print(
            "What to do. Move up (u), Add (a), Skip(s): ",
            .{},
        );
        const input = try stdin.readByte();

        // Read all remain characters
        while (try stdin.readByte() != '\n') {}

        switch (input) {
            // Add action
            'a' => {
                try stdout.print(
                    "Add {s} to ignore list\n",
                    .{child.path},
                );

                var buf: [128]u8 = undefined;
                try stdout.print(
                    "Enter category of ignored path: ",
                    .{},
                );
                const user_input = try stdin.readUntilDelimiterOrEof(
                    &buf,
                    '\n',
                );

                // Code that works, but I hate it
                const category = try allocator.dupe(u8, user_input.?);
                const existing_category = ignore_list.is_category_exist(
                    category,
                );
                const child_path = try allocator.dupe(u8, child.path);

                if (existing_category != null) {
                    try ignore_list.add(existing_category.?, child_path);
                    allocator.free(category);
                } else {
                    try ignore_list.add(category, child_path);
                }

                try ignore_list.commit_changes();
                break;
            },
            // Move up action
            'u' => {
                child = child.parent orelse root;
                try stdout.print("Move up {s}\n", .{child});
            },
            // Quit action
            's' => {
                break;
            },
            // 'I don't know what to do' action
            else => {},
        }
    }
}
