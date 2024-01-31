const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Disk = struct {
    const WORK_SIZE = 71 * 1024 * 1024;
    allocator: Allocator,
    initial_buf: [100]u8,
    initial_len: usize,

    pub fn init(allocator: Allocator) Disk {
        return .{
            .allocator = allocator,
            .initial_buf = undefined,
            .initial_len = 0,
        };
    }

    pub fn addLine(self: *Disk, line: []const u8) !void {
        std.mem.copyForwards(u8, &self.initial_buf, line);
        self.initial_len = line.len;
    }

    pub fn getDiskChecksum(self: *Disk, size: usize, buf: []u8) ![]const u8 {
        // allocate two work buffers, we flip-flop between them
        var tmp: [2][]u8 = undefined;
        for (tmp, 0..) |_, p| {
            tmp[p] = try self.allocator.alloc(u8, WORK_SIZE);
        }
        var pos: usize = 0;

        // start with initial state
        var len: usize = self.initial_len;
        std.mem.copyForwards(u8, tmp[pos], self.initial_buf[0..len]);

        // while it is too short, grow it with "dragon curve"
        while (len < size) {
            const cur = len;
            const nxt = 1 - pos;
            std.mem.copyForwards(u8, tmp[nxt], tmp[pos][0..cur]);
            tmp[nxt][len] = '0';
            len += 1;
            for (0..cur) |p| {
                const q = cur - p - 1;
                const c: u8 = if (tmp[pos][p] == '1') '0' else '1';
                tmp[nxt][len + q] = c;
            }
            len += cur;
            pos = nxt;
        }
        len = size;

        // while length is even, shrink it with checksum
        while (len % 2 == 0) {
            const cur = len;
            const nxt = 1 - pos;
            len = 0;
            var p: usize = 0;
            while (p < cur - 1) : (p += 2) {
                const c: u8 = if (tmp[pos][p] == tmp[pos][p + 1]) '1' else '0';
                tmp[nxt][len] = c;
                len += 1;
            }
            pos = nxt;
        }

        // copy to output buffer
        std.mem.copyForwards(u8, buf, tmp[pos][0..len]);

        // release work buffers and return
        for (tmp, 0..) |_, p| {
            self.allocator.free(tmp[p]);
        }
        return buf[0..len];
    }
};

test "sample part 1" {
    const data =
        \\10000
    ;
    std.debug.print("\n", .{});

    var disk = Disk.init(testing.allocator);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try disk.addLine(line);
    }

    var buf: [100]u8 = undefined;
    const checksum = try disk.getDiskChecksum(20, &buf);
    const expected = "01100";
    try testing.expectEqualSlices(u8, expected, checksum);
}
