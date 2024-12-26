const std = @import("std");

// standard static maps
pub fn StaticStringMap(comptime V: type) type {
    return StaticMap(
        []const u8,
        V,
        stringHash,
        stringEql,
    );
}

pub fn StaticStringMapFirst(comptime V: type) type {
    return StaticMap(
        []const u8,
        V,
        stringHashFirst,
        stringEql,
    );
}

// standard hash functions
pub fn stringHash(item: []const u8) usize {
    return item.len;
}

pub fn stringHashFirst(item: []const u8) usize {
    return @intCast(item[0]);
}

// standard equality functions
pub fn stringEql(a: []const u8, b: []const u8) bool {
    if (a.ptr == b.ptr) return true;
    for (a, b) |i, j| {
        if (i != j) return false;
    }
    return true;
}

pub fn stringEqlCaseless(a: []const u8, b: []const u8) bool {
    if (a.ptr == b.ptr) return true;
    for (a, b) |i, j| {
        if (std.ascii.toLower(i) != std.ascii.toLower(j)) return false;
    }
    return true;
}

pub fn stringSingleEql(a: []const u8, b: []const u8) bool {
    return (a[0] == b[0]);
}

pub fn stringSingleEqlCaseless(a: []const u8, b: []const u8) bool {
    return (std.ascii.toLower(a[0]) == std.ascii.toLower(b[0]));
}

pub fn StaticMap(
    comptime K: type,
    comptime V: type,
    comptime hash: fn (item: K) usize,
    comptime eql: fn (a: K, b: K) bool,
) type {
    return struct {
        kvs: *const KVs = &empty_kvs,
        kv_refs: [*]const usize = &empty_refs,
        kv_refs_len: usize = 0,
        min_ref: usize = std.math.maxInt(usize),
        max_ref: usize = 0,

        const Self = @This();

        pub const KV = struct {
            key: K,
            value: V,
        };

        pub const KVs = struct {
            keys: [*]const K,
            values: [*]const V,
            len: usize,
        };

        const empty_kvs = KVs{
            .keys = &empty_keys,
            .values = &empty_values,
            .len = 0,
        };
        const empty_refs = [0]usize{};
        const empty_keys = [0]K{};
        const empty_values = [0]V{};

        pub inline fn initComptime(comptime kvs_list: anytype) Self {
            comptime {
                var self = Self{};
                if (kvs_list.len == 0) return self;

                // set eval branch quota ???

                var sorted_keys: [kvs_list.len]K = undefined;
                var sorted_values: [kvs_list.len]V = undefined;

                self.initSortedKVs(kvs_list, &sorted_keys, &sorted_values);
                const final_keys = sorted_keys;
                const final_values = sorted_values;
                self.kvs = &.{
                    .keys = &final_keys,
                    .values = &final_values,
                    .len = kvs_list.len,
                };

                var refs: [1 + self.max_ref - self.min_ref]usize = undefined;
                self.initRefs(&refs);
                const final_refs = refs;
                self.kv_refs = &final_refs;
                self.kv_refs_len = final_refs.len;

                return self;
            }
        }

        fn initSortedKVs(
            self: *Self,
            kvs_list: anytype,
            sorted_keys: []K,
            sorted_values: []V,
        ) void {
            for (kvs_list, 0..) |kv, i| {
                sorted_keys[i] = kv[0];
                sorted_values[i] = if (V == void) {} else kv[1];
                self.min_ref = @min(self.min_ref, hash(kv[0]));
                self.max_ref = @max(self.max_ref, hash(kv[0]));
            }
            std.mem.sortUnstableContext(0, sorted_keys.len, SortContext{
                .keys = sorted_keys,
                .values = sorted_values,
            });
        }

        fn initRefs(self: Self, refs: []usize) void {
            var current_ref: usize = 0;
            for (self.min_ref..(self.max_ref + 1)) |ref| {
                while (ref > hash(self.kvs.keys[current_ref])) {
                    current_ref += 1;
                }
                refs[ref - self.min_ref] = current_ref;
            }
        }

        const SortContext = struct {
            keys: []K,
            values: []V,

            pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
                return hash(ctx.keys[a]) < hash(ctx.keys[b]);
            }

            pub fn swap(ctx: @This(), a: usize, b: usize) void {
                std.mem.swap(K, &ctx.keys[a], &ctx.keys[b]);
                std.mem.swap(V, &ctx.values[a], &ctx.values[b]);
            }
        };

        pub fn keys(self: Self) []const K {
            const kvs = self.kvs.*;
            return kvs.keys[0..kvs.len];
        }

        pub fn values(self: Self) []const V {
            const kvs = self.kvs.*;
            return kvs.values[0..kvs.len];
        }

        pub fn has(self: Self, key: K) bool {
            return (self.get(key) != null);
        }

        pub fn get(self: Self, key: K) ?V {
            return self.kvs.values[self.getIndex(key) orelse return null];
        }

        pub fn getIndex(self: Self, key: K) ?usize {
            const kvs = self.kvs.*;

            if (kvs.len == 0) return null;

            const ref: usize = hash(key);
            if ((ref < self.min_ref) or (ref > self.max_ref)) return null;

            for (self.kv_refs[ref - self.min_ref]..kvs.len) |i| {
                const map_key = kvs.keys[i];
                if (hash(map_key) != ref) return null;
                if (eql(key, map_key)) return i;
            }
            return null;
        }
    };
}

test "standardStrings" {
    const Item = struct { []const u8, u8 };
    const stringMap = StaticMap([]const u8, u8, stringHashFirst, stringEql)
        .initComptime([_]Item{
        .{ "Goodbye", 1 },
        .{ "Worlds", 2 },
        .{ "Hello", 3 },
    });

    for (stringMap.keys(), stringMap.values()) |key, value| {
        std.debug.print("{s}: {d}\n", .{ key, value });
    }

    std.debug.print("Number of worlds: {d}\n", .{stringMap.get("Worlds").?});
}
