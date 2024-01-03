const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Present = struct {
    const StringId = StringTable.StringId;

    const Compound = enum {
        children,
        cats,
        samoyeds,
        pomeranians,
        akitas,
        vizslas,
        goldfish,
        trees,
        cars,
        perfumes,

        pub fn parse(text: []const u8) !Compound {
            for (std.meta.tags(Compound)) |c| {
                if (std.mem.eql(u8, text, @tagName(c))) return c;
            }
            return error.InvalidCompound;
        }

        pub fn valueMatch(self: Compound, l: usize, r: usize, ranged: bool) bool {
            if (ranged) {
                switch (self) {
                    .cats, .trees => return l > r,
                    .pomeranians, .goldfish => return l < r,
                    else => {},
                }
            }
            return l == r;
        }
    };
    const CompoundSize = std.meta.tags(Compound).len;

    const Spec = struct {
        values: [CompoundSize]usize,

        pub fn init() Spec {
            return Spec{
                .values = [_]usize{std.math.maxInt(usize)} ** CompoundSize,
            };
        }

        pub fn matches(self: Spec, other: Spec, ranged: bool) bool {
            for (self.values, 0..) |v, c| {
                if (v == std.math.maxInt(usize)) continue;
                const compound: Compound = @enumFromInt(c);
                if (!compound.valueMatch(v, other.values[c], ranged)) return false;
            }
            return true;
        }
    };

    const Aunt = struct {
        id: usize,
        spec: Spec,

        pub fn init() Aunt {
            return Aunt{ .id = 0, .spec = Spec.init() };
        }
    };

    allocator: Allocator,
    ranged: bool,
    aunts: std.ArrayList(Aunt),

    pub fn init(allocator: Allocator, ranged: bool) Present {
        return Present{
            .allocator = allocator,
            .ranged = ranged,
            .aunts = std.ArrayList(Aunt).init(allocator),
        };
    }

    pub fn deinit(self: *Present) void {
        self.aunts.deinit();
    }

    pub fn addLine(self: *Present, line: []const u8) !void {
        var pos: usize = 0;
        var aunt = Aunt.init();
        var compound: Compound = undefined;
        var value: usize = undefined;
        var it = std.mem.tokenizeAny(u8, line, " :,");
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                1 => aunt.id = try std.fmt.parseUnsigned(usize, chunk, 10),
                2, 4, 6 => compound = try Compound.parse(chunk),
                3, 5, 7 => {
                    value = try std.fmt.parseInt(usize, chunk, 10);
                    const c = @intFromEnum(compound);
                    aunt.spec.values[c] = value;
                },
                else => continue,
            }
        }
        try self.aunts.append(aunt);
    }

    pub fn show(self: Present) void {
        std.debug.print("List of {} aunts\n", .{self.aunts.items.len});
        for (self.aunts.items) |aunt| {
            std.debug.print("  {d} =>", .{aunt.id});
            for (0..CompoundSize) |c| {
                const compound: Compound = @enumFromInt(c);
                if (aunt.spec.values[c] == std.math.maxInt(usize)) continue;
                std.debug.print(" {s}={}", .{ @tagName(compound), aunt.spec.values[c] });
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn findAunt(self: Present) !usize {
        var spec = Present.Spec.init();
        spec.values[@intFromEnum(Compound.children)] = 3;
        spec.values[@intFromEnum(Compound.cats)] = 7;
        spec.values[@intFromEnum(Compound.samoyeds)] = 2;
        spec.values[@intFromEnum(Compound.pomeranians)] = 3;
        spec.values[@intFromEnum(Compound.akitas)] = 0;
        spec.values[@intFromEnum(Compound.vizslas)] = 0;
        spec.values[@intFromEnum(Compound.goldfish)] = 5;
        spec.values[@intFromEnum(Compound.trees)] = 3;
        spec.values[@intFromEnum(Compound.cars)] = 2;
        spec.values[@intFromEnum(Compound.perfumes)] = 1;

        var count: usize = 0;
        var matching: usize = std.math.maxInt(usize);
        for (self.aunts.items) |aunt| {
            if (!aunt.spec.matches(spec, self.ranged)) continue;
            matching = aunt.id;
            count += 1;
        }
        if (count != 1) return error.NoMatchFound;
        return matching;
    }
};
