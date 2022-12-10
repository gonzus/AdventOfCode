const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Stack = struct {
    crates: std.ArrayList(u8),

    pub fn init(allocator: Allocator) Stack {
        var self = Stack{
            .crates = std.ArrayList(u8).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Stack) void {
        self.crates.deinit();
    }

    pub fn reverse(self: *Stack) void {
        const len = self.crates.items.len;
        const mid = len / 2;
        var j: usize = 0;
        while (j < mid) : (j += 1) {
            const t = self.crates.items[j];
            self.crates.items[j] = self.crates.items[len - j - 1];
            self.crates.items[len - j - 1] = t;
        }
    }
};

pub const Move = struct {
    cnt: usize,
    src: usize,
    tgt: usize,

    pub fn init(cnt: usize, src: usize, tgt: usize) Move {
        var self = Move{
            .cnt = cnt,
            .src = src,
            .tgt = tgt,
        };
        return self;
    }
};

pub const State = enum {
    Contents,
    Crates,
    Instructions,
};

pub const Arrangement = struct {
    allocator: Allocator,
    state: State,
    stacks: std.ArrayList(Stack),
    moves: std.ArrayList(Move),
    message: ?[]u8,

    pub fn init(allocator: Allocator) Arrangement {
        var self = Arrangement{
            .allocator = allocator,
            .state = .Contents,
            .stacks = std.ArrayList(Stack).init(allocator),
            .moves = std.ArrayList(Move).init(allocator),
            .message = null,
        };
        return self;
    }

    pub fn deinit(self: *Arrangement) void {
        if (self.message) |m| {
            self.allocator.free(m);
        }
        self.moves.deinit();
        for (self.stacks.items) |*stack| {
            stack.deinit();
        }
        self.stacks.deinit();
    }

    pub fn add_line(self: *Arrangement, line: []const u8) !void {
        if (line.len == 0) {
            self.state = .Instructions;
            return;
        }
        if (line[1] >= '0' and line[1] <= '9') {
            self.state = .Crates;
        }

        switch (self.state) {
            .Contents => {
                var pos: usize = 1;
                var pile: usize = 0;
                while (pos < line.len) {
                    while (self.stacks.items.len <= pile) {
                        try self.stacks.append(Stack.init(self.allocator));
                    }
                    const crate = line[pos];
                    pos += 4;
                    if (crate != ' ') {
                        try self.stacks.items[pile].crates.append(crate);
                    }
                    pile += 1;

                }
            },
            .Crates => {
                for (self.stacks.items) |*stack| {
                    stack.reverse();
                }
            },
            .Instructions => {
                var move: Move = undefined;
                var pos: usize = 0;
                var it = std.mem.tokenize(u8, line, " ");
                while (it.next()) |what| : (pos += 1) {
                    switch (pos) {
                        1 => move.cnt = try std.fmt.parseInt(usize, what, 10),
                        3 => move.src = try std.fmt.parseInt(usize, what, 10),
                        5 => move.tgt = try std.fmt.parseInt(usize, what, 10),
                        else => continue,
                    }
                }
                try self.moves.append(move);
            }
        }
    }

    pub fn show(self: Arrangement) void {
        std.debug.print("\nArrangement: state {}\n", .{self.state});
        for (self.stacks.items) |stack, j| {
            std.debug.print("Stack {}:\n", .{j+1});
            for (stack.crates.items) |crate, k| {
                std.debug.print("  Crate {}: {c}\n", .{k+1, crate});
            }
        }
        for (self.moves.items) |move, j| {
            std.debug.print("Move {}: {} {} {}\n", .{j+1, move.cnt, move.src, move.tgt});
        }
    }

    pub fn rearrange(self: *Arrangement, simultaneous: bool) !void {
        for (self.moves.items) |move| {
            const ns = move.src - 1;
            const nt = move.tgt - 1;
            var s: *Stack = &self.stacks.items[ns];
            var t: *Stack = &self.stacks.items[nt];
            var j: usize = 0;
            while (j < move.cnt) : (j += 1) {
                const offset = if (simultaneous) move.cnt - j else j + 1;
                const item = s.*.crates.items[s.*.crates.items.len - offset];
                try t.*.crates.append(item);
            }
            s.*.crates.items.len -= move.cnt;
        }
    }

    pub fn get_message(self: *Arrangement) ![]const u8 {
        if (self.message == null) {
            self.message = try self.allocator.alloc(u8, self.stacks.items.len);
        }
        var pos: usize = 0;
        for (self.stacks.items) |stack| {
            const top = stack.crates.items[stack.crates.items.len - 1];
            self.message.?[pos] = top;
            pos += 1;
        }
        return self.message.?[0..pos];
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\    [D]
        \\[N] [C]
        \\[Z] [M] [P]
        \\ 1   2   3
        \\
        \\move 1 from 2 to 1
        \\move 3 from 1 to 3
        \\move 2 from 2 to 1
        \\move 1 from 1 to 2
    ;

    var arrangement = Arrangement.init(std.testing.allocator);
    defer arrangement.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try arrangement.add_line(line);
    }

    // arrangement.show();
    try arrangement.rearrange(false);
    const message = try arrangement.get_message();
    try testing.expectEqualStrings(message, "CMZ");
}

test "sample part 2" {
    const data: []const u8 =
        \\    [D]
        \\[N] [C]
        \\[Z] [M] [P]
        \\ 1   2   3
        \\
        \\move 1 from 2 to 1
        \\move 3 from 1 to 3
        \\move 2 from 2 to 1
        \\move 1 from 1 to 2
    ;

    var arrangement = Arrangement.init(std.testing.allocator);
    defer arrangement.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try arrangement.add_line(line);
    }

    // arrangement.show();
    try arrangement.rearrange(true);
    const message = try arrangement.get_message();
    try testing.expectEqualStrings(message, "MCD");
}
