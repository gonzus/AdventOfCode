const std = @import("std");
const testing = std.testing;
const StringTable = @import("./strtab.zig").StringTable;

const allocator = std.heap.page_allocator;

pub const DB = struct {
    pub const Ticket = struct {
        values: std.ArrayList(usize),
        valid: bool,

        pub fn init() *Ticket {
            var self = allocator.create(Ticket) catch unreachable;
            self.* = Ticket{
                .values = std.ArrayList(usize).init(allocator),
                .valid = true,
            };
            return self;
        }
        pub fn deinit(self: *Ticket) void {
            self.values.deinit();
        }
    };

    const Range = struct {
        min: usize,
        max: usize,
    };

    const Rule = struct {
        code: usize,
        ranges: [2]Range = undefined,

        pub fn init(code: usize) Rule {
            var self = Rule{
                .code = code,
                .ranges = undefined,
            };
            return self;
        }
    };

    const Guess = struct {
        mask: usize,
        code: usize,

        pub fn init(mask: usize) Guess {
            var self = Guess{
                .mask = mask,
                .code = std.math.maxInt(usize),
            };
            return self;
        }
    };

    zone: usize,
    fields: StringTable,
    rules: std.AutoHashMap(usize, Rule),
    tickets: std.ArrayList(*Ticket), // first one is mine
    guessed: std.ArrayList(Guess), // per field

    pub fn init() DB {
        var self = DB{
            .zone = 0,
            .fields = StringTable.init(allocator),
            .rules = std.AutoHashMap(usize, Rule).init(allocator),
            .tickets = std.ArrayList(*Ticket).init(allocator),
            .guessed = std.ArrayList(Guess).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *DB) void {
        self.guessed.deinit();
        self.tickets.deinit();
        self.rules.deinit();
        self.fields.deinit();
    }

    pub fn add_line(self: *DB, line: []const u8) void {
        if (line.len == 0) return;
        if (std.mem.eql(u8, line, "your ticket:") or
            std.mem.eql(u8, line, "nearby tickets:"))
        {
            self.zone += 1;
            // std.debug.warn("ZONE {}\n", .{self.zone});
            return;
        }
        if (self.zone == 0) {
            var it_colon = std.mem.tokenize(line, ":");
            const name = it_colon.next().?;
            const code = self.fields.add(name);
            // std.debug.warn("FIELD {} {}\n", .{ code, name });
            var rule = Rule.init(code);

            const rest = it_colon.next().?;
            var it = std.mem.tokenize(rest, " -");
            rule.ranges[0].min = std.fmt.parseInt(usize, it.next().?, 10) catch unreachable;
            rule.ranges[0].max = std.fmt.parseInt(usize, it.next().?, 10) catch unreachable;
            _ = it.next().?; // "or"
            rule.ranges[1].min = std.fmt.parseInt(usize, it.next().?, 10) catch unreachable;
            rule.ranges[1].max = std.fmt.parseInt(usize, it.next().?, 10) catch unreachable;
            _ = self.rules.put(code, rule) catch unreachable;
            // std.debug.warn("RULE {} {}\n", .{ code, self.fields.get_str(code) });
            return;
        }
        if (self.zone == 1 or self.zone == 2) {
            var ticket = Ticket.init();
            var it = std.mem.tokenize(line, ",");
            while (it.next()) |str| {
                const value = std.fmt.parseInt(usize, str, 10) catch unreachable;
                ticket.values.append(value) catch unreachable;
            }
            self.tickets.append(ticket) catch unreachable;
            return;
        }
        @panic("ZONE");
    }

    pub fn ticket_scanning_error_rate(self: *DB) usize {
        return self.mark_invalid_tickets();
    }

    pub fn multiply_fields(self: *DB, prefix: []const u8) usize {
        _ = self.mark_invalid_tickets();
        self.guess_ticket_fields();
        var product: usize = 1;
        var pg: usize = 0;
        while (pg < self.guessed.items.len) : (pg += 1) {
            const guess = self.guessed.items[pg];
            const name = self.fields.get_str(guess.code).?;
            if (!std.mem.startsWith(u8, name, prefix)) continue;
            const value = self.tickets.items[0].values.items[pg];
            // std.debug.warn("MULT {} POS {} VAL {}\n", .{ name, pg, value });
            product *= value;
        }
        return product;
    }

    fn mark_invalid_tickets(self: *DB) usize {
        var rate: usize = 0;
        var pt: usize = 1; // skip mine
        while (pt < self.tickets.items.len) : (pt += 1) {
            const ticket = self.tickets.items[pt];
            ticket.valid = true;
            var pv: usize = 0;
            while (pv < ticket.values.items.len) : (pv += 1) {
                const value = ticket.values.items[pv];
                if (self.is_value_valid(value)) continue;
                rate += value;
                ticket.valid = false;
            }
        }
        return rate;
    }

    fn is_value_valid(self: *DB, value: usize) bool {
        var itr = self.rules.iterator();
        while (itr.next()) |kv| {
            const rule = kv.value;
            var pr: usize = 0;
            while (pr < 2) : (pr += 1) {
                if (value >= rule.ranges[pr].min and
                    value <= rule.ranges[pr].max)
                {
                    return true;
                }
            }
        }
        return false;
    }

    fn guess_ticket_fields(self: *DB) void {
        const NF = self.tickets.items[0].values.items.len;
        var pf: usize = 0;
        while (pf < NF) : (pf += 1) {
            // std.debug.warn("FIELD {}\n", .{pf});
            var field_mask: usize = std.math.maxInt(usize);
            var pt: usize = 1; // skip mine
            while (pt < self.tickets.items.len) : (pt += 1) {
                var ticket_mask: usize = 0;
                const ticket = self.tickets.items[pt];
                if (!ticket.valid) continue;
                // std.debug.warn("TICKET {}\n", .{pt});
                const value = ticket.values.items[pf];
                var itr = self.rules.iterator();
                while (itr.next()) |kv| {
                    const code = kv.key;
                    const rule = kv.value;
                    var valid = false;
                    var pr: usize = 0;
                    while (pr < 2) : (pr += 1) {
                        if (value >= rule.ranges[pr].min and
                            value <= rule.ranges[pr].max)
                        {
                            valid = true;
                            break;
                        }
                    }
                    if (!valid) continue;
                    const shift: u6 = @intCast(u6, code);
                    ticket_mask |= @as(u64, 1) << shift;
                }
                // std.debug.warn("TICKET {} MASK {b}\n", .{ pt, ticket_mask });
                field_mask &= ticket_mask;
            }
            // std.debug.warn("FIELD {} MASK {b}\n", .{ pf, field_mask });
            self.guessed.append(Guess.init(field_mask)) catch unreachable;
        }

        var found: usize = 0;
        while (found < NF) {
            var count: usize = 0;
            var pg: usize = 0;
            while (pg < self.guessed.items.len) : (pg += 1) {
                var guess = &self.guessed.items[pg];
                if (guess.*.code != std.math.maxInt(usize)) continue;
                const mask = guess.*.mask;
                if (mask == 0) @panic("MASK");
                if (@popCount(usize, mask) != 1) continue;
                const code = @ctz(usize, mask);
                const name = self.fields.get_str(code);
                // std.debug.warn("FIELD {} IS {b} {} {}\n", .{ pg, mask, code, name });
                guess.*.code = code;
                count += 1;
                var po: usize = 0;
                while (po < self.guessed.items.len) : (po += 1) {
                    if (po == pg) continue;
                    var other = &self.guessed.items[po];
                    if (other.*.code != std.math.maxInt(usize)) continue;
                    const old = other.*.mask;
                    other.*.mask &= ~mask;
                    // std.debug.warn("RESET FIELD {} {b} -> {b}\n", .{ po, old, other.*.mask });
                }
            }
            if (count <= 0) break;
            found += count;
        }
    }
};

test "sample part a" {
    const data: []const u8 =
        \\class: 1-3 or 5-7
        \\row: 6-11 or 33-44
        \\seat: 13-40 or 45-50
        \\
        \\your ticket:
        \\7,1,14
        \\
        \\nearby tickets:
        \\7,3,47
        \\40,4,50
        \\55,2,20
        \\38,6,12
    ;

    var db = DB.init();
    defer db.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        db.add_line(line);
    }
    const tser = db.ticket_scanning_error_rate();
    testing.expect(tser == 71);
}

test "sample part b" {
    const data: []const u8 =
        \\class: 0-1 or 4-19
        \\flight row: 0-5 or 8-19
        \\flight seat: 0-13 or 16-19
        \\
        \\your ticket:
        \\11,12,13
        \\
        \\nearby tickets:
        \\3,9,18
        \\15,1,5
        \\5,14,9
    ;

    var db = DB.init();
    defer db.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        db.add_line(line);
    }
    const product = db.multiply_fields("flight");
    testing.expect(product == 143);
}
