const std = @import("std");
const assert = std.debug.assert;
const Computer = @import("./computer.zig").Computer;

pub const Droid = struct {
    computer: Computer,

    pub fn init(prg: []const u8) Droid {
        var self = Droid{
            .computer = Computer.init(true),
        };
        self.computer.parse(prg);
        return self;
    }

    pub fn deinit(self: *Droid) void {
        self.computer.deinit();
    }

    pub fn run_code(self: *Droid, code: []const u8) i64 {
        var it = std.mem.split(u8, code, "\n");
        while (it.next()) |line| {
            var k: usize = 0;
            while (k < line.len) : (k += 1) {
                self.computer.enqueueInput(line[k]);
            }
            self.computer.enqueueInput('\n');
        }
        while (!self.computer.halted)
            self.computer.run();

        var damage: i64 = 0;
        while (true) {
            const result = self.computer.getOutput();
            if (result == null) break;
            if (result.? >= 0 and result.? < 256) {
                const c = @intCast(u8, result.?);
                std.debug.warn("{c}", .{c});
            } else {
                damage = result.?;
                break;
            }
        }
        return damage;
    }
};
