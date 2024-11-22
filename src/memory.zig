const std = @import("std");

pub fn free_array_list_of_strings(allocator: std.mem.Allocator, array_list: *std.ArrayList([]const u8)) void {
    for (array_list.items) |string| {
        allocator.free(string);
    }
    array_list.deinit();
}

/// Item must have deinit method
pub fn free_array_list_of_item(comptime T: type, array_list: *std.ArrayList(T)) void {
    for (array_list.items) |item| {
        item.deinit();
    }
    array_list.deinit();
}
