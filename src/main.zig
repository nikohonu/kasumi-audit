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

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

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
    var child: *Entry = root;
    while (true) {
        if (child.count > 1) {
            child = child.children.items[0];
            try stdout.print("{s} - {}\n", .{ child.path, child.count });
        } else {
            break;
        }
    }

    // UI
    while (true) {
        try stdout.print(
            "Add (a), Next (n), Up (u), Quit (q): ",
            .{},
        );

        const action = get_char(stdin) catch |err|
            if (err == error.InputMoreThanOneChar) continue else return err;
        switch (action) {
            // Add
            'a' => {},
            // Next
            'n' => {},
            // Up
            'u' => {},
            // Quit
            'q' => break,
            // Non existing action
            else => continue,
        }
        //         switch (input) {
        //             // Add action
        //             'a' => {
        //                 try stdout.print(
        //                     "Add {s} to ignore list\n",
        //                     .{child.path},
        //                 );
        //
        //                 var buf: [128]u8 = undefined;
        //                 try stdout.print(
        //                     "Enter category of ignored path: ",
        //                     .{},
        //                 );
        //                 const user_input = try stdin.readUntilDelimiterOrEof(
        //                     &buf,
        //                     '\n',
        //                 );
        //
        //                 // Code that works, but I hate it
        //                 const category = try allocator.dupe(u8, user_input.?);
        //                 const existing_category = ignore_list.is_category_exist(
        //                     category,
        //                 );
        //                 const child_path = try allocator.dupe(u8, child.path);
        //
        //                 if (existing_category != null) {
        //                     try ignore_list.add(existing_category.?, child_path);
        //                     allocator.free(category);
        //                 } else {
        //                     try ignore_list.add(category, child_path);
        //                 }
        //
        //                 try ignore_list.commit_changes();
        //                 break;
        //             },
        //             // Move up action
        //             'u' => {
        //                 child = child.parent orelse root;
        //                 try stdout.print("Move up {s}\n", .{child});
        //             },
        //             // Quit action
        //             's' => {
        //                 break;
        //             },
        //             // 'I don't know what to do' action
        //             else => {},
        //         }
        //     }
    }
}

fn get_char(reader: anytype) !u8 {
    const input = try reader.readByte();

    var input_more_than_one_char = false;
    while (try reader.readByte() != '\n') {
        input_more_than_one_char = true;
    }
    if (input_more_than_one_char) {
        return error.InputMoreThanOneChar;
    }

    return input;
}
