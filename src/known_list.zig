const std = @import("std");
const BaseDirectory = @import("base_directory.zig");

const KnownList = @This();

allocator: std.mem.Allocator,
hash_map: std.StringHashMap(std.ArrayList([]u8)),
known_file_path: []const u8,

pub fn init(allocator: std.mem.Allocator, base_directory: *BaseDirectory) !KnownList {
    const hash_map = std.StringHashMap(std.ArrayList([]u8)).init(allocator);

    const data_home_app = try base_directory.get_data_home_app("kasumi-audit");
    defer allocator.free(data_home_app);
    const known_file_path = try std.fs.path.join(
        allocator,
        &[_][]const u8{ data_home_app, "known.json" },
    );

    var self: KnownList = .{
        .allocator = allocator,
        .hash_map = hash_map,
        .known_file_path = known_file_path,
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
        ); // free
        for (entry.value_ptr.array.items) |value| {
            const result = try std.fmt.allocPrint(
                allocator,
                "{s}{s}",
                .{ base_directory.get_home(), value.string[1..] },
            ); // free
            try self.add(category, result);
        }
    }
    return self;
}

pub fn deinit(self: *KnownList) void {
    self.allocator.free(self.known_file_path);
    var iterator = self.hash_map.iterator();
    while (iterator.next()) |entry| {
        for (entry.value_ptr.items) |item| {
            self.allocator.free(item);
        }
        self.allocator.free(entry.key_ptr.*);
        entry.value_ptr.deinit();
    }
    self.hash_map.deinit();
}

pub fn add(self: *KnownList, category: []const u8, path: []u8) !void {
    // std.debug.print("{} {s}\n", .{ &category, category });
    var entry = try self.hash_map.getOrPutValue(category, std.ArrayList([]u8).init(self.allocator));
    return entry.value_ptr.append(path);
}

pub fn is_path_know(self: KnownList, path: []const u8) bool {
    var iterator = self.hash_map.iterator();
    while (iterator.next()) |entry| {
        for (entry.value_ptr.items) |item_path| {
            if (std.mem.eql(u8, item_path, path)) {
                return true;
            }
        }
    }
    return false;
}
//
// fn print(self: KnownList, writer: anytype) !void {
//     var iterator = self.data.iterator();
//     while (iterator.next()) |entry| {
//         try writer.print("{s}:\n", .{entry.key_ptr.*});
//         for (entry.value_ptr.items) |value| {
//             try writer.print("\t{s}\n", .{value});
//         }
//     }
// }
//
// pub fn jsonStringify(self: KnownList, jws: anytype) !void {
//     try jws.beginObject();
//     var iterator = self.data.iterator();
//     while (iterator.next()) |entry| {
//         try jws.objectField(entry.key_ptr.*);
//         try jws.beginArray();
//         for (entry.value_ptr.items) |value| {
//             try jws.print("\"~{s}\"", .{value[self.home_path.len..]});
//         }
//         try jws.endArray(); } try jws.endObject(); }
// pub fn commit_changes(self: KnownList) !void {
//     const file = try std.fs.cwd().createFile("ignore.json", .{});
//     defer file.close();
//     try std.json.stringify(self, .{ .whitespace = .indent_2 }, file.writer());
// }
//
// pub fn is_category_exist(self: KnownList, string: []const u8) ?[]const u8 {
//     var iterator = self.data.iterator();
//     while (iterator.next()) |entry| {
//         if (std.mem.eql(u8, entry.key_ptr.*, string)) {
//             return entry.key_ptr.*;
//         }
//     }
//     return null;
// }
//
//
// /// You need deinit ArrayList it by youself
// pub fn get_flat_ignore_list(self: KnownList, allocator: std.mem.Allocator) !std.ArrayList([]u8) {
//     var result = std.ArrayList([]u8).init(allocator);
//     var iterator = self.data.iterator();
//     while (iterator.next()) |entry| {
//         for (entry.value_ptr.items) |value| {
//             try result.append(value);
//         }
//     }
//     return result;
// }
