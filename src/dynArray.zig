const std = @import("std");

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
            if (self._size == 0) return try std.fmt.allocPrint(self._allocator, "", .{});
            // special first case
            var text: []u8 = try prn(self._allocator, self._data[0]);
            var disp: []u8 = try std.fmt.allocPrint(self._allocator, "{s}", .{text});
            self._allocator.free(text);
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

        pub fn size(self: Self) usize {
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
                // self._data is only null if capacity is 0
                for (self._data, 0..) |data, idx| {
                    new_data[idx] = data;
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

        pub fn remove(self: *Self, pos: usize) !T {
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
            self._data[pos] == value;
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
        var w = out.writer();
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

        // our dynamic array of strings
        var da = DynArray(i32).init(allo);
        defer da.deinit();

        // string printer
        const prn = struct {
            fn prn(a: Allocator, v: i32) ![]u8 {
                return try std.fmt.allocPrint(a, "{d}", .{v});
            }
        }.prn;

        // menu
        const menu = [_]struct { []const u8, []const u8 }{
            .{ "1", "Get the size of the dynamic array" },
            .{ "2", "Get the item at a position of the dynamic array" },
            .{ "3", "Insert an item to the end of the dynamic array" },
            .{ "4", "Set an item at a position of the dynamic array" },
            .{ "5", "Delete the item at a position of the dynamic array" },
            .{ "Q", "Quit" },
        };

        // START OF MAIN //
        try w.print("\n\nWelcome to the dynamic array playground!\n", .{});
        while (true) {
            const str: []u8 = try da.toOwnedStr(prn);
            defer allo.free(str);
            try w.print("\nYour current dynamic array looks like this:\n", .{});
            try w.print("{s}\n", .{str});
            try w.print("What would you like to do?\n", .{});
            for (menu) |tup| {
                try w.print("\t[{s}] {s}\n", .{ tup[0], tup[1] });
            }
            try out.flush();
            try get(r, &input);

            if (std.ascii.eqlIgnoreCase(input.items, "q")) break;
            switch (std.fmt.parseInt(u8, input.items, 10) catch {
                try w.print("Please input a valid answer", .{});
                continue;
            }) {
                1 => {},
                2 => {},
                3 => {
                    while (true) : (try w.print("Please enter a valid number\n", .{})) {
                        try w.print("Enter the number to insert: ", .{});
                        try out.flush();
                        try get(r, &input);
                        const num: u8 = std.fmt.parseInt(u8, input.items, 10) catch continue;
                        try da.insert(num);
                        break;
                    }
                },
                4 => {},
                5 => {},
                // change this to an enum / for loop to merge catch and else
                else => {
                    try w.print("Please input a valid answer", .{});
                    continue;
                },
            }
        }
    }
    return ret;
}

// Full Test
test "DynArray" {
    // init the Arena Allocator and GPA
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

    const rem1: i32 = try da.remove(0);
    try testing.expect(rem1 == 5);

    const str1: []u8 = try da.toOwnedStr(prn);
    defer allo.free(str1);
    try testing.expect(std.mem.eql(u8, str1, "10, 20"));

    const rem2: i32 = try da.remove(0);
    try testing.expect(rem2 == 10);
    const rem3: i32 = try da.remove(0);
    try testing.expect(rem3 == 20);

    const str2: []u8 = try da.toOwnedStr(prn);
    defer allo.free(str2);
    try testing.expect(std.mem.eql(u8, str2, ""));
}
