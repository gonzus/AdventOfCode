const std = @import("std");
const testing = std.testing;

pub const Crypto = struct {
    const Credentials = struct {
        public_key: usize,
        private_key: usize,
        loop_size: usize,

        pub fn init(public_key: usize) Credentials {
            var self = Credentials{
                .public_key = public_key,
                .private_key = 0,
                .loop_size = 0,
            };
            return self;
        }

        pub fn guess_loop_size(self: *Credentials) void {
            const INITIAL_VALUE: usize = 7;
            const GUESSES: usize = 10_000_000;
            var result: usize = 1;
            var loop_size: usize = 1;
            while (loop_size <= GUESSES) : (loop_size += 1) {
                result = step(result, INITIAL_VALUE);
                if (result == self.public_key) {
                    self.loop_size = loop_size;
                    // std.debug.warn("Guessed loop size for public key {} => {}\n", .{ self.public_key, self.loop_size });
                    return;
                }
            }
            @panic("TOO MANY GUESSES");
        }

        pub fn operate(subject_number: usize, loop_size: usize) usize {
            var result: usize = 1;
            var c: usize = 0;
            while (c < loop_size) : (c += 1) {
                result = step(result, subject_number);
            }
            // std.debug.warn("Operated {} times on subject number {} => {}\n", .{ loop_size, subject_number, result });
            return result;
        }

        fn step(curr: usize, subject_number: usize) usize {
            const CRYPTO_DIVISOR: usize = 20201227;
            var next = curr;
            next *= subject_number;
            next %= CRYPTO_DIVISOR;
            return next;
        }
    };

    door: Credentials,
    card: Credentials,
    count: usize,

    pub fn init() Crypto {
        var self = Crypto{
            .door = undefined,
            .card = undefined,
            .count = 0,
        };
        return self;
    }

    pub fn deinit(self: *Crypto) void {
        _ = self;
    }

    pub fn add_public_key(self: *Crypto, line: []const u8) void {
        const public_key = std.fmt.parseInt(usize, line, 10) catch unreachable;
        switch (self.count) {
            0 => self.door = Credentials.init(public_key),
            1 => self.card = Credentials.init(public_key),
            else => @panic("TOO MANY CREDENTIALS"),
        }
        self.count += 1;
    }

    pub fn guess_encryption_key(self: *Crypto) usize {
        self.door.guess_loop_size();
        self.card.guess_loop_size();
        self.door.private_key = Credentials.operate(self.card.public_key, self.door.loop_size);
        self.card.private_key = Credentials.operate(self.door.public_key, self.card.loop_size);
        // std.debug.warn("Door private key = {}, Card private key = {}, OK = {}\n", .{
        //     self.door.private_key,
        //     self.card.private_key,
        //     self.door.private_key == self.card.private_key,
        // });
        return self.door.private_key;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\5764801
        \\17807724
    ;

    var crypto = Crypto.init();
    defer crypto.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        crypto.add_public_key(line);
    }

    const encryption_key = crypto.guess_encryption_key();
    try testing.expect(encryption_key == 14897079);
}
