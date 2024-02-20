const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Firewall = struct {
    const Layer = struct {
        depth: usize,
        range: usize,
        cycle: usize,

        pub fn init(depth: usize, range: usize) Layer {
            return .{
                .depth = depth,
                .range = range,
                .cycle = 2 * (range - 1),
            };
        }

        pub fn getPosition(self: Layer, delay: usize) usize {
            return (delay + self.depth) % self.cycle;
        }
    };

    layers: std.ArrayList(Layer),

    pub fn init(allocator: Allocator) Firewall {
        return .{
            .layers = std.ArrayList(Layer).init(allocator),
        };
    }

    pub fn deinit(self: *Firewall) void {
        self.layers.deinit();
    }

    pub fn addLine(self: *Firewall, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " :");
        const depth = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const range = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        try self.layers.append(Layer.init(depth, range));
    }

    pub fn getTripSeverity(self: Firewall) !usize {
        var severity: usize = 0;
        for (self.layers.items) |layer| {
            if (layer.getPosition(0) != 0) continue;
            severity += layer.depth * layer.range;
        }
        return severity;
    }

    pub fn getSmallestDelay(self: *Firewall) !usize {
        var delay: usize = 0;
        DELAY: while (true) : (delay += 1) {
            for (self.layers.items) |layer| {
                if (layer.getPosition(delay) == 0) continue :DELAY;
            }
            return delay;
        }
        return 0;
    }
};

test "sample part 1" {
    const data =
        \\0: 3
        \\1: 2
        \\4: 4
        \\6: 4
    ;

    var firewall = Firewall.init(testing.allocator);
    defer firewall.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try firewall.addLine(line);
    }

    const severity = try firewall.getTripSeverity();
    const expected = @as(usize, 24);
    try testing.expectEqual(expected, severity);
}

test "sample part 2" {
    const data =
        \\0: 3
        \\1: 2
        \\4: 4
        \\6: 4
    ;

    var firewall = Firewall.init(testing.allocator);
    defer firewall.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try firewall.addLine(line);
    }

    const severity = try firewall.getSmallestDelay();
    const expected = @as(usize, 10);
    try testing.expectEqual(expected, severity);
}
