const std = @import("std");

const IO = @This();

pub const Reader = std.fs.File.Reader;
pub const Writer = std.fs.File.Writer;

allocator: std.mem.Allocator,
reader: Reader,
writer: Writer,

pub fn init(allocator: std.mem.Allocator) IO {
    return .{
        .allocator = allocator,
        .writer = std.io.getStdOut().writer(),
        .reader = std.io.getStdIn().reader(),
    };
}

pub fn deinit(self: IO) void {
    _ = self;
}

pub fn get_char(self: IO) !u8 {
    const input = try self.reader.readByte();

    var input_more_than_one_char = false;
    while (try self.reader.readByte() != '\n') {
        input_more_than_one_char = true;
    }
    if (input_more_than_one_char) {
        return error.InputMoreThanOneChar;
    }

    return input;
}

/// You must free given memory!
pub fn get_string(self: IO) ![]const u8 {
    var input = std.ArrayList(u8).init(self.allocator);
    defer input.deinit();
    var char: u8 = try self.reader.readByte();
    while (char != '\n') {
        try input.append(char);
        char = try self.reader.readByte();
    }
    return try self.allocator.dupe(u8, input.items);
}

pub fn print(self: IO, comptime fmt: []const u8, args: anytype) !void {
    try self.writer.print(fmt, args);
}

pub fn println(self: IO, comptime fmt: []const u8, args: anytype) !void {
    try self.print(fmt, args);
    try self.print("\n", .{});
}

pub fn print_string(self: IO, string: []const u8) !void {
    try self.print("{s}", .{string});
}

pub fn println_string(self: IO, string: []const u8) !void {
    try self.println("{s}", .{string});
}
