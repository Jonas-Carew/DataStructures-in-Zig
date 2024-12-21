const std = @import("std");
const testing = std.testing;

pub fn cKV_str(inlist: anytype) type {
    const Self = @This();
    _ = Self;

    const KeyType = @TypeOf(inlist[0][0]);
    const ValueType = @TypeOf(inlist[0][1]);
    const size = inlist.len;

    var _keys: [size]KeyType = undefined;
    for (0..size) |i| {
        _keys[i] = inlist[i][0];
    }
    const keys = _keys;

    var _values: [size]ValueType = undefined;
    for (0..size) |i| {
        _values[i] = inlist[i][1];
    }
    const values = _values;

    return struct {
        pub fn getKeys() [size]KeyType {
            return keys;
        }

        pub fn getValue(inkey: KeyType) ?ValueType {
            for (keys, 0..) |key, i| {
                if (std.mem.eql(u8, key, inkey)) {
                    return values[i];
                }
            }
            return null;
        }

        pub fn getValueCaseless(inkey: KeyType) ?ValueType {
            key: for (keys, 0..) |key, i| {
                if (key.len != inkey.len) continue;
                for (key, inkey) |c, inc| {
                    if (std.ascii.toLower(c) != std.ascii.toLower(inc)) continue :key;
                }
                return values[i];
            }
            return null;
        }
    };
}

test "cKV" {
    const list = cKV_str([_]struct { []const u8, u8 }{
        .{ "a", 1 },
        .{ "b", 2 },
        .{ "c", 3 },
        .{ "d", 4 },
        .{ "e", 5 },
    });

    var chars = [1]u8{'a' - 1};
    for (list.getKeys()) |key| {
        chars[0] += 1;
        const char = chars[0..1];
        try testing.expect(std.mem.eql(u8, key, char));
    }

    try testing.expect(list.getValue("b") == 2);
    try testing.expect(list.getValueCaseless("C") == 3);
}
