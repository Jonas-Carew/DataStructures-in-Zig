const std = @import("std");

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

        _allocator: Allocator,
        _head: ?*Node,

        // constructor for the List
        pub fn init(allocator: Allocator) Self {
            return .{
                ._allocator = allocator,
                ._head = null,
            };
        }

        // free entire list
        pub fn deinit(self: *Self) void {
            var node: ?*Node = self._head;
            while (node) |current| {
                const next = current.next;
                self._allocator.destroy(current);
                node = next;
            }
        }

        // print list
        pub fn toOwnedStr(
            self: Self,
            prn: *const fn (allo: Allocator, v: T) anyerror![]u8,
        ) ![]u8 {
            var onode: ?*Node = self._head;

            var text: []u8 = undefined;
            var disp: []u8 = "";
            var disp_free: []u8 = undefined;

            // first case we don't free disp_free
            if (onode) |node| {
                text = try prn(self._allocator, node.value);
                defer self._allocator.free(text);

                disp = try std.fmt.allocPrint(self._allocator, "{s}", .{text});

                onode = node.next;
            }
            // remaining nodes
            while (onode) |node| : (onode = node.next) {
                disp_free = disp;
                defer self._allocator.free(disp_free);

                text = try prn(self._allocator, node.value);
                defer self._allocator.free(text);

                disp = try std.fmt.allocPrint(
                    self._allocator,
                    "{s}, {s}",
                    .{ disp, text },
                );
            }
            return disp;
        }

        pub fn length(self: Self) usize {
            var i: usize = 0;
            var node: ?*Node = self._head;
            while (node) |current| {
                node = current.next;
                i += 1;
            }
            return i;
        }

        // List push
        pub fn push(self: *Self, value: T) !void {
            var node = try self._allocator.create(Node);

            const head = self._head;
            node.value = value;
            node.next = head;

            self._head = node;
        }

        // List pop
        pub fn pop(self: *Self) !T {
            const node: *Node = self._head orelse return ListError.PoppedEmptyList;
            defer self._allocator.destroy(node);
            self._head = node.next;
            return node.value;
        }

        // position in List
        pub fn position(self: Self, value: T, cmp: *const fn (a: T, b: T) bool) ?usize {
            var node: ?*Node = self._head;
            var i: u32 = 0;
            while (node) |current| : (i += 1) {
                if (cmp(current.value, value)) return i;
                node = current.next;
            }
            return null;
        }

        pub fn insert(self: *Self, value: T, pos: usize) !void {
            if (pos == 0) return push(self, value);
            // pos > 0
            var next_node: ?*Node = self._head;
            var prev_node: *Node = next_node orelse return ListError.IndexOutOfBounds;
            for (0..pos) |_| {
                prev_node = next_node orelse return ListError.IndexOutOfBounds;
                next_node = prev_node.next;
            }
            const node = try self._allocator.create(Node);
            prev_node.next = node;
            node.value = value;
            node.next = next_node;
        }

        pub fn remove_pos(self: *Self, pos: usize) !T {
            if (pos == 0) return pop(self);
            // pos > 0
            var node: *Node = self._head orelse return ListError.IndexOutOfBounds;
            var prev_node: *Node = node;
            for (0..pos) |_| {
                prev_node = node;
                node = node.next orelse return ListError.IndexOutOfBounds;
            }
            prev_node.next = node.next;
            const value: T = node.value;
            self._allocator.destroy(node);
            return value;
        }

        pub fn remove_val(self: *Self, value: T) bool {
            var node: *Node = self._head orelse return false;
            if (node.value == value) {
                self._head = node.next;
                self._allocator.destroy(node);
                return true;
            }
            while (node.next) |next_node| {
                if (next_node.value == value) {
                    node.next = next_node.next;
                    self._allocator.destroy(next_node);
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
    // init the Arena Allocator and GPA
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        testing.expect(deinit_status != .leak) catch @panic("MEMORY LEAK");
    }

    // Set the used allocator
    const allo = gpa.allocator();

    // Test Creating a List
    var list = List(i32).init(allo);
    defer list.deinit();

    try testing.expect(list._head == null);
    try testing.expect(list.length() == 0);

    // Test pushing to a List
    var i: i32 = 10;
    while (i >= 0) : (i -= 1) {
        try list.push(std.math.pow(i32, -2, i));
    }

    try testing.expect(list.length() == 11);

    try testing.expect(list._head != null);

    // Test popping from a List
    const pop: i32 = try list.pop();

    try testing.expect(pop == 1);

    // Test finding a position in a List
    // comparison function
    const cmp = struct {
        fn cmp(a: i32, b: i32) bool {
            return a == b;
        }
    }.cmp;

    const pos4: ?usize = list.position(4, cmp);
    try testing.expect(pos4.? == 1);

    const pos8: ?usize = list.position(8, cmp);
    try testing.expect(pos8 == null);

    try list.insert(5, 2);
    try list.insert(7, list.length());

    const pos5 = try list.remove_pos(5);
    try testing.expect(pos5 == -32);

    try testing.expect(list.remove_val(64));
    try testing.expect(list.remove_val(10) == false);

    const prn = struct {
        fn prn(a: Allocator, v: i32) ![]u8 {
            return try std.fmt.allocPrint(a, "{d}", .{v});
        }
    }.prn;

    const str = try list.toOwnedStr(prn);
    defer allo.free(str);
    try testing.expect(std.mem.eql(u8, str, "-2, 4, 5, -8, 16, -128, 256, -512, 1024, 7"));
}
