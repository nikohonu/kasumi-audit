const std = @import("std");

const print = std.debug.print;

pub fn main() !void {
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();

    const home_path = std.posix.getenv("HOME").?;

    const current_dir = std.fs.cwd();

    var home_dir = try current_dir.openDir(home_path, .{ .iterate = true });
    defer home_dir.close();
    var iter = home_dir.iterate();

    while (try iter.next()) |entry| {
        print("{s} {}\n", .{ entry.name, entry.kind });
    }
}
