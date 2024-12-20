const std = @import("std");
const testing = std.testing;

const DynArray = @import("dynArray.zig").DynArray;
const List = @import("list.zig").List;

pub fn dynArray() !void {}

pub fn list() !void {}

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

        // the choice menu
        // an array of tuples
        // each tuple has a string selector, a description, and a function
        const text = [_]struct { []const u8, []const u8, *const fn () anyerror!void }{
            .{ "A", "Dynamic Array", dynArray },
            .{ "L", "Linked List", list },
            .{ "Q", "Quit", struct {
                fn quit() !void {
                    return error.Quit;
                }
            }.quit },
        };

        // START OF MAIN //
        main: while (true) {
            // running the data structures
            data: while (true) : (try w.print("\nPlease input a valid answer\n", .{})) {
                // choice menu output & response
                try w.print("\nSelect the data structure to use:\n", .{});
                for (text) |tup| {
                    try w.print("\t[{s}] {s}\n", .{ tup[0], tup[1] });
                }
                try out.flush();
                try get(r, &input);

                // check valid response & run function
                for (text) |tup| {
                    if (!std.ascii.eqlIgnoreCase(input.items, tup[0])) continue;
                    tup[2]() catch |err| if (err == error.Quit) {
                        break :main;
                    } else return err;
                    break :data;
                }
            }

            // prompting to run another
            repeat: while (true) : (try w.print("\nPlease input a valid answer\n", .{})) {
                // question output & response
                try w.print("\nWould you like to test another data structure? [y/n]\n", .{});
                try out.flush();
                try get(r, &input);

                // check for valid response & goto
                if (std.ascii.eqlIgnoreCase(input.items, "y")) break :repeat;
                if (std.ascii.eqlIgnoreCase(input.items, "n")) break :main;
            }
        }
    }
    return ret;
}
