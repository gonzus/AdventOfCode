const std = @import("std");
const assert = std.debug.assert;

pub const Image = struct {
    allocator: *std.mem.Allocator,
    w: usize,
    h: usize,
    l: usize,
    data: [128 * 25 * 6]u8,

    pub fn init(allocator: *std.mem.Allocator, w: usize, h: usize) Image {
        var self = Image{
            .allocator = allocator,
            .w = w,
            .h = h,
            .l = 0,
            .data = undefined,
        };
        return self;
    }

    pub fn deinit(self: Image) void {
        std.debug.warn("DEINIT {} layers\n", self.l);
        // self.allocator.free(self.data);
    }

    fn pos(self: Image, l: usize, h: usize, w: usize) usize {
        return l * self.w * self.h + h * self.w + w;
    }

    pub fn parse(self: *Image, data: []const u8) void {
        var j: usize = 0;
        var pl: usize = 0;
        var ph: usize = 0;
        var pw: usize = 0;

        const layer_size = self.w * self.h;
        const num_layers = (data.len + layer_size - 1) / layer_size;
        if (self.l < num_layers) {
            if (self.l > 0) {
                std.debug.warn("FREE {} layers\n", self.l);
                // self.allocator.free(self.data);
                self.l = 0;
            }
            // self.data = self.allocator.alloc(u8, layer_size * num_layers);
            self.l = num_layers;
            std.debug.warn("ALLOC {} layers\n", self.l);
        }
        while (j < data.len) : (j += 1) {
            const c = data[j] - '0';
            self.data[self.pos(pl, ph, pw)] = c;
            // std.debug.warn("DATA {} {} {} = {}\n", pl, ph, pw, c);
            pw += 1;
            if (pw >= self.w) {
                pw = 0;
                ph += 1;
            }
            if (ph >= self.h) {
                pw = 0;
                ph = 0;
                pl += 1;
            }
        }
        self.l = pl;
    }

    pub fn find_layer_with_fewest_zeros(self: *Image) usize {
        var m0: usize = std.math.maxInt(u32);
        var ml: usize = 0;
        var mp: usize = 0;
        var pl: usize = 0;
        while (pl < self.l) : (pl += 1) {
            var c0: usize = 0;
            var c1: usize = 0;
            var c2: usize = 0;
            var ph: usize = 0;
            while (ph < self.h) : (ph += 1) {
                var pw: usize = 0;
                while (pw < self.w) : (pw += 1) {
                    switch (self.data[self.pos(pl, ph, pw)]) {
                        0 => c0 += 1,
                        1 => c1 += 1,
                        2 => c2 += 1,
                        else => break,
                    }
                }
            }
            // std.debug.warn("LAYER {} has {} zeros\n", pl, c0);
            if (m0 > c0) {
                m0 = c0;
                ml = pl;
                mp = c1 * c2;
            }
        }
        // std.debug.warn("LAYER MIN is {} has {} zeros product is {}\n", ml, m0, mp);
        return mp;
    }

    pub fn render(self: *Image) void {
        var ph: usize = 0;
        while (ph < self.h) : (ph += 1) {
            var pw: usize = 0;
            while (pw < self.w) : (pw += 1) {
                var pl: usize = 0;
                while (pl < self.l) : (pl += 1) {
                    const c = self.data[self.pos(pl, ph, pw)];
                    if (c == 2) {
                        continue;
                    } else if (c == 0) {
                        std.debug.warn(" ");
                    } else if (c == 1) {
                        std.debug.warn("\u{2588}");
                    } else {}
                    break;
                }
            }
            std.debug.warn("\n");
        }
    }
};

test "total orbit count" {
    const data: []const u8 = "123456789012";
    var image = Image.init(std.heap.direct_allocator, 3, 2);
    defer image.deinit();

    image.parse(data);
    assert(image.l == 2);
    const result = image.find_layer_with_fewest_zeros();
}
