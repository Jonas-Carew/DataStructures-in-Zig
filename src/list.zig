const std = @import("std");

const print = std.debug.print;
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

        // constructor for the List
        pub fn create(allocator: Allocator) Self {
            return .{
                .private = impl{
                    .head = null,
                },
                .allocator = allocator,
            };
        }

        // List push
        pub fn push(self: *Self, value: T) !void {
            var node = try self.allocator.create(Node);

            const head = self.private.head;
            node.value = value;
            node.next = head;

            self.private.head = node;
        }

        // List pop
        pub fn pop(self: *Self) !T {
            if (self.private.head == null) return ListError.PoppedEmptyList;

            const node: *Node = self.private.head.?;
            defer self.allocator.destroy(node);
            self.private.head = node.next;
            return node.value;
        }

        // position in List
        pub fn position(self: Self, value: T, cmp: *const fn (a: T, b: T) bool) ?u32 {
            var node: ?*Node = self.private.head;
            var i: u32 = 0;
            while (node) |current| : (i += 1) {
                if (cmp(current.value, value)) return i;
                node = current.next;
            }
            return null;
        }

        // clear list
        pub fn free(self: *Self) void {
            var node: ?*Node = self.private.head;
            while (node) |current| {
                const next = current.next;
                self.allocator.destroy(current);
                node = next;
            }
        }
    };
}

test "List" {
    const mhead = @import("test.zig").mhead;
    const mtest = @import("test.zig").mtest;

    // init the Arena Allocator and GPA
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) testing.expect(false) catch @panic("MEMORY LEAK");
    }

    // Set the used allocator
    const allocator = gpa.allocator();

    // Test Creating a List
    mhead("Creating a List");
    var list = List(i32).create(allocator);

    try testing.expect(list.private.head == null);
    mtest("List head is null");

    // Test pushing to a List
    mhead("Pushing values to List");
    const values = [_]i32{ 1, 3, 2 };

    for (values) |n| {
        try list.push(n);
    }
    mtest("Values pushed to List");

    try testing.expect(list.private.head != null);
    mtest("List head is not null");

    try testing.expect(list.private.head.?.value == 2);
    mtest("List head value is 2");

    // Test popping from a List
    mhead("Popping first value from List");
    const pop: i32 = try list.pop();
    mtest("First value popped");

    try testing.expect(pop == 2);
    mtest("Value popped is 2");

    // Test finding a position in a List
    mhead("Finding positions of values in the List");
    // comparison function
    const cmp = struct {
        fn cmp(a: i32, b: i32) bool {
            return a == b;
        }
    }.cmp;

    const pos3: ?u32 = list.position(3, cmp);
    try testing.expect(pos3.? == 0);
    mtest("Position of 3 is 0");

    const pos2: ?u32 = list.position(2, cmp);
    try testing.expect(pos2 == null);
    mtest("Position of 2 is null");

    mhead("Freeing List");
    list.free();
    mtest("List freed");

    print("\n", .{});
}
