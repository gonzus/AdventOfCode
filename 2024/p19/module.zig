const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const StringId = StringTable.StringId;
    const State = enum { patterns, designs };

    allocator: Allocator,
    strtab: StringTable,
    state: State,
    patterns: std.ArrayList(StringId),
    designs: std.ArrayList(StringId),
    matches: std.AutoHashMap(StringId, usize),

    pub fn init(allocator: Allocator) Module {
        return .{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .state = .patterns,
            .patterns = std.ArrayList(StringId).init(allocator),
            .designs = std.ArrayList(StringId).init(allocator),
            .matches = std.AutoHashMap(StringId, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Module) void {
        self.matches.deinit();
        self.designs.deinit();
        self.patterns.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (line.len == 0) {
            self.state = .designs;
            return;
        }
        switch (self.state) {
            .patterns => {
                var it = std.mem.tokenizeAny(u8, line, ", ");
                while (it.next()) |chunk| {
                    const pattern = try self.strtab.add(chunk);
                    try self.patterns.append(pattern);
                }
            },
            .designs => {
                const design = try self.strtab.add(line);
                try self.designs.append(design);
            },
        }
    }

    // pub fn show(self: Module) void {
    //     std.debug.print("Patterns: {}\n", .{self.patterns.items.len});
    //     for (self.patterns.items) |p| {
    //         std.debug.print("  {s}\n", .{self.strtab.get_str(p) orelse "***"});
    //     }
    //     std.debug.print("Designs: {}\n", .{self.designs.items.len});
    //     for (self.designs.items) |d| {
    //         std.debug.print("  {s}\n", .{self.strtab.get_str(d) orelse "***"});
    //     }
    // }

    fn countMatches(self: *Module, design: []const u8, len: usize) !usize {
        const full = design[0..len];
        const idf = try self.strtab.add(full);
        if (self.matches.get(idf)) |count| {
            return count;
        }
        var count: usize = 0;
        for (self.patterns.items) |idp| {
            const pattern = self.strtab.get_str(idp) orelse "***";
            if (pattern.len > full.len) continue;
            if (pattern.len == full.len) {
                if (idf != idp) continue;
                const r = try self.matches.getOrPut(idf);
                if (!r.found_existing) {
                    r.value_ptr.* = 0;
                }
                r.value_ptr.* += 1;
                count += 1;
                continue;
            }
            const tail = full[full.len - pattern.len ..];
            if (!std.mem.eql(u8, pattern, tail)) continue;

            const match = try self.countMatches(design, len - tail.len);
            if (match <= 0) continue;
            count += match;
        }
        try self.matches.put(idf, count);
        return count;
    }

    pub fn getDesignWays(self: *Module) !usize {
        // self.show();
        var count: usize = 0;
        for (self.designs.items) |d| {
            const design = self.strtab.get_str(d) orelse "***";
            const matches = try self.countMatches(design, design.len);
            if (matches <= 0) continue;
            count += matches;
        }
        return count;
    }

    pub fn getDesignCount(self: *Module) !usize {
        // self.show();
        var count: usize = 0;
        for (self.designs.items) |d| {
            const design = self.strtab.get_str(d) orelse "***";
            const matches = try self.countMatches(design, design.len);
            if (matches <= 0) continue;
            count += 1;
        }
        return count;
    }
};

test "sample part 1" {
    const data =
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        \\gbbr
        \\rrbgbr
        \\ubwu
        \\bwurrg
        \\brgr
        \\bbrgwb
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getDesignCount();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\r, wr, b, g, bwu, rb, gb, br
        \\
        \\brwrr
        \\bggr
        \\gbbr
        \\rrbgbr
        \\ubwu
        \\bwurrg
        \\brgr
        \\bbrgwb
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getDesignWays();
    const expected = @as(usize, 16);
    try testing.expectEqual(expected, count);
}
