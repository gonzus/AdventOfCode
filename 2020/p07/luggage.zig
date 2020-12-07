const std = @import("std");
const testing = std.testing;

pub const Luggage = struct {
    const StrList = struct {
        strs: [50][20]u8,
        count: usize,
        pub fn init() StrList {
            var self = StrList{
                .strs = undefined,
                .count = 0,
            };
            self.append("*NOT*USED*");
            return self;
        }
        pub fn deinit(self: StrList) void {}
        pub fn append(self: *StrList, str: []const u8) void {
            if (self.count >= 50) {
                @panic("self.count 50");
            }
            std.mem.copy(u8, self.strs[self.count][0..str.len], str);
            self.count += 1;
        }
        pub fn find(self: StrList, str: []const u8) usize {
            var p: usize = 0;
            while (p < self.count) : (p += 1) {
                if (std.mem.eql(u8, self.strs[p][0..str.len], str)) {
                    return p;
                }
            }
            return 0;
        }
        pub fn get(self: StrList, pos: usize) []const u8 {
            if (pos >= self.count) {
                return "*NOT*FOUND*";
            }
            return self.strs[pos][0..];
        }
    };

    const Data = struct {
        code: usize,
        count: usize,
    };

    const Bag = struct {
        pos: usize,
        cdata: [50]Data,
        ccount: usize,
        parents: [50]usize,
        pcount: usize,
        pub fn reset(self: *Bag, pos: usize) void {
            self.pos = pos;
            self.ccount = 0;
            self.pcount = 0;
        }
        pub fn add_parent(self: *Bag, parent: usize) void {
            var p: usize = 0;
            while (p < self.pcount) : (p += 1) {
                if (self.parents[p] == parent) {
                    return;
                }
            }
            self.*.parents[self.pcount] = parent;
            self.*.pcount += 1;
        }
    };

    color_tone: StrList,
    color_name: StrList,
    bags: [1000]Bag,
    count: usize,

    pub fn init() Luggage {
        var self = Luggage{
            .color_tone = StrList.init(),
            .color_name = StrList.init(),
            .bags = undefined,
            .count = 0,
        };
        return self;
    }

    pub fn deinit(self: *Luggage) void {
        self.color_name.deinit();
        self.color_tone.deinit();
    }

    pub fn add_rule(self: *Luggage, line: []const u8) void {
        // std.debug.warn("LINE [{}]\n", .{line});
        var pos: usize = 0;
        var tone: []const u8 = undefined;
        var cnt: usize = 0;
        var parent: *Bag = undefined;
        var it = std.mem.tokenize(line, " .,");
        while (it.next()) |str| {
            pos += 1;
            // std.debug.warn("FLD {}: [{}]\n", .{ pos, str });
            if (pos == 1) {
                // std.debug.warn("PTONE {}\n", .{str});
                tone = str;
                self.maybe_add(&self.color_tone, str);
                continue;
            }
            if (pos == 2) {
                // std.debug.warn("PNAME {}\n", .{str});
                self.maybe_add(&self.color_name, str);
                const code = self.color_code(tone, str);
                parent = &self.bags[self.count];
                parent.reset(code);
                self.count += 1;
                continue;
            }
            if (pos < 5) {
                continue;
            }
            var cpos: usize = (pos - 5) % 4;
            if (cpos == 0) {
                cnt = std.fmt.parseInt(usize, str, 10) catch 0;
                if (cnt <= 0) {
                    break;
                }
                // std.debug.warn("CNT {}\n", .{cnt});
                continue;
            }
            if (cpos == 1) {
                // std.debug.warn("CTONE {}\n", .{str});
                tone = str;
                self.maybe_add(&self.color_tone, str);
                continue;
            }
            if (cpos == 2) {
                // std.debug.warn("CNAME {}\n", .{str});
                self.maybe_add(&self.color_name, str);

                const code = self.color_code(tone, str);
                if (parent.ccount >= 50) {
                    @panic("parent.count 50");
                }
                // parent.children[parent.ccount].code = code;
                // parent.children[parent.ccount].count = 0;
                parent.cdata[parent.ccount].code = code;
                parent.cdata[parent.ccount].count = cnt;
                parent.ccount += 1;
                continue;
            }
        }
    }

    pub fn find_bag(self: *Luggage, code: usize) ?*Bag {
        var p: usize = 0;
        while (p < self.count) : (p += 1) {
            var bag: *Bag = &self.bags[p];
            if (bag.pos == code) {
                // std.debug.warn("FOUND BAG {} = {}\n", .{ code, @ptrToInt(bag) });
                return bag;
            }
        }
        return null;
    }

    pub fn compute_parents(self: *Luggage) void {
        var p: usize = 0;
        while (p < self.count) : (p += 1) {
            var parent = self.bags[p];
            var c: usize = 0;
            while (c < parent.ccount) : (c += 1) {
                var bag = self.find_bag(parent.cdata[c].code).?;
                bag.add_parent(parent.pos);
            }
        }
    }

    pub fn sum_can_contain(self: *Luggage, tone: []const u8, name: []const u8) usize {
        // std.debug.warn("** TONES {} NAMES {} BAGS {}\n", .{ self.color_tone.count, self.color_name.count, self.count });
        var count: usize = 0;
        const code = self.color_code(tone, name);
        const allocator = std.heap.page_allocator;
        var seen = std.AutoHashMap(usize, void).init(allocator);
        defer seen.deinit();
        return self.sum_can_contain_by_code(code, &seen) - 1;
    }

    pub fn count_contained_bags(self: *Luggage, tone: []const u8, name: []const u8) usize {
        // std.debug.warn("** TONES {} NAMES {} BAGS {}\n", .{ self.color_tone.count, self.color_name.count, self.count });
        const code = self.color_code(tone, name);
        return self.count_contained_bags_by_code(code) - 1;
    }

    fn sum_can_contain_by_code(self: *Luggage, code: usize, seen: *std.AutoHashMap(usize, void)) usize {
        if (seen.contains(code)) {
            return 0;
        }
        _ = seen.put(code, {}) catch unreachable;
        // std.debug.warn("CAN {} {}\n", .{ self.get_tone(code), self.get_name(code) });
        var count: usize = 0;
        var bag = self.find_bag(code).?;
        var posp: usize = 0;
        while (posp < bag.pcount) : (posp += 1) {
            count += self.sum_can_contain_by_code(bag.parents[posp], seen);
        }
        count += 1;
        return count;
    }

    fn count_contained_bags_by_code(self: *Luggage, code: usize) usize {
        // std.debug.warn("SUM {} {}\n", .{ self.get_tone(code), self.get_name(code) });
        var count: usize = 0;
        var bag = self.find_bag(code).?;
        var posc: usize = 0;
        while (posc < bag.ccount) : (posc += 1) {
            const child = self.count_contained_bags_by_code(bag.cdata[posc].code);
            count += bag.cdata[posc].count * child;
        }
        return count + 1;
    }

    fn maybe_add(self: Luggage, list: *StrList, str: []const u8) void {
        const pos = list.find(str);
        if (pos > 0) {
            return;
        }
        list.append(str);
    }

    fn color_code(self: Luggage, tone: []const u8, name: []const u8) usize {
        const ptone = self.color_tone.find(tone);
        if (ptone <= 0) {
            std.debug.warn("CANNOT FIND TONE {}\n", .{tone});
            @panic("TONE");
        }
        const pname = self.color_name.find(name);
        if (pname <= 0) {
            std.debug.warn("CANNOT FIND NAME {}\n", .{name});
            @panic("NAME");
        }
        return ptone * 100 + pname;
    }

    fn get_tone(self: Luggage, code: usize) []const u8 {
        const ptone = code / 100;
        const tone = self.color_tone.get(ptone);
        if (tone.len <= 0) {
            @panic("TONE");
        }
        return tone;
    }

    fn get_name(self: Luggage, code: usize) []const u8 {
        const pname = code % 100;
        const name = self.color_name.get(pname);
        if (name.len <= 0) {
            @panic("NAME");
        }
        return name;
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
    luggage.compute_parents();
    // luggage.show();

    const containers = luggage.sum_can_contain("shiny", "gold");
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

    const contained = luggage.count_contained_bags("shiny", "gold");
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

    const contained = luggage.count_contained_bags("shiny", "gold");
    testing.expect(contained == 126);
}
