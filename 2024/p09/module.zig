const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const FREE = std.math.maxInt(usize);

    const Free = struct {
        pos: usize,
        len: usize,

        pub fn init(pos: usize, len: usize) Free {
            return .{ .pos = pos, .len = len };
        }
    };

    whole: bool,
    map: std.ArrayList(u8),
    blocks: std.ArrayList(usize),
    free: std.ArrayList(Free),

    pub fn init(allocator: Allocator, whole: bool) Module {
        const self = Module{
            .whole = whole,
            .map = std.ArrayList(u8).init(allocator),
            .blocks = std.ArrayList(usize).init(allocator),
            .free = std.ArrayList(Free).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Module) void {
        self.free.deinit();
        self.blocks.deinit();
        self.map.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        try self.map.appendSlice(line);
    }

    pub fn show(self: *Module) void {
        std.debug.print("Disk with map length {}, compacting whole: {}\n", .{ self.map.items.len, self.whole });

        std.debug.print("MAP\n", .{});
        for (self.map.items) |m| {
            std.debug.print("{c}", .{m});
        }
        std.debug.print("\n", .{});

        std.debug.print("BLOCKS\n", .{});
        for (0..self.blocks.items.len) |p| {
            const b = self.blocks.items[p];
            if (b == FREE) {
                std.debug.print(".", .{});
            } else {
                std.debug.print("{}", .{b});
            }
        }
        std.debug.print("\n", .{});

        std.debug.print("FREE\n", .{});
        for (self.free.items) |f| {
            std.debug.print("  {}\n", .{f});
        }
    }

    fn computeMap(self: *Module) !void {
        self.blocks.clearRetainingCapacity();
        var id: usize = 0;
        var free = false;
        for (self.map.items) |i| {
            const len = i - '0';
            if (free) {
                const beg = self.blocks.items.len;
                try self.blocks.appendNTimes(FREE, len);
                try self.free.append(Free.init(beg, len));
            } else {
                try self.blocks.appendNTimes(id, len);
                id += 1;
            }
            free = !free;
        }
    }

    fn compactMapByBlocks(self: *Module) !void {
        var beg: usize = 0;
        var end: usize = self.blocks.items.len - 1;
        while (true) {
            while (beg <= end and self.blocks.items[beg] != FREE) : (beg += 1) {}
            if (beg > end) break;
            self.blocks.items[beg] = self.blocks.items[end];
            self.blocks.items[end] = FREE;
            beg += 1;
            end -= 1;
            while (end > 0 and self.blocks.items[end] == FREE) : (end -= 1) {}
            if (beg > end) break;
        }
    }

    fn compactMapByWholeFiles(self: *Module) !void {
        var end: usize = self.blocks.items.len - 1;
        while (true) {
            if (end < self.free.items[0].pos) break;
            var beg = end;
            while (beg > 0 and self.blocks.items[beg - 1] == self.blocks.items[end]) : (beg -= 1) {}
            const len = end - beg + 1;
            for (self.free.items) |*free| {
                if (free.pos >= beg) break; // because they are sorted
                if (free.len < len) continue;
                std.mem.copyForwards(usize, self.blocks.items[free.pos .. free.pos + len], self.blocks.items[beg .. beg + len]);
                @memset(self.blocks.items[beg .. beg + len], FREE);
                free.pos += len;
                free.len -= len;
                break;
            }
            end -= len;
            while (end > 0 and self.blocks.items[end] == FREE) : (end -= 1) {}
        }
    }

    fn compactMap(self: *Module) !void {
        if (self.whole) {
            try self.compactMapByWholeFiles();
        } else {
            try self.compactMapByBlocks();
        }
    }

    pub fn computeChecksum(self: *Module) !usize {
        try self.computeMap();
        try self.compactMap();
        // self.show();
        var checksum: usize = 0;
        for (0..self.blocks.items.len) |pos| {
            const id = self.blocks.items[pos];
            if (id == FREE) continue;
            checksum += pos * id;
        }
        return checksum;
    }
};

test "sample part 1" {
    const data =
        \\2333133121414131402
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.computeChecksum();
    const expected = @as(usize, 1928);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\2333133121414131402
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.computeChecksum();
    const expected = @as(usize, 2858);
    try testing.expectEqual(expected, count);
}
