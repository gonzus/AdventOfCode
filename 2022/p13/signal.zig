const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

const Tag = enum {
    Number,
    Multi,
};

const Node = union(Tag) {
    Number: usize,
    Multi: *List,

    pub fn create_number(allocator: Allocator, number: usize) !*Node {
        const node = try allocator.create(Node);
        node.* = Node{.Number = number};
        return node;
    }

    pub fn create_multi(allocator: Allocator) !*Node {
        const list = try allocator.create(List);
        list.* = List.init(allocator);
        const node = try allocator.create(Node);
        node.* = Node{.Multi = list};
        return node;
    }

    fn show_node(node: *Node) void {
        switch (node.*) {
            .Number => |n| std.debug.print(" {}", .{n}),
            .Multi => |l| {
                std.debug.print(" [", .{});
                for (l.*.nodes.items) |n| {
                    show_node(n);
                }
                std.debug.print(" ]", .{});
            },
        }
    }

    pub fn show(node: *Node) void {
        show_node(node);
    }

    pub fn destroy(node: *Node, allocator: Allocator)  void {
        switch (node.*) {
            .Number => {},
            .Multi => |l| {
                l.deinit();
                allocator.destroy(l);
            },
        }
        allocator.destroy(node);
    }

    pub fn maybe_parse_list(allocator: Allocator, line: []const u8, pos: *usize) !?*Node {
        if (line[pos.*] != '[') {
            return null;
        }
        pos.* += 1;
        const node = try Node.create_multi(allocator);
        while (true) {
            const c = line[pos.*];
            if (c == ']') {
                pos.* += 1;
                break; // list is finished
            }
            if (c == ',') {
                pos.* += 1;
                continue; // another member of the list
            }
            const maybe_list = try maybe_parse_list(allocator, line, pos);
            if (maybe_list) |n| {
                try node.*.Multi.*.nodes.append(n);
                continue;
            }
            const maybe_num = try maybe_parse_num(allocator, line, pos);
            if (maybe_num) |n| {
                try node.*.Multi.*.nodes.append(n);
                continue;
            }
        }
        return node;
    }

    pub fn maybe_parse_num(allocator: Allocator, line: []const u8, pos: *usize) !?*Node {
        var digits: usize = 0;
        var n: usize = 0;
        while (true) {
            const c = line[pos.*];
            if (c < '0' or c > '9') break;
            digits += 1;
            n *= 10;
            n += c - '0';
            pos.* += 1;
        }
        if (digits <= 0) return null;
        return try Node.create_number(allocator, n);
    }

    fn compare_number(ln: usize, rn: usize) !i8 {
        if (ln > rn) return 1;
        if (ln < rn) return -1;
        return 0;
    }

    pub fn compare_multi(allocator: Allocator, l: *List, r: *List) !i8 {
        var pl: usize = 0;
        var pr: usize = 0;
        while (true) {
            if (pl >= l.*.nodes.items.len and pr >= r.*.nodes.items.len) {
                return 0;
            }
            if (pl >= l.*.nodes.items.len) {
                return -1;
            }
            if (pr >= r.*.nodes.items.len) {
                return 1;
            }
            const nl = l.*.nodes.items[pl];
            const nr = r.*.nodes.items[pr];
            pl += 1;
            pr += 1;
            const cmp = try compare_node(allocator, nl, nr);
            if (cmp != 0) return cmp;
        }
        return 0;
    }

    pub fn compare_node(allocator: Allocator, l: *Node, r: *Node) !i8 {
        switch (l.*) {
            .Number => |ln| switch (r.*) {
                .Number => |rn| return Node.compare_number(ln, rn),
                .Multi => |rm| {
                    const tmp = try Node.create_multi(allocator);
                    try tmp.*.Multi.nodes.append(try Node.create_number(allocator, ln));
                    const ret = Node.compare_multi(allocator, tmp.Multi, rm);
                    tmp.destroy(allocator);
                    return ret;
                },
            },
            .Multi => |lm| switch (r.*) {
                .Number => |rn| {
                    const tmp = try Node.create_multi(allocator);
                    try tmp.*.Multi.nodes.append(try Node.create_number(allocator, rn));
                    const ret = Node.compare_multi(allocator, lm, tmp.Multi);
                    tmp.destroy(allocator);
                    return ret;
                },
                .Multi => |rm| return Node.compare_multi(allocator, lm, rm),
            },
        }
    }
};

