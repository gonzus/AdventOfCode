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

    fn pos(self: Image, l: usize, c: usize, r: usize) usize {
        return (l * self.h + r) * self.w + c;
    }

    pub fn parse(self: *Image, data: []const u8) void {
        var j: usize = 0;
        var l: usize = 0;
        var r: usize = 0;
        var c: usize = 0;

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
            const color = data[j] - '0';
            self.data[self.pos(l, c, r)] = color;
            // std.debug.warn("DATA {} {} {} = {}\n", l, r, c, color);
            c += 1;
            if (c >= self.w) {
                c = 0;
                r += 1;
            }
            if (r >= self.h) {
                c = 0;
                r = 0;
                l += 1;
            }
        }
        self.l = l;
    }

    pub fn find_layer_with_fewest_zeros(self: *Image) usize {
        var m0: usize = std.math.maxInt(u32);
        var ml: usize = 0;
        var mp: usize = 0;
        var l: usize = 0;
        while (l < self.l) : (l += 1) {
            var c0: usize = 0;
            var c1: usize = 0;
            var c2: usize = 0;
            var r: usize = 0;
            while (r < self.h) : (r += 1) {
                var c: usize = 0;
                while (c < self.w) : (c += 1) {
                    switch (self.data[self.pos(l, c, r)]) {
                        0 => c0 += 1,
                        1 => c1 += 1,
                        2 => c2 += 1,
                        else => break,
                    }
                }
            }
            // std.debug.warn("LAYER {} has {} zeros\n", l, c0);
            if (m0 > c0) {
                m0 = c0;
                ml = l;
                mp = c1 * c2;
            }
        }
        // std.debug.warn("LAYER MIN is {} has {} zeros product is {}\n", ml, m0, mp);
        return mp;
    }

    pub fn render(self: *Image) void {
        var r: usize = 0;
        while (r < self.h) : (r += 1) {
            var c: usize = 0;
            while (c < self.w) : (c += 1) {
                var l: usize = 0;
                while (l < self.l) : (l += 1) {
                    const color = self.data[self.pos(l, c, r)];
                    if (color == 2) {
                        continue;
                    } else if (color == 0) {
                        std.debug.warn(" ");
                    } else if (color == 1) {
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
