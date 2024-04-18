const std = @import("std");
const testing = std.testing;
const Grids = @import("./util/grid.zig");
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Mine = struct {
    pub const Pos = Math.Vector(usize, 2);
    const Grid = Grids.DenseGrid(Segment);

    const Dir = enum {
        up,
        down,
        left,
        right,

        pub fn format(
            v: Dir,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            const l = switch (v) {
                .up => "⇧",
                .down => "⇩",
                .left => "⇦",
                .right => "⇨",
            };
            _ = try writer.print("{s}", .{l});
        }
    };

    const Segment = enum {
        empty,
        horizontal,
        vertical,
        upper_left,
        upper_right,
        lower_left,
        lower_right,
        crossing,

        pub fn format(
            v: Segment,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            const l = switch (v) {
                .empty => " ",
                .horizontal => "─",
                .vertical => "│",
                .upper_left => "┌",
                .upper_right => "┐",
                .lower_left => "└",
                .lower_right => "┘",
                .crossing => "┼",
            };
            _ = try writer.print("{s}", .{l});
        }
    };

    const Action = enum {
        left,
        straight,
        right,

        pub fn nextAction(self: Action) Action {
            return switch (self) {
                .left => .straight,
                .straight => .right,
                .right => .left,
            };
        }

        pub fn nextTurn(self: Action, dir: Dir) Dir {
            return switch (self) {
                .left => switch (dir) {
                    .up => .left,
                    .down => .right,
                    .left => .down,
                    .right => .up,
                },
                .right => switch (dir) {
                    .up => .right,
                    .down => .left,
                    .left => .up,
                    .right => .down,
                },
                .straight => dir,
            };
        }
    };

    const Cart = struct {
        id: usize,
        pos: Pos,
        dir: Dir,
        action: Action,
        crashed: bool,

        pub fn init(id: usize, pos: Pos, dir: Dir) Cart {
            return .{
                .id = id,
                .pos = pos,
                .dir = dir,
                .action = .left,
                .crashed = false,
            };
        }

        pub fn nextTurn(self: *Cart, dir: Dir) Dir {
            const next = self.action.nextTurn(dir);
            self.action = self.action.nextAction();
            return next;
        }

        pub fn lessThan(_: void, l: Cart, r: Cart) bool {
            return Pos.lessThan({}, l.pos, r.pos);
        }
    };

    grid: Grid,
    carts: std.ArrayList(Cart),
    ticks: usize,
    final: Pos,

    pub fn init(allocator: Allocator) Mine {
        return .{
            .grid = Grid.init(allocator, .empty),
            .carts = std.ArrayList(Cart).init(allocator),
            .ticks = 0,
            .final = Pos.init(),
        };
    }

    pub fn deinit(self: *Mine) void {
        self.carts.deinit();
        self.grid.deinit();
    }

    pub fn addLine(self: *Mine, line: []const u8) !void {
        try self.grid.ensureCols(line.len);
        const y = self.grid.rows();
        try self.grid.ensureExtraRow();
        var segment = false;
        for (line, 0..) |c, x| {
            switch (c) {
                ' ' => {
                    try self.grid.set(x, y, .empty);
                },
                '/' => {
                    if (segment) {
                        try self.grid.set(x, y, .lower_right);
                        segment = false;
                    } else {
                        try self.grid.set(x, y, .upper_left);
                        segment = true;
                    }
                },
                '\\' => {
                    if (segment) {
                        try self.grid.set(x, y, .upper_right);
                        segment = false;
                    } else {
                        try self.grid.set(x, y, .lower_left);
                        segment = true;
                    }
                },
                '|' => try self.grid.set(x, y, .vertical),
                '-' => try self.grid.set(x, y, .horizontal),
                '+' => try self.grid.set(x, y, .crossing),
                '^' => {
                    try self.grid.set(x, y, .vertical);
                    try self.addCart(x, y, .up);
                },
                'v' => {
                    try self.grid.set(x, y, .vertical);
                    try self.addCart(x, y, .down);
                },
                '<' => {
                    try self.grid.set(x, y, .horizontal);
                    try self.addCart(x, y, .left);
                },
                '>' => {
                    try self.grid.set(x, y, .horizontal);
                    try self.addCart(x, y, .right);
                },
                else => return error.InvalidSegment,
            }
        }
    }

    pub fn show(self: *Mine) void {
        std.debug.print("Mine {}x{} with {} carts\n", .{
            self.grid.rows(),
            self.grid.cols(),
            self.carts.items.len,
        });
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                const pos = Pos.copy(&[_]usize{ x, y });
                var found = false;
                for (self.carts.items) |cart| {
                    if (pos.equal(cart.pos)) {
                        std.debug.print("{}", .{cart.dir});
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    std.debug.print("{}", .{self.grid.get(x, y)});
                }
            }
            std.debug.print("\n", .{});
        }
        for (self.carts.items) |cart| {
            std.debug.print("Cart at {} going {}\n", .{ cart.pos, cart.dir });
        }
    }

    pub fn runUntilCrash(self: *Mine) !Pos {
        try self.runUntil(true);
        return self.final;
    }

    pub fn runUntilOneCart(self: *Mine) !Pos {
        try self.runUntil(false);
        return self.final;
    }

    fn addCart(self: *Mine, x: usize, y: usize, dir: Dir) !void {
        const id = self.carts.items.len;
        const pos = Pos.copy(&[_]usize{ x, y });
        try self.carts.append(Cart.init(id, pos, dir));
    }

    fn runUntil(self: *Mine, crash: bool) !void {
        while (true) {
            try self.step();
            const crashed = self.countCrashed();
            if (crash) {
                if (crashed > 0) break;
            } else {
                if (crashed + 1 == self.carts.items.len) {
                    for (self.carts.items) |cart| {
                        if (cart.crashed) continue;
                        self.final = cart.pos;
                        break;
                    }
                    break;
                }
            }
        }
    }

    fn step(self: *Mine) !void {
        std.sort.heap(Cart, self.carts.items, {}, Cart.lessThan);
        for (self.carts.items) |*cart| {
            if (cart.crashed) continue;

            var nd = cart.dir;
            var nx = cart.pos.v[0];
            var ny = cart.pos.v[1];
            switch (nd) {
                .up => ny -= 1,
                .down => ny += 1,
                .left => nx -= 1,
                .right => nx += 1,
            }
            switch (self.grid.get(nx, ny)) {
                .empty => return error.InvalidSegment,
                .horizontal => {},
                .vertical => {},
                .upper_left => nd = if (nd == .left) .down else .right,
                .upper_right => nd = if (nd == .right) .down else .left,
                .lower_left => nd = if (nd == .left) .up else .right,
                .lower_right => nd = if (nd == .right) .up else .left,
                .crossing => nd = cart.nextTurn(nd),
            }
            cart.pos = Pos.copy(&[_]usize{ nx, ny });
            cart.dir = nd;
            for (self.carts.items) |*other| {
                if (cart.id == other.id) continue;
                if (other.crashed) continue;
                if (!cart.pos.equal(other.pos)) continue;
                self.final = other.pos;
                cart.crashed = true;
                other.crashed = true;
            }
        }
        self.ticks += 1;
    }

    fn countCrashed(self: Mine) usize {
        var count: usize = 0;
        for (self.carts.items) |*cart| {
            if (cart.crashed) count += 1;
        }
        return count;
    }
};

test "sample part 1" {
    const data =
        \\/->-\
        \\|   |  /----\
        \\| /-+--+-\  |
        \\| | |  | v  |
        \\\-+-/  \-+--/
        \\  \------/
    ;

    var mine = Mine.init(testing.allocator);
    defer mine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try mine.addLine(line);
    }
    // mine.show();

    const pos = try mine.runUntilCrash();
    const expected = Mine.Pos.copy(&[_]usize{ 7, 3 });
    try testing.expectEqual(expected, pos);
}

test "sample part 2" {
    const data =
        \\/>-<\  
        \\|   |  
        \\| /<+-\
        \\| | | v
        \\\>+</ |
        \\  |   ^
        \\  \<->/
    ;

    var mine = Mine.init(testing.allocator);
    defer mine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try mine.addLine(line);
    }
    // mine.show();

    const pos = try mine.runUntilOneCart();
    const expected = Mine.Pos.copy(&[_]usize{ 6, 4 });
    try testing.expectEqual(expected, pos);
}
