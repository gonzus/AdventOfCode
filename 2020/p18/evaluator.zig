const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Evaluator = struct {
    pub const Precedence = enum {
        None,
        MulBeforeAdd,
        AddBeforeMul,
    };

    precedence: Precedence,
    nums: [128]usize,
    oprs: [128]u8,
    pn: usize,
    po: usize,

    pub fn init(precedence: Precedence) Evaluator {
        return Evaluator{
            .precedence = precedence,
            .nums = undefined,
            .oprs = undefined,
            .pn = 0,
            .po = 0,
        };
    }

    pub fn deinit(self: *Evaluator) void {}

    pub fn reset(self: *Evaluator) void {
        self.pn = 0;
        self.po = 0;
    }

    pub fn push_num(self: *Evaluator, num: usize) void {
        // std.debug.warn("NUM {} {}\n", .{ self.pn, num });
        self.nums[self.pn] = num;
        self.pn += 1;
    }

    pub fn push_op(self: *Evaluator, op: u8) void {
        // std.debug.warn("OP {} {c}\n", .{ self.po, op });
        self.oprs[self.po] = op;
        self.po += 1;
    }

    fn reduce_one(self: *Evaluator) bool {
        if (self.pn < 2 or self.po < 1) return false;
        const l = self.nums[self.pn - 2];
        const r = self.nums[self.pn - 1];
        const o = self.oprs[self.po - 1];
        const a = switch (o) {
            '+' => l + r,
            '*' => l * r,
            else => @panic("REDUCE"),
        };
        // std.debug.warn("REDUCE {}({}) {c}({}) {}({}) = {}\n", .{ l, self.pn - 2, o, self.po - 1, r, self.pn - 1, a });
        self.nums[self.pn - 2] = a;
        self.pn -= 1;
        self.po -= 1;
        return true;
    }

    // reduce while operator found
    fn reduce_eq(self: *Evaluator, needed: usize, op: u8) void {
        while (self.pn >= needed and self.po >= 1 and self.oprs[self.po - 1] == op) {
            if (!self.reduce_one()) break;
        }
    }

    // reduce while operator not found
    fn reduce_ne(self: *Evaluator, needed: usize, op: u8) void {
        while (self.pn >= needed and self.po >= 1 and self.oprs[self.po - 1] != op) {
            if (!self.reduce_one()) break;
        }
    }

    // reduce high precedence while possible
    fn reduce_greedy(self: *Evaluator) void {
        switch (self.precedence) {
            .AddBeforeMul => self.reduce_eq(2, '+'),
            .MulBeforeAdd => self.reduce_eq(2, '*'),
            .None => self.reduce_ne(2, '('),
        }
    }

    // reduce inside parenthesis and then greedily
    fn reduce_parens(self: *Evaluator) void {
        self.reduce_ne(1, '(');
        self.po -= 1;
        self.reduce_greedy();
    }

    pub fn eval(self: *Evaluator, str: []const u8) usize {
        // std.debug.warn("\nEVAL {}\n", .{str});
        self.reset();
        for (str) |c| {
            switch (c) {
                ' ', '\t' => {},
                '0'...'9' => {
                    const n = c - '0';
                    self.push_num(n);
                    self.reduce_greedy();
                },
                '+' => {
                    self.push_op(c);
                },
                '*' => {
                    self.push_op(c);
                },
                '(' => {
                    self.push_op(c);
                },
                ')' => {
                    self.reduce_parens();
                },
                else => {
                    @panic("CHAR");
                },
            }
        }
        self.reduce_ne(2, 0);
        return self.nums[0];
    }
};

test "samples part a" {
    var evaluator = Evaluator.init(Evaluator.Precedence.None);
    defer evaluator.deinit();

    testing.expect(evaluator.eval("1 + 2 * 3 + 4 * 5 + 6") == 71);
    testing.expect(evaluator.eval("1 + (2 * 3) + (4 * (5 + 6))") == 51);
    testing.expect(evaluator.eval("2 * 3 + (4 * 5)") == 26);
    testing.expect(evaluator.eval("5 + (8 * 3 + 9 + 3 * 4 * 3)") == 437);
    testing.expect(evaluator.eval("5 * 9 * (7 * 3 * 3 + 9 * 3 + (8 + 6 * 4))") == 12240);
    testing.expect(evaluator.eval("((2 + 4 * 9) * (6 + 9 * 8 + 6) + 6) + 2 + 4 * 2") == 13632);
}

test "samples normal precedence" {
    var evaluator = Evaluator.init(Evaluator.Precedence.MulBeforeAdd);
    defer evaluator.deinit();

    testing.expect(evaluator.eval("1 + 2 * 3 + 4 * 5 + 6") == 33);
    testing.expect(evaluator.eval("1 + (2 * 3) + (4 * (5 + 6))") == 51);
    testing.expect(evaluator.eval("2 * 3 + (4 * 5)") == 26);
    testing.expect(evaluator.eval("5 + (8 * 3 + 9 + 3 * 4 * 3)") == 74);
    testing.expect(evaluator.eval("5 * 9 * (7 * 3 * 3 + 9 * 3 + (8 + 6 * 4))") == 5490);
    testing.expect(evaluator.eval("((2 + 4 * 9) * (6 + 9 * 8 + 6) + 6) + 2 + 4 * 2") == 3208);
    testing.expect(evaluator.eval("(6 + 6 * 8) + 4 * 3 + (8 * 2 + 2 * 3) * (7 * (8 * 4)) * 9") == 44418);
}

test "samples part b" {
    var evaluator = Evaluator.init(Evaluator.Precedence.AddBeforeMul);
    defer evaluator.deinit();

    testing.expect(evaluator.eval("1 + 2 * 3 + 4 * 5 + 6") == 231);
    testing.expect(evaluator.eval("1 + (2 * 3) + (4 * (5 + 6))") == 51);
    testing.expect(evaluator.eval("2 * 3 + (4 * 5)") == 46);
    testing.expect(evaluator.eval("5 + (8 * 3 + 9 + 3 * 4 * 3)") == 1445);
    testing.expect(evaluator.eval("5 * 9 * (7 * 3 * 3 + 9 * 3 + (8 + 6 * 4))") == 669060);
    testing.expect(evaluator.eval("((2 + 4 * 9) * (6 + 9 * 8 + 6) + 6) + 2 + 4 * 2") == 23340);

    // this is how I found out a bug
    testing.expect(evaluator.eval("(6 + 6 * 8) + 4 * 3 + (8 * 2 + 2 * 3) * (7 * (8 * 4)) * 9") == 19958400);
}
