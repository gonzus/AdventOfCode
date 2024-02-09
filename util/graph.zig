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
