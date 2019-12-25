const std = @import("std");
const assert = std.debug.assert;
const Computer = @import("./computer.zig").Computer;

pub const Maze = struct {
    computer: Computer,

    pub fn init() Maze {
        var self = Maze{
            .computer = Computer.init(true),
        };
        return self;
    }

    pub fn deinit(self: *Maze) void {
        self.computer.deinit();
    }

    pub fn run_to_solve(self: *Maze) usize {
        // Got this answer with pen and paper
        const program =
            \\north
            \\east
            \\take astrolabe
            \\south
            \\take space law space brochure
            \\north
            \\west
            \\north
            \\north
            \\north
            \\north
            \\take weather machine
            \\north
            \\take antenna
            \\west
            \\inv
            \\south
            \\inv
        ;
        var it = std.mem.separate(program, "\n");
        while (it.next()) |line| {
            // std.debug.warn("RUNNING\n");
            _ = self.computer.run();
            var number: usize = 0;
            while (true) {
                const output = self.computer.getOutput();
                if (output == null) break;
                const c = @intCast(u8, output.?);
                // std.debug.warn("{c}", c);
                if (c >= '0' and c <= '9') {
                    number = number * 10 + c - '0';
                } else {}
            }
            if (number > 0) {
                // std.debug.warn("=== NUMBER {} ===\n", number);
                return number;
            }
            // std.debug.warn("{}\n", line);
            var j: usize = 0;
            while (j < line.len) : (j += 1) {
                self.computer.enqueueInput(line[j]);
            }
            self.computer.enqueueInput('\n');
        }
        return 0;
    }
};
