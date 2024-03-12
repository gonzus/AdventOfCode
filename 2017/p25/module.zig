const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Turing = struct {
    const Label = u8;
    const Value = u8;

    const Dir = enum {
        left,
        right,

        pub fn parse(str: []const u8) !Dir {
            for (Dirs) |d| {
                if (std.mem.eql(u8, str, @tagName(d))) return d;
            }
            return error.InvalidDir;
        }

        pub fn format(
            v: Dir,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{c}", .{std.ascii.toUpper(@tagName(v)[0])});
        }
    };
    const Dirs = std.meta.tags(Dir);

    const Action = struct {
        write: Value,
        move: Dir,
        next: Label,

        pub fn format(
            v: Action,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("w={d},m={},n={c}", .{ v.write, v.move, v.next });
        }
    };

    const State = struct {
        label: Label,
        value: Value,

        pub fn format(
            v: State,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{c}:{d}", .{ v.label, v.value });
        }
    };

    const Tape = struct {
        const SIZE = 20000;
        slots: [SIZE]Value,
        pos: usize,

        pub fn init() Tape {
            var self = Tape{
                .slots = undefined,
                .pos = undefined,
            };
            self.reset();
            return self;
        }

        pub fn reset(self: *Tape) void {
            for (&self.slots) |*s| {
                s.* = 0;
            }
            self.pos = SIZE / 2;
        }

        pub fn countValue(self: Tape, value: Value) usize {
            var count: usize = 0;
            for (&self.slots) |s| {
                if (s == value) count += 1;
            }
            return count;
        }

        pub fn doAction(self: *Tape, action: Action) Value {
            self.slots[self.pos] = action.write;
            switch (action.move) {
                .left => self.pos -= 1,
                .right => self.pos += 1,
            }
            return self.slots[self.pos];
        }
    };

    actions: std.AutoHashMap(State, Action),
    tape: Tape,
    start: State,
    steps: usize,
    tmp_state: State,
    tmp_action: Action,

    pub fn init(allocator: Allocator) Turing {
        return .{
            .actions = std.AutoHashMap(State, Action).init(allocator),
            .tape = Tape.init(),
            .start = undefined,
            .steps = undefined,
            .tmp_state = undefined,
            .tmp_action = undefined,
        };
    }

    pub fn deinit(self: *Turing) void {
        self.actions.deinit();
    }

    pub fn addLine(self: *Turing, line: []const u8) !void {
        if (line.len == 0) return;

        var it = std.mem.tokenizeAny(u8, line, " :.-");
        const word = it.next().?;
        if (std.mem.eql(u8, word, "Begin")) {
            _ = it.next();
            _ = it.next();
            const chunk = it.next().?;
            self.start.label = chunk[0];
            self.start.value = 0;
            return;
        }
        if (std.mem.eql(u8, word, "Perform")) {
            _ = it.next();
            _ = it.next();
            _ = it.next();
            _ = it.next();
            const chunk = it.next().?;
            self.steps = try std.fmt.parseUnsigned(usize, chunk, 10);
            return;
        }
        if (std.mem.eql(u8, word, "In")) {
            _ = it.next();
            const chunk = it.next().?;
            self.tmp_state.label = chunk[0];
            return;
        }
        if (std.mem.eql(u8, word, "If")) {
            _ = it.next();
            _ = it.next();
            _ = it.next();
            _ = it.next();
            const chunk = it.next().?;
            self.tmp_state.value = chunk[0] - '0';
            return;
        }
        if (std.mem.eql(u8, word, "Write")) {
            _ = it.next();
            _ = it.next();
            const chunk = it.next().?;
            self.tmp_action.write = chunk[0] - '0';
            return;
        }
        if (std.mem.eql(u8, word, "Move")) {
            _ = it.next();
            _ = it.next();
            _ = it.next();
            _ = it.next();
            const chunk = it.next().?;
            self.tmp_action.move = try Dir.parse(chunk);
            return;
        }
        if (std.mem.eql(u8, word, "Continue")) {
            _ = it.next();
            _ = it.next();
            const chunk = it.next().?;
            self.tmp_action.next = chunk[0];
            try self.actions.put(self.tmp_state, self.tmp_action);
            return;
        }
    }

    pub fn show(self: Turing) void {
        std.debug.print("Turing with {} states, start {}, steps {}\n", .{ self.actions.count(), self.start, self.steps });
        var it = self.actions.iterator();
        while (it.next()) |a| {
            std.debug.print("{} => {}\n", .{ a.key_ptr.*, a.value_ptr.* });
        }
    }

    pub fn reset(self: *Turing) State {
        self.tape.reset();
        return self.start;
    }

    pub fn run(self: *Turing) !usize {
        var state = self.reset();
        for (0..self.steps) |_| {
            const action_opt = self.actions.get(state);
            if (action_opt) |action| {
                state.value = self.tape.doAction(action);
                state.label = action.next;
            } else {
                return error.InvalidState;
            }
        }
        return self.tape.countValue(1);
    }
};

test "sample part 1" {
    const data =
        \\Begin in state A.
        \\Perform a diagnostic checksum after 6 steps.
        \\
        \\In state A:
        \\  If the current value is 0:
        \\    - Write the value 1.
        \\    - Move one slot to the right.
        \\    - Continue with state B.
        \\  If the current value is 1:
        \\    - Write the value 0.
        \\    - Move one slot to the left.
        \\    - Continue with state B.
        \\
        \\In state B:
        \\  If the current value is 0:
        \\    - Write the value 1.
        \\    - Move one slot to the left.
        \\    - Continue with state A.
        \\  If the current value is 1:
        \\    - Write the value 1.
        \\    - Move one slot to the right.
        \\    - Continue with state A.
    ;

    var turing = Turing.init(std.testing.allocator);
    defer turing.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try turing.addLine(line);
    }
    // turing.show();

    const checksum = try turing.run();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, checksum);
}
