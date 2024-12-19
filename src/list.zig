const std = @import("std");

const print = std.debug.print;
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn List(comptime T: type) type {
    return struct {

        // Defintions
        const ListError = error{
            PoppedEmptyList,
            IndexOutOfBounds,
        };

        const Self = @This();

        const Node = struct {
            value: T,
            next: ?*Node,
        };

        // Private sector
        const impl = struct {
            head: ?*Node,
            allocator: Allocator,
        };
        private: impl,

        // Public sector

        // constructor for the List
        pub fn create(allocator: Allocator) Self {
            return .{
                .private = impl{
                    .head = null,
                    .allocator = allocator,
                },
            };
        }

        // free entire list
        pub fn free(self: *Self) void {
            var node: ?*Node = self.private.head;
            while (node) |current| {
                const next = current.next;
                self.private.allocator.destroy(current);
                node = next;
            }
        }

        // print list
        pub fn display(self: Self) void {
            var node: *Node = self.private.head orelse return;
            print("{}", .{node.value});
            while (node.next) |current| {
                print(", {}", .{current.value});
                node = current;
            }
        }

        pub fn length(self: Self) u32 {
            var i: u32 = 0;
            var node: ?*Node = self.private.head;
            while (node) |current| {
                node = current.next;
                i += 1;
            }
            return i;
        }

        // List push
        pub fn push(self: *Self, value: T) !void {
            var node = try self.private.allocator.create(Node);

            const head = self.private.head;
            node.value = value;
            node.next = head;

            self.private.head = node;
        }

        // List pop
        pub fn pop(self: *Self) !T {
            const node: *Node = self.private.head orelse return ListError.PoppedEmptyList;
            defer self.private.allocator.destroy(node);
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

        pub fn insert(self: *Self, value: T, pos: u32) !void {
            if (pos == 0) return push(self, value);
            // pos > 0
            var next_node: ?*Node = self.private.head;
            var prev_node: *Node = next_node orelse return ListError.IndexOutOfBounds;
            for (0..pos) |_| {
                prev_node = next_node orelse return ListError.IndexOutOfBounds;
                next_node = prev_node.next;
            }
            const node = try self.private.allocator.create(Node);
            prev_node.next = node;
            node.value = value;
            node.next = next_node;
        }

        pub fn remove_pos(self: *Self, pos: u32) !T {
            if (pos == 0) return pop(self);
            // pos > 0
            var node: *Node = self.private.head orelse return ListError.IndexOutOfBounds;
            var prev_node: *Node = node;
            for (0..pos) |_| {
                prev_node = node;
                node = node.next orelse return ListError.IndexOutOfBounds;
            }
            prev_node.next = node.next;
            const value: T = node.value;
            self.private.allocator.destroy(node);
            return value;
        }

        pub fn remove_val(self: *Self, value: T) bool {
            var node: *Node = self.private.head orelse return false;
            if (node.value == value) {
                self.private.head = node.next;
                self.private.allocator.destroy(node);
                return true;
            }
            while (node.next) |next_node| {
                if (next_node.value == value) {
                    node.next = next_node.next;
                    self.private.allocator.destroy(next_node);
                    return true;
                }
                node = next_node;
            }
            return false;
        }
    };
}

// Full Test
test "List" {
    const mhead = @import("test.zig").mhead;
    const mtest = @import("test.zig").mtest;

    // init the Arena Allocator and GPA
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        testing.expect(deinit_status != .leak) catch @panic("MEMORY LEAK");
    }

    // Set the used allocator
    const allocator = gpa.allocator();

    // Test Creating a List
    mhead("Creating a List");
    var list = List(i32).create(allocator);
    defer list.free();

    try testing.expect(list.private.head == null);
    mtest("List head is null");
    try testing.expect(list.length() == 0);
    mtest("List length is 0");

    // Test pushing to a List
    mhead("Pushing values to List");
    var i: i32 = 10;
    while (i >= 0) : (i -= 1) {
        try list.push(std.math.pow(i32, -2, i));
    }
    mtest("Values pushed to List");

    try testing.expect(list.length() == 11);
    mtest("List length is 11");

    try testing.expect(list.private.head != null);
    mtest("List head is not null");

    // Test popping from a List
    mhead("Popping first value from List");
    const pop: i32 = try list.pop();
    mtest("First value popped");

    try testing.expect(pop == 1);
    mtest("Value popped is 1");

    // Test finding a position in a List
    mhead("Finding positions of values in the List");
    // comparison function
    const cmp = struct {
        fn cmp(a: i32, b: i32) bool {
            return a == b;
        }
    }.cmp;

    const pos4: ?u32 = list.position(4, cmp);
    try testing.expect(pos4.? == 1);
    mtest("Position of 4 is 1");

    const pos8: ?u32 = list.position(8, cmp);
    try testing.expect(pos8 == null);
    mtest("Position of 8 is null");

    mhead("Inserting values");
    try list.insert(5, 2);
    mtest("5 Inserted at position 2");
    try list.insert(7, list.length());
    mtest("7 Inserted at end of list");

    mhead("Removing values");
    const pos5 = try list.remove_pos(5);
    mtest("Removed value at position 5");
    try testing.expect(pos5 == -32);
    mtest("Value removed was -32");

    try testing.expect(list.remove_val(64));
    mtest("Removed value of 64");
    try testing.expect(list.remove_val(10) == false);
    mtest("Couldn't remove value of 10");

    print("\n", .{});
}
