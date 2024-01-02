const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Table = struct {
    const SIZE = 10;
    const MYSELF = "Gonzus";
    const StringId = StringTable.StringId;

    const Data = struct {
        person: StringId = 0,
        seated: bool = false,
    };

    include_me: bool,
    strtab: StringTable,
    prefs: [SIZE][SIZE]isize,
    seating: [SIZE]Data,
    best: isize,

    pub fn init(allocator: Allocator, include_me: bool) Table {
        const self = Table{
            .include_me = include_me,
            .strtab = StringTable.init(allocator),
            .prefs = [_][SIZE]isize{[_]isize{0} ** SIZE} ** SIZE,
            .seating = undefined,
            .best = std.math.minInt(isize),
        };
        return self;
    }

    pub fn deinit(self: *Table) void {
        self.strtab.deinit();
    }

    pub fn addLine(self: *Table, line: []const u8) !void {
        var pos: usize = 0;
        var li: StringId = undefined;
        var ls: isize = undefined;
        var ln: isize = undefined;
        var ri: StringId = undefined;
        var it = std.mem.tokenizeAny(u8, line, " .");
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                0 => li = try self.strtab.add(chunk),
                2 => ls = try getSign(chunk),
                3 => ln = try std.fmt.parseUnsigned(isize, chunk, 10),
                10 => ri = try self.strtab.add(chunk),
                else => {},
            }
        }
        try self.addPerson(li, ri, ls * ln);
    }

    fn addPerson(self: *Table, l: StringId, r: StringId, change: isize) !void {
        self.prefs[l][r] = change;
    }

    fn addMyself(self: *Table) !void {
        const size = self.strtab.size();
        const me = try self.strtab.add(MYSELF);
        for (0..size) |other| {
            try self.addPerson(me, other, 0);
            try self.addPerson(other, me, 0);
        }
    }

    pub fn show(self: Table) void {
        const size = self.strtab.size();
        std.debug.print("Table with {} people\n", .{size});
        for (0..size) |l| {
            std.debug.print("  {d}:{s} =>", .{ l, self.strtab.get_str(l) orelse "***" });
            for (0..size) |r| {
                std.debug.print(" {d}", .{self.prefs[l][r]});
            }
            std.debug.print("\n", .{});
        }
    }
    pub fn getBestSeatingChange(self: *Table) !isize {
        if (self.include_me) try self.addMyself();
        try self.findBestSeating(0);
        return self.best;
    }

    fn getSign(text: []const u8) !isize {
        if (std.mem.eql(u8, text, "gain")) return 1;
        if (std.mem.eql(u8, text, "lose")) return -1;
        return error.InvalidAction;
    }

    fn findBestSeating(self: *Table, pos: usize) !void {
        const size = self.strtab.size();
        if (pos >= size) {
            var change: isize = 0;
            for (0..size) |j| {
                const p = self.seating[j].person;
                const l = self.seating[(j + size - 1) % size].person;
                const r = self.seating[(j + 1) % size].person;
                change += self.prefs[p][l];
                change += self.prefs[p][r];
            }
            if (self.best < change) {
                self.best = change;
            }
            return;
        }
        for (0..size) |p| {
            if (self.seating[p].seated) continue;
            self.seating[pos].person = p;
            self.seating[p].seated = true;
            try self.findBestSeating(pos + 1);
            self.seating[p].seated = false;
        }
    }
};

test "sample part 1" {
    const data =
        \\Alice would gain 54 happiness units by sitting next to Bob.
        \\Alice would lose 79 happiness units by sitting next to Carol.
        \\Alice would lose 2 happiness units by sitting next to David.
        \\Bob would gain 83 happiness units by sitting next to Alice.
        \\Bob would lose 7 happiness units by sitting next to Carol.
        \\Bob would lose 63 happiness units by sitting next to David.
        \\Carol would lose 62 happiness units by sitting next to Alice.
        \\Carol would gain 60 happiness units by sitting next to Bob.
        \\Carol would gain 55 happiness units by sitting next to David.
        \\David would gain 46 happiness units by sitting next to Alice.
        \\David would lose 7 happiness units by sitting next to Bob.
        \\David would gain 41 happiness units by sitting next to Carol.
    ;

    var table = Table.init(std.testing.allocator, false);
    defer table.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try table.addLine(line);
    }

    const change = try table.getBestSeatingChange();
    const expected = @as(isize, 330);
    try testing.expectEqual(expected, change);
}
