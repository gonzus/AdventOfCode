const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub fn BitBag(comptime B: type) type {
    return struct {
        const Self = @This();

        bits: B,

        pub fn init() Self {
            var self = Self{ .bits = undefined };
            self.clear();
            return self;
        }

        pub fn count(self: Self) usize {
            const size = @popCount(self.bits);
            return @intCast(size);
        }

        pub fn empty(self: Self) bool {
            return self.count() == 0;
        }

        pub fn clear(self: *Self) void {
            self.bits = 0;
        }

        pub fn first(self: Self) usize {
            return @ctz(self.bits);
        }

        pub fn hasBit(self: Self, pos: usize) bool {
            const p: IntForSizeOf(B) = @intCast(pos);
            const mask = @as(B, 1) << p;
            return self.bits & mask > 0;
        }

        pub fn setBit(self: *Self, pos: usize) void {
            const p: IntForSizeOf(B) = @intCast(pos);
            const mask = @as(B, 1) << p;
            self.bits |= mask;
        }

        pub fn resetBit(self: *Self, pos: usize) void {
            const p: IntForSizeOf(B) = @intCast(pos);
            const mask = @as(B, 1) << p;
            self.bits &= ~mask;
        }

        fn IntForSizeOf(comptime t: anytype) type {
            return switch (t) {
                u64 => u6,
                u32 => u5,
                u16 => u4,
                u8 => u3,
                else => @panic("GONZO: define more types"),
            };
        }
    };
}

test "BitBag" {
    const Bitmap = BitBag(u32);
    var bm = Bitmap.init();

    try testing.expectEqual(bm.count(), 0);
    try testing.expect(bm.empty());

    const setBits = [_]usize{ 2, 3, 11, 19 };
    for (&setBits) |b| {
        bm.setBit(b);
    }
    try testing.expectEqual(bm.count(), 4);
    try testing.expect(!bm.empty());

    for (0..32) |c| {
        var found = false;
        for (&setBits) |b| {
            if (b == c) {
                found = true;
                break;
            }
        }
        if (found) {
            try testing.expect(bm.hasBit(c));
        } else {
            try testing.expect(!bm.hasBit(c));
        }
    }

    var count: usize = setBits.len;
    for (&setBits) |b| {
        try testing.expectEqual(bm.count(), count);
        try testing.expectEqual(bm.first(), b);
        try testing.expect(bm.hasBit(b));
        bm.resetBit(b);
        try testing.expect(!bm.hasBit(b));
        count -= 1;
    }
    try testing.expect(bm.empty());

    for (&setBits) |b| {
        bm.setBit(b);
    }
    try testing.expect(!bm.empty());
    bm.clear();
    try testing.expect(bm.empty());
}
