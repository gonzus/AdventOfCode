const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

pub const Module = struct {
    const StringId = StringTable.StringId;

    const Mode = enum { horizontal, vertical };
    const Op = enum(u8) {
        add = '+',
        mul = '*',
    };

    alloc: std.mem.Allocator,
    strtab: StringTable,
    mode: Mode,
    lines: std.ArrayList(StringId),
    width: usize,

    pub fn init(alloc: std.mem.Allocator, mode: Mode) Module {
        return .{
            .alloc = alloc,
            .strtab = StringTable.init(alloc),
            .mode = mode,
            .lines = .empty,
            .width = 0,
        };
    }

    pub fn deinit(self: *Module) void {
        self.lines.deinit(self.alloc);
        self.strtab.deinit();
    }

    pub fn parseInput(self: *Module, data: []const u8) !void {
        var it_lines = std.mem.splitScalar(u8, data, '\n');
        while (it_lines.next()) |line| {
            const id = try self.strtab.add(line);
            try self.lines.append(self.alloc, id);
            if (self.width < line.len) self.width = line.len;
        }
    }

    pub fn addAllAnswers(self: Module) !usize {
        std.debug.assert(self.lines.items.len >= 2);
        const value_lines = self.lines.items[0 .. self.lines.items.len - 1];
        const oprs_sid = self.lines.items[self.lines.items.len - 1];
        const oprs = self.strtab.get_str(oprs_sid) orelse return error.InvalidData;
        var total: usize = 0;
        switch (self.mode) {
            .horizontal => {
                const SIZE = 1024;
                var mul: [SIZE]usize = @splat(1);
                var sum: [SIZE]usize = @splat(0);
                for (value_lines) |values_sid| {
                    const txt = self.strtab.get_str(values_sid) orelse return error.InvalidData;
                    const values = std.mem.trim(u8, txt, " \t\r\n");
                    var col: usize = 0;
                    var it = std.mem.tokenizeAny(u8, values, " \t");
                    while (it.next()) |chunk| : (col += 1) {
                        const val = try std.fmt.parseUnsigned(usize, chunk, 10);
                        mul[col] *= val;
                        sum[col] += val;
                    }
                }
                var col: usize = 0;
                var it = std.mem.tokenizeAny(u8, oprs, " \t");
                while (it.next()) |chunk| : (col += 1) {
                    const op: Op = @enumFromInt(chunk[0]);
                    switch (op) {
                        .mul => total += mul[col],
                        .add => total += sum[col],
                    }
                }
            },
            .vertical => {
                var opr_col: usize = self.width - 1;
                var num_col: usize = self.width - 1;
                while (true) {
                    var mul: usize = 1;
                    var sum: usize = 0;
                    while (oprs[opr_col] == ' ') opr_col -= 1;
                    const op: Op = @enumFromInt(oprs[opr_col]);
                    while (num_col >= opr_col) {
                        var numeric = false;
                        var val: usize = 0;
                        for (value_lines) |values_sid| {
                            const values = self.strtab.get_str(values_sid) orelse return error.InvalidData;
                            const digit = values[num_col];
                            if (!std.ascii.isDigit(digit)) continue;
                            numeric = true;
                            val *= 10;
                            val += digit - '0';
                        }
                        if (numeric) {
                            switch (op) {
                                .mul => mul *= val,
                                .add => sum += val,
                            }
                        }
                        if (num_col == 0) break;
                        num_col -= 1;
                    }
                    switch (op) {
                        .mul => total += mul,
                        .add => total += sum,
                    }
                    if (opr_col == 0) break;
                    opr_col -= 1;
                }
            },
        }
        return total;
    }
};

test "sample part 1" {
    const data =
        \\123 328  51 64 
        \\ 45 64  387 23 
        \\  6 98  215 314
        \\*   +   *   +  
    ;

    var module = Module.init(testing.allocator, .horizontal);
    defer module.deinit();
    try module.parseInput(data);

    const fresh = try module.addAllAnswers();
    const expected = @as(usize, 4277556);
    try testing.expectEqual(expected, fresh);
}

test "sample part 2" {
    const data =
        \\123 328  51 64 
        \\ 45 64  387 23 
        \\  6 98  215 314
        \\*   +   *   +  
    ;

    var module = Module.init(testing.allocator, .vertical);
    defer module.deinit();
    try module.parseInput(data);

    const fresh = try module.addAllAnswers();
    const expected = @as(usize, 3263827);
    try testing.expectEqual(expected, fresh);
}
