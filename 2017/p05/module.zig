const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const CPU = struct {
    strange: bool,
    jumps: std.ArrayList(isize),

    pub fn init(allocator: Allocator, strange: bool) CPU {
        return .{
            .strange = strange,
            .jumps = std.ArrayList(isize).init(allocator),
        };
    }

    pub fn deinit(self: *CPU) void {
        self.jumps.deinit();
    }

    pub fn addLine(self: *CPU, line: []const u8) !void {
        const jump = try std.fmt.parseInt(isize, line, 10);
        try self.jumps.append(jump);
    }

    pub fn getStepsUntilExit(self: CPU) !usize {
        var step: usize = 0;
        var pos: isize = 0;
        while (pos >= 0 and pos < self.jumps.items.len) : (step += 1) {
            const p: usize = @intCast(pos);
            const offset = self.jumps.items[p];
            pos += offset;
            const delta: isize = if (self.strange and offset >= 3) -1 else 1;
            self.jumps.items[p] += delta;
        }
        return step;
    }
};

test "sample part 1" {
    const data =
        \\0
        \\3
        \\0
        \\1
        \\-3
    ;

    var cpu = CPU.init(testing.allocator, false);
    defer cpu.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cpu.addLine(line);
    }

    const steps = try cpu.getStepsUntilExit();
    const expected = @as(usize, 5);
    try testing.expectEqual(expected, steps);
}

test "sample part 2" {
    const data =
        \\0
        \\3
        \\0
        \\1
        \\-3
    ;

    var cpu = CPU.init(testing.allocator, true);
    defer cpu.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cpu.addLine(line);
    }

    const steps = try cpu.getStepsUntilExit();
    const expected = @as(usize, 10);
    try testing.expectEqual(expected, steps);
}
