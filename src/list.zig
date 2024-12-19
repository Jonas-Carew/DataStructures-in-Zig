const std = @import("std");

const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn List(comptime T: type) type {
    return struct {

        // Defintions
        const ListError = error{
            PoppedEmptyList,
        };

        const Self = @This();

        const Node = struct {
            value: T,
            next: ?*Node,
        };

        // Private sector
        const impl = struct {
            head: ?*Node,
        };
        private: impl,

        // Public sector
        allocator: Allocator,

        pub fn create(allocator: Allocator) Self {
            return .{
                .private = impl{
                    .head = null,
                },
                .allocator = allocator,
            };
        }

        pub fn insert(self: *Self, value: T) !void {
            var node = try self.allocator.create(Node);

            const head = self.private.head;
            node.value = value;
            node.next = head;

            self.private.head = node;
        }

        pub fn pop(self: *Self) !T {
            if (self.private.head == null) return ListError.PoppedEmptyList;

            const node: *Node = self.private.head.?;
            defer self.allocator.destroy(node);
            self.private.head = node.next;
            return node.value;
        }
    };
}

test "List" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) testing.expect(false) catch @panic("TEST FAIL");
    }

    const allocator = arena.allocator();

    var list = List(u32).create(allocator);
    try testing.expect(list.private.head == null);

    try list.insert(1);
    try testing.expect(list.private.head != null);
    try testing.expect(list.private.head.?.value == 1);

    const x: u32 = try list.pop();
    try testing.expect(x == 1);
}
