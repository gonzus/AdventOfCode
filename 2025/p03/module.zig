const std = @import("std");
const testing = std.testing;

pub const Module = struct {
    const SIZE = 128;

    const Bank = struct {
        cells: [SIZE]u8,
        size: usize,

        pub fn init(data: []const u8) Bank {
            var self: Bank = .{
                .cells = undefined,
                .size = data.len,
            };
            @memcpy(self.cells[0..data.len], data);
            return self;
        }

        pub fn getMaxJoltage(self: Bank, batteries_needed: usize) !usize {
            var joltage: usize = 0;
            var remaining = self.cells[0..self.size];
            var needed = batteries_needed;
            while (needed > 0) {
                needed -= 1;
                var top: usize = 0;
                for (1..remaining.len - needed) |p| {
                    if (remaining[top] < remaining[p]) top = p;
                }
                joltage *= 10;
                joltage += remaining[top] - '0';
                remaining = remaining[top + 1 ..];
            }
            return joltage;
        }
    };

    alloc: std.mem.Allocator,
    batteries_needed: usize,
    batteries_avail: usize,
    banks: std.ArrayList(Bank),

    pub fn init(alloc: std.mem.Allocator, batteries_needed: usize) Module {
        return .{
            .alloc = alloc,
            .batteries_needed = batteries_needed,
            .batteries_avail = 0,
            .banks = .{},
        };
    }

    pub fn deinit(self: *Module) void {
        self.banks.deinit(self.alloc);
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (self.batteries_avail == 0) self.batteries_avail = line.len;
        if (self.batteries_avail >= SIZE) return error.DataTooBig;
        if (self.batteries_avail != line.len) return error.InvalidData;
        try self.banks.append(self.alloc, Bank.init(line));
    }

    pub fn getTotalJoltage(self: *Module) !usize {
        var total: usize = 0;
        for (self.banks.items) |b| {
            total += try b.getMaxJoltage(self.batteries_needed);
        }
        return total;
    }
};

test "sample part 1" {
    const data =
        \\987654321111111
        \\811111111111119
        \\234234234234278
        \\818181911112111
    ;

    var module = Module.init(testing.allocator, 2);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const joltage = try module.getTotalJoltage();
    const expected = @as(usize, 357);
    try testing.expectEqual(expected, joltage);
}

test "sample part 2" {
    const data =
        \\987654321111111
        \\811111111111119
        \\234234234234278
        \\818181911112111
    ;

    var module = Module.init(testing.allocator, 12);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const joltage = try module.getTotalJoltage();
    const expected = @as(usize, 3121910778619);
    try testing.expectEqual(expected, joltage);
}
