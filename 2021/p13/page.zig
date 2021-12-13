const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Page = struct {
    pub const Buffer = std.ArrayList(u8);

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            var self = Pos{ .x = x, .y = y };
            return self;
        }
    };

    cur: usize,
    dots: [2]std.AutoHashMap(Pos, usize),
    width: usize,
    height: usize,
    folding: bool,
    fold_count: usize,
    first_count: usize,

    pub fn init() Page {
        var self = Page{
            .cur = 0,
            .dots = undefined,
            .width = 0,
            .height = 0,
            .folding = false,
            .fold_count = 0,
            .first_count = 0,
        };
        self.dots[0] = std.AutoHashMap(Pos, usize).init(allocator);
        self.dots[1] = std.AutoHashMap(Pos, usize).init(allocator);
        return self;
    }

    pub fn deinit(self: *Page) void {
        self.dots[1].deinit();
        self.dots[0].deinit();
    }

    pub fn process_line(self: *Page, data: []const u8) !void {
        if (data.len == 0) {
            self.folding = true;
            // std.debug.warn("FOLDING\n", .{});
            return;
        }
        if (!self.folding) {
            var x: usize = 0;
            var pos: usize = 0;
            var it = std.mem.split(u8, data, ",");
            while (it.next()) |num| : (pos += 1) {
                const n = std.fmt.parseInt(usize, num, 10) catch unreachable;
                if (pos == 0) {
                    x = n;
                    continue;
                }
                if (pos == 1) {
                    try self.dots[self.cur].put(Pos.init(x, n), 1);
                    // std.debug.warn("DOT {} {}\n", .{ x, n });
                    x = 0;
                    continue;
                }
                unreachable;
            }
        } else {
            var poss: usize = 0;
            var its = std.mem.tokenize(u8, data, " ");
            while (its.next()) |word| : (poss += 1) {
                if (poss != 2) continue;

                var axis: u8 = 0;
                var posq: usize = 0;
                var itq = std.mem.split(u8, word, "=");
                while (itq.next()) |what| : (posq += 1) {
                    if (posq == 0) {
                        axis = what[0];
                        continue;
                    }
                    if (posq == 1) {
                        const pos = std.fmt.parseInt(usize, what, 10) catch unreachable;
                        self.fold_count += 1;
                        try self.fold(axis, pos);
                        axis = 0;
                        if (self.fold_count == 1) {
                            self.first_count = self.count_total_dots();
                        }
                        continue;
                    }
                    unreachable;
                }
            }
        }
    }

    pub fn dots_after_first_fold(self: Page) usize {
        return self.first_count;
    }

    pub fn render_code(self: Page, buffer: *Buffer, empty: []const u8, full: []const u8) !void {
        var y: usize = 0;
        while (y <= self.height) : (y += 1) {
            var x: usize = 0;
            while (x <= self.width) : (x += 1) {
                var txt = empty;
                var p = Pos.init(x, y);
                if (self.dots[self.cur].contains(p)) {
                    if (self.dots[self.cur].get(p).? > 0) {
                        txt = full;
                    }
                }
                for (txt) |c| {
                    try buffer.append(c);
                }
            }
            try buffer.append('\n');
        }
    }

    fn count_total_dots(self: Page) usize {
        var count: usize = 0;
        var it = self.dots[self.cur].iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* == 0) continue;
            count += 1;
        }
        // std.debug.warn("DOTS {}\n", .{count});
        return count;
    }

    fn fold(self: *Page, axis: u8, pos: usize) !void {
        // std.debug.warn("FOLD {c} {}\n", .{ axis, pos });
        self.width = 0;
        self.height = 0;
        const nxt = 1 - self.cur;
        self.dots[nxt].clearRetainingCapacity();
        var it = self.dots[self.cur].iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* == 0) continue;
            var p = entry.key_ptr.*;
            if (axis == 'x') {
                if (p.x > pos) {
                    p.x = pos * 2 - p.x;
                }
            }
            if (axis == 'y') {
                if (p.y > pos) {
                    p.y = pos * 2 - p.y;
                }
            }
            // std.debug.warn("DOT {}\n", .{ p });
            try self.dots[nxt].put(p, 1);
            if (self.width < p.x) self.width = p.x;
            if (self.height < p.y) self.height = p.y;
        }
        self.cur = nxt;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\6,10
        \\0,14
        \\9,10
        \\0,3
        \\10,4
        \\4,11
        \\6,0
        \\6,12
        \\4,1
        \\0,13
        \\10,12
        \\3,4
        \\3,0
        \\8,4
        \\1,10
        \\2,14
        \\8,10
        \\9,0
        \\
        \\fold along y=7
        \\fold along x=5
    ;

    var page = Page.init();
    defer page.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try page.process_line(line);
    }
    const total_dots = page.dots_after_first_fold();
    try testing.expect(total_dots == 17);
}

test "sample part b" {
    const data: []const u8 =
        \\6,10
        \\0,14
        \\9,10
        \\0,3
        \\10,4
        \\4,11
        \\6,0
        \\6,12
        \\4,1
        \\0,13
        \\10,12
        \\3,4
        \\3,0
        \\8,4
        \\1,10
        \\2,14
        \\8,10
        \\9,0
        \\
        \\fold along y=7
        \\fold along x=5
    ;
    const expected: []const u8 =
        \\*****
        \\*...*
        \\*...*
        \\*...*
        \\*****
        \\
    ;

    var page = Page.init();
    defer page.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try page.process_line(line);
    }

    var buffer = Page.Buffer.init(allocator);
    defer buffer.deinit();
    try page.render_code(&buffer, ".", "*");
    try testing.expect(std.mem.eql(u8, buffer.items, expected));
}
