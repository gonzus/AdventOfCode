const std = @import("std");
const assert = std.debug.assert;

const Vec = struct {
    x: i32,
    y: i32,
    z: i32,
};

const Moon = struct {
    pos: Vec,
    vel: Vec,
};

pub const Map = struct {
    const DIM = 3;

    moons: [10]Moon,
    pos: usize,
    traces: [3]std.AutoHashMap(u128, usize),
    trace_done: [3]bool,

    pub fn init() Map {
        var self = Map{
            .moons = undefined,
            .pos = 0,
            .traces = undefined,
            .trace_done = undefined,
        };
        var j: usize = 0;
        while (j < 3) : (j += 1) {
            self.traces[j] = std.AutoHashMap(u128, usize).init(std.heap.direct_allocator);
            self.trace_done[j] = false;
        }
        return self;
    }

    pub fn deinit(self: *Map) void {
        var j: usize = 0;
        while (j < 3) : (j += 1) {
            self.traces[j].deinit();
        }
    }

    pub fn add_lines(self: *Map, lines: []const u8) void {
        var it = std.mem.separate(lines, "\n");
        while (it.next()) |line| {
            self.add_line(line);
        }
    }

    pub fn add_line(self: *Map, line: []const u8) void {
        var itc = std.mem.separate(line[1 .. line.len - 1], ", ");
        while (itc.next()) |str3| {
            var ite = std.mem.separate(str3, "=");
            var j: usize = 0;
            var state: usize = 99;
            while (ite.next()) |str1| : (j += 1) {
                if (state == 99) {
                    state = str1[0] - 'x';
                    continue;
                }
                const input = std.fmt.parseInt(i32, str1, 10) catch unreachable;
                if (state == 0) {
                    self.moons[self.pos].pos.x = input;
                    self.moons[self.pos].vel.x = 0;
                } else if (state == 1) {
                    self.moons[self.pos].pos.y = input;
                    self.moons[self.pos].vel.y = 0;
                } else if (state == 2) {
                    self.moons[self.pos].pos.z = input;
                    self.moons[self.pos].vel.z = 0;
                }
                state = 99;
            }
        }
        self.pos += 1;
    }

    fn step_vel(self: *Map) void {
        // std.debug.warn("STEP\n");
        var j: usize = 0;
        while (j < self.pos) : (j += 1) {
            var k: usize = j + 1;
            while (k < self.pos) : (k += 1) {
                if (self.moons[j].pos.x < self.moons[k].pos.x) {
                    self.moons[j].vel.x += 1;
                    self.moons[k].vel.x -= 1;
                }
                if (self.moons[j].pos.x > self.moons[k].pos.x) {
                    self.moons[j].vel.x -= 1;
                    self.moons[k].vel.x += 1;
                }
                if (self.moons[j].pos.y < self.moons[k].pos.y) {
                    self.moons[j].vel.y += 1;
                    self.moons[k].vel.y -= 1;
                }
                if (self.moons[j].pos.y > self.moons[k].pos.y) {
                    self.moons[j].vel.y -= 1;
                    self.moons[k].vel.y += 1;
                }
                if (self.moons[j].pos.z < self.moons[k].pos.z) {
                    self.moons[j].vel.z += 1;
                    self.moons[k].vel.z -= 1;
                }
                if (self.moons[j].pos.z > self.moons[k].pos.z) {
                    self.moons[j].vel.z -= 1;
                    self.moons[k].vel.z += 1;
                }
            }
        }
    }

    fn step_pos(self: *Map) void {
        var j: usize = 0;
        while (j < self.pos) : (j += 1) {
            self.moons[j].pos.x += self.moons[j].vel.x;
            self.moons[j].pos.y += self.moons[j].vel.y;
            self.moons[j].pos.z += self.moons[j].vel.z;
        }
    }

    pub fn step(self: *Map) void {
        _ = self.trace(0);
        _ = self.trace(1);
        _ = self.trace(2);
        self.step_vel();
        self.step_pos();
    }

    pub fn total_energy(self: Map) usize {
        var total: usize = 0;
        var j: usize = 0;
        while (j < self.pos) : (j += 1) {
            var potential: usize = 0;
            potential += @intCast(usize, std.math.absInt(self.moons[j].pos.x) catch 0);
            potential += @intCast(usize, std.math.absInt(self.moons[j].pos.y) catch 0);
            potential += @intCast(usize, std.math.absInt(self.moons[j].pos.z) catch 0);

            var kinetic: usize = 0;
            kinetic += @intCast(usize, std.math.absInt(self.moons[j].vel.x) catch 0);
            kinetic += @intCast(usize, std.math.absInt(self.moons[j].vel.y) catch 0);
            kinetic += @intCast(usize, std.math.absInt(self.moons[j].vel.z) catch 0);

            total += potential * kinetic;
        }
        return total;
    }

    pub fn trace_completed(self: *Map) bool {
        var j: usize = 0;
        while (j < DIM) : (j += 1) {
            if (!self.trace_done[j]) {
                return false;
            }
        }
        return true;
    }

    pub fn trace(self: *Map, dim: usize) ?usize {
        const size = self.traces[dim].count();
        if (self.trace_done[dim]) {
            return size;
        }

        var label: u128 = 0;
        if (dim == 0) {
            var j: usize = 0;
            while (j < self.pos) : (j += 1) {
                label = label * 10000 + @intCast(u128, 10000 - self.moons[j].pos.x);
                label = label * 10000 + @intCast(u128, 10000 - self.moons[j].vel.x);
            }
        } else if (dim == 1) {
            var j: usize = 0;
            while (j < self.pos) : (j += 1) {
                label = label * 10000 + @intCast(u128, 10000 - self.moons[j].pos.y);
                label = label * 10000 + @intCast(u128, 10000 - self.moons[j].vel.y);
            }
        } else if (dim == 2) {
            var j: usize = 0;
            while (j < self.pos) : (j += 1) {
                label = label * 10000 + @intCast(u128, 10000 - self.moons[j].pos.z);
                label = label * 10000 + @intCast(u128, 10000 - self.moons[j].vel.z);
            }
        } else {
            @panic("FUCK YOU\n");
        }

        const pos = size + 1;
        if (self.traces[dim].contains(label)) {
            self.trace_done[dim] = true;
            const where = self.traces[dim].get(label).?.value;
            // std.debug.warn("*** FOUND dim {} pos {} label {} => {}\n", dim, pos, label, size);
            return pos;
        } else {
            _ = self.traces[dim].put(label, pos) catch unreachable;
            // std.debug.warn("*** CREATE dim {} pos {} label {}\n", dim, pos, label);
            return null;
        }
    }

    fn gcd(a: usize, b: usize) usize {
        var la = a;
        var lb = b;
        while (lb != 0) {
            const t = lb;
            lb = la % lb;
            la = t;
        }
        return la;
    }

    pub fn cycle_size(self: Map) usize {
        var j: usize = 0;
        var p: usize = 1;
        while (j < 3) : (j += 1) {
            const v = self.traces[j].count();
            if (j == 0) {
                p = v;
                continue;
            }
            const g = gcd(v, p);
            p *= v / g;
        }
        return p;
    }

    pub fn find_cycle_size(self: *Map) usize {
        while (!self.trace_completed()) {
            self.step();
        }
        return self.cycle_size();
    }

    pub fn show(self: Map) void {
        std.debug.warn("Map: {} moons\n", self.pos);
        std.debug.warn("Total energy: {}\n", self.total_energy());
        var j: usize = 0;
        while (j < self.pos) : (j += 1) {
            std.debug.warn("Moon {}: pos {} {} {}, vel {} {} {}\n", j, self.moons[j].pos.x, self.moons[j].pos.y, self.moons[j].pos.z, self.moons[j].vel.x, self.moons[j].vel.y, self.moons[j].vel.z);
        }
    }
};

// test "simple" {
//     std.debug.warn("\n");
//     const data: []const u8 =
//         \\<x=-1, y=0, z=2>
//         \\<x=2, y=-10, z=-7>
//         \\<x=4, y=-8, z=8>
//         \\<x=3, y=5, z=-1>
//     ;
//     var map = Map.init();
//     map.add_lines(data);
//     map.show();
//     var j: usize = 0;
//     while (j < 10) : (j += 1) {
//         map.step();
//         map.show();
//     }
// }

test "recur" {
    std.debug.warn("\n");
    const data: []const u8 =
        \\<x=-1, y=0, z=2>
        \\<x=2, y=-10, z=-7>
        \\<x=4, y=-8, z=8>
        \\<x=3, y=5, z=-1>
    ;
    var map = Map.init();
    map.add_lines(data);
    map.show();
    var j: usize = 0;
    while (j < 2772) : (j += 1) {
        map.step();
        map.show();
    }
    std.debug.warn("Cycle size: {}\n", map.cycle_size());
}
