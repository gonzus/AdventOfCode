const std = @import("std");
const testing = std.testing;

pub const Scanner = struct {
    fields: std.StringHashMap(usize),
    total_valid: usize,

    pub fn init() Scanner {
        const allocator = std.heap.page_allocator;
        var self = Scanner{
            .fields = std.StringHashMap(usize).init(allocator),
            .total_valid = 0,
        };
        return self;
    }

    pub fn deinit(self: *Scanner) void {
        self.fields.deinit();
    }

    pub fn add_line(self: *Scanner, line: []const u8) void {
        var count: usize = 0;
        var name = true;
        var it = std.mem.tokenize(line, " :");
        while (it.next()) |field| {
            std.debug.warn("FIELD {}\n", .{field});
            if (name) {
                const current = self.fields.get(field);
                var new: usize = 0;
                if (current != null) {
                    new = current.?;
                }
                new += 1;
                _ = self.fields.put(field, new) catch unreachable;
                std.debug.warn("FIELD {} => {}\n", .{ field, new });
            }
            name = !name;
            count += 1;
        }
        if (count == 0) {
            self.done();
        }
    }

    pub fn done(self: *Scanner) void {
        std.debug.warn("DONE\n", .{});
        var valid = false;
        if (self.fields.count() == 8) {
            valid = true;
        } else if (self.fields.count() == 7 and
            !self.fields.contains("cid"))
        {
            valid = true;
        }
        if (valid) {
            self.total_valid += 1;
        }
        self.fields.clearRetainingCapacity();
    }

    pub fn valid_count(self: Scanner) usize {
        return self.total_valid;
    }
};

test "sample" {
    const data: []const u8 =
        \\ecl:gry pid:860033327 eyr:2020 hcl:#fffffd
        \\byr:1937 iyr:2017 cid:147 hgt:183cm
        \\
        \\iyr:2013 ecl:amb cid:350 eyr:2023 pid:028048884
        \\hcl:#cfa07d byr:1929
        \\
        \\hcl:#ae17e1 iyr:2013
        \\eyr:2024
        \\ecl:brn pid:760753108 byr:1931
        \\hgt:179cm
        \\
        \\hcl:#cfa07d eyr:2025 pid:166559648
        \\iyr:2011 ecl:brn hgt:59in
    ;

    var scanner = Scanner.init();
    defer scanner.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        scanner.add_line(line);
    }
    scanner.done();
    // scanner.show();

    const count = scanner.valid_count();
    testing.expect(count == 2);
}
