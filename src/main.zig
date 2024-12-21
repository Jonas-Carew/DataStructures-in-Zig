const std = @import("std");
const testing = std.testing;

const cKV = @import("cKV.zig").cKV_str;

const List = @import("list.zig").List;
const DynArray = @import("dynArray.zig").DynArray;

pub fn list() !void {}

pub fn dynArray() !void {}

pub fn main() !void {
    // inner scope allows us to defer errors to be returned
    // e.g. flushing the write buffer or checking for memory leaks
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

        const choice = struct {
            text: []const u8,
            play: *const fn () anyerror!void,
        };

        // START OF MAIN //
        main: while (true) {
            data: while (true) : (try w.print("\nPlease input a valid answer\n", .{})) {
                const text = cKV([_]struct { []const u8, choice }{
                    .{ "Q", choice{ .text = "Quit", .play = list } },
                    .{ "L", choice{ .text = "Linked List", .play = list } },
                    .{ "A", choice{ .text = "Dynamic Array", .play = list } },
                });
                try w.print("\nSelect the data structure to use:\n", .{});
                for (text.getKeys()) |key| {
                    try w.print("\t[{s}] {s}\n", .{ key, text.getValue(key).?.text });
                }
                try out.flush();
                try get(r, &input);
                try (text.getValueCaseless(input.items) orelse continue :data).play();
                break;
            }

            repeat: while (true) {
                try w.print("\nWould you like to test another data structure? [y/n]\n", .{});
                try out.flush();
                try get(r, &input);

                if (std.ascii.eqlIgnoreCase(input.items, "y")) break :repeat;
                if (std.ascii.eqlIgnoreCase(input.items, "n")) break :main;

                try w.print("\nPlease input a valid answer\n", .{});
            }
        }
    }
    return ret;
}
