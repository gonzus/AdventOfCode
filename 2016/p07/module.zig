const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Address = struct {
    tls_count: usize,
    ssl_count: usize,
    abas: std.AutoHashMap(usize, void),
    babs: std.AutoHashMap(usize, void),

    pub fn init(allocator: Allocator) Address {
        const self = Address{
            .tls_count = 0,
            .ssl_count = 0,
            .abas = std.AutoHashMap(usize, void).init(allocator),
            .babs = std.AutoHashMap(usize, void).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Address) void {
        self.babs.deinit();
        self.abas.deinit();
    }

    pub fn addLine(self: *Address, line: []const u8) !void {
        self.abas.clearRetainingCapacity();
        self.babs.clearRetainingCapacity();
        var in_hypernet = false;
        var count_abba: isize = 0;
        var it = std.mem.tokenizeAny(u8, line, "[]");
        while (it.next()) |chunk| {
            if (self.findABBA(chunk)) {
                if (in_hypernet) {
                    count_abba = std.math.minInt(isize);
                } else {
                    count_abba += 1;
                }
            }
            if (in_hypernet) {
                try self.processBAB(chunk);
            } else {
                try self.processABA(chunk);
            }
            in_hypernet = !in_hypernet;
        }

        if (count_abba > 0) {
            self.tls_count += 1;
        }

        var it_abas = self.abas.keyIterator();
        while (it_abas.next()) |k| {
            if (!self.babs.contains(k.*)) continue;
            self.ssl_count += 1;
            break;
        }
    }

    pub fn getAddressesSupportingTLS(self: Address) usize {
        return self.tls_count;
    }

    pub fn getAddressesSupportingSSL(self: Address) usize {
        return self.ssl_count;
    }

    fn findABBA(_: Address, address: []const u8) bool {
        for (address, 0..) |_, p| {
            if (p + 4 > address.len) break;
            if (address[p + 0] != address[p + 3]) continue;
            if (address[p + 1] != address[p + 2]) continue;
            if (address[p + 0] == address[p + 1]) continue;
            return true;
        }
        return false;
    }

    fn processABA(self: *Address, address: []const u8) !void {
        for (address, 0..) |_, p| {
            if (p + 3 > address.len) break;
            if (address[p + 0] != address[p + 2]) continue;
            if (address[p + 0] == address[p + 1]) continue;
            _ = try self.abas.getOrPut(makeKey(address, p + 0, p + 1));
        }
    }

    fn processBAB(self: *Address, address: []const u8) !void {
        for (address, 0..) |_, p| {
            if (p + 3 > address.len) break;
            if (address[p + 0] != address[p + 2]) continue;
            if (address[p + 0] == address[p + 1]) continue;
            _ = try self.babs.getOrPut(makeKey(address, p + 1, p + 0));
        }
    }

    fn makeKey(address: []const u8, p0: usize, p1: usize) usize {
        const v0: usize = address[p0] - 'a';
        const v1: usize = address[p1] - 'a';
        return v0 * 100 + v1;
    }
};

test "sample part 1" {
    const data =
        \\abba[mnop]qrst
        \\abcd[bddb]xyyx
        \\aaaa[qwer]tyui
        \\ioxxoj[asdfgh]zxcvbn
    ;

    var address = Address.init(std.testing.allocator);
    defer address.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try address.addLine(line);
    }

    const count = address.getAddressesSupportingTLS();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\aba[bab]xyz
        \\xyx[xyx]xyx
        \\aaa[kek]eke
        \\zazbz[bzb]cdb
    ;

    var address = Address.init(std.testing.allocator);
    defer address.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try address.addLine(line);
    }

    const count = address.getAddressesSupportingSSL();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, count);
}
