const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;

pub const License = struct {
    const NodeId = usize;
    const Metadata = u8;

    const Node = struct {
        children: std.ArrayList(NodeId),
        metadata: std.ArrayList(Metadata),

        pub fn init(allocator: Allocator) Node {
            return .{
                .children = std.ArrayList(NodeId).init(allocator),
                .metadata = std.ArrayList(Metadata).init(allocator),
            };
        }

        pub fn deinit(self: *Node) void {
            self.metadata.deinit();
            self.children.deinit();
        }
    };

    const Tree = struct {
        nodes: std.ArrayList(Node),
        root: NodeId,

        pub fn init(allocator: Allocator) Tree {
            return .{
                .nodes = std.ArrayList(Node).init(allocator),
                .root = undefined,
            };
        }

        pub fn deinit(self: *Tree) void {
            for (self.nodes.items) |*node| {
                node.*.deinit();
            }
            self.nodes.deinit();
        }
    };

    allocator: Allocator,
    numbers: std.ArrayList(u8),
    tree: Tree,

    pub fn init(allocator: Allocator) License {
        return .{
            .allocator = allocator,
            .numbers = std.ArrayList(u8).init(allocator),
            .tree = Tree.init(allocator),
        };
    }

    pub fn deinit(self: *License) void {
        self.numbers.deinit();
        self.tree.deinit();
    }

    pub fn addLine(self: *License, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |chunk| {
            const n = try std.fmt.parseUnsigned(u8, chunk, 10);
            try self.numbers.append(n);
        }
        _ = try self.parseNumbers(0, 0, null);
        self.numbers.clearAndFree();
    }

    pub fn show(self: License) void {
        std.debug.print("License with {} numbers\n", .{self.numbers.items.len});
        for (self.numbers.items) |number| {
            std.debug.print("{}\n", .{number});
        }
        std.debug.print("Tree with {} nodes, root at pos {}\n", .{ self.tree.nodes.items.len, self.tree.root });
        for (self.tree.nodes.items, 0..) |node, pos| {
            std.debug.print("Node {}: {} children, {} metadata\n", .{
                pos,
                node.children.items.len,
                node.metadata.items.len,
            });
            for (node.children.items) |c| {
                std.debug.print("  C {}\n", .{c});
            }
            for (node.metadata.items) |m| {
                std.debug.print("  M {}\n", .{m});
            }
        }
    }

    pub fn sumMetadata(self: License) usize {
        return self.sumNodeMetadata(self.tree.root);
    }

    pub fn rootValue(self: License) usize {
        return self.valueOfNode(self.tree.root);
    }

    fn parseNumbers(self: *License, level: usize, start: usize, parent: ?*Node) !usize {
        var pos: usize = start;
        const children = self.numbers.items[pos];
        pos += 1;
        const metadata = self.numbers.items[pos];
        pos += 1;
        var node = Node.init(self.allocator);
        for (0..children) |_| {
            pos = try self.parseNumbers(level + 1, pos, &node);
        }
        for (0..metadata) |_| {
            try node.metadata.append(self.numbers.items[pos]);
            pos += 1;
        }
        const index = self.tree.nodes.items.len;
        try self.tree.nodes.append(node);
        if (parent) |p| {
            try p.*.children.append(index);
        } else {
            self.tree.root = index;
        }
        return pos;
    }

    fn sumNodeMetadata(self: License, pos: usize) usize {
        var sum: usize = 0;
        const node = self.tree.nodes.items[pos];
        for (node.metadata.items) |m| {
            sum += m;
        }
        for (node.children.items) |c| {
            sum += self.sumNodeMetadata(c);
        }
        return sum;
    }

    fn valueOfNode(self: License, pos: usize) usize {
        var value: usize = 0;
        const node = self.tree.nodes.items[pos];
        if (node.children.items.len == 0) {
            for (node.metadata.items) |m| {
                value += m;
            }
        } else {
            for (node.metadata.items) |m| {
                if (m == 0) continue;
                const index = m - 1;
                if (index >= node.children.items.len) continue;
                value += self.valueOfNode(node.children.items[index]);
            }
        }
        return value;
    }
};

test "sample part 1" {
    const data =
        \\2 3 0 3 10 11 12 1 1 0 1 99 2 1 1 2
    ;

    var license = License.init(testing.allocator);
    defer license.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try license.addLine(line);
    }
    // license.show();

    const sum = license.sumMetadata();
    const expected = @as(usize, 138);
    try testing.expectEqual(expected, sum);
}

test "sample part 2" {
    const data =
        \\2 3 0 3 10 11 12 1 1 0 1 99 2 1 1 2
    ;

    var license = License.init(testing.allocator);
    defer license.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try license.addLine(line);
    }
    // license.show();

    const value = license.rootValue();
    const expected = @as(usize, 66);
    try testing.expectEqual(expected, value);
}
