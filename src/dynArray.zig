const std = @import("std");

const sm = @import("staticMap.zig");

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
            if (self._size <= 0) return try std.fmt.allocPrint(self._allocator, "", .{});
            // special first case
            var text: []u8 = undefined;
            var disp: []u8 = try prn(self._allocator, self._data[0]);
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

        pub fn getSize(self: Self) usize {
            return self._size;
        }

        pub fn insert(self: *Self, value: T) !void {
            if (self._capacity == 0) {
                self._capacity = 1;
                self._data = try self._allocator.alloc(T, 1);
            }
            if (self._size >= self._capacity) {
                self._capacity *= 2;
                var new_data: []T = try self._allocator.alloc(T, self._capacity);
                // self._data is only undefined if capacity is 0
                for (0..self._size) |idx| {
                    new_data[idx] = self._data[idx];
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

        pub fn delete(self: *Self, pos: usize) !T {
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
            self._data[pos] = value;
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
        const daType = DynArray([]const u8);
        var da = daType.init(allo);
        defer {
            for (0..da.getSize()) |i| {
                allo.free(da.get(i) catch |err| {
                    ret = err;
                    continue;
                });
            }
            da.deinit();
        }

        // string printer for dynarray
        const prn = struct {
            fn prn(a: Allocator, v: []const u8) ![]u8 {
                return try std.fmt.allocPrint(a, "{s}", .{v});
            }
        }.prn;

        const _size = struct {
            fn _size(icx: context, ida: *daType) !void {
                try icx.w.print("The size of the dynamic array is {d}\n", .{ida.getSize()});
            }
        }._size;

        const _get = struct {
            fn _get(icx: context, ida: *daType) !void {
                while (true) : ({
                    try icx.w.print("\nPlease input a valid index\n", .{});
                }) {
                    try icx.w.print("Enter the index to get: ", .{});
                    try icx.out.flush();
                    try get(icx.r, icx.input);
                    const n: usize = std.fmt.parseInt(usize, icx.input.items, 10) catch continue;
                    try icx.w.print("The item at index {d} is {s}\n", .{ n, ida.get(n) catch continue });
                    break;
                }
            }
        }._get;

        const _insert = struct {
            fn _insert(icx: context, ida: *daType) !void {
                try icx.w.print("Enter the string to insert: ", .{});
                try icx.out.flush();
                try get(icx.r, icx.input);
                try ida.insert(try icx.input.toOwnedSlice());
            }
        }._insert;

        const _set = struct {
            fn _set(icx: context, ida: *daType) !void {
                var n: usize = undefined;
                while (true) : ({
                    try icx.w.print("\nPlease input a valid index\n", .{});
                }) {
                    try icx.w.print("Enter the index to get: ", .{});
                    try icx.out.flush();
                    try get(icx.r, icx.input);
                    n = std.fmt.parseInt(usize, icx.input.items, 10) catch continue;
                    icx.allo.free(ida.get(n) catch continue);
                    break;
                }
                try icx.w.print("Enter the string to replace index {d}: ", .{n});
                try icx.out.flush();
                try get(icx.r, icx.input);
                try ida.set(n, try icx.input.toOwnedSlice());
            }
        }._set;

        const _delete = struct {
            fn _delete(icx: context, ida: *daType) !void {
                while (true) : ({
                    try icx.w.print("\nPlease input a valid index\n", .{});
                }) {
                    try icx.w.print("Enter the index to delete: ", .{});
                    try icx.out.flush();
                    try get(icx.r, icx.input);
                    const n = std.fmt.parseInt(usize, icx.input.items, 10) catch continue;
                    icx.allo.free(ida.delete(n) catch continue);
                    break;
                }
            }
        }._delete;

        // choice menu
        const menuItem = struct {
            description: []const u8,
            func: *const fn (icx: context, ida: *daType) anyerror!void,
        };
        const mapItem = struct { []const u8, menuItem };

        const menuItems = [_]mapItem{
            .{ "Z", .{ .description = "Get the size of the dynamic array", .func = _size } },
            .{ "G", .{ .description = "Get the item at an index of the dynamic array", .func = _get } },
            .{ "I", .{ .description = "Insert an item to the end of the dynamic array", .func = _insert } },
            .{ "S", .{ .description = "Set an item at an index of the dynamic array", .func = _set } },
            .{ "D", .{ .description = "Delete the item at an index of the dynamic array", .func = _delete } },
            .{ "Q", .{ .description = "Quit", .func = struct {
                fn quit(icx: context, ida: *daType) !void {
                    _ = icx;
                    _ = ida;
                    return error.quit;
                }
            }.quit } },
        };
        const menuFull = sm.MenuMap(menuItem).initComptime(menuItems[0..]);
        const menuOrderFull = [_][]const u8{ "I", "S", "D", "G", "Z", "Q" };
        const menuEmpty = sm.MenuMap(menuItem).initComptime(
            [_]mapItem{ menuItems[0], menuItems[2], menuItems[5] },
        );
        const menuOrderEmpty = [_][]const u8{ "I", "Z", "Q" };

        // START OF MAIN //
        try w.print("\n\nWelcome to the dynamic array playground!\n", .{});
        while (true) {
            const str: []u8 = try da.toOwnedStr(prn);
            defer allo.free(str);
            try w.print("\nYour current dynamic array looks like this:\n", .{});
            try w.print("{s}\n", .{str});
            try w.print("What would you like to do?\n", .{});
            const menu = if (da.getSize() > 0) &menuFull else &menuEmpty;
            const menuOrder = if (da.getSize() > 0) &menuOrderFull else &menuOrderEmpty;
            for (menuOrder) |item| {
                try w.print("\t[{s}] {s}\n", .{ item, menu.get(item).?.description });
            }
            try out.flush();
            try get(r, &input);

            (menu.get(input.items) orelse {
                try w.print("\nPlease input a valid answer\n", .{});
                continue;
            }).func(cx, &da) catch |err| {
                if (err == error.quit) break;
                return err;
            };
        }
    }
    return ret;
}

// Full Test
test "DynArray" {
    // init the general purpose allocator
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

    const rem1: i32 = try da.delete(0);
    try testing.expect(rem1 == 5);

    const str1: []u8 = try da.toOwnedStr(prn);
    defer allo.free(str1);
    try testing.expect(std.mem.eql(u8, str1, "10, 20"));

    const rem2: i32 = try da.delete(0);
    try testing.expect(rem2 == 10);
    const rem3: i32 = try da.delete(0);
    try testing.expect(rem3 == 20);

    const str2: []u8 = try da.toOwnedStr(prn);
    defer allo.free(str2);
    try testing.expect(std.mem.eql(u8, str2, ""));
}
