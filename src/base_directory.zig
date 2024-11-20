const std = @import("std");

const BaseDirectory = @This();

allocator: std.mem.Allocator,
data_home: ?[]const u8,

pub fn init(allocator: std.mem.Allocator) BaseDirectory {
    return .{
        .allocator = allocator,
        .data_home = null,
    };
}

pub fn get_data_home(self: *BaseDirectory) []const u8 {
    if (self.data_home) |data_home| {
        return data_home;
    } else {
        self.data_home = "a b c"; // FIXME
        return self.data_home.?;
    }
}

pub fn deinit(self: *BaseDirectory) void {
    _ = self;
}
