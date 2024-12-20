const std = @import("std");

const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn Dynarray(comptime T: type) type {
    return struct {

        // Defintions
        const DynArrayError = error{
            PoppedEmptyList,
            IndexOutOfBounds,
        };

        const Self = @This();

        _allocator: Allocator,
        _capacity: usize,
        _size: usize,
        _data: ?[]T,

        pub fn init(allocator: Allocator) Self {
            return .{
                ._allocator = allocator,
                ._capacity = 0,
                ._size = 0,
                ._data = null,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self._data != null) {
                self._allocator.free(self._data.?);
            }
        }

        pub fn display(
            self: Self,
            prn: *const fn (v: T, allo: Allocator) anyerror![]u8,
        ) ![]u8 {
            const data = self._data orelse return "";

            var text: []u8 = try prn(data[0], self._allocator);
            var disp: []u8 = try std.fmt.allocPrint(self._allocator, "{s}", .{text});
            self._allocator.free(text);

            var disp_free: []u8 = undefined;
            for (1..self._size) |idx| {
                disp_free = disp;
                text = try prn(data[idx], self._allocator);
                disp = try std.fmt.allocPrint(self._allocator, "{s}, {s}", .{ disp, text });
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
                for (self._data.?, 0..) |data, idx| {
                    new_data[idx] = data;
                }
                self._allocator.free(self._data.?);
                self._data = new_data;
            }
            self._data.?[self._size] = value;
            self._size += 1;
        }

        pub fn get(self: Self, pos: usize) !T {
            _ = self;
            _ = pos;
            return error{};
        }

        pub fn remove(self: *Self, pos: usize) !T {
            _ = self;
            _ = pos;
            return error{};
        }

        pub fn set(self: *Self, pos: usize) !void {
            _ = self;
            _ = pos;
            return error{};
        }
    };
}

// Full Test
test "Dynarray" {
    // init the Arena Allocator and GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer testing.expect(gpa.deinit() != .leak) catch @panic("MEMORY LEAK");

    // Set the used allocator
    const allo = gpa.allocator();

    // Test Creating a List
    var da = Dynarray(i32).init(allo);
    defer da.deinit();

    try da.insert(5);
    try da.insert(10);
    try da.insert(20);

    const prn = struct {
        fn prn(v: i32, a: Allocator) ![]u8 {
            return try std.fmt.allocPrint(a, "{}", .{v});
        }
    }.prn;

    const disp: []u8 = try da.display(prn);
    defer allo.free(disp);
    std.debug.print("{s}\n", .{disp});
}
