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

pub fn get_home(_: BaseDirectory) []const u8 {
    return std.posix.getenv("HOME").?;
}

pub fn get_data_home(self: *BaseDirectory) ![]const u8 {
    if (self.data_home) |data_home| {
        return data_home;
    } else {
        const xdg_data_home = std.posix.getenv("XDG_DATA_HOME");
        if (xdg_data_home) |path| {
            // XDG_DATA_HOME is set
            self.data_home = try self.allocator.dupe(u8, path);
        } else {
            // XDG_DATA_HOME is not set
            self.data_home = try std.fs.path.join(
                self.allocator,
                &[_][]const u8{ self.get_home(), ".local/share" },
            );
        }
        return self.data_home.?;
    }
}

/// You must free given memory!
pub fn get_data_home_app(self: *BaseDirectory, app: []const u8) ![]const u8 {
    return try std.fs.path.join(
        self.allocator,
        &[_][]const u8{ try self.get_data_home(), app },
    );
}

pub fn deinit(self: *BaseDirectory) void {
    if (self.data_home) |data_home| {
        self.allocator.free(data_home);
    }
}
