const std = @import("std");
const testing = std.testing;

const List = @import("list.zig").List;

pub fn main() !void {
    var ret: anyerror!void = void{};
    {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer if (gpa.deinit() == .leak) {
            ret = error.MemoryLeak;
        };
        const allo = gpa.allocator();

        var bufin = std.io.bufferedReader(std.io.getStdIn().reader());
        const r = bufin.reader();

        var input = std.ArrayList(u8).init(allo);
        defer input.deinit();

        var bufout = std.io.bufferedWriter(std.io.getStdOut().writer());
        var w = bufout.writer();
        defer bufout.flush() catch |err| {
            ret = err;
        };

        const get = struct {
            fn get(reader: anytype, buf: *std.ArrayList(u8)) !void {
                buf.clearAndFree();
                try reader.streamUntilDelimiter(buf.writer(), '\n', null);
            }
        }.get;

        while (true) {
            try w.print(
                "\nSelect the data structure to use:\n\t[1] Linked List\n",
                .{},
            );
            try bufout.flush();

            try get(r, &input);

            switch (std.fmt.parseUnsigned(u8, input.items, 10) catch {
                try w.print("Please input a valid number\n", .{});
                continue;
            }) {
                1 => {
                    try w.print("Linked List Stuff\n", .{});
                },
                else => {
                    try w.print("Please input a valid number\n", .{});
                    continue;
                },
            }

            break;
        }
    }
    return ret;
}
