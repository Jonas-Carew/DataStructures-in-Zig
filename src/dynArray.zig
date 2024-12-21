const std = @import("std");

const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn DynArray(comptime T: type) type {
    return struct {

        // Defintions
        const DynArrayError = error{
            IndexOutOfBounds,
        };

        const Self = @This();

        _allocator: Allocator,
        _capacity: usize,
        _size: usize,
        _data: []T,

        pub fn init(allocator: Allocator) Self {
            return .{
                ._allocator = allocator,
                ._capacity = 0,
                ._size = 0,
                ._data = undefined,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self._capacity > 0) {
                self._allocator.free(self._data);
            }
        }

        pub fn toOwnedStr(
            self: Self,
            prn: *const fn (allo: Allocator, v: T) anyerror![]u8,
        ) ![]u8 {
            // empty array case
            if (self._size == 0) return try std.fmt.allocPrint(self._allocator, "", .{});
            // special first case
            var text: []u8 = try prn(self._allocator, self._data[0]);
            var disp: []u8 = try std.fmt.allocPrint(self._allocator, "{s}", .{text});
            self._allocator.free(text);
            var disp_free: []u8 = undefined;
            // loop for remaining indices
            for (1..self._size) |idx| {
                disp_free = disp;
                text = try prn(self._allocator, self._data[idx]);
                disp = try std.fmt.allocPrint(
                    self._allocator,
                    "{s}, {s}",
                    .{ disp, text },
                );
                self._allocator.free(text);
                self._allocator.free(disp_free);
            }
            return disp;
        }

        pub fn size(self: Self) usize {
            _ = self;
            return 0;
        }

        pub fn insert(self: *Self, value: T) !void {
            if (self._capacity == 0) {
                self._capacity = 1;
                self._data = try self._allocator.alloc(T, 1);
            }
            if (self._size >= self._capacity) {
                self._capacity *= 2;
                var new_data: []T = try self._allocator.alloc(T, self._capacity);
                // self._data is only null if capacity is 0
                for (self._data, 0..) |data, idx| {
                    new_data[idx] = data;
                }
                self._allocator.free(self._data);
                self._data = new_data;
            }
            self._data[self._size] = value;
            self._size += 1;
        }

        pub fn get(self: Self, pos: usize) !T {
            if ((pos >= self._size) or (pos < 0)) return DynArrayError.IndexOutOfBounds;
            return self._data[pos];
        }

        pub fn remove(self: *Self, pos: usize) !T {
            if ((pos >= self._size) or (pos < 0)) return DynArrayError.IndexOutOfBounds;

            const val: T = self._data[pos];

            self._size -= 1;
            for (pos..self._size) |idx| {
                self._data[idx] = self._data[idx + 1];
            }

            return val;
        }

        pub fn set(self: *Self, pos: usize, value: T) !void {
            if ((pos >= self._size) or (pos < 0)) return DynArrayError.IndexOutOfBounds;
            self._data[pos] == value;
        }
    };
}

// Full Test
test "DynArray" {
    // init the Arena Allocator and GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer testing.expect(gpa.deinit() != .leak) catch @panic("MEMORY LEAK");

    // Set the used allocator
    const allo = gpa.allocator();

    // Test Creating a List
    var da = DynArray(i32).init(allo);
    defer da.deinit();

    try da.insert(5);
    try da.insert(10);
    try da.insert(20);

    try testing.expect(da._capacity == 4);

    const prn = struct {
        fn prn(a: Allocator, v: i32) ![]u8 {
            return try std.fmt.allocPrint(a, "{d}", .{v});
        }
    }.prn;

    const str: []u8 = try da.toOwnedStr(prn);
    defer allo.free(str);
    try testing.expect(std.mem.eql(u8, str, "5, 10, 20"));

    const rem1: i32 = try da.remove(0);
    try testing.expect(rem1 == 5);

    const str1: []u8 = try da.toOwnedStr(prn);
    defer allo.free(str1);
    try testing.expect(std.mem.eql(u8, str1, "10, 20"));

    const rem2: i32 = try da.remove(0);
    try testing.expect(rem2 == 10);
    const rem3: i32 = try da.remove(0);
    try testing.expect(rem3 == 20);

    const str2: []u8 = try da.toOwnedStr(prn);
    defer allo.free(str2);
    try testing.expect(std.mem.eql(u8, str2, ""));
}
