const std = @import("std");
const List = @import("list.zig").List;

const testing = std.testing;

pub fn Stack(comptime T: type) type {
    return struct {
        const Self = @This();

        _list: List(T),
        _allocator: std.mem.Allocator,

        pub fn init(allo: std.mem.Allocator) Self {
            return Self{
                ._list = List(T).init(allo),
                ._allocator = allo,
            };
        }

        pub fn deinit(self: *Self) void {
            self._list.deinit();
        }

        pub fn isEmpty(self: Self) bool {
            return (self._list._head == null);
        }

        pub fn push(self: *Self, value: T) !void {
            try self._list.push(value);
        }

        pub fn top(self: Self) ?T {
            const node = self._list._head orelse return null;
            return node.value;
        }

        pub fn pop(self: *Self) ?T {
            return self._list.pop();
        }
    };
}

test "stack" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        testing.expect(deinit_status != .leak) catch @panic("MEMORY LEAK");
    }
    const allo = gpa.allocator();

    var stack = Stack(u8).init(allo);
    defer stack.deinit();

    try testing.expect(stack.isEmpty());
}
