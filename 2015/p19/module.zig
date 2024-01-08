const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Machine = struct {
    const StringId = StringTable.StringId;
    const INVALID_STRING = std.math.maxInt(StringId);

    const StringPair = struct {
        src: StringId,
        tgt: StringId,

        pub fn init() StringPair {
            return StringPair{ .src = INVALID_STRING, .tgt = INVALID_STRING };
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    transforms: std.ArrayList(StringPair),
    molecule: StringId,
    reading_molecule: bool,

    pub fn init(allocator: Allocator) Machine {
        return Machine{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .transforms = std.ArrayList(StringPair).init(allocator),
            .molecule = INVALID_STRING,
            .reading_molecule = false,
        };
    }

    pub fn deinit(self: *Machine) void {
        self.transforms.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Machine, line: []const u8) !void {
        if (line.len == 0) {
            self.reading_molecule = true;
            return;
        }

        if (self.reading_molecule) {
            self.molecule = try self.strtab.add(line);
            return;
        }

        var pair = StringPair.init();
        var pos: usize = 0;
        var it = std.mem.tokenizeSequence(u8, line, " => ");
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                0 => pair.src = try self.strtab.add(chunk),
                1 => pair.tgt = try self.strtab.add(chunk),
                else => return error.InvalidData,
            }
        }
        try self.transforms.append(pair);
    }

    pub fn show(self: Machine) void {
        std.debug.print("Machine with {} transforms\n", .{self.transforms.items.len});
        std.debug.print("Start: [{s}]\n", .{self.strtab.get_str(self.molecule) orelse "***"});
        for (self.transforms.items) |t| {
            std.debug.print("{s} => {s}\n", .{
                self.strtab.get_str(t.src) orelse "***",
                self.strtab.get_str(t.tgt) orelse "***",
            });
        }
    }

    const StringSet = std.AutoHashMap(StringId, void);

    pub fn getMoleculesProduced(self: *Machine) !usize {
        var seen = StringSet.init(self.allocator);
        defer seen.deinit();

        const molecule = self.strtab.get_str(self.molecule) orelse "***";
        for (self.transforms.items) |t| {
            const src = self.strtab.get_str(t.src) orelse "***";
            const tgt = self.strtab.get_str(t.tgt) orelse "***";
            try self.replaceOne(molecule, src, tgt, &seen);
        }

        return seen.count();
    }

    pub fn countStepsToWantedMolecule(self: *Machine) !usize {
        var random_generator = std.rand.DefaultPrng.init(0);
        const random = random_generator.random();

        const start = self.strtab.get_str(self.molecule) orelse "***";

        var buf: [2][1024]u8 = undefined;
        var cur: usize = 0;
        std.mem.copyForwards(u8, &buf[cur], start);
        var mol = buf[cur][0..start.len];

        var replacements: usize = 0;
        var shuffles: usize = 0;
        while (mol.len > 1) {
            const orig = mol;
            for (self.transforms.items) |t| {
                const src = self.strtab.get_str(t.src) orelse "***";
                const tgt = self.strtab.get_str(t.tgt) orelse "***";
                const nxt = 1 - cur;
                const size = std.mem.replacementSize(u8, mol, tgt, src);
                replacements += std.mem.replace(u8, mol, tgt, src, &buf[nxt]);
                mol = buf[nxt][0..size];
                cur = nxt;
            }
            if (std.mem.eql(u8, orig, mol)) {
                // hit a dead end, restart after shuffling transforms
                std.rand.Random.shuffle(random, StringPair, self.transforms.items);
                std.mem.copyForwards(u8, &buf[cur], start);
                mol = buf[cur][0..start.len];
                replacements = 0;
                shuffles += 1;
            }
        }
        return replacements;
    }

    fn replaceOne(self: *Machine, str: []const u8, src: []const u8, tgt: []const u8, seen: *StringSet) !void {
        // replace src with tgt one by one, and remember the results
        for (str, 0..) |_, pos| {
            if (str.len - pos < src.len) break;
            if (std.mem.eql(u8, src, str[pos .. pos + src.len])) {
                var buf: [1024]u8 = undefined;
                var len: usize = 0;
                if (pos > 0) {
                    std.mem.copyForwards(u8, buf[len..], str[0..pos]);
                    len += pos;
                }
                std.mem.copyForwards(u8, buf[len..], tgt);
                len += tgt.len;
                if (pos + src.len < str.len) {
                    std.mem.copyForwards(u8, buf[len..], str[pos + src.len ..]);
                    len += str.len - pos - src.len;
                }
                const name = try self.strtab.add(buf[0..len]);
                _ = try seen.*.getOrPut(name);
            }
        }
    }
};

test "sample part 1" {
    const data =
        \\H => HO
        \\H => OH
        \\O => HH
        \\
        \\HOH
    ;

    var machine = Machine.init(std.testing.allocator);
    defer machine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try machine.addLine(line);
    }
    // machine.show();

    const count = try machine.getMoleculesProduced();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, count);
}

test "sample part 1 Santa" {
    const data =
        \\H => HO
        \\H => OH
        \\O => HH
        \\
        \\HOHOHO
    ;

    var machine = Machine.init(std.testing.allocator);
    defer machine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try machine.addLine(line);
    }
    // machine.show();

    const count = try machine.getMoleculesProduced();
    const expected = @as(usize, 7);
    try testing.expectEqual(expected, count);
}

test "sample part 1 extra chars" {
    const data =
        \\H => OO
        \\
        \\H2O
    ;

    var machine = Machine.init(std.testing.allocator);
    defer machine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try machine.addLine(line);
    }
    // machine.show();

    const count = try machine.getMoleculesProduced();
    const expected = @as(usize, 1);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\e => H
        \\e => O
        \\H => HO
        \\H => OH
        \\O => HH
        \\
        \\HOH
    ;

    var machine = Machine.init(std.testing.allocator);
    defer machine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try machine.addLine(line);
    }
    // machine.show();

    const count = try machine.countStepsToWantedMolecule();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, count);
}

test "sample part 2 Santa" {
    const data =
        \\e => H
        \\e => O
        \\H => HO
        \\H => OH
        \\O => HH
        \\
        \\HOHOHO
    ;

    var machine = Machine.init(std.testing.allocator);
    defer machine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try machine.addLine(line);
    }
    // machine.show();

    const count = try machine.countStepsToWantedMolecule();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, count);
}
