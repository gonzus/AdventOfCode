const std = @import("std");
const testing = std.testing;

const allocator = std.testing.allocator;

pub const Bingo = struct {
    const Board = struct {
        const SIZE = 5;

        const Pos = struct {
            row: usize,
            col: usize,
            hit: bool,

            pub fn init(row: usize, col: usize) Pos {
                var self = Pos{
                    .row = row,
                    .col = col,
                    .hit = false,
                };
                return self;
            }
        };

        won: bool,
        data: std.AutoHashMap(usize, Pos),
        row_hits: [SIZE]usize,
        col_hits: [SIZE]usize,

        pub fn init() Board {
            var self = Board{
                .won = false,
                .data = std.AutoHashMap(usize, Pos).init(allocator),
                .row_hits = [_]usize{0} ** SIZE,
                .col_hits = [_]usize{0} ** SIZE,
            };
            return self;
        }

        pub fn deinit(self: *Board) void {
            self.data.deinit();
        }

        fn get_score(self: *Board, draw: usize) usize {
            var sum: usize = 0;
            var it = self.data.iterator();
            while (it.next()) |entry| {
                const p = entry.value_ptr;
                if (p.*.hit) continue;
                const n = entry.key_ptr.*;
                // std.debug.warn("POS {} {} = {}\n", .{ p.*.row, p.*.col, n });
                sum += n;
            }
            const score = draw * sum;
            // std.debug.warn("SCORE {} * {} = {}\n", .{ draw, sum, score });
            return score;
        }
    };

    boards: std.ArrayList(Board),
    draws: std.ArrayList(usize),
    row: usize,
    col: usize,

    pub fn init() Bingo {
        var self = Bingo{
            .boards = std.ArrayList(Board).init(allocator),
            .draws = std.ArrayList(usize).init(allocator),
            .row = 0,
            .col = 0,
        };
        return self;
    }

    pub fn deinit(self: *Bingo) void {
        self.draws.deinit();
        for (self.boards.items) |*board| {
            board.deinit();
        }
        self.boards.deinit();
    }

    pub fn process_line(self: *Bingo, data: []const u8) void {
        if (self.draws.items.len == 0) {
            var it = std.mem.split(u8, data, ",");
            while (it.next()) |num| {
                const n = std.fmt.parseInt(usize, num, 10) catch unreachable;
                // std.debug.warn("DRAW {}\n", .{n});
                self.draws.append(n) catch unreachable;
            }
            return;
        }
        if (data.len == 0) {
            // std.debug.warn("BLANK\n", .{});
            self.row = 0;
            self.col = 0;
            return;
        }

        if (self.row == 0 and self.col == 0) {
            const b = Board.init();
            self.boards.append(b) catch unreachable;
        }
        const b = self.boards.items.len - 1;
        var it = std.mem.tokenize(u8, data, " ");
        while (it.next()) |num| {
            const n = std.fmt.parseInt(usize, num, 10) catch unreachable;
            // std.debug.warn("POS {} => {} {}\n", .{ n, self.row, self.col });
            const p = Board.Pos.init(self.row, self.col);
            self.boards.items[b].data.put(n, p) catch unreachable;
            self.col += 1;
        }
        self.col = 0;
        self.row += 1;
    }

    pub fn play_until_first_win(self: *Bingo) usize {
        for (self.draws.items) |draw| {
            // std.debug.warn("FIRST DRAW {}\n", .{draw});
            for (self.boards.items) |*board| {
                if (!board.data.contains(draw)) continue;
                const entry = board.data.getEntry(draw).?;
                var p = entry.value_ptr;
                p.*.hit = true;
                board.row_hits[p.*.row] += 1;
                board.col_hits[p.*.col] += 1;
                if (board.row_hits[p.*.row] == Board.SIZE or board.col_hits[p.*.col] == Board.SIZE) {
                    // std.debug.warn("FIRST WINNER\n", .{});
                    return board.get_score(draw);
                }
            }
        }
        return 0;
    }

    pub fn play_until_last_win(self: *Bingo) usize {
        for (self.draws.items) |draw| {
            // std.debug.warn("LAST DRAW {}\n", .{draw});
            var count_left: usize = 0;
            var count_won: usize = 0;
            var score: usize = 0;
            for (self.boards.items) |*board| {
                if (board.won) continue;
                count_left += 1;
                if (!board.data.contains(draw)) continue;
                const entry = board.data.getEntry(draw).?;
                var p = entry.value_ptr;
                p.*.hit = true;
                board.row_hits[p.*.row] += 1;
                board.col_hits[p.*.col] += 1;
                if (board.row_hits[p.*.row] == Board.SIZE or board.col_hits[p.*.col] == Board.SIZE) {
                    // std.debug.warn("LAST WINNER\n", .{});
                    board.won = true;
                    score = board.get_score(draw);
                    count_won += 1;
                }
            }
            if (count_left == 1 and count_won == 1) {
                return score;
            }
        }
        return 0;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\7,4,9,5,11,17,23,2,0,14,21,24,10,16,13,6,15,25,12,22,18,20,8,19,3,26,1
        \\
        \\22 13 17 11  0
        \\ 8  2 23  4 24
        \\21  9 14 16  7
        \\ 6 10  3 18  5
        \\ 1 12 20 15 19
        \\
        \\ 3 15  0  2 22
        \\ 9 18 13 17  5
        \\19  8  7 25 23
        \\20 11 10 24  4
        \\14 21 16 12  6
        \\
        \\14 21 17 24  4
        \\10 16 15  9 19
        \\18  8 23 26 20
        \\22 11 13  6  5
        \\ 2  0 12  3  7
    ;

    var bingo = Bingo.init();
    defer bingo.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        bingo.process_line(line);
    }

    const score = bingo.play_until_first_win();
    try testing.expect(score == 4512);
}

test "sample part b" {
    const data: []const u8 =
        \\7,4,9,5,11,17,23,2,0,14,21,24,10,16,13,6,15,25,12,22,18,20,8,19,3,26,1
        \\
        \\22 13 17 11  0
        \\ 8  2 23  4 24
        \\21  9 14 16  7
        \\ 6 10  3 18  5
        \\ 1 12 20 15 19
        \\
        \\ 3 15  0  2 22
        \\ 9 18 13 17  5
        \\19  8  7 25 23
        \\20 11 10 24  4
        \\14 21 16 12  6
        \\
        \\14 21 17 24  4
        \\10 16 15  9 19
        \\18  8 23 26 20
        \\22 11 13  6  5
        \\ 2  0 12  3  7
    ;

    var bingo = Bingo.init();
    defer bingo.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        bingo.process_line(line);
    }

    const score = bingo.play_until_last_win();
    try testing.expect(score == 1924);
}
