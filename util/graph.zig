const std = @import("std");
const testing = std.testing;
const StringTable = @import("strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub fn DirectedGraph(comptime E: type) type {
    const StringId = StringTable.StringId;

    const Handler = fn (context: anytype, dist: E) void;

    return struct {
        const Self = @This();

        const Node = struct {
            name: StringId,
            neighbors: std.AutoHashMap(StringId, E),

            pub fn init(allocator: Allocator, name: StringId) Node {
                return Node{
                    .name = name,
                    .neighbors = std.AutoHashMap(StringId, E).init(allocator),
                };
            }

            pub fn deinit(self: *Node) void {
                self.neighbors.deinit();
            }
        };

        allocator: Allocator,
        strtab: StringTable,
        nodes: std.AutoHashMap(StringId, Node),
        visited: std.AutoHashMap(StringId, void),

        pub fn init(allocator: Allocator) Self {
            const self = Self{
                .allocator = allocator,
                .strtab = StringTable.init(allocator),
                .nodes = std.AutoHashMap(StringId, Node).init(allocator),
                .visited = std.AutoHashMap(StringId, void).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.visited.deinit();
            var it = self.nodes.valueIterator();
            while (it.next()) |*node| {
                node.*.deinit();
            }
            self.nodes.deinit();
            self.strtab.deinit();
        }

        pub fn show(self: Self) void {
            std.debug.print("Graph with {} nodes\n", .{self.nodes.count()});
            var it = self.nodes.valueIterator();
            while (it.next()) |node| {
                std.debug.print("  {s} =>", .{
                    self.strtab.get_str(node.name) orelse "***",
                });
                var it_neighbor = node.neighbors.iterator();
                while (it_neighbor.next()) |entry| {
                    std.debug.print(" {s}:{d}", .{
                        self.strtab.get_str(entry.key_ptr.*) orelse "***",
                        entry.value_ptr.*,
                    });
                }
                std.debug.print("\n", .{});
            }
        }

        pub fn addNode(self: *Self, name: []const u8) !*Node {
            const id = try self.strtab.add(name);
            const r = try self.nodes.getOrPut(id);
            if (!r.found_existing) {
                r.value_ptr.* = Node.init(self.allocator, id);
            }
            return r.value_ptr;
        }

        pub fn joinNodes(self: *Self, src: []const u8, tgt: []const u8, dist: E) !void {
            const s = try self.addNode(src);
            const t = try self.addNode(tgt);

            const rs = try s.*.neighbors.getOrPut(t.name);
            rs.value_ptr.* = dist;

            const rt = try t.*.neighbors.getOrPut(s.name);
            rt.value_ptr.* = dist;
        }

        pub fn reset(self: *Self) void {
            self.visited.clearRetainingCapacity();
        }

        pub fn clear(self: *Self) void {
            self.reset();
            self.nodes.clearRetainingCapacity();
            self.strtab.clear();
        }

        pub fn findBestWalk(self: *Self, start: StringId, dist: E, comptime handler: Handler, context: anytype) !void {
            try self.visited.put(start, {});
            defer _ = self.visited.remove(start);

            if (self.visited.count() == self.nodes.count()) {
                handler(context, dist);
                return;
            }

            const node_maybe = self.nodes.get(start);
            if (node_maybe) |node| {
                var it = node.neighbors.iterator();
                while (it.next()) |neighbor| {
                    const tgt = neighbor.key_ptr.*;
                    if (self.visited.contains(tgt)) continue;
                    try self.findBestWalk(tgt, dist + neighbor.value_ptr.*, handler, context);
                }
            } else {
                return error.InvalidNode;
            }
        }
    };
}

pub fn FloodFill(comptime Context: type, comptime Node: type) type {
    return struct {
        const Self = @This();

        const NodeDist = struct {
            node: Node,
            dist: usize,

            fn init(node: Node, dist: usize) NodeDist {
                return NodeDist{ .node = node, .dist = dist };
            }

            fn lessThan(_: void, l: NodeDist, r: NodeDist) std.math.Order {
                return std.math.order(l.dist, r.dist);
            }
        };
        const PQ = std.PriorityQueue(NodeDist, void, NodeDist.lessThan);

        allocator: Allocator,
        context: *Context,
        pending: PQ,
        seen: std.AutoHashMap(Node, void),

        pub fn init(allocator: Allocator, context: *Context) Self {
            const self = Self{
                .allocator = allocator,
                .context = context,
                .pending = PQ.init(allocator, {}),
                .seen = std.AutoHashMap(Node, void).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.seen.deinit();
            self.pending.deinit();
        }

        pub const Action = enum { visit, skip, abort };

        pub fn run(self: *Self, start: Node) !void {
            self.seen.clearRetainingCapacity();
            try self.pending.add(NodeDist.init(start, 0));
            PENDING: while (self.pending.count() != 0) {
                const nd = self.pending.remove();
                const action: Action = try self.context.visit(nd.node, nd.dist, self.seen.count());
                switch (action) {
                    .visit => {},
                    .skip => continue :PENDING,
                    .abort => break :PENDING,
                }

                const neighbors = self.context.neighbors(nd.node);
                for (neighbors) |n| {
                    const r = try self.seen.getOrPut(n);
                    if (r.found_existing) continue;
                    try self.pending.add(NodeDist.init(n, nd.dist + 1));
                }
            }
        }
    };
}
