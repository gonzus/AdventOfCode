const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Sequence = struct {
    const Lens = struct {
        label: []const u8,
        length: usize,
        active: bool,

        pub fn init(label: []const u8, length: usize) Lens {
            var self = Lens{
                .label = label,
                .length = length,
                .active = true,
            };
            return self;
        }
    };

    const Box = struct {
        lenses: std.ArrayList(Lens),

        pub fn init(allocator: Allocator) Box {
            var self = Box{
                .lenses = std.ArrayList(Lens).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Box) void {
            self.lenses.deinit();
        }
    };

    const NUM_BOXES = 256;

    sum: usize,
    boxes: [NUM_BOXES]Box,

    pub fn init(allocator: Allocator) Sequence {
        var self = Sequence{
            .sum = 0,
            .boxes = undefined,
        };
        for (self.boxes, 0..) |_, p| {
            self.boxes[p] = Box.init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *Sequence) void {
        for (self.boxes, 0..) |_, p| {
            self.boxes[p].deinit();
        }
    }

    pub fn addLine(self: *Sequence, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ',');
        while (it.next()) |step| {
            try self.processStep(step);
        }
    }

    pub fn show(self: Sequence) void {
        for (self.boxes, 0..) |_, box_pos| {
            var lens_count: usize = 0;
            for (self.boxes[box_pos].lenses.items) |lens| {
                if (!lens.active) continue;
                lens_count += 1;
            }
            if (lens_count == 0) continue;
            std.debug.print("Box {}:", .{box_pos});
            for (self.boxes[box_pos].lenses.items) |lens| {
                if (!lens.active) continue;
                std.debug.print(" [{s} {}]", .{ lens.label, lens.length });
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getSumHashes(self: *Sequence) usize {
        return self.sum;
    }

    pub fn getFocusingPower(self: *Sequence) usize {
        var total_power: usize = 0;
        for (self.boxes, 0..) |_, box_pos| {
            var lens_pos: usize = 0;
            for (self.boxes[box_pos].lenses.items) |lens| {
                if (!lens.active) continue;
                lens_pos += 1;
                var power: usize = box_pos + 1;
                power *= lens_pos;
                power *= lens.length;
                total_power += power;
            }
        }
        return total_power;
    }

    fn processStep(self: *Sequence, step: []const u8) !void {
        self.sum += hash(step);

        const pos = std.mem.indexOfAny(u8, step, "=-") orelse 0;
        if (pos == 0) return error.InvalidStep;

        const label = step[0..pos];
        const box_pos = hash(label);
        const operation = step[pos];
        switch (operation) {
            '-' => {
                for (self.boxes[box_pos].lenses.items) |*lens| {
                    if (!lens.active) continue;
                    if (std.mem.eql(u8, label, lens.label)) {
                        lens.active = false;
                        break;
                    }
                }
            },
            '=' => {
                const length = try std.fmt.parseUnsigned(usize, step[pos + 1 ..], 10);
                var found = false;
                for (self.boxes[box_pos].lenses.items) |*lens| {
                    if (!lens.active) continue;
                    if (std.mem.eql(u8, label, lens.label)) {
                        lens.length = length;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    try self.boxes[box_pos].lenses.append(Lens.init(label, length));
                }
            },
            else => return error.InvalidStep,
        }

        // std.debug.print("After '{s}':\n", .{step});
        // self.show();
        // std.debug.print("\n", .{});
    }

    fn hash(str: []const u8) usize {
        var h: usize = 0;
        for (str) |c| {
            h += c;
            h *= 17;
            h %= NUM_BOXES;
        }
        return h;
    }
};

test "sample part 1" {
    const data =
        \\rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7
    ;

    var sequence = Sequence.init(std.testing.allocator);
    defer sequence.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try sequence.addLine(line);
    }

    const summary = sequence.getSumHashes();
    const expected = @as(usize, 1320);
    try testing.expectEqual(expected, summary);
}

test "sample part 2" {
    const data =
        \\rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7
    ;

    var sequence = Sequence.init(std.testing.allocator);
    defer sequence.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try sequence.addLine(line);
    }

    const summary = sequence.getFocusingPower();
    const expected = @as(usize, 145);
    try testing.expectEqual(expected, summary);
}
