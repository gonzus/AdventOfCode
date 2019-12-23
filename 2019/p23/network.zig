const std = @import("std");
const assert = std.debug.assert;
const Computer = @import("./computer.zig").Computer;

pub const Network = struct {
    const SIZE: usize = 50;

    pub const NAT = struct {
        xcur: i64,
        ycur: i64,
        xprv: i64,
        yprv: i64,
        count: usize,

        pub fn init() NAT {
            var self = NAT{
                .xcur = -2,
                .ycur = -2,
                .xprv = -1,
                .yprv = -1,
                .count = 0,
            };
            return self;
        }
    };

    computers: [SIZE]Computer,
    nat: NAT,

    pub fn init(prg: []const u8) Network {
        var self = Network{
            .computers = undefined,
            .nat = NAT.init(),
        };
        std.debug.warn("Initializing network of {} computers...\n", SIZE);
        var j: usize = 0;
        while (j < SIZE) : (j += 1) {
            self.computers[j] = Computer.init(true);
            self.computers[j].parse(prg);
        }
        return self;
    }

    pub fn deinit(self: *Network) void {
        var j: usize = 0;
        while (j < SIZE) : (j += 1) {
            self.computers[j].deinit();
        }
    }

    pub fn run(self: *Network, once: bool) i64 {
        std.debug.warn("Running network of {} computers...\n", SIZE);
        var j: usize = 0;
        j = 0;
        while (j < SIZE) : (j += 1) {
            const input = @intCast(i64, j);
            // std.debug.warn("C {} enqueue {}\n", j, input);
            self.computers[j].enqueueInput(input);
        }
        var result: i64 = 0;
        main: while (true) {
            // std.debug.warn("MAIN LOOP\n");
            while (true) {
                var cycles: usize = 0;
                j = 0;
                while (j < SIZE) : (j += 1) {
                    // std.debug.warn("C {} run\n", j);
                    cycles += self.computers[j].run();
                }
                // std.debug.warn("CYCLES {}\n", cycles);
                if (cycles == 0) break;
            }
            j = 0;
            while (j < SIZE) : (j += 1) {
                var got: [3]i64 = undefined;
                var p: usize = 0;
                while (true) {
                    if (p >= 3) {
                        var d = @intCast(usize, got[0]);
                        const x = got[1];
                        const y = got[2];
                        if (d == 255) {
                            // std.debug.warn("Got packet for NAT: {} {}\n", x, y);
                            self.nat.count += 1;
                            self.nat.xcur = x;
                            self.nat.ycur = y;
                            if (once) {
                                result = self.nat.ycur;
                                break :main;
                            }
                        } else {
                            // std.debug.warn("C {} enqueue {} - {}\n", d, x, y);
                            self.computers[d].enqueueInput(x);
                            self.computers[d].enqueueInput(y);
                        }
                        p = 0;
                        break; // ????
                    }
                    const output = self.computers[j].getOutput();
                    if (output == null) break;
                    got[p] = output.?;
                    p += 1;
                    // std.debug.warn("C {} output {}\n", j, output.?);
                }
            }
            var enqueued: usize = 0;
            j = 0;
            while (j < SIZE) : (j += 1) {
                if (!self.computers[j].inputs.empty()) continue;
                // std.debug.warn("C {} enqueue -1\n", j);
                self.computers[j].enqueueInput(-1);
                enqueued += 1;
            }
            if (enqueued == SIZE) {
                // std.debug.warn("NETWORK IDLE\n");
                if (self.nat.count > 0) {
                    std.debug.warn("Sending packet from NAT: {} {}\n", self.nat.xcur, self.nat.ycur);
                    if (self.nat.ycur == self.nat.yprv) {
                        // std.debug.warn("REPEATED: {}\n", self.nat.ycur);
                        result = self.nat.ycur;
                        break :main;
                    }
                    self.nat.xprv = self.nat.xcur;
                    self.nat.yprv = self.nat.ycur;
                    self.computers[0].enqueueInput(self.nat.xcur);
                    self.computers[0].enqueueInput(self.nat.ycur);
                }
            }
        }
        return result;
    }
};
