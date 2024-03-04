const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;
const Grid = @import("./util/grid.zig").Grid;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Building = struct {
    const StringId = StringTable.StringId;
    const Pos = Math.Vector(usize, 2);

    const Dir = enum {
        U,
        D,
        L,
        R,

        pub fn parse(char: u8) !Dir {
            const str: [1]u8 = [_]u8{char};
            for (Dirs) |d| {
                if (std.mem.eql(u8, @tagName(d), &str)) return d;
            }
            return error.InvalidDir;
        }
    };
    const Dirs = std.meta.tags(Dir);

    const Keypad = struct {
        const Data = Grid(u8);

        grid: Data,
        pos: Pos,

        pub fn init(allocator: Allocator) Keypad {
            const keypad = Keypad{
                .grid = Data.init(allocator, '.'),
                .pos = undefined,
            };
            return keypad;
        }

        pub fn deinit(self: *Keypad) void {
            self.grid.deinit();
        }

        pub fn getValue(self: Keypad) u8 {
            return self.grid.get(self.pos.v[0], self.pos.v[1]);
        }

        pub fn initSquare(allocator: Allocator) !Keypad {
            var keypad = Keypad.init(allocator);
            try keypad.addLine(".....");
            try keypad.addLine(".123.");
            try keypad.addLine(".456.");
            try keypad.addLine(".789.");
            try keypad.addLine(".....");
            keypad.setStart('5');
            return keypad;
        }

        pub fn initDiamond(allocator: Allocator) !Keypad {
            var keypad = Keypad.init(allocator);
            try keypad.addLine(".......");
            try keypad.addLine("...1...");
            try keypad.addLine("..234..");
            try keypad.addLine(".56789.");
            try keypad.addLine("..ABC..");
            try keypad.addLine("...D...");
            try keypad.addLine(".......");
            keypad.setStart('5');
            return keypad;
        }

        pub fn move(self: Keypad, pos: Pos, dir: Dir) Pos {
            var new = pos;
            switch (dir) {
                .U => new.v[1] -= 1,
                .D => new.v[1] += 1,
                .L => new.v[0] -= 1,
                .R => new.v[0] += 1,
            }
            if (self.isBorder(new)) return pos;
            return new;
        }

        fn setStart(self: *Keypad, start: u8) void {
            for (0..self.grid.rows()) |y| {
                for (0..self.grid.cols()) |x| {
                    if (self.grid.get(x, y) == start) {
                        self.pos = Pos.copy(&[_]usize{ x, y });
                        return;
                    }
                }
            }
        }

        fn addLine(self: *Keypad, line: []const u8) !void {
            try self.grid.ensureCols(line.len);
            try self.grid.ensureExtraRow();
            const y = self.grid.rows();
            for (line, 0..) |c, x| {
                try self.grid.set(x, y, c);
            }
        }

        fn isBorder(self: Keypad, pos: Pos) bool {
            return self.grid.get(pos.v[0], pos.v[1]) == '.';
        }
    };

    strtab: StringTable,
    instrs: std.ArrayList(StringId),
    keypad: Keypad,
    buf: [100]u8,
    len: usize,

    pub fn init(allocator: Allocator, diamond: bool) !Building {
        const building = Building{
            .strtab = StringTable.init(allocator),
            .instrs = std.ArrayList(StringId).init(allocator),
            .keypad = if (diamond) try Keypad.initDiamond(allocator) else try Keypad.initSquare(allocator),
            .buf = undefined,
            .len = 0,
        };
        return building;
    }

    pub fn deinit(self: *Building) void {
        self.keypad.deinit();
        self.instrs.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Building, line: []const u8) !void {
        const id = try self.strtab.add(line);
        try self.instrs.append(id);
    }

    pub fn getCode(self: *Building) ![]const u8 {
        self.len = 0;
        for (self.instrs.items) |instr| {
            const char = try self.applyInstr(instr);
            self.buf[self.len] = char;
            self.len += 1;
        }
        return self.buf[0..self.len];
    }

    fn applyInstr(self: *Building, instr: StringId) !u8 {
        const str = self.strtab.get_str(instr) orelse "";
        for (str) |char| {
            const dir = try Dir.parse(char);
            self.keypad.pos = self.keypad.move(self.keypad.pos, dir);
        }
        return self.keypad.getValue();
    }
};

test "sample part 1" {
    const data =
        \\ULL
        \\RRDDD
        \\LURDL
        \\UUUUD
    ;

    var building = try Building.init(std.testing.allocator, false);
    defer building.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try building.addLine(line);
    }

    const code = try building.getCode();
    const expected = "1985";
    try testing.expectEqualStrings(expected, code);
}

test "sample part 2" {
    const data =
        \\ULL
        \\RRDDD
        \\LURDL
        \\UUUUD
    ;

    var building = try Building.init(std.testing.allocator, true);
    defer building.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try building.addLine(line);
    }

    const code = try building.getCode();
    const expected = "5DB3";
    try testing.expectEqualStrings(expected, code);
}
