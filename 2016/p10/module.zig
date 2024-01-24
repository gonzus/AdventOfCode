const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Factory = struct {
    const BOT_NONE = std.math.maxInt(usize);
    const VALUE_NONE = std.math.maxInt(usize);

    const Kind = enum {
        bin,
        bot,

        pub fn parse(str: []const u8) !Kind {
            if (std.mem.eql(u8, str, "bot")) return .bot;
            if (std.mem.eql(u8, str, "output")) return .bin;
            return error.InvalidKind;
        }
    };

    const Bin = struct {
        id: usize,
        value: usize,
        dest: usize,

        pub fn initSource(id: usize, value: usize, dest: usize) Bin {
            return Bin.init(id, value, dest);
        }

        pub fn initSink(id: usize) Bin {
            return Bin.init(id, VALUE_NONE, BOT_NONE);
        }

        fn init(id: usize, value: usize, dest: usize) Bin {
            return Bin{
                .id = id,
                .value = value,
                .dest = dest,
            };
        }

        pub fn isSource(self: Bin) bool {
            return self.dest != BOT_NONE;
        }

        pub fn addValue(self: *Bin, value: usize) !void {
            if (self.value == VALUE_NONE) {
                self.value = value;
            }
            if (self.value != value) return error.InvalidValue;
        }
    };

    const Destination = struct {
        kind: Kind,
        id: usize,

        pub fn init(kind: Kind, id: usize) Destination {
            return Destination{
                .kind = kind,
                .id = id,
            };
        }
    };

    const Bot = struct {
        id: usize,
        dests: [2]Destination,
        pos: usize,
        values: [2]usize,
        seen: std.AutoHashMap(usize, void),

        pub fn init(allocator: Allocator, id: usize) Bot {
            return Bot{
                .id = id,
                .dests = undefined,
                .pos = 0,
                .values = undefined,
                .seen = std.AutoHashMap(usize, void).init(allocator),
            };
        }

        pub fn deinit(self: *Bot) void {
            self.seen.deinit();
        }

        pub fn addDestination(self: *Bot, which: []const u8, kind: Kind, dest: usize) !void {
            if (std.mem.eql(u8, which, "low") and self.pos != 0) return error.InvalidDestination;
            if (std.mem.eql(u8, which, "high") and self.pos != 1) return error.InvalidDestination;
            self.dests[self.pos] = Destination.init(kind, dest);
            self.pos += 1;
            if (self.pos >= 2) self.pos = 0;
        }

        pub fn addValue(self: *Bot, value: usize) !void {
            if (self.pos >= 2) return error.TooManyValues;

            self.values[self.pos] = value;
            self.pos += 1;
            _ = try self.seen.getOrPut(value);
            if (self.pos < 2) return;

            if (self.values[0] > self.values[1]) {
                std.mem.swap(usize, &self.values[0], &self.values[1]);
            }
        }
    };

    allocator: Allocator,
    bins: std.AutoHashMap(usize, Bin),
    bots: std.AutoHashMap(usize, Bot),
    input_id: usize,

    pub fn init(allocator: Allocator) Factory {
        return Factory{
            .allocator = allocator,
            .bins = std.AutoHashMap(usize, Bin).init(allocator),
            .bots = std.AutoHashMap(usize, Bot).init(allocator),
            .input_id = 1_000_000,
        };
    }

    pub fn deinit(self: *Factory) void {
        var it = self.bots.iterator();
        while (it.next()) |e| {
            e.value_ptr.*.deinit();
        }
        self.bots.deinit();
        self.bins.deinit();
    }

    pub fn addLine(self: *Factory, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const what = it.next().?;
        if (std.mem.eql(u8, what, "value")) {
            const value = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            _ = it.next().?;
            _ = it.next().?;
            _ = it.next().?;
            const id = self.input_id;
            self.input_id += 1;
            const dest = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            const bin = Bin.initSource(id, value, dest);
            try self.bins.put(id, bin);
            return;
        }
        if (std.mem.eql(u8, what, "bot")) {
            const id = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            var bot = Bot.init(self.allocator, id);
            for (0..2) |_| {
                _ = it.next().?;
                const which = it.next().?;
                _ = it.next().?;
                const kind = try Kind.parse(it.next().?);
                const dest = try std.fmt.parseUnsigned(usize, it.next().?, 10);
                try bot.addDestination(which, kind, dest);
                if (kind == .bin) {
                    const r = try self.bins.getOrPut(dest);
                    if (!r.found_existing) {
                        r.value_ptr.* = Bin.initSink(dest);
                    }
                }
            }
            try self.bots.put(id, bot);
            return;
        }
        return error.InvalidData;
    }

    pub fn getBotComparingChips(self: *Factory, l: usize, r: usize) !usize {
        try self.run();
        var it = self.bots.valueIterator();
        while (it.next()) |bot| {
            if (!bot.seen.contains(l)) continue;
            if (!bot.seen.contains(r)) continue;
            return bot.id;
        }
        return BOT_NONE;
    }

    pub fn getProductOfValuesInBins(self: *Factory, bins: []const usize) !usize {
        try self.run();
        var prod: usize = 1;
        var it = self.bins.valueIterator();
        while (it.next()) |bin| {
            for (bins) |b| {
                if (bin.id != b) continue;
                prod *= bin.value;
                break;
            }
        }
        return prod;
    }

    const Move = struct {
        gen: usize,
        bot: usize,
        value: usize,
        dest: Destination,

        pub fn init(gen: usize, bot: usize, value: usize, dest: Destination) Move {
            return Move{
                .gen = gen,
                .bot = bot,
                .value = value,
                .dest = dest,
            };
        }

        fn lessThan(_: void, l: Move, r: Move) std.math.Order {
            const go = std.math.order(l.gen, r.gen);
            if (go != .eq) return go;
            const bo = std.math.order(l.bot, r.bot);
            if (bo != .eq) return bo;
            const vo = std.math.order(l.value, r.value);
            if (vo != .eq) return vo;
            return std.math.order(l.dest.id, r.dest.id);
        }
    };

    const PQ = std.PriorityQueue(Move, void, Move.lessThan);

    fn run(self: *Factory) !void {
        var queue = PQ.init(self.allocator, {});
        defer queue.deinit();

        var it = self.bins.valueIterator();
        while (it.next()) |bin| {
            if (!bin.isSource()) continue;
            try queue.add(Move.init(0, BOT_NONE, bin.value, Destination.init(.bot, bin.dest)));
        }

        while (queue.count() > 0) {
            const move = queue.remove();
            switch (move.dest.kind) {
                .bin => {
                    const entry = self.bins.getEntry(move.dest.id);
                    const bin = entry.?.value_ptr;
                    try bin.addValue(move.value);
                },
                .bot => {
                    const entry = self.bots.getEntry(move.dest.id);
                    const bot = entry.?.value_ptr;
                    try bot.addValue(move.value);
                    if (bot.pos >= 2) {
                        const gen = move.gen + 1;
                        for (0..2) |p| {
                            try queue.add(Move.init(gen, bot.id, bot.values[p], bot.dests[p]));
                        }
                        bot.pos = 0;
                    }
                },
            }
        }
    }
};

test "sample part 1" {
    const data =
        \\value 5 goes to bot 2
        \\bot 2 gives low to bot 1 and high to bot 0
        \\value 3 goes to bot 1
        \\bot 1 gives low to output 1 and high to bot 0
        \\bot 0 gives low to output 2 and high to output 0
        \\value 2 goes to bot 2
    ;

    var factory = Factory.init(std.testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.addLine(line);
    }

    const bot = try factory.getBotComparingChips(5, 2);
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, bot);
}
