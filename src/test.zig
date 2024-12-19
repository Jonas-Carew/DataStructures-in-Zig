const print = @import("std").debug.print;

pub fn mhead(message: []const u8) void {
    print("\n{s}...\n", .{message});
}

pub fn mtest(message: []const u8) void {
    print("\t...{s}\n", .{message});
}
