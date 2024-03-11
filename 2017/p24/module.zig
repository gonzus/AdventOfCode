const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Bridge = struct {
    const Component = struct {
        port0: usize,
        port1: usize,
        used: bool,

        pub fn init(port0: usize, port1: usize) Component {
            return .{
                .port0 = port0,
                .port1 = port1,
                .used = false,
            };
        }

        pub fn strength(self: Component) usize {
            return self.port0 + self.port1;
        }

        pub fn otherPort(self: Component, port: usize) usize {
            return if (self.port0 == port) self.port1 else self.port0;
        }
    };

    const Positions = std.AutoHashMap(usize, void);

    allocator: Allocator,
    longest: bool,
    components: std.ArrayList(Component),
    ports: std.AutoHashMap(usize, Positions),
    best_strength: usize,
    best_length: usize,

    pub fn init(allocator: Allocator, longest: bool) Bridge {
        return .{
            .allocator = allocator,
            .longest = longest,
            .components = std.ArrayList(Component).init(allocator),
            .ports = std.AutoHashMap(usize, Positions).init(allocator),
            .best_strength = 0,
            .best_length = 0,
        };
    }

    pub fn deinit(self: *Bridge) void {
        var it = self.ports.valueIterator();
        while (it.next()) |*p| {
            p.*.deinit();
        }
        self.ports.deinit();
        self.components.deinit();
    }

    pub fn addLine(self: *Bridge, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, '/');
        const port0 = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const port1 = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const component = Component.init(port0, port1);
        const pos = self.components.items.len;
        try self.components.append(component);
        try self.addPortPos(port0, pos);
        try self.addPortPos(port1, pos);
    }

    pub fn show(self: Bridge) void {
        std.debug.print("Bridge with {} components\n", .{self.components.items.len});
        for (self.components.items, 0..) |component, pos| {
            std.debug.print("  {}: {} / {}\n", .{ pos, component.port0, component.port1 });
        }
        var it = self.ports.iterator();
        while (it.next()) |e| {
            std.debug.print("Port {} at", .{e.key_ptr.*});
            var itp = e.value_ptr.*.keyIterator();
            while (itp.next()) |p| {
                std.debug.print(" {}", .{p.*});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn findStrongest(self: *Bridge) !usize {
        try self.walk(0, 0, 0);
        return self.best_strength;
    }

    fn addPortPos(self: *Bridge, port: usize, pos: usize) !void {
        var r = try self.ports.getOrPut(port);
        if (!r.found_existing) {
            r.value_ptr.* = Positions.init(self.allocator);
        }
        try r.value_ptr.put(pos, {});
    }

    fn walk(self: *Bridge, port: usize, strength: usize, length: usize) !void {
        self.register(strength, length);
        const maybe_ports = self.ports.get(port);
        if (maybe_ports) |ports| {
            var it = ports.keyIterator();
            while (it.next()) |pos| {
                const component = &self.components.items[pos.*];
                if (component.used) continue;

                component.used = true;
                try self.walk(component.otherPort(port), strength + component.strength(), length + 1);
                component.used = false;
            }
        }
    }

    fn register(self: *Bridge, strength: usize, length: usize) void {
        if (!self.longest) {
            if (self.best_strength < strength) {
                self.best_length = length;
                self.best_strength = strength;
            }
            return;
        }

        if (self.best_length < length) {
            self.best_length = length;
            self.best_strength = strength;
        }
        if (self.best_length == length and self.best_strength < strength) {
            self.best_strength = strength;
        }
    }
};

test "sample part 1" {
    const data =
        \\0/2
        \\2/2
        \\2/3
        \\3/4
        \\3/5
        \\0/1
        \\10/1
        \\9/10
    ;

    var bridge = Bridge.init(std.testing.allocator, false);
    defer bridge.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try bridge.addLine(line);
    }

    const strength = try bridge.findStrongest();
    const expected = @as(usize, 31);
    try testing.expectEqual(expected, strength);
}

test "sample part 2" {
    const data =
        \\0/2
        \\2/2
        \\2/3
        \\3/4
        \\3/5
        \\0/1
        \\10/1
        \\9/10
    ;

    var bridge = Bridge.init(std.testing.allocator, true);
    defer bridge.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try bridge.addLine(line);
    }

    const strength = try bridge.findStrongest();
    const expected = @as(usize, 19);
    try testing.expectEqual(expected, strength);
}
