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

        pub fn push(self: *Self, value: T) !void {
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

        pub fn position(self: Self, value: T, cmp: *const fn (a: T, b: T) bool) ?u32 {
            var node: ?*Node = self.private.head;
            var i: u32 = 0;
            while (node != null) : ({
                node = node.?.next;
                i += 1;
            }) {
                if (cmp(node.?.value, value)) return i;
            }
            return null;
        }
    };
}

test "List" {
    // init the Arena Allocator and GPA
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) testing.expect(false) catch @panic("TEST FAIL");
    }

    // Set the used allocator
    const allocator = arena.allocator();

    // Test Creating a List
    var list = List(i32).create(allocator);
    try testing.expect(list.private.head == null);

    // Test pushing to a List
    try list.push(1);
    try list.push(3);
    try list.push(2);
    try testing.expect(list.private.head != null);
    try testing.expect(list.private.head.?.value == 2);

    // Test popping from a List
    const pop: i32 = try list.pop();
    try testing.expect(pop == 2);

    // Test finding a position in a List
    const cmp = struct {
        fn cmp(a: i32, b: i32) bool {
            return a == b;
        }
    }.cmp;
    const pos3: ?u32 = list.position(3, cmp);
    try testing.expect(pos3.? == 0);
    const pos2: ?u32 = list.position(2, cmp);
    try testing.expect(pos2 == null);
}
