const std = @import("std");

const sm = @import("staticMap.zig");

const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn List(comptime T: type) type {
    return struct {

        // Defintions
        const ListError = error{
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
        pub fn pop(self: *Self) ?T {
            const node: *Node = self._head orelse return null;
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
            if (pos == 0) return pop(self) orelse ListError.IndexOutOfBounds;
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

        pub fn remove_val(self: *Self, value: T, cmp: *const fn (a: T, b: T) bool) ?T {
            var node: *Node = self._head orelse return null;
            if (cmp(node.value, value)) {
                self._head = node.next;
                const val: T = node.value;
                self._allocator.destroy(node);
                return val;
            }
            while (node.next) |next_node| {
                if (cmp(next_node.value, value)) {
                    node.next = next_node.next;
                    const val: T = next_node.value;
                    self._allocator.destroy(next_node);
                    return val;
                }
                node = next_node;
            }
            return null;
        }

        pub const Iter = struct {
            node: ?*Node,

            pub fn next(self: *@This()) void {
                self.node = (self.node orelse return).next;
            }

            pub fn get(self: @This()) ?T {
                return (self.node orelse return null).value;
            }
        };

        pub fn getIter(self: Self) Iter {
            return .{
                .node = self._head,
            };
        }
    };
}

pub fn play() !void {
    var ret: anyerror!void = void{};
    {
        // get the GPA and defer leak checking
        // use "allo" to allocate memory
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer if (gpa.deinit() == .leak) {
            ret = error.MemoryLeak;
        };
        const allo = gpa.allocator();

        // get a buffered writer and defer the final buffer flush
        // use "w.print" to print to buffer
        // try out.flush to print to stdout
        var out = std.io.bufferedWriter(std.io.getStdOut().writer());
        const w = out.writer();
        defer out.flush() catch |err| {
            ret = err;
        };

        // get a buffered reader
        // pass "r" to the get function
        var in = std.io.bufferedReader(std.io.getStdIn().reader());
        const r = in.reader();

        // get an arraylist to store input as strings
        // input.items is a []u8 (string) that stores stdin
        var input = std.ArrayList(u8).init(allo);
        defer input.deinit();

        // create a function to handle the input easier (and shorter)
        // call get(r, &input) to store stdin in input until the next \n
        const get = struct {
            fn get(reader: anytype, buf: *std.ArrayList(u8)) !void {
                buf.clearAndFree();
                try reader.streamUntilDelimiter(buf.writer(), '\n', null);
            }
        }.get;

        const context = struct {
            out: @TypeOf(&out),
            w: @TypeOf(&w),
            in: @TypeOf(&in),
            r: @TypeOf(&r),
            input: @TypeOf(&input),
            allo: @TypeOf(&allo),
        };
        const cx = context{
            .out = &out,
            .w = &w,
            .in = &in,
            .r = &r,
            .input = &input,
            .allo = &allo,
        };

        // our dynamic array of strings
        const listType = List([]const u8);
        var list = listType.init(allo);
        defer {
            var iter = list.getIter();
            while (iter.get()) |str| : (iter.next()) {
                allo.free(str);
            }
            list.deinit();
        }

        // string printer for dynarray
        const prn = struct {
            fn prn(a: Allocator, v: []const u8) ![]u8 {
                return try std.fmt.allocPrint(a, "{s}", .{v});
            }
        }.prn;

        const cmp = struct {
            fn cmp(a: []const u8, b: []const u8) bool {
                return std.mem.eql(u8, a, b);
            }
        }.cmp;

        const _length = struct {
            fn _length(icx: context, ilist: *listType) !void {
                try icx.w.print("The length of the linked list is {d}\n", .{ilist.length()});
            }
        }._length;

        const _push = struct {
            fn _push(icx: context, ilist: *listType) !void {
                try icx.w.print("Enter the string to push: ", .{});
                try icx.out.flush();
                try get(icx.r, icx.input);
                try ilist.push(try icx.input.toOwnedSlice());
            }
        }._push;

        const _pop = struct {
            fn _pop(icx: context, ilist: *listType) !void {
                const toFree = ilist.pop() orelse return;
                try icx.w.print("The popped string from the linked list was \"{s}\"\n", .{toFree});
                icx.allo.free(toFree);
            }
        }._pop;

        const _pos = struct {
            fn _pos(icx: context, ilist: *listType) !void {
                try icx.w.print("Enter the string to find: ", .{});
                try icx.out.flush();
                try get(icx.r, icx.input);
                const posOpt: ?usize = ilist.position(icx.input.items, cmp);
                if (posOpt) |pos| {
                    try icx.w.print("The first position of \"{s}\" is {d}", .{ icx.input.items, pos });
                } else try icx.w.print("The string \"{s}\" is not in the list", .{icx.input.items});
            }
        }._pos;

        const _insert = struct {
            fn _insert(icx: context, ilist: *listType) !void {
                var n: usize = undefined;
                while (true) : ({
                    try icx.w.print("\nPlease input a valid position\n", .{});
                }) {
                    try icx.w.print("Enter the position to insert a value: ", .{});
                    try icx.out.flush();
                    try get(icx.r, icx.input);
                    n = std.fmt.parseInt(usize, icx.input.items, 10) catch continue;
                    if ((n < 0) or (n > ilist.length())) continue;
                    break;
                }
                try icx.w.print("Enter the string to insert at position {d}: ", .{n});
                try icx.out.flush();
                try get(icx.r, icx.input);
                try ilist.insert(try icx.input.toOwnedSlice(), n);
            }
        }._insert;

        const _delPos = struct {
            fn _delPos(icx: context, ilist: *listType) !void {
                var n: usize = undefined;
                while (true) : ({
                    try icx.w.print("\nPlease input a valid position\n", .{});
                }) {
                    try icx.w.print("Enter the position to delete: ", .{});
                    try icx.out.flush();
                    try get(icx.r, icx.input);
                    n = std.fmt.parseInt(usize, icx.input.items, 10) catch continue;
                    icx.allo.free(ilist.remove_pos(n) catch continue);
                    break;
                }
            }
        }._delPos;

        const _delVal = struct {
            fn _delVal(icx: context, ilist: *listType) !void {
                try icx.w.print("Enter the string to delete: ", .{});
                try icx.out.flush();
                try get(icx.r, icx.input);
                const str: []const u8 = ilist.remove_val(icx.input.items, cmp) orelse {
                    try icx.w.print("The string \"{s}\" is not in the list\n", .{icx.input.items});
                    return;
                };
                icx.allo.free(str);
            }
        }._delVal;

        // choice menu
        const menuItem = struct {
            description: []const u8,
            func: *const fn (icx: context, ilist: *listType) anyerror!void,
        };
        const mapItem = struct { []const u8, menuItem };

        const menuItems = [_]mapItem{
            .{ "L", .{ .description = "Get the length of the linked list", .func = _length } },
            .{ "U", .{ .description = "Push an item onto the linked list", .func = _push } },
            .{ "O", .{ .description = "Pop an item from the linked list", .func = _pop } },
            .{ "P", .{ .description = "Get the first position of a value in the linked list", .func = _pos } },
            .{ "I", .{ .description = "Insert an item at a position in the linked list", .func = _insert } },
            .{ "D", .{ .description = "Delete an item at a position in the linked list", .func = _delPos } },
            .{ "V", .{ .description = "Delete the first specified value in the linked list", .func = _delVal } },
            .{ "Q", .{ .description = "Quit", .func = struct {
                fn quit(icx: context, ilist: *listType) !void {
                    _ = icx;
                    _ = ilist;
                    return error.quit;
                }
            }.quit } },
        };
        const menuFull = sm.MenuMap(menuItem).initComptime(menuItems[0..]);
        const menuOrderFull = [_][]const u8{ "U", "O", "I", "D", "V", "P", "L", "Q" };
        const menuEmpty = sm.MenuMap(menuItem).initComptime(
            [_]mapItem{ menuItems[1], menuItems[4], menuItems[0], menuItems[7] },
        );
        const menuOrderEmpty = [_][]const u8{ "U", "I", "L", "Q" };

        // START OF MAIN //
        try w.print("\n\nWelcome to the linkedlist playground!\n", .{});
        while (true) {
            const str: []u8 = try list.toOwnedStr(prn);
            defer allo.free(str);
            try w.print("\nYour current linked list looks like this:\n", .{});
            try w.print("{s}\n", .{str});
            try w.print("What would you like to do?\n", .{});
            const menu = if (list.length() > 0) &menuFull else &menuEmpty;
            const menuOrder = if (list.length() > 0) &menuOrderFull else &menuOrderEmpty;
            for (menuOrder) |item| {
                try w.print("\t[{s}] {s}\n", .{ item, menu.get(item).?.description });
            }
            try out.flush();
            try get(r, &input);

            (menu.get(input.items) orelse {
                try w.print("\nPlease input a valid answer\n", .{});
                continue;
            }).func(cx, &list) catch |err| {
                if (err == error.quit) break;
                return err;
            };
        }
    }
    return ret;
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
    const pop: ?i32 = list.pop();

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

    try testing.expect(list.remove_val(64, cmp) == 64);
    try testing.expect(list.remove_val(10, cmp) == null);

    const prn = struct {
        fn prn(a: Allocator, v: i32) ![]u8 {
            return try std.fmt.allocPrint(a, "{d}", .{v});
        }
    }.prn;

    const str = try list.toOwnedStr(prn);
    defer allo.free(str);
    try testing.expect(std.mem.eql(u8, str, "-2, 4, 5, -8, 16, -128, 256, -512, 1024, 7"));
}
