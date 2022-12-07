const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const StringTable = @import("./util/strtab.zig").StringTable;

const NodeType = enum {
    Dir,
    File,
};

pub const Node = struct {
    allocator: Allocator,
    name: usize,
    typ: NodeType,
    size: usize,
    parent: ?*Node,
    children: std.AutoHashMap(usize, *Node),

    pub fn init(allocator: Allocator, name: usize, typ: NodeType, parent: ?*Node, size: usize) !*Node {
        var self = try allocator.create(Node);
        self.allocator = allocator;
        self.name = name;
        self.typ = typ;
        self.size = size;
        self.parent = parent;
        self.children = std.AutoHashMap(usize, *Node).init(allocator);
        return self;
    }

    pub fn deinit(self: *Node) void {
        var it = self.children.iterator();
        while (it.next()) |entry| {
            const node = entry.value_ptr.*;
            node.deinit();
        }
        self.children.deinit();
        self.allocator.destroy(self);
    }

    fn add_dirs_at_most(node: *Node, at_most: usize, total: *usize) usize {
        var current: usize = 0;
        var it = node.children.iterator();
        while (it.next()) |entry| {
            const n = entry.value_ptr.*;
            if (n.typ == .File) {
                current += n.size;
                continue;
            }
            current += n.add_dirs_at_most(at_most, total);
        }
        if (current <= at_most) {
            total.* += current;
        }
        return current;
    }

    fn find_smallest_dir_at_least(node: *Node, at_least: usize, best: *usize) usize {
        var current: usize = 0;
        var it = node.children.iterator();
        while (it.next()) |entry| {
            const n = entry.value_ptr.*;
            if (n.typ == .File) {
                current += n.size;
                continue;
            }
            current += n.find_smallest_dir_at_least(at_least, best);
        }
        if (current >= at_least and best.* > current) {
            best.* = current;
        }
        return current;
    }

    fn compute_dir_size(node: *Node) usize {
        var current: usize = 0;
        var it = node.children.iterator();
        while (it.next()) |entry| {
            const n = entry.value_ptr.*;
            if (n.typ == .File) {
                current += n.size;
                continue;
            }
            current += n.compute_dir_size();
        }
        return current;
    }
};

pub const Tree = struct {
    allocator: Allocator,
    strings: StringTable,
    root: ?*Node,
    current: ?*Node,
    pending: std.ArrayList(*Node),

    pub fn init(allocator: Allocator) Tree {
        var self = Tree{
            .allocator = allocator,
            .strings = StringTable.init(allocator),
            .root = null,
            .current = null,
            .pending = std.ArrayList(*Node).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Tree) void {
        self.pending.deinit();
        if (self.root) |r| {
            r.deinit();
        }
        self.strings.deinit();
    }

    pub fn add_line(self: *Tree, line: []const u8) !void {
        if (line[0] == '$') {
            var it = std.mem.tokenize(u8, line, " ");
            _ = it.next(); // $
            const cmd = it.next().?;
            if (std.mem.eql(u8, cmd, "cd")) {
                const dir = it.next().?;
                // std.debug.print("CD [{s}]\n", .{dir});
                if (std.mem.eql(u8, dir, "..")) {
                    self.current = self.current.?.parent;
                } else if (std.mem.eql(u8, dir, "/")) {
                    // We create the root node here, because this happens at the beginning, only once.
                    const name = self.strings.add(dir);
                    self.root = try Node.init(self.allocator, name, .Dir, null, 0);
                    self.current = self.root;
                } else {
                    const pos = self.strings.get_pos(dir).?;
                    self.current = self.current.?.children.get(pos);
                }
            } else if (std.mem.eql(u8, cmd, "ls")) {
                // std.debug.print("LS\n", .{});
            } else {
                unreachable;
            }
        } else {
            var it = std.mem.tokenize(u8, line, " ");
            const what = it.next().?;
            const str = it.next().?;
            var typ: NodeType = .Dir;
            var size: usize = 0;
            if (!std.mem.eql(u8, what, "dir")) {
                typ = .File;
                size = try std.fmt.parseInt(usize, what, 10);
            }
            const name = self.strings.add(str);
            var node = try Node.init(self.allocator, name, typ, self.current, size);
            try self.current.?.children.put(name, node);
            // std.debug.print("ENTRY [{s}] {}\n", .{str, size});
        }
    }

    pub fn add_dirs_at_most(self: Tree, at_most: usize) usize {
        var total: usize = 0;
        if (self.root) |r| {
            _ = r.add_dirs_at_most(at_most, &total);
        }
        return total;
    }

    pub fn smallest_dir_to_achieve(self: Tree, total: usize, needed: usize) usize {
        var size: usize = 0;
        if (self.root) |r| {
            var used = r.compute_dir_size();
            var left = total - used;
            var extra = needed - left;
            // std.debug.print("USED: {}, LEFT: {}, EXTRA: {}\n", .{used, left, extra});
            var best: usize = std.math.maxInt(usize);
            _ = r.find_smallest_dir_at_least(extra, &best);
            // std.debug.print("FOUND {}\n", .{best});
            size = best;
        }
        return size;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\$ cd /
        \\$ ls
        \\dir a
        \\14848514 b.txt
        \\8504156 c.dat
        \\dir d
        \\$ cd a
        \\$ ls
        \\dir e
        \\29116 f
        \\2557 g
        \\62596 h.lst
        \\$ cd e
        \\$ ls
        \\584 i
        \\$ cd ..
        \\$ cd ..
        \\$ cd d
        \\$ ls
        \\4060174 j
        \\8033020 d.log
        \\5626152 d.ext
        \\7214296 k
    ;

    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try tree.add_line(line);
    }

    const size = tree.add_dirs_at_most(100_000);
    try testing.expect(size == 95437);
}

test "sample part 2" {
    const data: []const u8 =
        \\$ cd /
        \\$ ls
        \\dir a
        \\14848514 b.txt
        \\8504156 c.dat
        \\dir d
        \\$ cd a
        \\$ ls
        \\dir e
        \\29116 f
        \\2557 g
        \\62596 h.lst
        \\$ cd e
        \\$ ls
        \\584 i
        \\$ cd ..
        \\$ cd ..
        \\$ cd d
        \\$ ls
        \\4060174 j
        \\8033020 d.log
        \\5626152 d.ext
        \\7214296 k
    ;

    var tree = Tree.init(std.testing.allocator);
    defer tree.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try tree.add_line(line);
    }

    const size = tree.smallest_dir_to_achieve(70_000_000, 30_000_000);
    try testing.expect(size == 24933642);
}
