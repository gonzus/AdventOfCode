const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Timetable = struct {
    departure: usize,
    buses: std.AutoHashMap(usize, usize),

    pub fn init() Timetable {
        var self = Timetable{
            .departure = 0,
            .buses = std.AutoHashMap(usize, usize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Timetable) void {
        self.buses.deinit();
    }

    pub fn add_line(self: *Timetable, line: []const u8) void {
        if (self.departure <= 0) {
            self.departure = std.fmt.parseInt(usize, line, 10) catch unreachable;
            return;
        }

        var pos: usize = 0;
        var it = std.mem.tokenize(u8, line, ",");
        while (it.next()) |str| : (pos += 1) {
            if (str[0] == 'x') continue;
            const id = std.fmt.parseInt(usize, str, 10) catch unreachable;
            _ = self.buses.put(pos, id) catch unreachable;
        }
    }

    pub fn product_for_earliest_bus(self: Timetable) usize {
        var product: usize = 0;
        var min: usize = std.math.maxInt(usize);
        var it = self.buses.iterator();
        while (it.next()) |kv| {
            const id = kv.value_ptr.*;
            const next = self.departure % id;
            const wait = id - next;
            const departure = self.departure + wait;
            if (min > departure) {
                min = departure;
                product = id * wait;
            }
        }
        return product;
    }

    pub fn earliest_departure(self: Timetable) usize {
        var divs = std.ArrayList(usize).init(allocator);
        defer divs.deinit();

        var rems = std.ArrayList(usize).init(allocator);
        defer rems.deinit();

        var it = self.buses.iterator();
        while (it.next()) |kv| {
            const pos = kv.key_ptr.*;
            const id = kv.value_ptr.*;
            divs.append(id) catch unreachable;

            const rem: usize = if (pos == 0) 0 else id - pos % id;
            rems.append(rem) catch unreachable;
        }
        const cr = chinese_remainder(divs.items, rems.items);
        return cr;
    }
};

fn chinese_remainder(divs: []const usize, rems: []const usize) usize {
    if (divs.len != rems.len) return 0;

    const len = divs.len;
    if (len == 0) return 0;

    var prod: usize = 1;
    var j: usize = 0;
    while (j < len) : (j += 1) {
        // if this overflows, can't do
        prod *= divs[j];
    }

    var sum: usize = 0;
    var k: usize = 0;
    while (k < len) : (k += 1) {
        const p: usize = prod / divs[k];
        sum += rems[k] * mul_inv(p, divs[k]) * p;
    }

    return sum % prod;
}

// returns x where (a * x) % b == 1
fn mul_inv(a: usize, b: usize) usize {
    if (b == 1) return 1;

    var ax = @intCast(isize, a);
    var bx = @intCast(isize, b);
    var x0: isize = 0;
    var x1: isize = 1;
    while (ax > 1) {
        const q = @divTrunc(ax, bx);

        // both @mod and @rem work here
        const t0 = bx;
        bx = @rem(ax, bx);
        ax = t0;

        const t1 = x0;
        x0 = x1 - q * x0;
        x1 = t1;
    }
    if (x1 < 0) {
        x1 += @intCast(isize, b);
    }
    return @intCast(usize, x1);
}

test "sample earliest bus" {
    const data: []const u8 =
        \\939
        \\7,13,x,x,59,x,31,19
    ;

    var timetable = Timetable.init();
    defer timetable.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        timetable.add_line(line);
    }

    const product = timetable.product_for_earliest_bus();
    try testing.expect(product == 295);
}

test "chinese reminder" {
    const n = [_]usize{ 3, 5, 7 };
    const a = [_]usize{ 2, 3, 2 };
    const cr = chinese_remainder(n[0..], a[0..]);
    try testing.expect(cr == 23);
}

test "sample earliest departure 1" {
    const data: []const u8 =
        \\939
        \\7,13,x,x,59,x,31,19
    ;

    var timetable = Timetable.init();
    defer timetable.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        timetable.add_line(line);
    }

    const timestamp = timetable.earliest_departure();
    try testing.expect(timestamp == 1068781);
}

test "sample earliest departure 2" {
    const data: []const u8 =
        \\999
        \\17,x,13,19
    ;

    var timetable = Timetable.init();
    defer timetable.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        timetable.add_line(line);
    }

    const timestamp = timetable.earliest_departure();
    try testing.expect(timestamp == 3417);
}

test "sample earliest departure 3" {
    const data: []const u8 =
        \\999
        \\67,7,59,61
    ;

    var timetable = Timetable.init();
    defer timetable.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        timetable.add_line(line);
    }

    const timestamp = timetable.earliest_departure();
    try testing.expect(timestamp == 754018);
}

test "sample earliest departure 4" {
    const data: []const u8 =
        \\999
        \\67,x,7,59,61
    ;

    var timetable = Timetable.init();
    defer timetable.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        timetable.add_line(line);
    }

    const timestamp = timetable.earliest_departure();
    try testing.expect(timestamp == 779210);
}

test "sample earliest departure 5" {
    const data: []const u8 =
        \\999
        \\67,7,x,59,61
    ;

    var timetable = Timetable.init();
    defer timetable.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        timetable.add_line(line);
    }

    const timestamp = timetable.earliest_departure();
    try testing.expect(timestamp == 1261476);
}

test "sample earliest departure 6" {
    const data: []const u8 =
        \\999
        \\1789,37,47,1889
    ;

    var timetable = Timetable.init();
    defer timetable.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        timetable.add_line(line);
    }

    const timestamp = timetable.earliest_departure();
    try testing.expect(timestamp == 1202161486);
}
