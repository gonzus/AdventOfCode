const std = @import("std");
const testing = std.testing;

pub const Street = struct {
    presents: usize,
    limit: usize,
    multiplier: usize,

    pub fn init(limited: bool) Street {
        var street: Street = undefined;
        street.presents = 0;
        if (limited) {
            street.limit = 50;
            street.multiplier = 11;
        } else {
            street.limit = 0;
            street.multiplier = 10;
        }
        return street;
    }

    pub fn addLine(self: *Street, line: []const u8) !void {
        self.presents = try std.fmt.parseUnsigned(usize, line, 10);
    }

    pub fn findLowestHouseWithPresents(self: Street) usize {
        var house: usize = 0;
        while (true) : (house += 1) {
            const presents = self.getPresentsForHouse(house);
            if (presents >= self.presents) break;
        }
        return house;
    }

    fn getPresentsForHouse(self: Street, house: usize) usize {
        const house_float: f64 = @floatFromInt(house);
        const house_root = @trunc(@sqrt(house_float));
        const root: usize = @intFromFloat(house_root);
        var sum: usize = 0;
        var n: usize = 1;
        while (n <= root) : (n += 1) {
            if (house % n > 0) continue;
            const div = house / n;
            if (self.limit == 0 or div <= self.limit) {
                sum += n;
            }
            if (div == n) continue;
            if (self.limit == 0 or n <= self.limit) {
                sum += div;
            }
        }
        return sum * self.multiplier;
    }
};

test "sample part 1" {
    const Data = struct {
        house: usize,
        presents: usize,
    };
    const data = [_]Data{
        Data{ .house = 1, .presents = 10 },
        Data{ .house = 2, .presents = 30 },
        Data{ .house = 3, .presents = 40 },
        Data{ .house = 4, .presents = 70 },
        Data{ .house = 5, .presents = 60 },
        Data{ .house = 6, .presents = 120 },
        Data{ .house = 7, .presents = 80 },
        Data{ .house = 8, .presents = 150 },
        Data{ .house = 9, .presents = 130 },
    };

    var street = Street.init(false);
    for (data) |d| {
        const presents = street.getPresentsForHouse(d.house);
        try testing.expectEqual(d.presents, presents);
    }
}
