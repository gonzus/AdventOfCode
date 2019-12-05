const std = @import("std");
const assert = std.debug.assert;

pub const Computer = struct {
    mem: [1024]u32,
    pos: usize,

    const OP = enum(u32) {
        ADD = 1,
        MUL = 2,
        STOP = 99,
    };

    pub fn init(str: []const u8) Computer {
        var self = Computer{
            .mem = undefined,
            .pos = 0,
        };
        var cur: u32 = 0;
        var j: usize = 0;
        var l: usize = 0;
        while (true) {
            if (j >= str.len or str[j] < '0' or str[j] > '9') {
                self.append(cur);
                cur = 0;
                l = 0;
                if (j >= str.len) {
                    break;
                }
            } else {
                cur = cur * 10 + str[j] - '0';
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

test "simple - pos 0 becomes 3500" {
    const data: []const u8 = "1,9,10,3,2,3,11,0,99,30,40,50";
    var computer = Computer.init(data[0..]);
    computer.run();
    assert(computer.get(0) == 3500);
}

test "simple - pos 0 becomes 2" {
    const data: []const u8 = "1,0,0,0,99";
    var computer = Computer.init(data[0..]);
    computer.run();
    assert(computer.get(0) == 2);
}

test "simple - pos 3 becomes 6" {
    const data: []const u8 = "2,3,0,3,99";
    var computer = Computer.init(data[0..]);
    computer.run();
    assert(computer.get(3) == 6);
}

test "simple - pos 5 becomes 9801" {
    const data: []const u8 = "2,4,4,5,99,0";
    var computer = Computer.init(data[0..]);
    computer.run();
    assert(computer.get(5) == 9801);
}

test "simple - pos 0 becomes 30" {
    const data: []const u8 = "1,1,1,4,99,5,6,0,99";
    var computer = Computer.init(data[0..]);
    computer.run();
    assert(computer.get(0) == 30);
}
