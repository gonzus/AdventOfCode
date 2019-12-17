const std = @import("std");
const assert = std.debug.assert;
const Computer = @import("./computer.zig").Computer;

pub const Bank = struct {
    node: [5]Computer,

    pub fn init(str: []const u8) Bank {
        var self = Bank{
            .node = undefined,
        };
        var j: usize = 0;
        while (j < self.node.len) : (j += 1) {
            self.node[j] = Computer.init(str);
            self.node[j].setReentrant();
        }
        return self;
    }

    pub fn deinit(self: *Bank) void {
        var j: usize = 0;
        while (j < self.node.len) : (j += 1) {
            self.node[j].deinit();
        }
    }

    pub fn setReentrant(self: *Bank) void {
        var j: usize = 0;
        while (j < self.node.len) : (j += 1) {
            self.node[j].setReentrant();
        }
    }

    pub fn clear(self: *Bank) void {
        var j: usize = 0;
        while (j < self.node.len) : (j += 1) {
            self.node[j].clear();
        }
    }

    pub fn get_thruster_signal(self: *Bank, phases: [5]u8) i32 {
        self.clear();
        const top = self.node.len;
        var n: usize = 0;
        while (n < top) : (n += 1) {
            self.node[n].enqueueInput(phases[n]);
        }
        n = 0;
        var previous: ?i32 = 0;
        var result: i32 = 0;
        while (true) {
            if (self.node[n].halted) {
                // std.debug.warn("NODE {} halted\n", n);
                if (n == top - 1) break;
            } else if (previous != null) {
                self.node[n].enqueueInput(previous.?);
                const output = self.node[n].run();
                if (output != null and n == top - 1) {
                    result = output.?;
                }
                previous = output;
            } else {
                std.debug.warn("NODE {} is paused but there is no input\n", n);
                break;
            }
            n = (n + 1) % phases.len;
        }
        return result;
    }

    pub fn optimize_thruster_signal(self: *Bank, phases: *[5]u8) i32 {
        var mt: i32 = std.math.minInt(i32);
        self.ots(phases, phases.*.len, &mt);
        return mt;
    }

    fn ots(self: *Bank, phases: *[5]u8, len: usize, mt: *i32) void {
        if (len == 1) {
            const t = self.get_thruster_signal(phases.*);
            if (mt.* < t) {
                mt.* = t;
            }
            return;
        }

        var j: usize = 0;
        while (j < phases.len) : (j += 1) {
            const m = len - 1;
            std.mem.swap(u8, &phases[j], &phases[m]);
            self.ots(phases, m, mt);
            std.mem.swap(u8, &phases[j], &phases[m]);
        }
    }
};

test "thruster signals, non-reentrant, short program" {
    const code: []const u8 = "3,15,3,16,1002,16,10,16,1,16,15,15,4,15,99,0,0";
    const phases = [5]u8{ 4, 3, 2, 1, 0 };
    var bank = Bank.init(code[0..]);
    assert(bank.get_thruster_signal(phases) == 43210);
}

test "thruster signals, non-reentrant, medium program" {
    const code: []const u8 = "3,23,3,24,1002,24,10,24,1002,23,-1,23,101,5,23,23,1,24,23,23,4,23,99,0,0";
    const phases = [5]u8{ 0, 1, 2, 3, 4 };
    var bank = Bank.init(code[0..]);
    assert(bank.get_thruster_signal(phases) == 54321);
}

test "thruster signals, non-reentrant, long program" {
    const code: []const u8 = "3,31,3,32,1002,32,10,32,1001,31,-2,31,1007,31,0,33,1002,33,7,33,1,33,31,31,1,32,31,31,4,31,99,0,0,0";
    const phases = [5]u8{ 1, 0, 4, 3, 2 };
    var bank = Bank.init(code[0..]);
    assert(bank.get_thruster_signal(phases) == 65210);
}

test "optimize thruster signals, non-reentrant, short program" {
    const code: []const u8 = "3,15,3,16,1002,16,10,16,1,16,15,15,4,15,99,0,0";
    var bank = Bank.init(code[0..]);
    var phases = [5]u8{ 0, 1, 2, 3, 4 }; // must be sorted
    assert(bank.optimize_thruster_signal(&phases) == 43210);
}

test "thruster signals, reentrant, short program" {
    const code: []const u8 = "3,26,1001,26,-4,26,3,27,1002,27,2,27,1,27,26,27,4,27,1001,28,-1,28,1005,28,6,99,0,0,5";
    const phases = [5]u8{ 9, 8, 7, 6, 5 };
    var bank = Bank.init(code[0..]);
    assert(bank.get_thruster_signal(phases) == 139629729);
}

test "thruster signals, reentrant, medium program" {
    const code: []const u8 = "3,52,1001,52,-5,52,3,53,1,52,56,54,1007,54,5,55,1005,55,26,1001,54,-5,54,1105,1,12,1,53,54,53,1008,54,0,55,1001,55,1,55,2,53,55,53,4,53,1001,56,-1,56,1005,56,6,99,0,0,0,0,10";
    const phases = [5]u8{ 9, 7, 8, 5, 6 };
    var bank = Bank.init(code[0..]);
    assert(bank.get_thruster_signal(phases) == 18216);
}
