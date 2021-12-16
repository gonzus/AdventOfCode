const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Computer = struct {
    const Op = enum(u8) {
        ADD = 0,
        MUL = 1,
        MIN = 2,
        MAX = 3,
        LIT = 4,
        CGT = 5,
        CLT = 6,
        CEQ = 7,
    };

    bits: std.ArrayList(u1),
    pos: usize,
    sum_versions: usize,
    result: usize,

    pub fn init() Computer {
        var self = Computer{
            .bits = std.ArrayList(u1).init(allocator),
            .pos = 0,
            .sum_versions = 0,
            .result = 0,
        };
        return self;
    }

    pub fn deinit(self: *Computer) void {
        self.bits.deinit();
    }

    fn hex2int(c: u8) u8 {
        if (c >= 'A' and c <= 'F') return c - 'A' + 10;
        if (c >= 'a' and c <= 'f') return c - 'a' + 10;
        if (c >= '0' and c <= '9') return c - '0';
        unreachable;
    }

    pub fn process_line(self: *Computer, data: []const u8) !void {
        for (data) |c| {
            const n = hex2int(c);
            try self.bits.append(if ((n & 8) > 0) 1 else 0);
            try self.bits.append(if ((n & 4) > 0) 1 else 0);
            try self.bits.append(if ((n & 2) > 0) 1 else 0);
            try self.bits.append(if ((n & 1) > 0) 1 else 0);
        }
        self.result = self.decode_packet();
    }

    pub fn get_sum_of_versions(self: *Computer) !usize {
        return self.sum_versions;
    }

    pub fn get_result(self: *Computer) !usize {
        return self.result;
    }

    fn decode_packet(self: *Computer) usize {
        const version = self.decode_bits(3);
        const type_id = @intToEnum(Op, self.decode_bits(3));
        // std.debug.warn("VERSION {}, TYPE_ID {}\n", .{ version, type_id });
        self.sum_versions += version;
        return self.decode_operator(type_id);
    }

    fn decode_operator(self: *Computer, op: Op) usize {
        if (op == Op.LIT) {
            return self.run_operator(0, op, 0);
        }

        const length_type_id = self.decode_bits(1);
        if (length_type_id == 0) {
            return self.decode_operator_bits(op, self.decode_bits(15));
        } else {
            return self.decode_operator_packets(op, self.decode_bits(11));
        }
    }

    fn decode_operator_bits(self: *Computer, op: Op, length_in_bits: usize) usize {
        var result: usize = std.math.maxInt(usize);
        const target = self.pos + length_in_bits;
        while (self.pos < target) {
            result = self.run_operator(result, op, self.decode_packet());
        }
        return result;
    }

    fn decode_operator_packets(self: *Computer, op: Op, number_of_packets: usize) usize {
        var result: usize = std.math.maxInt(usize);
        var p: usize = 0;
        while (p < number_of_packets) : (p += 1) {
            result = self.run_operator(result, op, self.decode_packet());
        }
        return result;
    }

    fn run_operator(self: *Computer, before: usize, op: Op, value: usize) usize {
        if (before == std.math.maxInt(usize)) {
            return value;
        }
        return switch (op) {
            Op.ADD => before + value,
            Op.MUL => before * value,
            Op.MIN => if (before < value) before else value,
            Op.MAX => if (before > value) before else value,
            Op.LIT => self.decode_literal(),
            Op.CGT => if (before > value) @as(usize, 1) else @as(usize, 0),
            Op.CLT => if (before < value) @as(usize, 1) else @as(usize, 0),
            Op.CEQ => if (before == value) @as(usize, 1) else @as(usize, 0),
        };
    }

    fn decode_literal(self: *Computer) usize {
        var value: usize = 0;
        while (true) {
            const more = self.decode_bits(1);
            const nibble = self.decode_bits(4);
            value *= 16;
            value += nibble;
            // std.debug.warn("NIBBLE pos {} more {} value {} TOTAL {}\n", .{ self.pos, more, nibble, value });
            if (more == 0) break;
        }
        return value;
    }

    fn decode_bits(self: *Computer, count: usize) usize {
        var value: usize = 0;
        var p: usize = 0;
        while (p < count) : (p += 1) {
            value *= 2;
            value += self.bits.items[self.pos + p];
        }
        // std.debug.warn("BITS at {} len {} = {}\n", .{ self.pos, count, value });
        self.pos += count;
        return value;
    }
};

test "sample part a small" {
    const data: []const u8 =
        \\D2FE28
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const sum = try computer.get_sum_of_versions();
    try testing.expect(sum == 6);
}

test "sample part a bits" {
    const data: []const u8 =
        \\38006F45291200
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const sum = try computer.get_sum_of_versions();
    try testing.expect(sum == 9);
}

test "sample part a packets" {
    const data: []const u8 =
        \\EE00D40C823060
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const sum = try computer.get_sum_of_versions();
    try testing.expect(sum == 14);
}

test "sample part a 1" {
    const data: []const u8 =
        \\8A004A801A8002F478
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const sum = try computer.get_sum_of_versions();
    try testing.expect(sum == 16);
}

test "sample part a 2" {
    const data: []const u8 =
        \\620080001611562C8802118E34
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const sum = try computer.get_sum_of_versions();
    try testing.expect(sum == 12);
}

test "sample part a 3" {
    const data: []const u8 =
        \\C0015000016115A2E0802F182340
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const sum = try computer.get_sum_of_versions();
    try testing.expect(sum == 23);
}

test "sample part a 4" {
    const data: []const u8 =
        \\A0016C880162017C3686B18A3D4780
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const sum = try computer.get_sum_of_versions();
    try testing.expect(sum == 31);
}

test "sample part b 1" {
    const data: []const u8 =
        \\C200B40A82
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const result = try computer.get_result();
    try testing.expect(result == 3);
}

test "sample part b 2" {
    const data: []const u8 =
        \\04005AC33890
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const result = try computer.get_result();
    try testing.expect(result == 54);
}

test "sample part b 3" {
    const data: []const u8 =
        \\880086C3E88112
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const result = try computer.get_result();
    try testing.expect(result == 7);
}

test "sample part b 4" {
    const data: []const u8 =
        \\CE00C43D881120
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const result = try computer.get_result();
    try testing.expect(result == 9);
}

test "sample part b 5" {
    const data: []const u8 =
        \\D8005AC2A8F0
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const result = try computer.get_result();
    try testing.expect(result == 1);
}

test "sample part b 6" {
    const data: []const u8 =
        \\F600BC2D8F
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const result = try computer.get_result();
    try testing.expect(result == 0);
}

test "sample part b 7" {
    const data: []const u8 =
        \\9C005AC2F8F0
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const result = try computer.get_result();
    try testing.expect(result == 0);
}

test "sample part b 8" {
    const data: []const u8 =
        \\9C0141080250320F1802104A08
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.process_line(line);
    }
    const result = try computer.get_result();
    try testing.expect(result == 1);
}
