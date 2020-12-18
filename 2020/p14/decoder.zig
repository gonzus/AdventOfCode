const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Decoder = struct {
    pub const Mode = enum {
        Value,
        Address,
    };

    mode: Mode,
    mem: std.AutoHashMap(u64, u64),
    mask0: u64,
    mask1: u64,
    floats: [36]u6,
    fpos: usize,

    pub fn init(mode: Mode) Decoder {
        var self = Decoder{
            .mode = mode,
            .mem = std.AutoHashMap(u64, u64).init(allocator),
            .mask0 = 0,
            .mask1 = 0,
            .floats = undefined,
            .fpos = 0,
        };
        return self;
    }

    pub fn deinit(self: *Decoder) void {
        self.mem.deinit();
    }

    pub fn add_line(self: *Decoder, line: []const u8) void {
        var it = std.mem.tokenize(line, " =");
        const cmd = it.next().?;
        const val = it.next().?;
        if (std.mem.eql(u8, cmd, "mask")) {
            self.set_mask(val);
            return;
        }
        if (std.mem.eql(u8, cmd[0..3], "mem")) {
            var addr = std.fmt.parseInt(u64, cmd[4 .. cmd.len - 1], 10) catch unreachable;
            var value = std.fmt.parseInt(u64, val, 10) catch unreachable;
            self.set_mem(addr, value);
            return;
        }
        @panic("Field");
    }

    pub fn sum_all_values(self: Decoder) usize {
        var sum: usize = 0;
        var it = self.mem.iterator();
        while (it.next()) |kv| {
            sum += kv.value;
        }
        return sum;
    }

    fn set_mask(self: *Decoder, mask: []const u8) void {
        self.fpos = 0;
        self.mask0 = 0;
        self.mask1 = 0;
        for (mask) |c, j| {
            self.mask0 <<= 1;
            self.mask1 <<= 1;
            self.mask0 |= 1;
            if (c == 'X') {
                const bit = mask.len - j - 1;
                self.floats[self.fpos] = @intCast(u6, bit);
                self.fpos += 1;
                continue;
            }
            if (c == '0') {
                if (self.mode == Mode.Address) continue;
                self.mask0 &= ~(@as(u64, 1));
                continue;
            }
            if (c == '1') {
                self.mask1 |= 1;
                continue;
            }
        }
    }

    fn set_mem(self: *Decoder, addr: u64, val: u64) void {
        switch (self.mode) {
            Mode.Value => {
                var value: u64 = val;
                value &= self.mask0;
                value |= self.mask1;
                self.store(addr, value);
            },
            Mode.Address => {
                var address: u64 = addr;
                address &= self.mask0;
                address |= self.mask1;
                self.set_mem_multiple(address, val, 0);
            },
        }
    }

    fn set_mem_multiple(self: *Decoder, addr: u64, value: u64, pos: usize) void {
        if (pos >= self.fpos) {
            self.store(addr, value);
            return;
        }
        const bit: u6 = self.floats[pos];
        const mask0: u64 = @as(u64, 1) << bit;
        const mask1: u64 = ~mask0;
        self.set_mem_multiple(addr & mask1, value, pos + 1);
        self.set_mem_multiple(addr | mask0, value, pos + 1);
    }

    fn store(self: *Decoder, addr: u64, val: u64) void {
        // std.debug.warn("MEM {} {b} => {}\n", .{ addr, addr, val });
        if (self.mem.contains(addr)) {
            _ = self.mem.remove(addr);
        }
        _ = self.mem.put(addr, val) catch unreachable;
    }
};

test "sample value" {
    const data: []const u8 =
        \\mask = XXXXXXXXXXXXXXXXXXXXXXXXXXXXX1XXXX0X
        \\mem[8] = 11
        \\mem[7] = 101
        \\mem[8] = 0
    ;

    var decoder = Decoder.init(Decoder.Mode.Value);
    defer decoder.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        decoder.add_line(line);
    }

    const sum = decoder.sum_all_values();
    testing.expect(sum == 165);
}

test "sample address" {
    const data: []const u8 =
        \\mask = 000000000000000000000000000000X1001X
        \\mem[42] = 100
        \\mask = 00000000000000000000000000000000X0XX
        \\mem[26] = 1
    ;

    var decoder = Decoder.init(Decoder.Mode.Address);
    defer decoder.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        decoder.add_line(line);
    }

    const sum = decoder.sum_all_values();
    testing.expect(sum == 208);
}
