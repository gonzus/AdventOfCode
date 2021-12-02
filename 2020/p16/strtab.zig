const std = @import("std");
const testing = std.testing;

pub const StringTable = struct {
    allocator: *std.mem.Allocator,
    p2s: std.ArrayList([]const u8),
    s2p: std.StringHashMap(usize),

    pub fn init(allocator: *std.mem.Allocator) StringTable {
        var self = StringTable{
            .allocator = allocator,
            .p2s = std.ArrayList([]const u8).init(allocator),
            .s2p = std.StringHashMap(usize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *StringTable) void {
        self.s2p.deinit();
        // for (self.colors.items) |item| {
        //     allocator.free(item);
        // }
        self.p2s.deinit();
    }

    pub fn add(self: *StringTable, str: []const u8) usize {
        if (self.s2p.contains(str)) {
            return self.s2p.get(str).?;
        }
        const pos = self.p2s.items.len;
        const copy = self.allocator.dupe(u8, str) catch unreachable;
        self.p2s.append(copy) catch unreachable;
        _ = self.s2p.put(copy, pos) catch unreachable;
        return pos;
    }

    pub fn get_pos(self: StringTable, str: []const u8) ?usize {
        return self.s2p.get(str);
    }

    pub fn get_str(self: StringTable, pos: usize) ?[]const u8 {
        return self.p2s.items[pos];
    }

    pub fn size(self: StringTable) usize {
        return self.p2s.items.len;
    }
};

test "basic" {
    const allocator = std.heap.page_allocator;
    var strtab = StringTable.init(allocator);
    defer strtab.deinit();

    const str = "gonzo";
    const pos: usize = 0;

    _ = strtab.add(str);
    try testing.expect(strtab.get_pos(str).? == pos);
    try testing.expect(std.mem.eql(u8, strtab.get_str(pos).?, str));
    try testing.expect(strtab.size() == 1);
}

test "no overwrites" {
    const allocator = std.heap.page_allocator;
    var strtab = StringTable.init(allocator);
    defer strtab.deinit();

    const prefix = "This is string #";
    var c: u8 = 0;
    var buf: [100]u8 = undefined;
    while (c < 10) : (c += 1) {
        var len: usize = 0;
        std.mem.copy(u8, buf[len..], prefix);
        len += prefix.len;
        buf[len] = c + '0';
        len += 1;
        const str = buf[0..len];
        // std.debug.warn("ADD [{}]\n", .{str});
        _ = strtab.add(str);
    }

    const size = strtab.size();
    try testing.expect(size == 10);
    while (c < 10) : (c += 1) {
        var len: usize = 0;
        std.mem.copy(u8, buf[len..], prefix);
        len += prefix.len;
        buf[len] = c + '0';
        len += 1;
        const str = buf[0..len];
        const got = strtab.get_str(c).?;
        // std.debug.warn("GOT [{}] EXPECT [{}]\n", .{ got, str });
        try testing.expect(std.mem.eql(u8, got, str));
    }
}
