const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Sculpture = struct {
    const Disc = struct {
        positions: usize,
        start: usize,

        pub fn init(positions: usize, start: usize) Disc {
            return .{ .positions = positions, .start = start };
        }
    };

    extra: bool,
    discs: std.ArrayList(Disc),

    pub fn init(allocator: Allocator, extra: bool) Sculpture {
        return .{
            .extra = extra,
            .discs = std.ArrayList(Disc).init(allocator),
        };
    }

    pub fn deinit(self: *Sculpture) void {
        self.discs.deinit();
    }

    pub fn addLine(self: *Sculpture, line: []const u8) !void {
        const id = self.discs.items.len + 1;
        var disc: Disc = undefined;
        var pos: usize = 0;
        var it = std.mem.tokenizeAny(u8, line, " #;=.,");
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                1 => std.debug.assert(id == try std.fmt.parseUnsigned(usize, chunk, 10)),
                3 => disc.positions = try std.fmt.parseUnsigned(usize, chunk, 10),
                7 => std.debug.assert(0 == try std.fmt.parseUnsigned(usize, chunk, 10)),
                12 => disc.start = try std.fmt.parseUnsigned(usize, chunk, 10),
                else => continue,
            }
        }
        try self.discs.append(disc);
    }

    pub fn show(self: Sculpture) void {
        std.debug.print("Sculpture with {} discs\n", .{self.discs.items.len});
        for (self.discs.items, 0..) |d, p| {
            std.debug.print("  Disc #{} with {} positions starting at {}\n", .{ p + 1, d.positions, d.start });
        }
    }

    pub fn getStartTime(self: *Sculpture) !usize {
        var len = self.discs.items.len;
        if (self.extra) {
            try self.discs.append(Disc.init(11, 0));
            len += 1;
        }
        // self.show();

        var divs: [100]usize = undefined;
        var mods: [100]usize = undefined;
        for (self.discs.items, 0..) |d, p| {
            divs[p] = d.positions;
            mods[p] = d.positions - (d.start + p + 1) % d.positions;
        }
        return Math.chineseRemainder(divs[0..len], mods[0..len]);
    }
};

test "sample part 1" {
    const data =
        \\Disc #1 has 5 positions; at time=0, it is at position 4.
        \\Disc #2 has 2 positions; at time=0, it is at position 1.
    ;

    var sculpture = Sculpture.init(std.testing.allocator, false);
    defer sculpture.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try sculpture.addLine(line);
    }

    const time = try sculpture.getStartTime();
    const expected = @as(usize, 5);
    try testing.expectEqual(expected, time);
}
