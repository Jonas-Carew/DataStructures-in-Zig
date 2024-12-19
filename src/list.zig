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
    print("\nCreating a List of i32...\n", .{});
    var list = List(i32).create(allocator);
    print("\t...List created successfully\n", .{});

    try testing.expect(list.private.head == null);
    print("\t...List head is null\n", .{});

    // Test pushing to a List
    print("\nPushing values to List...\n", .{});
    const values = [_]i32{ 1, 3, 2 };
    for (values) |n| {
        try list.push(n);
    }

    try testing.expect(list.private.head != null);
    print("\t...List head is not null\n", .{});

    try testing.expect(list.private.head.?.value == 2);
    print("\t...List head value is 2\n", .{});

    // Test popping from a List
    print("\nPopping first value from List...\n", .{});
    const pop: i32 = try list.pop();
    print("\t...First value popped\n", .{});

    try testing.expect(pop == 2);
    print("\t...Value popped is 2\n", .{});

    // Test finding a position in a List
    print("\nFinding positions of values in the List...\n", .{});
    // comparison function
    const cmp = struct {
        fn cmp(a: i32, b: i32) bool {
            return a == b;
        }
    }.cmp;

    const pos3: ?u32 = list.position(3, cmp);
    try testing.expect(pos3.? == 0);
    print("\t...Position of 3 is 0\n", .{});

    const pos2: ?u32 = list.position(2, cmp);
    try testing.expect(pos2 == null);
    print("\t...Position of 2 is null\n", .{});

    print("\n", .{});
}
