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
        var j = 0;
        while (j < node.len) : (j += 1) {
            node[j].deinit();
        }
    }

    pub fn reset(self: *Bank) void {
        var j: usize = 0;
        while (j < self.node.len) : (j += 1) {
            self.node[j].resetRAM();
        }
    }

    pub fn get_thruster_signal(self: *Bank, phase: [5]u8) i32 {
        self.reset();
        const top = self.node.len;
        var n: usize = 0;
        while (n < top) : (n += 1) {
            self.node[n].enqueueInput(phase[n]);
        }
        n = 0;
        var previous: ?i32 = 0;
        var result: i32 = 0;
        while (true) {
            if (self.node[n].halted) {
                std.debug.warn("NODE {} halted\n", n);
                if (n == top - 1) break;
            } else if (previous != null) {
                self.node[n].enqueueInput(previous.?);
                const output = self.node[n].run();
                if (output == null) {
                    std.debug.warn("NODE {} paused\n", n);
                } else {
                    if (n == top - 1) result = output.?;
                    std.debug.warn("NODE {}: {} => {}\n", n, previous, output.?);
                }
                previous = output;
            }
            n += 1;
            if (n >= phase.len) n = 0;
        }
        return result;
    }

    pub fn optimize_thruster_signal(self: *Bank) i32 {
        var phase = [5]u8{ 5, 6, 7, 8, 9 }; // must be sorted
        var mt: i32 = std.math.minInt(i32);
        self.ots(&phase, phase.len, &mt);
        return mt;
    }

    fn ots(self: *Bank, phase: *[5]u8, len: usize, mt: *i32) void {
        if (len == 1) {
            const t = self.get_thruster_signal(phase.*);
            if (mt.* < t) {
                mt.* = t;
            }
            return;
        }

        var j: usize = 0;
        while (j < phase.len) : (j += 1) {
            const m = len - 1;
            var t: u8 = 0;

            t = phase[j];
            phase[j] = phase[m];
            phase[m] = t;

            self.ots(phase, m, mt);

            t = phase[j];
            phase[j] = phase[m];
            phase[m] = t;
        }
    }
};

test "thruster signals, short program" {
    std.debug.warn("\n");
    const code: []const u8 = "3,26,1001,26,-4,26,3,27,1002,27,2,27,1,27,26,27,4,27,1001,28,-1,28,1005,28,6,99,0,0,5";
    const phases = [5]u8{ 9, 8, 7, 6, 5 };
    var bank = Bank.init(code[0..]);
    assert(bank.get_thruster_signal(phases) == 139629729);
}

test "thruster signals, medium program" {
    std.debug.warn("\n");
    const code: []const u8 = "3,52,1001,52,-5,52,3,53,1,52,56,54,1007,54,5,55,1005,55,26,1001,54,-5,54,1105,1,12,1,53,54,53,1008,54,0,55,1001,55,1,55,2,53,55,53,4,53,1001,56,-1,56,1005,56,6,99,0,0,0,0,10";
    const phases = [5]u8{ 9, 7, 8, 5, 6 };
    var bank = Bank.init(code[0..]);
    assert(bank.get_thruster_signal(phases) == 18216);
}
