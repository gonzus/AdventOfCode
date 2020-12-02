const std = @import("std");
const testing = std.testing;

pub const Data = struct {
    n1: usize,
    n2: usize,
    chr: u8,
    pass: []const u8,

    pub fn init() Data {
        var self = Data{
            .n1 = 0,
            .n2 = 0,
            .chr = 0,
            .pass = "",
        };
        return self;
    }
};

pub const Password = struct {
    pub fn init() Password {
        var self = Password{};
        return self;
    }

    pub fn deinit(self: *Password) void {}

    fn parse_line(self: Password, line: []const u8) Data {
        var it = std.mem.split(line, " ");
        var data = Data.init();
        var what: usize = 0;
        while (it.next()) |part| {
            what += 1;
            if (what == 1) {
                // std.debug.warn("SPEC {}\n", .{part});
                var it2 = std.mem.split(part, "-");
                var pos2: usize = 0;
                while (it2.next()) |part2| {
                    pos2 += 1;
                    if (pos2 == 1) {
                        data.n1 = std.fmt.parseInt(usize, part2, 10) catch unreachable;
                        continue;
                    }
                    if (pos2 == 2) {
                        data.n2 = std.fmt.parseInt(usize, part2, 10) catch unreachable;
                        continue;
                    }
                    // std.debug.warn("TOO MANY SPECS\n", .{});
                    data.chr = 0;
                    break;
                }
                continue;
            }
            if (what == 2) {
                // std.debug.warn("CHAR {}\n", .{part});
                data.chr = part[0];
                continue;
            }
            if (what == 3) {
                // std.debug.warn("PASS {}\n", .{part});
                data.pass = part;
                continue;
            }
            // std.debug.warn("TOO MANY PARTS\n", .{});
            data.chr = 0;
            break;
        }
        return data;
    }

    pub fn check_count(self: Password, line: []const u8) bool {
        const data = self.parse_line(line);
        var cnt: usize = 0;
        var pos: usize = 0;
        while (pos < data.pass.len) : (pos += 1) {
            if (data.pass[pos] == data.chr) {
                cnt += 1;
            }
        }
        const ok = (cnt >= data.n1 and cnt <= data.n2);
        // std.debug.warn("FOUND {} of {}, expect {}-{} => {}\n", .{ cnt, data.chr, data.n1, data.n2, ok });
        return ok;
    }

    pub fn check_pos(self: Password, line: []const u8) bool {
        const data = self.parse_line(line);
        var cnt: usize = 0;
        if (data.pass.len >= data.n1 and data.pass[data.n1 - 1] == data.chr) {
            cnt += 1;
        }
        if (data.pass.len >= data.n2 and data.pass[data.n2 - 1] == data.chr) {
            cnt += 1;
        }
        const ok = (cnt == 1);
        // std.debug.warn("FOUND {} of {}, expect {}&{} => {}\n", .{ cnt, data.chr, data.n1, data.n2, ok });
        return ok;
    }
};

test "sample count" {
    const valid = 2;
    const data: []const u8 =
        \\1-3 a: abcde
        \\1-3 b: cdefg
        \\2-9 c: ccccccccc
    ;

    var password = Password.init();
    defer password.deinit();

    var count: usize = 0;
    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        if (password.check_count(line)) {
            count += 1;
        }
    }

    testing.expect(count == valid);
}

test "sample pos" {
    const valid = 1;
    const data: []const u8 =
        \\1-3 a: abcde
        \\1-3 b: cdefg
        \\2-9 c: ccccccccc
    ;

    var password = Password.init();
    defer password.deinit();

    var count: usize = 0;
    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        if (password.check_pos(line)) {
            count += 1;
        }
    }

    testing.expect(count == valid);
}
