const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Message = struct {
    const Vec = Math.Vector(isize, 2);
    const INFINITY = std.math.maxInt(isize);

    const Light = struct {
        pos: Vec,
        vel: Vec,

        pub fn init(px: isize, py: isize, vx: isize, vy: isize) Light {
            return .{
                .pos = Vec.copy(&[_]isize{ px, py }),
                .vel = Vec.copy(&[_]isize{ vx, vy }),
            };
        }
    };

    allocator: Allocator,
    lights: [2]std.ArrayList(Light),
    grid: std.AutoHashMap(Vec, void),
    pos: usize,
    pmin: Vec,
    pmax: Vec,

    pub fn init(allocator: Allocator) Message {
        var self = Message{
            .allocator = allocator,
            .lights = undefined,
            .grid = std.AutoHashMap(Vec, void).init(allocator),
            .pos = 0,
            .pmin = Vec.copy(&[_]isize{ INFINITY, INFINITY }),
            .pmax = Vec.copy(&[_]isize{ -INFINITY, -INFINITY }),
        };
        for (self.lights, 0..) |_, p| {
            self.lights[p] = std.ArrayList(Light).init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *Message) void {
        self.grid.deinit();
        for (self.lights, 0..) |_, p| {
            self.lights[p].deinit();
        }
    }

    pub fn addLine(self: *Message, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " <>=,");
        _ = it.next();
        const px = try std.fmt.parseInt(isize, it.next().?, 10);
        const py = try std.fmt.parseInt(isize, it.next().?, 10);
        _ = it.next();
        const vx = try std.fmt.parseInt(isize, it.next().?, 10);
        const vy = try std.fmt.parseInt(isize, it.next().?, 10);
        const light = Light.init(px, py, vx, vy);
        for (self.lights, 0..) |_, p| {
            try self.lights[p].append(light);
        }
        self.updateBox(light);
    }

    pub fn show(self: Message) void {
        std.debug.print("Message min {} max {}, with {} lights\n", .{ self.pmin, self.pmax, self.lights[self.pos].items.len });
        for (self.lights[self.pos].items) |light| {
            std.debug.print("light pos {} vel {}\n", .{ light.pos, light.vel });
        }
    }

    pub fn displayLights(self: *Message) !void {
        self.grid.clearRetainingCapacity();
        for (self.lights[1 - self.pos].items) |light| {
            try self.grid.put(light.pos, {});
        }
        var y = self.pmin.v[1];
        while (y <= self.pmax.v[1]) : (y += 1) {
            var x = self.pmin.v[0];
            while (x <= self.pmax.v[0]) : (x += 1) {
                const vec = Vec.copy(&[_]isize{ x, y });
                const label: []const u8 = if (self.grid.contains(vec)) "█" else " ";
                std.debug.print("{s}", .{label});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn findMessage(self: *Message) !usize {
        var count: usize = 0;
        var best = self.boxSize();
        while (true) : (count += 1) {
            self.pos = self.updateLights();
            const size = self.boxSize();
            if (best < size) break;
            best = size;
        }
        return count;
    }

    fn updateLights(self: *Message) usize {
        const nxt = 1 - self.pos;
        self.pmin = Vec.copy(&[_]isize{ INFINITY, INFINITY });
        self.pmax = Vec.copy(&[_]isize{ -INFINITY, -INFINITY });
        for (self.lights[self.pos].items, self.lights[nxt].items) |src, *tgt| {
            tgt.pos.v[0] = src.pos.v[0] + src.vel.v[0];
            tgt.pos.v[1] = src.pos.v[1] + src.vel.v[1];
            self.updateBox(tgt.*);
        }
        return nxt;
    }

    fn updateBox(self: *Message, light: Light) void {
        self.pmin.v[0] = @min(self.pmin.v[0], light.pos.v[0]);
        self.pmax.v[0] = @max(self.pmax.v[0], light.pos.v[0]);
        self.pmin.v[1] = @min(self.pmin.v[1], light.pos.v[1]);
        self.pmax.v[1] = @max(self.pmax.v[1], light.pos.v[1]);
    }

    fn boxSize(self: Message) usize {
        const sx: usize = @intCast(self.pmax.v[0] - self.pmin.v[0] + 1);
        const sy: usize = @intCast(self.pmax.v[1] - self.pmin.v[1] + 1);
        return sx * sy;
    }
};

test "sample" {
    const data =
        \\position=< 9,  1> velocity=< 0,  2>
        \\position=< 7,  0> velocity=<-1,  0>
        \\position=< 3, -2> velocity=<-1,  1>
        \\position=< 6, 10> velocity=<-2, -1>
        \\position=< 2, -4> velocity=< 2,  2>
        \\position=<-6, 10> velocity=< 2, -2>
        \\position=< 1,  8> velocity=< 1, -1>
        \\position=< 1,  7> velocity=< 1,  0>
        \\position=<-3, 11> velocity=< 1, -2>
        \\position=< 7,  6> velocity=<-1, -1>
        \\position=<-2,  3> velocity=< 1,  0>
        \\position=<-4,  3> velocity=< 2,  0>
        \\position=<10, -3> velocity=<-1,  1>
        \\position=< 5, 11> velocity=< 1, -2>
        \\position=< 4,  7> velocity=< 0, -1>
        \\position=< 8, -2> velocity=< 0,  1>
        \\position=<15,  0> velocity=<-2,  0>
        \\position=< 1,  6> velocity=< 1,  0>
        \\position=< 8,  9> velocity=< 0, -1>
        \\position=< 3,  3> velocity=<-1,  1>
        \\position=< 0,  5> velocity=< 0, -1>
        \\position=<-2,  2> velocity=< 2,  0>
        \\position=< 5, -2> velocity=< 1,  2>
        \\position=< 1,  4> velocity=< 2,  1>
        \\position=<-2,  7> velocity=< 2, -2>
        \\position=< 3,  6> velocity=<-1, -1>
        \\position=< 5,  0> velocity=< 1,  0>
        \\position=<-6,  0> velocity=< 2,  0>
        \\position=< 5,  9> velocity=< 1, -2>
        \\position=<14,  7> velocity=<-2,  0>
        \\position=<-3,  6> velocity=< 2, -1>
    ;

    var message = Message.init(testing.allocator);
    defer message.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try message.addLine(line);
    }
    // message.show();
    // try message.displayLights();

    const iterations = try message.findMessage();
    try message.displayLights();
    const text = "HI";
    std.debug.print("That should be: [{s}]\n", .{text});
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, iterations);
}
