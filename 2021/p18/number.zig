const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Number = struct {
    const PAIR = std.math.maxInt(usize);

    const State = enum { SEARCH, EXPLODE, SPLIT };

    const Cell = struct {
        num: usize,
        l: ?*Cell,
        r: ?*Cell,
        p: ?*Cell,

        fn init() *Cell {
            var c: *Cell = allocator.create(Cell) catch unreachable;
            c.*.num = 0;
            c.*.l = null;
            c.*.r = null;
            c.*.p = null;
            return c;
        }

        pub fn init_num(num: usize) *Cell {
            var c = Cell.init();
            c.*.num = num;
            return c;
        }

        pub fn init_pair(l: *Cell, r: *Cell) *Cell {
            var c = Cell.init();
            c.*.num = PAIR;
            c.l = l;
            c.r = r;
            l.p = c;
            r.p = c;
            return c;
        }

        pub fn clone(c: *Cell) *Cell {
            if (c.is_num()) return init_num(c.num);
            return init_pair(c.l.?.clone(), c.r.?.clone());
        }

        pub fn deinit(self: *Cell) void {
            if (self.l) |l| l.*.deinit();
            if (self.r) |r| r.*.deinit();
            allocator.destroy(self);
        }

        pub fn equal(self: *Cell, other: *Cell) bool {
            if (self.is_num() and other.is_num()) {
                return self.num == other.num;
            }
            if (self.is_pair() and other.is_pair()) {
                return Cell.equal(self.l.?, other.l.?) and Cell.equal(self.r.?, other.r.?);
            }
            return false;
        }

        pub fn is_num(self: Cell) bool {
            return self.num != PAIR;
        }

        pub fn is_pair(self: Cell) bool {
            return self.num == PAIR;
        }

        pub fn is_simple(self: Cell) bool {
            return self.is_pair() and self.l.?.is_num() and self.r.?.is_num();
        }

        pub fn show(self: Cell) void {
            if (self.is_num()) {
                std.debug.warn("{d}", .{self.num});
            } else {
                std.debug.warn("[", .{});
                self.l.?.show();
                std.debug.warn(",", .{});
                self.r.?.show();
                std.debug.warn("]", .{});
            }
        }

        pub fn add(l: *Cell, r: *Cell) *Cell {
            var c: *Cell = init_pair(l.clone(), r.clone());
            c.*.reduce();
            return c;
        }

        pub fn parse_pair(data: []const u8, pos: *usize) *Cell {
            pos.* += 1; // '['
            var l = parse_cell(data, pos);
            pos.* += 1; // ','
            var r = parse_cell(data, pos);
            pos.* += 1; // ']'
            var c = init_pair(l, r);
            return c;
        }

        pub fn parse_cell(data: []const u8, pos: *usize) *Cell {
            if (data[pos.*] < '0' or data[pos.*] > '9') {
                return parse_pair(data, pos);
            }

            var num: usize = 0;
            for (data[pos.*..]) |c| {
                if (c < '0' or c > '9') break;
                num *= 10;
                num += c - '0';
                pos.* += 1;
            }
            return init_num(num);
        }

        fn find_parent_for_right(self: *Cell) ?*Cell {
            // std.debug.warn("FIND RIGHT node {}\n", .{self});
            if (self.p) |p| {
                if (self == p.r) {
                    return p.l;
                }
                return p.find_parent_for_right();
            }
            return null;
        }

        fn find_parent_for_left(self: *Cell) ?*Cell {
            // std.debug.warn("FIND LEFT node {}\n", .{self});
            if (self.p) |p| {
                if (self == p.l) {
                    return p.r;
                }
                return p.find_parent_for_left();
            }
            return null;
        }

        fn add_first(self: *Cell, delta: usize) void {
            if (self.is_num()) {
                // std.debug.warn("ADDING FIRST {} to {} => {}\n", .{ delta, self.*.num, self.*.num + delta });
                self.*.num += delta;
            } else {
                self.l.?.add_first(delta);
            }
        }

        fn add_last(self: *Cell, delta: usize) void {
            if (self.is_num()) {
                // std.debug.warn("ADDING LAST {} to {} => {}\n", .{ delta, self.*.num, self.*.num + delta });
                self.*.num += delta;
            } else {
                self.r.?.add_last(delta);
            }
        }

        pub fn magnitude(self: *Cell) usize {
            if (self.is_num()) {
                return self.num;
            }
            return 3 * self.l.?.magnitude() + 2 * self.r.?.magnitude();
        }

        pub fn reduce(self: *Cell) void {
            // std.debug.warn("REDUCE ", .{});
            // self.show();
            // std.debug.warn("\n", .{});

            while (true) {
                if (self.explode(1)) continue;
                if (self.split(1)) continue;
                break;
            }
        }

        pub fn split(self: *Cell, depth: usize) bool {
            if (self.*.is_num()) {
                if (self.*.num < 10) return false;

                const mid = @divTrunc(self.*.num, 2);
                const odd = if (self.*.num & 1 == 1) @as(usize, 1) else @as(usize, 0);
                // std.debug.warn("[{}] SPLIT {} => [{},{}]\n", .{ depth, self.*.num, mid, mid + odd });

                self.*.num = PAIR;
                self.*.l = init_num(mid);
                self.*.l.?.p = self;
                self.*.r = init_num(mid + odd);
                self.*.r.?.p = self;
                return true;
            } else {
                if (self.*.l.?.split(depth + 1)) return true;
                if (self.*.r.?.split(depth + 1)) return true;
                return false;
            }
        }

        pub fn explode(self: *Cell, depth: usize) bool {
            if (self.*.is_num()) {
                return false;
            }

            if (depth <= 4 or !self.is_simple()) {
                if (self.*.l.?.explode(depth + 1)) return true;
                if (self.*.r.?.explode(depth + 1)) return true;
                return false;
            }

            // std.debug.warn("[{}] EXPLODE ", .{depth});
            // self.*.show();
            // std.debug.warn("\n", .{});
            const L = self.*.l.?.num;
            const R = self.*.r.?.num;
            self.*.l.?.deinit();
            self.*.r.?.deinit();
            self.*.num = 0;
            self.*.l = null;
            self.*.r = null;

            var node: ?*Cell = null;

            node = self.find_parent_for_right();
            if (node) |n| {
                n.add_last(L);
            }

            node = self.find_parent_for_left();
            if (node) |n| {
                n.add_first(R);
            }

            return true;
        }
    };

    numbers: std.ArrayList(*Cell),

    pub fn init() Number {
        var self = Number{
            .numbers = std.ArrayList(*Cell).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Number) void {
        for (self.numbers.items) |*n| {
            n.*.deinit();
        }
        self.numbers.deinit();
    }

    pub fn process_line(self: *Number, data: []const u8) !void {
        var pos: usize = 0;
        var num = Cell.parse_cell(data, &pos);
        try self.numbers.append(num);
    }

    pub fn add_all(self: *Number) usize {
        var sum: ?*Cell = null;
        for (self.numbers.items) |n| {
            if (sum == null) {
                sum = n.clone();
            } else {
                var s = Cell.add(sum.?, n);
                sum.?.deinit();
                sum = s;
            }
        }
        var mag: usize = 0;
        if (sum != null) {
            mag = sum.?.magnitude();
            sum.?.deinit();
        }
        return mag;
    }

    pub fn largest_sum_of_two(self: *Number) usize {
        var mag: usize = 0;
        var j0: usize = 0;
        while (j0 < self.numbers.items.len) : (j0 += 1) {
            var j1: usize = 0;
            while (j1 < self.numbers.items.len) : (j1 += 1) {
                if (j0 == j1) continue;

                var c0 = self.numbers.items[j0].clone();
                defer c0.deinit();
                var c1 = self.numbers.items[j1].clone();
                defer c1.deinit();

                var s = Cell.add(c0, c1);
                defer s.deinit();

                var m = s.magnitude();
                if (mag < m) mag = m;
            }
        }
        return mag;
    }
};

// test "sample part a reduce 1" {
//     var pos: usize = 0;
//     std.debug.warn("\n", .{});

//     pos = 0;
//     var ori = Number.Cell.parse_cell("[[[[[9,8],1],2],3],4]", &pos);
//     defer ori.deinit();

//     ori.reduce();

//     pos = 0;
//     var res = Number.Cell.parse_cell("[[[[0,9],2],3],4]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(ori, res));
// }

// test "sample part a reduce 2" {
//     var pos: usize = 0;
//     std.debug.warn("\n", .{});

//     pos = 0;
//     var ori = Number.Cell.parse_cell("[7,[6,[5,[4,[3,2]]]]]", &pos);
//     defer ori.deinit();

//     ori.reduce();

//     pos = 0;
//     var res = Number.Cell.parse_cell("[7,[6,[5,[7,0]]]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(ori, res));
// }

// test "sample part a reduce 3" {
//     var pos: usize = 0;
//     std.debug.warn("\n", .{});

//     pos = 0;
//     var ori = Number.Cell.parse_cell("[[6,[5,[4,[3,2]]]],1]", &pos);
//     defer ori.deinit();

//     ori.reduce();

//     pos = 0;
//     var res = Number.Cell.parse_cell("[[6,[5,[7,0]]],3]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(ori, res));
// }

// test "sample part a reduce 4" {
//     var pos: usize = 0;
//     std.debug.warn("\n", .{});

//     pos = 0;
//     var ori = Number.Cell.parse_cell("[[3,[2,[1,[7,3]]]],[6,[5,[4,[3,2]]]]]", &pos);
//     defer ori.deinit();

//     ori.reduce();

//     pos = 0;
//     var res = Number.Cell.parse_cell("[[3,[2,[8,0]]],[9,[5,[7,0]]]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(ori, res));
// }

// test "sample part a reduce 5" {
//     var pos: usize = 0;
//     std.debug.warn("\n", .{});

//     pos = 0;
//     var ori = Number.Cell.parse_cell("[[[[[4,3],4],4],[7,[[8,4],9]]],[1,1]]", &pos);
//     defer ori.deinit();

//     ori.reduce();

//     pos = 0;
//     var res = Number.Cell.parse_cell("[[[[0,7],4],[[7,8],[6,0]]],[8,1]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(ori, res));
// }

// test "sample part a reduce 6" {
//     var pos: usize = 0;
//     std.debug.warn("\n", .{});

//     pos = 0;
//     var ori = Number.Cell.parse_cell("[[[[[1,1],[2,2]],[3,3]],[4,4]],[5,5]]", &pos);
//     defer ori.deinit();

//     ori.reduce();

//     pos = 0;
//     var res = Number.Cell.parse_cell("[[[[3,0],[5,3]],[4,4]],[5,5]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(ori, res));
// }

// test "sample part a add 0" {
//     const data: []const u8 =
//         \\[1,2]
//         \\[[3,4],5]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     var pos: usize = 0;
//     var res = Number.Cell.parse_cell("[[1,2],[[3,4],5]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(number.value.?, res));
// }

// test "sample part a add 1" {
//     const data: []const u8 =
//         \\[1,1]
//         \\[2,2]
//         \\[3,3]
//         \\[4,4]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     var pos: usize = 0;
//     var res = Number.Cell.parse_cell("[[[[1,1],[2,2]],[3,3]],[4,4]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(number.value.?, res));
// }

// test "sample part a add 2" {
//     const data: []const u8 =
//         \\[1,1]
//         \\[2,2]
//         \\[3,3]
//         \\[4,4]
//         \\[5,5]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     var pos: usize = 0;
//     var res = Number.Cell.parse_cell("[[[[3,0],[5,3]],[4,4]],[5,5]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(number.value.?, res));
// }

// test "sample part a add 3" {
//     const data: []const u8 =
//         \\[1,1]
//         \\[2,2]
//         \\[3,3]
//         \\[4,4]
//         \\[5,5]
//         \\[6,6]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     var pos: usize = 0;
//     var res = Number.Cell.parse_cell("[[[[5,0],[7,4]],[5,5]],[6,6]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(number.value.?, res));
// }

// test "sample part a add 4.1" {
//     const data: []const u8 =
//         \\[[[0,[4,5]],[0,0]],[[[4,5],[2,6]],[9,5]]]
//         \\[7,[[[3,7],[4,3]],[[6,3],[8,8]]]]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     var pos: usize = 0;
//     var res = Number.Cell.parse_cell("[[[[4,0],[5,4]],[[7,7],[6,0]]],[[8,[7,7]],[[7,9],[5,0]]]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(number.value.?, res));
// }

// test "sample part a add 4.2" {
//     const data: []const u8 =
//         \\[[[[4,0],[5,4]],[[7,7],[6,0]]],[[8,[7,7]],[[7,9],[5,0]]]]
//         \\[[2,[[0,8],[3,4]]],[[[6,7],1],[7,[1,6]]]]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     var pos: usize = 0;
//     var res = Number.Cell.parse_cell("[[[[6,7],[6,7]],[[7,7],[0,7]]],[[[8,7],[7,7]],[[8,8],[8,0]]]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(number.value.?, res));
// }

// test "sample part a add 4.3" {
//     const data: []const u8 =
//         \\[[[[6,7],[6,7]],[[7,7],[0,7]]],[[[8,7],[7,7]],[[8,8],[8,0]]]]
//         \\[[[[2,4],7],[6,[0,5]]],[[[6,8],[2,8]],[[2,1],[4,5]]]]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     var pos: usize = 0;
//     var res = Number.Cell.parse_cell("[[[[7,0],[7,7]],[[7,7],[7,8]]],[[[7,7],[8,8]],[[7,7],[8,7]]]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(number.value.?, res));
// }

// test "sample part a magnitude 1" {
//     const data: []const u8 =
//         \\[[1,2],[[3,4],5]]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     try testing.expect(number.magnitude() == 143);
// }

// test "sample part a magnitude 2" {
//     const data: []const u8 =
//         \\[[[[0,7],4],[[7,8],[6,0]]],[8,1]]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     try testing.expect(number.magnitude() == 1384);
// }

// test "sample part a magnitude 6" {
//     const data: []const u8 =
//         \\[[[[8,7],[7,7]],[[8,6],[7,7]]],[[[0,7],[6,6]],[8,7]]]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     try testing.expect(number.magnitude() == 3488);
// }

// test "sample part a add 11" {
//     const data: []const u8 =
//         \\[[[0,[4,5]],[0,0]],[[[4,5],[2,6]],[9,5]]]
//         \\[7,[[[3,7],[4,3]],[[6,3],[8,8]]]]
//         \\[[2,[[0,8],[3,4]]],[[[6,7],1],[7,[1,6]]]]
//         \\[[[[2,4],7],[6,[0,5]]],[[[6,8],[2,8]],[[2,1],[4,5]]]]
//         \\[7,[5,[[3,8],[1,4]]]]
//         \\[[2,[2,2]],[8,[8,1]]]
//         \\[2,9]
//         \\[1,[[[9,3],9],[[9,0],[0,7]]]]
//         \\[[[5,[7,4]],7],1]
//         \\[[[[4,2],2],6],[8,7]]
//     ;

//     var number = Number.init();
//     defer number.deinit();

//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try number.process_line(line);
//     }

//     var pos: usize = 0;
//     var res = Number.Cell.parse_cell("[[[[8,7],[7,7]],[[8,6],[7,7]]],[[[0,7],[6,6]],[8,7]]]", &pos);
//     defer res.deinit();

//     try testing.expect(Number.Cell.equal(number.value.?, res));
// }

test "sample part a add sample" {
    const data: []const u8 =
        \\[[[0,[5,8]],[[1,7],[9,6]]],[[4,[1,2]],[[1,4],2]]]
        \\[[[5,[2,8]],4],[5,[[9,9],0]]]
        \\[6,[[[6,2],[5,6]],[[7,6],[4,7]]]]
        \\[[[6,[0,7]],[0,9]],[4,[9,[9,0]]]]
        \\[[[7,[6,4]],[3,[1,3]]],[[[5,5],1],9]]
        \\[[6,[[7,3],[3,2]]],[[[3,8],[5,7]],4]]
        \\[[[[5,4],[7,7]],8],[[8,3],8]]
        \\[[9,3],[[9,9],[6,[4,9]]]]
        \\[[2,[[7,7],7]],[[5,8],[[9,3],[0,2]]]]
        \\[[[[5,2],5],[8,[3,7]]],[[5,[7,5]],[4,4]]]
    ;

    var number = Number.init();
    defer number.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try number.process_line(line);
    }

    const mag = number.add_all();
    try testing.expect(mag == 4140);
}

test "sample part b" {
    const data: []const u8 =
        \\[[[0,[5,8]],[[1,7],[9,6]]],[[4,[1,2]],[[1,4],2]]]
        \\[[[5,[2,8]],4],[5,[[9,9],0]]]
        \\[6,[[[6,2],[5,6]],[[7,6],[4,7]]]]
        \\[[[6,[0,7]],[0,9]],[4,[9,[9,0]]]]
        \\[[[7,[6,4]],[3,[1,3]]],[[[5,5],1],9]]
        \\[[6,[[7,3],[3,2]]],[[[3,8],[5,7]],4]]
        \\[[[[5,4],[7,7]],8],[[8,3],8]]
        \\[[9,3],[[9,9],[6,[4,9]]]]
        \\[[2,[[7,7],7]],[[5,8],[[9,3],[0,2]]]]
        \\[[[[5,2],5],[8,[3,7]]],[[5,[7,5]],[4,4]]]
    ;

    var number = Number.init();
    defer number.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try number.process_line(line);
    }

    const mag = number.largest_sum_of_two();
    try testing.expect(mag == 3993);
}
