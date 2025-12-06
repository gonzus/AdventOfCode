const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const StringTable = struct {
    pub const StringId = usize;

    allocator: Allocator,
    p2s: std.ArrayList([]const u8),
    s2p: std.StringHashMap(StringId),

    pub fn init(allocator: Allocator) StringTable {
        const self = StringTable{
            .allocator = allocator,
            .p2s = .empty,
            .s2p = std.StringHashMap(StringId).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *StringTable) void {
        self.clear();
        self.s2p.deinit();
        self.p2s.deinit(self.allocator);
    }

    pub fn clear(self: *StringTable) void {
        for (self.p2s.items) |item| {
            self.allocator.free(item);
        }
        self.s2p.clearRetainingCapacity();
        self.p2s.clearRetainingCapacity();
    }

    pub fn contains(self: *StringTable, str: []const u8) bool {
        return self.s2p.contains(str);
    }

    pub fn add(self: *StringTable, str: []const u8) !StringId {
        const entry = self.s2p.getEntry(str);
        if (entry) |e| {
            return e.value_ptr.*;
        }
        const pos = self.p2s.items.len;
        const copy = self.allocator.dupe(u8, str) catch unreachable;
        try self.p2s.append(self.allocator, copy);
        _ = try self.s2p.put(copy, pos);
        return pos;
    }

    pub fn get_pos(self: StringTable, str: []const u8) ?StringId {
        const entry = self.s2p.getEntry(str);
        if (entry) |e| {
            return e.value_ptr.*;
        }
        return null;
    }

    pub fn get_str(self: StringTable, pos: StringId) ?[]const u8 {
        if (pos >= self.p2s.items.len) return null;
        return self.p2s.items[pos];
    }

    pub fn size(self: StringTable) usize {
        return self.p2s.items.len;
    }
};

test "basic" {
    var strtab = StringTable.init(std.testing.allocator);
    defer strtab.deinit();

    const str = "gonzo";
    const pos: usize = 0;

    _ = try strtab.add(str);
    try testing.expect(strtab.get_pos(str).? == pos);
    try testing.expect(std.mem.eql(u8, strtab.get_str(pos).?, str));
    try testing.expect(strtab.size() == 1);
}

test "no overwrites" {
    var strtab = StringTable.init(std.testing.allocator);
    defer strtab.deinit();

    const prefix = "This is string #";
    const plen = prefix.len;
    var c: u8 = 0;
    var buf: [100]u8 = undefined;
    while (c < 10) : (c += 1) {
        var len: usize = 0;
        @memcpy(buf[len .. len + plen], prefix);
        len += prefix.len;
        buf[len] = c + '0';
        len += 1;
        const str = buf[0..len];
        // std.debug.warn("ADD [{}]\n", .{str});
        _ = try strtab.add(str);
    }

    const size = strtab.size();
    try testing.expect(size == 10);
    while (c < 10) : (c += 1) {
        var len: usize = 0;
        @memcpy(buf[len .. len + plen], prefix);
        len += prefix.len;
        buf[len] = c + '0';
        len += 1;
        const str = buf[0..len];
        const got = strtab.get_str(c).?;
        // std.debug.warn("GOT [{}] EXPECT [{}]\n", .{ got, str });
        try testing.expect(std.mem.eql(u8, got, str));
    }
}
