const std = @import("std");
const testing = std.testing;
const StringTable = @import("./strtab.zig").StringTable;

const allocator = std.heap.page_allocator;

pub const Luggage = struct {
    const Bag = struct {
        code: usize,
        children: std.AutoHashMap(usize, usize),
        parents: std.AutoHashMap(usize, void),
        pub fn init(code: usize) *Bag {
            var self = allocator.create(Bag) catch unreachable;
            self.* = Bag{
                .code = code,
                .children = std.AutoHashMap(usize, usize).init(allocator),
                .parents = std.AutoHashMap(usize, void).init(allocator),
            };
            return self;
        }
    };

    colors: StringTable,
    bags: std.AutoHashMap(usize, *Bag),

    pub fn init() Luggage {
        var self = Luggage{
            .colors = StringTable.init(allocator),
            .bags = std.AutoHashMap(usize, *Bag).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Luggage) void {
        self.bags.deinit();
        self.colors.deinit();
    }

    pub fn add_rule(self: *Luggage, line: []const u8) void {
        var pos: usize = 0;
        var tone: []const u8 = undefined;
        var count: usize = 0;
        var buf: [100]u8 = undefined;
        var parent: *Bag = undefined;
        var it = std.mem.tokenize(line, " .,");
        while (it.next()) |str| {
            pos += 1;
            if (pos == 1) {
                tone = str;
                continue;
            }
            if (pos == 2) {
                const color = std.fmt.bufPrint(buf[0..], "{s} {s}", .{ tone, str }) catch unreachable;
                const code = self.colors.add(color);
                // std.debug.warn("PCOLOR [{}] => {}\n", .{ color, code });
                parent = Bag.init(code);
                _ = self.bags.put(code, parent) catch unreachable;
                continue;
            }
            if (pos < 5) {
                continue;
            }
            var cpos: usize = (pos - 5) % 4;
            if (cpos == 0) {
                count = std.fmt.parseInt(usize, str, 10) catch 0;
                if (count <= 0) {
                    break;
                }
                // std.debug.warn("COUNT {}\n", .{count});
                continue;
            }
            if (cpos == 1) {
                tone = str;
                continue;
            }
            if (cpos == 2) {
                const color = std.fmt.bufPrint(buf[0..], "{s} {s}", .{ tone, str }) catch unreachable;
                const code = self.colors.add(color);
                // std.debug.warn("CCOLOR [{}] => {}\n", .{ color, code });
                _ = parent.children.put(code, count) catch unreachable;
                continue;
            }
        }
    }

    pub fn compute_parents(self: *Luggage) void {
        var itp = self.bags.iterator();
        while (itp.next()) |kvp| {
            const parent = kvp.value.*;
            var itc = parent.children.iterator();
            while (itc.next()) |kvc| {
                var child = self.bags.get(kvc.key).?;
                _ = child.parents.put(parent.code, {}) catch unreachable;
            }
        }
    }

    pub fn sum_can_contain(self: *Luggage, color: []const u8) usize {
        const code = self.colors.get_pos(color).?;
        var seen = std.AutoHashMap(usize, void).init(allocator);
        defer seen.deinit();
        return self.sum_can_contain_by_code(code, &seen) - 1;
    }

    fn sum_can_contain_by_code(self: *Luggage, code: usize, seen: *std.AutoHashMap(usize, void)) usize {
        if (seen.contains(code)) {
            return 0;
        }
        _ = seen.put(code, {}) catch unreachable;

        var count: usize = 1;
        const bag = self.bags.get(code).?;
        var it = bag.parents.iterator();
        while (it.next()) |kv| {
            const parent = kv.key;
            count += self.sum_can_contain_by_code(parent, seen);
        }
        return count;
    }

    pub fn count_contained_bags(self: *Luggage, color: []const u8) usize {
        const code = self.colors.get_pos(color).?;
        return self.count_contained_bags_by_code(code) - 1;
    }

    fn count_contained_bags_by_code(self: *Luggage, code: usize) usize {
        var count: usize = 1;
        const bag = self.bags.get(code).?;
        var it = bag.children.iterator();
        while (it.next()) |kv| {
            const child = kv.key;
            count += kv.value * self.count_contained_bags_by_code(child);
        }
        return count;
    }

    pub fn show(self: Luggage) void {
        std.debug.warn("Luggage with {} bags\n", .{self.bags.count()});
        var itp = self.bags.iterator();
        while (itp.next()) |kvp| {
            const bag: Bag = kvp.value.*;
            std.debug.warn(" [{}]\n", .{self.colors.get_str(bag.code).?});
            var itc = bag.children.iterator();
            while (itc.next()) |kvc| {
                std.debug.warn("   can contain {} [{}]\n", .{ kvc.value, self.colors.get_str(kvc.key).? });
            }
        }
    }
};

test "sample parents" {
    const data: []const u8 =
        \\light red bags contain 1 bright white bag, 2 muted yellow bags.
        \\dark orange bags contain 3 bright white bags, 4 muted yellow bags.
        \\bright white bags contain 1 shiny gold bag.
        \\muted yellow bags contain 2 shiny gold bags, 9 faded blue bags.
        \\shiny gold bags contain 1 dark olive bag, 2 vibrant plum bags.
        \\dark olive bags contain 3 faded blue bags, 4 dotted black bags.
        \\vibrant plum bags contain 5 faded blue bags, 6 dotted black bags.
        \\faded blue bags contain no other bags.
        \\dotted black bags contain no other bags.
    ;

    var luggage = Luggage.init();
    defer luggage.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        luggage.add_rule(line);
    }
    // luggage.show();
    luggage.compute_parents();

    const containers = luggage.sum_can_contain("shiny gold");
    testing.expect(containers == 4);
}

test "sample children 1" {
    const data: []const u8 =
        \\light red bags contain 1 bright white bag, 2 muted yellow bags.
        \\dark orange bags contain 3 bright white bags, 4 muted yellow bags.
        \\bright white bags contain 1 shiny gold bag.
        \\muted yellow bags contain 2 shiny gold bags, 9 faded blue bags.
        \\shiny gold bags contain 1 dark olive bag, 2 vibrant plum bags.
        \\dark olive bags contain 3 faded blue bags, 4 dotted black bags.
        \\vibrant plum bags contain 5 faded blue bags, 6 dotted black bags.
        \\faded blue bags contain no other bags.
        \\dotted black bags contain no other bags.
    ;

    var luggage = Luggage.init();
    defer luggage.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        luggage.add_rule(line);
    }
    // luggage.show();

    const contained = luggage.count_contained_bags("shiny gold");
    testing.expect(contained == 32);
}

test "sample children 2" {
    const data: []const u8 =
        \\shiny gold bags contain 2 dark red bags.
        \\dark red bags contain 2 dark orange bags.
        \\dark orange bags contain 2 dark yellow bags.
        \\dark yellow bags contain 2 dark green bags.
        \\dark green bags contain 2 dark blue bags.
        \\dark blue bags contain 2 dark violet bags.
        \\dark violet bags contain no other bags.
    ;

    var luggage = Luggage.init();
    defer luggage.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        luggage.add_rule(line);
    }
    // luggage.show();

    const contained = luggage.count_contained_bags("shiny gold");
    testing.expect(contained == 126);
}
