const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Building = struct {
    const StringId = StringTable.StringId;

    const Room = struct {
        building: *Building,
        words: std.ArrayList(StringId),
        sector: usize,
        checksum: StringId,
        counts: [26]usize,

        pub fn init(building: *Building) Room {
            return Room{
                .building = building,
                .words = std.ArrayList(StringId).init(building.allocator),
                .sector = undefined,
                .checksum = undefined,
                .counts = [_]usize{0} ** 26,
            };
        }

        pub fn deinit(self: *Room) void {
            self.words.deinit();
        }

        pub fn addWord(self: *Room, word: []const u8) !void {
            try self.words.append(try self.building.strtab.add(word));
            for (word) |chr| {
                self.counts[chr - 'a'] += 1;
            }
        }

        pub fn isValid(self: Room) !bool {
            var rank: [26]usize = undefined;
            for (0..26) |pos| {
                rank[pos] = self.counts[pos] * 100 + pos;
            }
            std.sort.heap(usize, &rank, {}, Room.lessThan);
            const checksum = self.building.strtab.get_str(self.checksum) orelse return error.ChecksumNotFound;
            for (checksum, 0..) |chr, pos| {
                var letter: u8 = 'a';
                letter += @intCast(rank[pos] % 100);
                if (chr != letter) return false;
            }
            return true;
        }

        pub fn decryptWords(self: *Room, wanted: []StringId) !bool {
            var wanted_room = true;
            for (self.words.items) |*word_id| {
                const word = self.building.strtab.get_str(word_id.*) orelse return error.InvalidWord;
                const new_id = try self.decryptWord(word);
                const wanted_pos = std.mem.indexOfScalar(StringId, wanted, new_id);
                if (wanted_pos) |_| {} else wanted_room = false;
                word_id.* = new_id;
            }
            return wanted_room;
        }

        fn lessThan(_: void, l: usize, r: usize) bool {
            const l_chr = l % 100;
            const l_cnt = l / 100;
            const r_chr = r % 100;
            const r_cnt = r / 100;
            if (l_cnt > r_cnt) return true;
            if (l_cnt < r_cnt) return false;
            return l_chr < r_chr;
        }

        fn decryptWord(self: *Room, word: []const u8) !StringId {
            var buf: [1024]u8 = undefined;
            var len: usize = 0;
            for (word) |chr| {
                var new: usize = chr - 'a';
                new += self.sector;
                new %= 26;
                buf[len] = @intCast(new + 'a');
                len += 1;
            }
            return try self.building.strtab.add(buf[0..len]);
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    rooms: std.ArrayList(Room),

    pub fn init(allocator: Allocator) Building {
        return Building{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .rooms = std.ArrayList(Room).init(allocator),
        };
    }

    pub fn deinit(self: *Building) void {
        for (self.rooms.items) |*room| {
            room.deinit();
        }
        self.rooms.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Building, line: []const u8) !void {
        var in_checksum = false;
        var room = Room.init(self);
        var it = std.mem.tokenizeAny(u8, line, "-[]");
        while (it.next()) |chunk| {
            if (in_checksum) {
                room.checksum = try self.strtab.add(chunk);
                continue;
            }
            const num = std.fmt.parseUnsigned(usize, chunk, 10) catch {
                try room.addWord(chunk);
                continue;
            };
            in_checksum = true;
            room.sector = num;
        }
        try self.rooms.append(room);
    }

    pub fn show(self: Building) void {
        std.debug.print("Building with {} rooms\n", .{self.rooms.items.len});
        for (self.rooms.items) |room| {
            std.debug.print("  Sector {} - Checksum [{s}] - Words ", .{
                room.sector,
                self.strtab.get_str(room.checksum) orelse "***",
            });
            for (room.words.items, 0..) |word, pos| {
                const chr: u8 = if (pos == 0) '[' else '-';
                std.debug.print("{c}{s}", .{
                    chr,
                    self.strtab.get_str(word) orelse "***",
                });
            }
            std.debug.print("]\n", .{});
        }
    }

    pub fn getSumValidSectorIDs(self: Building) !usize {
        var sum: usize = 0;
        for (self.rooms.items) |room| {
            if (!try room.isValid()) continue;
            sum += room.sector;
        }
        return sum;
    }

    pub fn getNorthPoleObjectStorageSectorID(self: *Building) !usize {
        var wanted: [3]StringId = undefined;
        wanted[0] = try self.strtab.add("northpole");
        wanted[1] = try self.strtab.add("object");
        wanted[2] = try self.strtab.add("storage");
        return try self.getWantedSectorID(&wanted);
    }

    fn getWantedSectorID(self: *Building, wanted: []StringId) !usize {
        for (self.rooms.items) |*room| {
            if (try room.decryptWords(wanted)) return room.sector;
        }
        return error.RoomNotFound;
    }
};

test "sample part 1" {
    const data =
        \\aaaaa-bbb-z-y-x-123[abxyz]
        \\a-b-c-d-e-f-g-h-987[abcde]
        \\not-a-real-room-404[oarel]
        \\totally-real-room-200[decoy]
    ;

    var building = Building.init(std.testing.allocator);
    defer building.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try building.addLine(line);
    }
    // building.show();

    const count = try building.getSumValidSectorIDs();
    const expected = @as(usize, 123 + 987 + 404);
    try testing.expectEqual(expected, count);
}
