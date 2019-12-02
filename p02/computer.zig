const std = @import("std");

pub const Computer = struct {
    mem: [1024]u32,
    pos: usize,

    const OP = enum(u32) {
        ADD = 1,
        MUL = 2,
        STOP = 99,
    };

    pub fn init(line: []u8) Computer {
        var self = Computer{
            .mem = undefined,
            .pos = 0,
        };
        var cur: u32 = 0;
        var j: usize = 0;
        var l: usize = 0;
        while (true) {
            if (j >= line.len or line[j] < '0' or line[j] > '9') {
                self.append(cur);
                cur = 0;
                l = 0;
                if (j >= line.len) {
                    break;
                }
            } else {
                cur = cur * 10 + line[j] - '0';
                l += 1;
            }
            j += 1;
        }
        return self;
    }

    pub fn get(self: Computer, pos: usize) u32 {
        return self.mem[pos];
    }

    pub fn set(self: *Computer, pos: usize, val: u32) void {
        self.mem[pos] = val;
    }

    pub fn append(self: *Computer, val: u32) void {
        self.mem[self.pos] = val;
        self.pos += 1;
    }

    pub fn run(self: *Computer) void {
        var j: usize = 0;
        while (true) : (j += 4) {
            const op = @intToEnum(OP, self.mem[j + 0]);
            const p1 = self.mem[j + 1];
            const p2 = self.mem[j + 2];
            const p3 = self.mem[j + 3];
            switch (op) {
                OP.STOP => break,
                OP.ADD => self.mem[p3] = self.mem[p1] + self.mem[p2],
                OP.MUL => self.mem[p3] = self.mem[p1] * self.mem[p2],
            }
        }
    }
};
