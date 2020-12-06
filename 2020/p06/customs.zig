const std = @import("std");
const testing = std.testing;

pub const Customs = struct {
    const SIZE: usize = 26;

    count_any: bool,
    count: [SIZE]usize,
    line_count: usize,
    total_sum: usize,

    pub fn init(count_any: bool) Customs {
        var self = Customs{
            .count_any = count_any,
            .count = [_]usize{0} ** SIZE,
            .line_count = 0,
            .total_sum = 0,
        };
        return self;
    }

    pub fn deinit(self: *Customs) void {}

    pub fn add_line(self: *Customs, line: []const u8) void {
        // std.debug.warn("LINE [{}]\n", .{line});
        if (line.len == 0) {
            self.done();
            return;
        }

        self.line_count += 1;
        for (line) |c| {
            var pos: usize = 0;
            if (c >= 'a' or c <= 'z') {
                pos = c - 'a';
            } else if (c >= 'A' or c <= 'Z') {
                pos = c - 'A';
            } else {
                continue;
            }
            self.count[pos] += 1;
        }
    }

    pub fn done(self: *Customs) void {
        // std.debug.warn("DONE\n", .{});
        var total: usize = 0;
        for (self.count) |count| {
            if (self.count_any and count > 0) {
                self.total_sum += 1;
            } else if (!self.count_any and count == self.line_count) {
                self.total_sum += 1;
            }
        }

        self.line_count = 0;
        for (self.count) |count, pos| {
            self.count[pos] = 0;
        }
    }

    pub fn get_total_sum(self: Customs) usize {
        return self.total_sum;
    }
};

test "sample any" {
    const data: []const u8 =
        \\abc
        \\
        \\a
        \\b
        \\c
        \\
        \\ab
        \\ac
        \\
        \\a
        \\a
        \\a
        \\a
        \\
        \\b
    ;

    var customs = Customs.init(true);
    defer customs.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        customs.add_line(line);
    }
    customs.done();

    const total_sum = customs.get_total_sum();
    testing.expect(total_sum == 11);
}

test "sample all" {
    const data: []const u8 =
        \\abc
        \\
        \\a
        \\b
        \\c
        \\
        \\ab
        \\ac
        \\
        \\a
        \\a
        \\a
        \\a
        \\
        \\b
    ;

    var customs = Customs.init(false);
    defer customs.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        customs.add_line(line);
    }
    customs.done();

    const total_sum = customs.get_total_sum();
    testing.expect(total_sum == 6);
}
