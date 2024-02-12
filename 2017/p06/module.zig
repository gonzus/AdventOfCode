const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Memory = struct {
    const StringId = usize;

    banks: std.ArrayList(usize),
    steps: usize,
    cycle: usize,
    seen: std.AutoHashMap(StringId, usize),
    strtab: StringTable,

    pub fn init(allocator: Allocator) Memory {
        return .{
            .banks = std.ArrayList(usize).init(allocator),
            .steps = 0,
            .cycle = 0,
            .seen = std.AutoHashMap(StringId, usize).init(allocator),
            .strtab = StringTable.init(allocator),
        };
    }

    pub fn deinit(self: *Memory) void {
        self.strtab.deinit();
        self.seen.deinit();
        self.banks.deinit();
    }

    pub fn addLine(self: *Memory, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " \t");
        while (it.next()) |chunk| {
            const num = try std.fmt.parseUnsigned(usize, chunk, 10);
            try self.banks.append(num);
        }
    }

    pub fn show(self: Memory) void {
        std.debug.print("Memory with {} banks:", .{self.banks.items.len});
        for (self.banks.items, 0..) |bank, pos| {
            const s: u8 = if (pos == 0) ' ' else '|';
            std.debug.print("{c}{d}", .{ s, bank });
        }
        std.debug.print("\n", .{});
    }

    pub fn getStepsUntilRepeat(self: *Memory) !usize {
        try self.reallocateMemory();
        return self.steps;
    }

    pub fn getRepeatCycleSize(self: *Memory) !usize {
        try self.reallocateMemory();
        return self.cycle;
    }

    fn reallocateMemory(self: *Memory) !void {
        self.strtab.clear();
        var steps: usize = 0;
        while (true) : (steps += 1) {
            var top_size: usize = 0;
            var top_pos: usize = std.math.maxInt(usize);
            var buf: [1000]u8 = undefined;
            var len: usize = 0;
            for (self.banks.items, 0..) |bank, pos| {
                if (top_size <= bank) {
                    if (top_size < bank or top_pos > pos) {
                        top_size = bank;
                        top_pos = pos;
                    }
                }
                if (len > 0) {
                    buf[len] = ':';
                    len += 1;
                }
                const sub = try std.fmt.bufPrint(buf[len..], "{d}", .{bank});
                len += sub.len;
            }
            const str = buf[0..len];
            if (self.strtab.get_pos(str)) |id| {
                if (self.seen.get(id)) |orig| {
                    self.steps = steps;
                    self.cycle = steps - orig;
                    break;
                } else {
                    return error.InvalidPos;
                }
            }

            const id = try self.strtab.add(str);
            try self.seen.put(id, steps);

            self.banks.items[top_pos] = 0;
            var pos = top_pos;
            while (top_size > 0) {
                pos += 1;
                pos %= self.banks.items.len;
                self.banks.items[pos] += 1;
                top_size -= 1;
            }
        }
    }
};

test "sample part 1" {
    const data =
        \\0 2 7 0
    ;

    var memory = Memory.init(testing.allocator);
    defer memory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try memory.addLine(line);
    }
    // memory.show();

    const steps = try memory.getStepsUntilRepeat();
    const expected = @as(usize, 5);
    try testing.expectEqual(expected, steps);
}

test "sample part 2" {
    const data =
        \\0 2 7 0
    ;

    var memory = Memory.init(testing.allocator);
    defer memory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try memory.addLine(line);
    }
    // memory.show();

    const cycle = try memory.getRepeatCycleSize();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, cycle);
}
