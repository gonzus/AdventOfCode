const std = @import("std");
const assert = std.debug.assert;

const DIM = 3;

const Vec = struct {
    v: [DIM]i32,
};

const Moon = struct {
    pos: Vec,
    vel: Vec,
};

pub const Trace = struct {
    data: std.AutoHashMap(u128, usize),
    done: bool,

    pub fn init() Trace {
        var self = Trace{
            .data = std.AutoHashMap(u128, usize).init(std.heap.direct_allocator),
            .done = false,
        };
        return self;
    }

    pub fn deinit(self: *Trace) void {
        self.data.deinit();
    }
};

pub const Map = struct {
    moons: [10]Moon,
    pos: usize,
    trace: [DIM]Trace,

    pub fn init() Map {
        var self = Map{
            .moons = undefined,
            .pos = 0,
            .trace = undefined,
        };
        var dim: usize = 0;
        while (dim < DIM) : (dim += 1) {
            self.trace[dim] = Trace.init();
        }
        return self;
    }

    pub fn deinit(self: *Map) void {
        var dim: usize = 0;
        while (dim < DIM) : (dim += 1) {
            self.trace[dim].deinit();
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
        while (itc.next()) |str_coord| {
            var ite = std.mem.separate(str_coord, "=");
            var j: usize = 0;
            var dim: usize = 99;
            while (ite.next()) |str_val| : (j += 1) {
                if (dim == 99) {
                    dim = str_val[0] - 'x';
                    continue;
                }
                const input = std.fmt.parseInt(i32, str_val, 10) catch unreachable;
                self.moons[self.pos].pos.v[dim] = input;
                self.moons[self.pos].vel.v[dim] = 0;
                dim = 99;
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
                var dim: usize = 0;
                while (dim < DIM) : (dim += 1) {
                    if (self.moons[j].pos.v[dim] < self.moons[k].pos.v[dim]) {
                        self.moons[j].vel.v[dim] += 1;
                        self.moons[k].vel.v[dim] -= 1;
                        continue;
                    }
                    if (self.moons[j].pos.v[dim] > self.moons[k].pos.v[dim]) {
                        self.moons[j].vel.v[dim] -= 1;
                        self.moons[k].vel.v[dim] += 1;
                        continue;
                    }
                }
            }
        }
    }

    fn step_pos(self: *Map) void {
        var j: usize = 0;
        while (j < self.pos) : (j += 1) {
            var dim: usize = 0;
            while (dim < DIM) : (dim += 1) {
                self.moons[j].pos.v[dim] += self.moons[j].vel.v[dim];
            }
        }
    }

    pub fn step(self: *Map) void {
        var dim: usize = 0;
        while (dim < DIM) : (dim += 1) {
            _ = self.trace_step(dim);
        }
        self.step_vel();
        self.step_pos();
    }

    pub fn total_energy(self: Map) usize {
        var total: usize = 0;
        var j: usize = 0;
        while (j < self.pos) : (j += 1) {
            var potential: usize = 0;
            var kinetic: usize = 0;

            var dim: usize = 0;
            while (dim < DIM) : (dim += 1) {
                potential += @intCast(usize, std.math.absInt(self.moons[j].pos.v[dim]) catch 0);
                kinetic += @intCast(usize, std.math.absInt(self.moons[j].vel.v[dim]) catch 0);
            }

            total += potential * kinetic;
        }
        return total;
    }

    pub fn trace_completed(self: *Map) bool {
        var dim: usize = 0;
        while (dim < DIM) : (dim += 1) {
            if (!self.trace[dim].done) {
                return false;
            }
        }
        return true;
    }

    pub fn trace_step(self: *Map, dim: usize) ?usize {
        const size = self.trace[dim].data.count();
        if (self.trace[dim].done) {
            return size;
        }

        var label: u128 = 0;
        var j: usize = 0;
        while (j < self.pos) : (j += 1) {
            label = label * 10000 + @intCast(u128, 10000 - self.moons[j].pos.v[dim]);
            label = label * 10000 + @intCast(u128, 10000 - self.moons[j].vel.v[dim]);
        }

        const pos = size + 1;
        if (self.trace[dim].data.contains(label)) {
            self.trace[dim].done = true;
            const where = self.trace[dim].data.get(label).?.value;
            // std.debug.warn("*** FOUND dim {} pos {} label {} => {}\n", dim, pos, label, size);
            return pos;
        } else {
            _ = self.trace[dim].data.put(label, pos) catch unreachable;
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

    fn compute_cycle_size(self: Map) usize {
        var p: usize = 1;
        var dim: usize = 0;
        while (dim < DIM) : (dim += 1) {
            const v = self.trace[dim].data.count();
            if (dim == 0) {
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
        return self.compute_cycle_size();
    }

    pub fn show(self: Map) void {
        std.debug.warn("Map: {} moons\n", self.pos);
        std.debug.warn("Total energy: {}\n", self.total_energy());
        var j: usize = 0;
        while (j < self.pos) : (j += 1) {
            std.debug.warn("Moon {}: pos {} {} {}, vel {} {} {}\n", j, self.moons[j].pos.v[0], self.moons[j].pos.v[1], self.moons[j].pos.v[2], self.moons[j].vel.v[0], self.moons[j].vel.v[1], self.moons[j].vel.v[2]);
        }
    }
};

test "energy aftr 10 steps" {
    const data: []const u8 =
        \\<x=-1, y=0, z=2>
        \\<x=2, y=-10, z=-7>
        \\<x=4, y=-8, z=8>
        \\<x=3, y=5, z=-1>
    ;
    var map = Map.init();
    map.add_lines(data);
    var j: usize = 0;
    while (j < 10) : (j += 1) {
        map.step();
    }

    assert(map.moons[0].pos.v[0] == 2);
    assert(map.moons[0].pos.v[1] == 1);
    assert(map.moons[0].pos.v[2] == -3);
    assert(map.moons[0].vel.v[0] == -3);
    assert(map.moons[0].vel.v[1] == -2);
    assert(map.moons[0].vel.v[2] == 1);
    assert(map.moons[1].pos.v[0] == 1);
    assert(map.moons[1].pos.v[1] == -8);
    assert(map.moons[1].pos.v[2] == 0);
    assert(map.moons[1].vel.v[0] == -1);
    assert(map.moons[1].vel.v[1] == 1);
    assert(map.moons[1].vel.v[2] == 3);
    assert(map.moons[2].pos.v[0] == 3);
    assert(map.moons[2].pos.v[1] == -6);
    assert(map.moons[2].pos.v[2] == 1);
    assert(map.moons[2].vel.v[0] == 3);
    assert(map.moons[2].vel.v[1] == 2);
    assert(map.moons[2].vel.v[2] == -3);
    assert(map.moons[3].pos.v[0] == 2);
    assert(map.moons[3].pos.v[1] == 0);
    assert(map.moons[3].pos.v[2] == 4);
    assert(map.moons[3].vel.v[0] == 1);
    assert(map.moons[3].vel.v[1] == -1);
    assert(map.moons[3].vel.v[2] == -1);
    assert(map.total_energy() == 179);
}

test "energy aftr 100 steps" {
    const data: []const u8 =
        \\<x=-8, y=-10, z=0>
        \\<x=5, y=5, z=10>
        \\<x=2, y=-7, z=3>
        \\<x=9, y=-8, z=-3>
    ;
    var map = Map.init();
    map.add_lines(data);
    var j: usize = 0;
    while (j < 100) : (j += 1) {
        map.step();
    }

    assert(map.moons[0].pos.v[0] == 8);
    assert(map.moons[0].pos.v[1] == -12);
    assert(map.moons[0].pos.v[2] == -9);
    assert(map.moons[0].vel.v[0] == -7);
    assert(map.moons[0].vel.v[1] == 3);
    assert(map.moons[0].vel.v[2] == 0);
    assert(map.moons[1].pos.v[0] == 13);
    assert(map.moons[1].pos.v[1] == 16);
    assert(map.moons[1].pos.v[2] == -3);
    assert(map.moons[1].vel.v[0] == 3);
    assert(map.moons[1].vel.v[1] == -11);
    assert(map.moons[1].vel.v[2] == -5);
    assert(map.moons[2].pos.v[0] == -29);
    assert(map.moons[2].pos.v[1] == -11);
    assert(map.moons[2].pos.v[2] == -1);
    assert(map.moons[2].vel.v[0] == -3);
    assert(map.moons[2].vel.v[1] == 7);
    assert(map.moons[2].vel.v[2] == 4);
    assert(map.moons[3].pos.v[0] == 16);
    assert(map.moons[3].pos.v[1] == -13);
    assert(map.moons[3].pos.v[2] == 23);
    assert(map.moons[3].vel.v[0] == 7);
    assert(map.moons[3].vel.v[1] == 1);
    assert(map.moons[3].vel.v[2] == 1);
    assert(map.total_energy() == 1940);
}

test "cycle size small" {
    const data: []const u8 =
        \\<x=-1, y=0, z=2>
        \\<x=2, y=-10, z=-7>
        \\<x=4, y=-8, z=8>
        \\<x=3, y=5, z=-1>
    ;
    var map = Map.init();
    map.add_lines(data);
    var j: usize = 0;
    while (j < 2772) : (j += 1) {
        map.step();
    }
    assert(map.moons[0].pos.v[0] == -1);
    assert(map.moons[0].pos.v[1] == 0);
    assert(map.moons[0].pos.v[2] == 2);
    assert(map.moons[0].vel.v[0] == 0);
    assert(map.moons[0].vel.v[1] == 0);
    assert(map.moons[0].vel.v[2] == 0);
    assert(map.moons[1].pos.v[0] == 2);
    assert(map.moons[1].pos.v[1] == -10);
    assert(map.moons[1].pos.v[2] == -7);
    assert(map.moons[1].vel.v[0] == 0);
    assert(map.moons[1].vel.v[1] == 0);
    assert(map.moons[1].vel.v[2] == 0);
    assert(map.moons[2].pos.v[0] == 4);
    assert(map.moons[2].pos.v[1] == -8);
    assert(map.moons[2].pos.v[2] == 8);
    assert(map.moons[2].vel.v[0] == 0);
    assert(map.moons[2].vel.v[1] == 0);
    assert(map.moons[2].vel.v[2] == 0);
    assert(map.moons[3].pos.v[0] == 3);
    assert(map.moons[3].pos.v[1] == 5);
    assert(map.moons[3].pos.v[2] == -1);
    assert(map.moons[3].vel.v[0] == 0);
    assert(map.moons[3].vel.v[1] == 0);
    assert(map.moons[3].vel.v[2] == 0);
    assert(map.compute_cycle_size() == 2772);
}

test "cycle size large" {
    const data: []const u8 =
        \\<x=-8, y=-10, z=0>
        \\<x=5, y=5, z=10>
        \\<x=2, y=-7, z=3>
        \\<x=9, y=-8, z=-3>
    ;
    var map = Map.init();
    map.add_lines(data);
    const result = map.find_cycle_size();
    assert(result == 4686774924);
}