pub const List = struct {
    allocator: Allocator,
    nodes: std.ArrayList(*Node),

    pub fn init(allocator: Allocator) List {
        const self = List{
            .allocator = allocator,
            .nodes = std.ArrayList(*Node).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *List) void {
        for (self.nodes.items) |node| {
            node.destroy(self.allocator);
        }
        self.nodes.deinit();
    }
};

pub const Signal = struct {
    allocator: Allocator,
    nodes: std.ArrayList(*Node),
    pos: usize,
    pairs: usize,
    count_ok: usize,

    pub fn init(allocator: Allocator) !Signal {
        const self = Signal{
            .allocator = allocator,
            .nodes = std.ArrayList(*Node).init(allocator),
            .pos = 0,
            .pairs = 0,
            .count_ok = 0,
        };
        return self;
    }

    pub fn deinit(self: *Signal) void {
        for (self.nodes.items) |*node| {
            node.*.destroy(self.allocator);
        }
        self.nodes.deinit();
    }

    pub fn add_line(self: *Signal, line: []const u8) !void {
        if (line.len == 0) {
            self.pos = 0;
            return;
        }
        var pos: usize = 0;
        const maybe_list = try Node.maybe_parse_list(self.allocator, line, &pos);
        try self.nodes.append(maybe_list.?);
        self.pos += 1;
        if (self.pos != 2) return;

        self.pairs += 1;
        const nodes = self.nodes.items;
        const n0 = nodes[nodes.len-2];
        const n1 = nodes[nodes.len-1];
        const cmp = try Node.compare_node(self.allocator, n0, n1);
        if (cmp >= 0) return;

        self.count_ok += self.pairs;
    }

    pub fn sum_indices_in_right_order(self: Signal) usize {
        return self.count_ok;
    }

    fn node_greater_than(self: *Signal, a: *Node, b: *Node) bool {
        const cmp = Node.compare_node(self.allocator, a, b) catch 0;
        return cmp < 0;
    }

    pub fn get_decoder_key(self: *Signal) !usize {
        const labels = [2][]const u8 { "[[2]]", "[[6]]" };
        var markers = [_]*Node{undefined} ** 2;
        for (labels) |label, j| {
            var pos: usize = 0;
            const n = try Node.maybe_parse_list(self.allocator, label, &pos);
            try self.nodes.append(n.?);
            markers[j] = n.?;
        }

        std.sort.sort(*Node, self.nodes.items, self, node_greater_than);

        var decoder_key: usize = 1;
        for (self.nodes.items) |node, j| {
            for (markers) |marker| {
                const cmp = try Node.compare_node(self.allocator, node, marker);
                if (cmp != 0) continue;
                decoder_key *= j+1;
            }
        }

        return decoder_key;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\[1,1,3,1,1]
        \\[1,1,5,1,1]
        \\
        \\[[1],[2,3,4]]
        \\[[1],4]
        \\
        \\[9]
        \\[[8,7,6]]
        \\
        \\[[4,4],4,4]
        \\[[4,4],4,4,4]
        \\
        \\[7,7,7,7]
        \\[7,7,7]
        \\
        \\[]
        \\[3]
        \\
        \\[[[]]]
        \\[[]]
        \\
        \\[1,[2,[3,[4,[5,6,7]]]],8,9]
        \\[1,[2,[3,[4,[5,6,0]]]],8,9]
    ;

    var signal = try Signal.init(std.testing.allocator);
    defer signal.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try signal.add_line(line);
    }

    // signal.show();

    const sum_right_order = signal.sum_indices_in_right_order();
    try testing.expectEqual(@as(usize, 13), sum_right_order);
}

test "sample part 2" {
    const data: []const u8 =
        \\[1,1,3,1,1]
        \\[1,1,5,1,1]
        \\
        \\[[1],[2,3,4]]
        \\[[1],4]
        \\
        \\[9]
        \\[[8,7,6]]
        \\
        \\[[4,4],4,4]
        \\[[4,4],4,4,4]
        \\
        \\[7,7,7,7]
        \\[7,7,7]
        \\
        \\[]
        \\[3]
        \\
        \\[[[]]]
        \\[[]]
        \\
        \\[1,[2,[3,[4,[5,6,7]]]],8,9]
        \\[1,[2,[3,[4,[5,6,0]]]],8,9]
    ;

    var signal = try Signal.init(std.testing.allocator);
    defer signal.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try signal.add_line(line);
    }

    // signal.show();

    const decoder_key = try signal.get_decoder_key();
    try testing.expectEqual(@as(usize, 140), decoder_key);
}
