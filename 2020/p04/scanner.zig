const std = @import("std");
const testing = std.testing;

pub const Scanner = struct {
    const SIZE: usize = 8; // TODO this is the number of elements in Field enum

    validate: bool,
    total_valid: usize,
    count: [SIZE]usize,

    pub fn init(validate: bool) Scanner {
        const allocator = std.heap.page_allocator;
        var self = Scanner{
            .validate = validate,
            .total_valid = 0,
            .count = [_]usize{0} ** SIZE,
        };
        return self;
    }

    pub fn deinit(self: *Scanner) void {}

    pub fn add_line(self: *Scanner, line: []const u8) void {
        // std.debug.warn("LINE [{}]\n", .{line});
        var field_count: usize = 0;
        var field: ?Field = null;
        var it = std.mem.tokenize(line, " :");
        while (it.next()) |str| {
            field_count += 1;
            if (field == null) {
                field = Field.parse(str);
                // std.debug.warn("FIELD [{}]\n", .{field});
                continue;
            }

            const valid = if (!self.validate) true else switch (field.?) {
                .BYR => self.check_num(str, 1920, 2002),
                .IYR => self.check_num(str, 2010, 2020),
                .EYR => self.check_num(str, 2020, 2030),
                .HGT => self.check_num_unit(str, "cm", 150, 193) or
                    self.check_num_unit(str, "in", 59, 76),
                .HCL => self.check_hcl(str),
                .ECL => self.check_ecl(str),
                .PID => self.check_pid(str),
                .CID => true,
            };
            if (valid) {
                self.count[field.?.pos()] += 1;
            }
            field = null;
        }
        if (field_count == 0) {
            // empty / blank lines indicate end of current passport data
            self.done();
        }
    }

    pub fn done(self: *Scanner) void {
        // std.debug.warn("DONE\n", .{});
        self.count[Field.CID.pos()] = 1; // always ok
        var total: usize = 0;
        for (self.count) |count| {
            if (count > 0) {
                total += 1;
            }
        }
        if (total >= 8) {
            self.total_valid += 1;
        }

        for (self.count) |count, pos| {
            self.count[pos] = 0;
        }
    }

    pub fn valid_count(self: Scanner) usize {
        return self.total_valid;
    }

    // pid (Passport ID) - a nine-digit number, including leading zeroes.
    fn check_pid(self: Scanner, str: []const u8) bool {
        if (str.len != 9) {
            return false;
        }
        var valid: i32 = std.fmt.parseInt(i32, str, 10) catch -1;
        return valid >= 0;
    }

    // ecl (Eye Color) - exactly one of: amb blu brn gry grn hzl oth.
    fn check_ecl(self: Scanner, str: []const u8) bool {
        if (std.mem.eql(u8, str, "amb")) return true;
        if (std.mem.eql(u8, str, "blu")) return true;
        if (std.mem.eql(u8, str, "brn")) return true;
        if (std.mem.eql(u8, str, "gry")) return true;
        if (std.mem.eql(u8, str, "grn")) return true;
        if (std.mem.eql(u8, str, "hzl")) return true;
        if (std.mem.eql(u8, str, "oth")) return true;
        return false;
    }

    // hcl (Hair Color) - a # followed by exactly six characters 0-9 or a-f.
    fn check_hcl(self: Scanner, str: []const u8) bool {
        if (str.len != 7) {
            return false;
        }
        if (str[0] != '#') {
            return false;
        }
        var valid: i32 = std.fmt.parseInt(i32, str[1..], 16) catch -1;
        return valid >= 0;
    }

    // byr (Birth Year) - four digits; at least 1920 and at most 2002.
    // iyr (Issue Year) - four digits; at least 2010 and at most 2020.
    // eyr (Expiration Year) - four digits; at least 2020 and at most 2030.
    fn check_num(self: Scanner, str: []const u8, min: usize, max: usize) bool {
        return self.check_num_unit(str, null, min, max);
    }

    // hgt (Height) - a number followed by either cm or in:
    //   If cm, the number must be at least 150 and at most 193.
    //   If in, the number must be at least 59 and at most 76.
    fn check_num_unit(self: Scanner, str: []const u8, unit: ?[]const u8, min: usize, max: usize) bool {
        const top = str.len - if (unit != null) unit.?.len else 0;
        var value: i32 = std.fmt.parseInt(i32, str[0..top], 10) catch -1;
        if (value < min or value > max) {
            return false;
        }
        if (unit != null and !std.mem.eql(u8, str[top..], unit.?)) {
            return false;
        }
        return true;
    }

    const Field = enum(usize) {
        BYR,
        IYR,
        EYR,
        HGT,
        HCL,
        ECL,
        PID,
        CID,

        pub fn parse(str: []const u8) ?Field {
            if (std.mem.eql(u8, str, "byr")) return Field.BYR;
            if (std.mem.eql(u8, str, "iyr")) return Field.IYR;
            if (std.mem.eql(u8, str, "eyr")) return Field.EYR;
            if (std.mem.eql(u8, str, "hgt")) return Field.HGT;
            if (std.mem.eql(u8, str, "hcl")) return Field.HCL;
            if (std.mem.eql(u8, str, "ecl")) return Field.ECL;
            if (std.mem.eql(u8, str, "pid")) return Field.PID;
            if (std.mem.eql(u8, str, "cid")) return Field.CID;
            return null;
        }

        pub fn pos(field: Field) usize {
            return @enumToInt(field);
        }
    };
};

test "sample no validation" {
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

    var scanner = Scanner.init(false);
    defer scanner.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        scanner.add_line(line);
    }
    scanner.done();

    const count = scanner.valid_count();
    testing.expect(count == 2);
}

test "sample invalid" {
    const data: []const u8 =
        \\eyr:1972 cid:100
        \\hcl:#18171d ecl:amb hgt:170 pid:186cm iyr:2018 byr:1926
        \\
        \\iyr:2019
        \\hcl:#602927 eyr:1967 hgt:170cm
        \\ecl:grn pid:012533040 byr:1946
        \\
        \\hcl:dab227 iyr:2012
        \\ecl:brn hgt:182cm pid:021572410 eyr:2020 byr:1992 cid:277
        \\
        \\hgt:59cm ecl:zzz
        \\eyr:2038 hcl:74454a iyr:2023
        \\pid:3556412378 byr:2007
    ;

    var scanner = Scanner.init(true);
    defer scanner.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        scanner.add_line(line);
    }
    scanner.done();

    const count = scanner.valid_count();
    testing.expect(count == 0);
}

test "sample valid" {
    const data: []const u8 =
        \\pid:087499704 hgt:74in ecl:grn iyr:2012 eyr:2030 byr:1980
        \\hcl:#623a2f
        \\
        \\eyr:2029 ecl:blu cid:129 byr:1989
        \\iyr:2014 pid:896056539 hcl:#a97842 hgt:165cm
        \\
        \\hcl:#888785
        \\hgt:164cm byr:2001 iyr:2015 cid:88
        \\pid:545766238 ecl:hzl
        \\eyr:2022
        \\
        \\iyr:2010 hgt:158cm hcl:#b6652a ecl:blu byr:1944 eyr:2021 pid:093154719
    ;

    var scanner = Scanner.init(true);
    defer scanner.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        scanner.add_line(line);
    }
    scanner.done();

    const count = scanner.valid_count();
    testing.expect(count == 4);
}
