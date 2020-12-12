const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Adapter = struct {
    top: usize,
    sorted: bool,
    ratings: std.ArrayList(usize),

    pub fn init() Adapter {
        var self = Adapter{
            .ratings = std.ArrayList(usize).init(allocator),
            .top = 0,
            .sorted = true,
        };
        return self;
    }

    pub fn deinit(self: *Adapter) void {
        self.ratings.deinit();
    }

    pub fn add_rating(self: *Adapter, line: []const u8) void {
        const number = std.fmt.parseInt(usize, line, 10) catch unreachable;
        self.ratings.append(number) catch unreachable;
        if (self.top < number) self.top = number;
        self.sorted = false;
    }

    pub fn get_one_by_three(self: *Adapter) usize {
        self.check_and_sort();

        var deltas = std.ArrayList(usize).init(allocator);
        defer deltas.deinit();
        self.compute_deltas(&deltas);

        var counts = [_]usize{0} ** 4;
        var p: usize = 0;
        while (p < deltas.items.len) : (p += 1) {
            counts[deltas.items[p]] += 1;
        }
        return counts[1] * counts[3];
    }

    pub fn count_valid(self: *Adapter) usize {
        self.check_and_sort();

        var deltas = std.ArrayList(usize).init(allocator);
        defer deltas.deinit();
        self.compute_deltas(&deltas);

        var count: usize = 1;
        var ones: usize = 0;
        var p: usize = 0;
        while (p < deltas.items.len) : (p += 1) {
            if (deltas.items[p] == 1) {
                ones += 1;
                continue;
            }

            if (ones > 1) {
                const factor = (ones * (ones - 1)) / 2 + 1;
                count *= factor;
            }
            ones = 0;
        }
        return count;
    }

    fn check_and_sort(self: *Adapter) void {
        if (self.sorted) return;
        self.ratings.append(self.top + 3) catch unreachable;
        std.sort.sort(usize, self.ratings.items, {}, comptime std.sort.asc(usize));
    }

    fn compute_deltas(self: Adapter, deltas: *std.ArrayList(usize)) void {
        var p: usize = 0;
        var previous: usize = 0;
        while (p < self.ratings.items.len) : (p += 1) {
            const current = self.ratings.items[p];
            const delta = current - previous;
            if (delta > 3) {
                std.debug.warn("TOO BIG: {} {} {}\n", .{ current, previous, delta });
                @panic("Too big");
            }
            deltas.*.append(delta) catch unreachable;
            previous = current;
        }
    }
};

test "sample small" {
    const data: []const u8 =
        \\16
        \\10
        \\15
        \\5
        \\1
        \\11
        \\7
        \\19
        \\6
        \\12
        \\4
    ;

    var adapter = Adapter.init();
    defer adapter.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        adapter.add_rating(line);
    }

    const one_by_three = adapter.get_one_by_three();
    testing.expect(one_by_three == 35);

    const valid = adapter.count_valid();
    testing.expect(valid == 8);
}

test "sample large" {
    const data: []const u8 =
        \\28
        \\33
        \\18
        \\42
        \\31
        \\14
        \\46
        \\20
        \\48
        \\47
        \\24
        \\23
        \\49
        \\45
        \\19
        \\38
        \\39
        \\11
        \\1
        \\32
        \\25
        \\35
        \\8
        \\17
        \\7
        \\9
        \\4
        \\2
        \\34
        \\10
        \\3
    ;

    var adapter = Adapter.init();
    defer adapter.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        adapter.add_rating(line);
    }

    const one_by_three = adapter.get_one_by_three();
    testing.expect(one_by_three == 220);

    const valid = adapter.count_valid();
    testing.expect(valid == 19208);
}
