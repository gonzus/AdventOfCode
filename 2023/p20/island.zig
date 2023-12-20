const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Circuit = struct {
    const StringId = StringTable.StringId;
    const STRING_INVALID = std.math.maxInt(usize);
    const MODULE_BROADCASTER = "broadcaster";

    const Pulse = enum {
        Low,
        High,
    };

    const Kind = enum(u8) {
        FlipFlop = '%',
        Conjunction = '&',
        Broadcaster = '*',

        pub fn parse(c: u8) Kind {
            return switch (c) {
                '%' => .FlipFlop,
                '&' => .Conjunction,
                '*' => .Broadcaster,
                else => unreachable,
            };
        }
    };

    const Broadcaster = struct {
        pub fn init() Broadcaster {
            return Broadcaster{};
        }

        pub fn gotPulse(_: *Broadcaster, pd: PulseData) !?Pulse {
            return pd.pulse;
        }
    };

    const FlipFlop = struct {
        is_on: bool,

        pub fn init() FlipFlop {
            return FlipFlop{ .is_on = false };
        }

        pub fn gotPulse(self: *FlipFlop, pd: PulseData) !?Pulse {
            var next_pulse: ?Pulse = null;
            switch (pd.pulse) {
                .High => {}, // ignore
                .Low => {
                    if (self.is_on) {
                        self.is_on = false;
                        next_pulse = .Low;
                    } else {
                        self.is_on = true;
                        next_pulse = .High;
                    }
                },
            }
            return next_pulse;
        }
    };

    const Conjunction = struct {
        sources: std.AutoHashMap(StringId, Pulse),

        pub fn init(allocator: Allocator) Conjunction {
            const self = Conjunction{
                .sources = std.AutoHashMap(StringId, Pulse).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Conjunction) void {
            self.sources.deinit();
        }

        pub fn gotPulse(self: *Conjunction, pd: PulseData) !?Pulse {
            _ = try self.sources.put(pd.src, pd.pulse);
            var it = self.sources.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.* == .Low) return .High;
            }
            return .Low;
        }
    };

    const Extra = union(Kind) {
        FlipFlop: FlipFlop,
        Conjunction: Conjunction,
        Broadcaster: Broadcaster,
    };

    const Module = struct {
        name: StringId,
        destinations: std.ArrayList(StringId),
        extra: Extra,

        pub fn init(allocator: Allocator, kind: Kind, name: StringId) Module {
            const self = Module{
                .name = name,
                .destinations = std.ArrayList(StringId).init(allocator),
                .extra = switch (kind) {
                    .FlipFlop => Extra{ .FlipFlop = FlipFlop.init() },
                    .Broadcaster => Extra{ .Broadcaster = Broadcaster.init() },
                    .Conjunction => Extra{ .Conjunction = Conjunction.init(allocator) },
                },
            };
            return self;
        }

        pub fn deinit(self: *Module) void {
            switch (self.extra) {
                .Conjunction => |*c| c.deinit(),
                .FlipFlop, .Broadcaster => {},
            }
            self.destinations.deinit();
        }

        pub fn gotPulse(self: *Module, pd: PulseData, queue: *PQ, pos: *usize) !void {
            const next_maybe = switch (self.extra) {
                .FlipFlop => |*f| try f.gotPulse(pd),
                .Conjunction => |*c| try c.gotPulse(pd),
                .Broadcaster => |*b| try b.gotPulse(pd),
            };
            if (next_maybe) |next| {
                const gen = pd.gen_pos / 1000 + 1;
                for (self.destinations.items) |dest| {
                    try queue.add(PulseData.init(next, pd.tgt, dest, gen, pos.*));
                    pos.* += 1;
                }
            }
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    modules: std.AutoHashMap(StringId, Module),
    total_low: usize,
    total_high: usize,

    pub fn init(allocator: Allocator) Circuit {
        const self = Circuit{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .modules = std.AutoHashMap(StringId, Module).init(allocator),
            .total_low = 0,
            .total_high = 0,
        };
        return self;
    }

    pub fn deinit(self: *Circuit) void {
        var it = self.modules.valueIterator();
        while (it.next()) |*module| {
            module.*.deinit();
        }
        self.modules.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Circuit, line: []const u8) !void {
        var it_module = std.mem.tokenizeSequence(u8, line, " -> ");
        const name_str = it_module.next().?;
        const destinations_str = it_module.next().?;
        var kind: Kind = undefined;
        var name: StringId = undefined;
        if (std.mem.eql(u8, name_str, MODULE_BROADCASTER)) {
            kind = .Broadcaster;
            name = try self.strtab.add(name_str);
        } else {
            kind = Kind.parse(name_str[0]);
            name = try self.strtab.add(name_str[1..]);
        }
        var module = Module.init(self.allocator, kind, name);

        var it_destinations = std.mem.tokenizeAny(u8, destinations_str, ", ");
        while (it_destinations.next()) |destination_str| {
            const destination = try self.strtab.add(destination_str);
            try module.destinations.append(destination);
        }

        try self.modules.put(name, module);
    }

    fn fixConnections(self: *Circuit) !void {
        var it = self.modules.valueIterator();
        while (it.next()) |module| {
            for (module.destinations.items) |destination| {
                var dest_entry = self.modules.getEntry(destination);
                if (dest_entry) |dest| {
                    switch (dest.value_ptr.*.extra) {
                        .Conjunction => |*c| {
                            try c.sources.put(module.name, .Low);
                        },
                        .FlipFlop, .Broadcaster => {},
                    }
                }
            }
        }
    }

    const PulseData = struct {
        pulse: Pulse,
        src: StringId,
        tgt: StringId,
        gen_pos: usize,

        pub fn init(pulse: Pulse, src: StringId, tgt: StringId, gen: usize, pos: usize) PulseData {
            if (pos >= 1000) unreachable;
            const gen_pos = gen * 1000 + pos;
            return PulseData{
                .pulse = pulse,
                .src = src,
                .tgt = tgt,
                .gen_pos = gen_pos,
            };
        }

        fn lessThan(_: void, l: PulseData, r: PulseData) std.math.Order {
            return std.math.order(l.gen_pos, r.gen_pos);
        }
    };

    const PQ = std.PriorityQueue(PulseData, void, PulseData.lessThan);

    fn pushButton(self: *Circuit) !void {
        var queue = PQ.init(self.allocator, {});
        defer queue.deinit();

        const bcast_str = self.strtab.get_pos(MODULE_BROADCASTER).?;
        try queue.add(PulseData.init(.Low, STRING_INVALID, bcast_str, 0, 0));
        while (queue.count() > 0) {
            const cur = queue.remove();
            switch (cur.pulse) {
                .Low => self.total_low += 1,
                .High => self.total_high += 1,
            }
            var pos: usize = 0;
            var module_maybe = self.modules.getEntry(cur.tgt);
            if (module_maybe) |module| {
                try module.value_ptr.*.gotPulse(cur, &queue, &pos);
            }
        }
    }

    pub fn getPulseProduct(self: *Circuit, repeats: usize) !usize {
        try self.fixConnections();
        for (0..repeats) |_| {
            try self.pushButton();
        }
        return self.total_low * self.total_high;
    }

    pub fn pressUntilModuleActivates(self: *Circuit) !usize {
        // This, I think, sucks. It requires knowledge about the input file.
        // The way to reach rx is through several register adders.
        // So we count how many times those will be activated.
        // And then take their LCM so they will all be active simultaneously.
        try self.fixConnections();
        var prod: usize = 1;
        var bits = std.ArrayList(u1).init(self.allocator);
        defer bits.deinit();
        const bcas_str = self.strtab.get_pos(MODULE_BROADCASTER).?;
        const bcast = self.modules.get(bcas_str).?;
        for (bcast.destinations.items) |dest| {
            var cur = dest;
            bits.clearRetainingCapacity();
            while (true) {
                var bit: u1 = 0;
                var candidate: ?Module = null;
                const bchild_maybe = self.modules.get(cur);
                if (bchild_maybe) |bchild| {
                    for (bchild.destinations.items) |dest_str| {
                        const dest_maybe = self.modules.get(dest_str);
                        if (dest_maybe) |next| {
                            switch (next.extra) {
                                .Conjunction => bit = 1,
                                .FlipFlop => candidate = next,
                                .Broadcaster => {},
                            }
                        }
                    }
                }
                try bits.append(bit);
                if (candidate == null) break;
                cur = candidate.?.name;
            }
            var num: usize = 0;
            for (bits.items, 0..) |_, p| {
                num *= 2;
                num += bits.items[bits.items.len - p - 1];
            }
            prod = Math.lcm(prod, num);
        }

        return prod;
    }
};

test "sample simple part 1" {
    const data =
        \\broadcaster -> a, b, c
        \\%a -> b
        \\%b -> c
        \\%c -> inv
        \\&inv -> a
    ;

    var circuit = Circuit.init(std.testing.allocator);
    defer circuit.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try circuit.addLine(line);
    }

    const count = try circuit.getPulseProduct(1000);
    const expected = @as(usize, 32000000);
    try testing.expectEqual(expected, count);
}

test "sample complex part 1" {
    const data =
        \\broadcaster -> a
        \\%a -> inv, con
        \\&inv -> b
        \\%b -> con
        \\&con -> output
    ;

    var circuit = Circuit.init(std.testing.allocator);
    defer circuit.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try circuit.addLine(line);
    }

    const count = try circuit.getPulseProduct(1000);
    const expected = @as(usize, 11687500);
    try testing.expectEqual(expected, count);
}
