const std = @import("std");
const assert = std.debug.assert;

pub const FFT = struct {
    const base_pattern = [_]i8{ 0, 1, 0, -1 };

    signal: []u8,
    times: usize,

    pub fn init() FFT {
        var self = FFT{
            .signal = undefined,
            .times = 0,
        };
        return self;
    }

    fn get_pattern(self: *FFT, r: usize, p: usize) i8 {
        // row 0: 0 -> 0, 1 -> 1, ...
        // row 1: 0, 1 -> 0, 1, 2 _. 1
        // row 2: 0, 1, 2 -> 0, 3, 4, 5 -> 1
        const x: usize = ((p + 1) / (r + 1)) % 4;
        return base_pattern[x];
    }

    // fn compute_row_pattern(self: *FFT, r: usize, pattern: []i8) void {
    //     var p: usize = 0;
    //     var x: usize = 0;
    //     var first: bool = true;
    //     var c: usize = 0;
    //     while (true) {
    //         if (first) {
    //             first = false;
    //             x += 1;
    //             if (x > r) {
    //                 x = 0;
    //                 p += 1;
    //                 if (p >= base_pattern.len) p = 0;
    //             }
    //         }
    //         pattern[c] = base_pattern[p];
    //         x += 1;
    //         if (x > r) {
    //             x = 0;
    //             p += 1;
    //             if (p >= base_pattern.len) p = 0;
    //         }
    //         c += 1;
    //         if (c >= SIZE) break;
    //     }
    // }

    pub fn parse(self: *FFT, str: []const u8, n: usize) void {
        var k: usize = 0;
        const allocator = std.heap.direct_allocator;
        self.signal = allocator.alloc(u8, str.len) catch @panic("FUCK\n");
        self.times = n;
        var j: usize = 0;
        while (j < str.len) : (j += 1) {
            self.signal[j] = str[j] - '0';
        }
        std.debug.warn("PARSED\n");
    }

    pub fn deinit(self: *FFT) void {}

    pub fn run_phase(self: *FFT, buf: [2][]u8, inp: usize, out: usize, last: usize) void {
        const size = self.signal.len * self.times;
        const first = size - last;
        const half = size / 2;
        var j: usize = size;
        var g: u32 = 0;
        while (j > first and j > half) {
            j -= 1;
            const s = buf[inp][j];
            g += s;
            const f = @intCast(u8, g % 10);
            // std.debug.warn(" = {}\n", f);
            buf[out][j] = f;
        }
        while (j > first) {
            j -= 1;
            var d: i32 = 0;
            var k: usize = size;
            // std.debug.warn("POS {}: ", j);
            while (true) {
                k -= 1;
                const s = @intCast(i32, buf[inp][k]);
                const p = self.get_pattern(j, k);
                d += s * p;
                // std.debug.warn(" {:2}", p);
                if (k == j) break;
                if ((size - k) == last) break;
            }
            const a = @intCast(usize, std.math.absInt(d) catch 0);
            const f = @intCast(u8, a % 10);
            // std.debug.warn(" = {}\n", f);
            buf[out][j] = f;
        }
    }

    pub fn run_phases(self: *FFT, n: usize, output: []u8, last: usize) void {
        std.debug.warn("Signal size: {} * {}  = {}, interested in last {} elements\n", self.signal.len, self.times, self.signal.len * self.times, last);
        const allocator = std.heap.direct_allocator;
        var buf: [2][]u8 = undefined;
        buf[0] = allocator.alloc(u8, self.signal.len * self.times) catch @panic("FUCK\n");
        buf[1] = allocator.alloc(u8, self.signal.len * self.times) catch @panic("FUCK\n");
        var j: usize = 0;
        while (j < self.times) : (j += 1) {
            std.mem.copy(u8, buf[0][j * self.signal.len ..], self.signal);
        }
        var p: usize = 0;
        var inp: usize = 0;
        var out: usize = 1;
        while (p < n) : (p += 1) {
            if (p % 10 == 0) std.debug.warn("== PHASE {} ==\n", p);
            self.run_phase(buf, inp, out, last);
            inp = 1 - inp;
            out = 1 - out;
            // std.debug.warn("OUTPUT:");
            // var j: usize = 0;
            // while (j < FFT.SIZE) : (j += 1) {
            //     std.debug.warn(" {}", output[j]);
            // }
            // std.debug.warn("\n");
        }
        std.mem.copy(u8, output[0..], buf[1 - out]);
    }

    fn show_signal(self: FFT) void {
        std.debug.warn("SIGNAL: {} values repeated {} times\n", self.signal.len, self.times);
        // var j: usize = 0;
        // var c: usize = 0;
        // while (j < self.pos) : (j += 1) {
        //     std.debug.warn("{} ", self.signal[j]);
        //     c += 1;
        //     if (c == 10) {
        //         std.debug.warn("\n");
        //         c = 0;
        //     }
        // }
        // if (c > 0) std.debug.warn("\n");
    }

    pub fn show(self: FFT) void {
        self.show_signal();
    }
};

test "foo" {
    std.debug.warn("\n");
    var fft = FFT.init();
    defer fft.deinit();
    const data = "12345678";
    fft.parse(data, 1);

    const allocator = std.heap.direct_allocator;
    var output: []u8 = allocator.alloc(u8, data.len) catch @panic("FUCK\n");
    fft.run_phases(4, output[0..], data.len - 3);
    const wanted = [_]u8{ 0, 1, 0, 2, 9, 4, 9, 8 };
    assert(std.mem.compare(u8, wanted[3..], output[3..]) == std.mem.Compare.Equal);
}

test "bar" {
    // 19617804207202209144916044189917 becomes 73745418.
    // 69317163492948606335995924319873 becomes 52432133.
    std.debug.warn("\n");
    var fft = FFT.init();
    defer fft.deinit();
    const data = "80871224585914546619083218645595";
    fft.parse(data, 1);

    const allocator = std.heap.direct_allocator;
    var output: []u8 = allocator.alloc(u8, data.len) catch @panic("FUCK\n");
    fft.run_phases(100, output[0..], data.len);
    const wanted = [_]u8{ 2, 4, 1, 7, 6, 1, 7, 6 };
    assert(std.mem.compare(u8, wanted, output[0..wanted.len]) == std.mem.Compare.Equal);
}
test "bar" {
    std.debug.warn("\n");
    var fft = FFT.init();
    defer fft.deinit();
    const data = "19617804207202209144916044189917";
    fft.parse(data, 1);

    const allocator = std.heap.direct_allocator;
    var output: []u8 = allocator.alloc(u8, data.len) catch @panic("FUCK\n");
    fft.run_phases(100, output[0..], data.len);
    const wanted = [_]u8{ 7, 3, 7, 4, 5, 4, 1, 8 };
    assert(std.mem.compare(u8, wanted, output[0..wanted.len]) == std.mem.Compare.Equal);
}

test "bar" {
    std.debug.warn("\n");
    var fft = FFT.init();
    defer fft.deinit();
    const data = "69317163492948606335995924319873";
    fft.parse(data, 1);

    const allocator = std.heap.direct_allocator;
    var output: []u8 = allocator.alloc(u8, data.len) catch @panic("FUCK\n");
    fft.run_phases(100, output[0..], data.len);
    const wanted = [_]u8{ 5, 2, 4, 3, 2, 1, 3, 3 };
    assert(std.mem.compare(u8, wanted, output[0..wanted.len]) == std.mem.Compare.Equal);
}
