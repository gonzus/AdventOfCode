const std = @import("std");
const assert = std.debug.assert;

pub const Image = struct {
    const Color = enum(u8) {
        Black = 0,
        White = 1,
        Transparent = 2,
        LAST = 3,
        OTHER = 99,
    };

    allocator: *std.mem.Allocator,
    w: usize,
    h: usize,
    l: usize,
    data: [128 * 25 * 6]Color,

    // the intention was to dynamically allocate data, but I got a compiler error:
    //
    //     broken LLVM module found: Call parameter type does not match function signature!
    //   %31 = getelementptr inbounds %Image, %Image* %30, i32 0, i32 4, !dbg !1078
    //  { %"[]u8", i16 }*  call fastcc void @std.mem.Allocator.alloc(%"[]u8"* sret %31, %std.builtin.StackTrace* %error_return_trace, %std.mem.Allocator* %34, i64 %38), !dbg !1121
    //
    // Unable to dump stack trace: debug info stripped
    // make: *** [img.zig_test] Abort trap: 6

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
        // std.debug.warn("DEINIT {} layers\n", self.l);
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
                // std.debug.warn("FREE {} layers\n", self.l);
                // self.allocator.free(self.data);
                self.l = 0;
            }
            // self.data = self.allocator.alloc(u8, layer_size * num_layers);
            self.l = num_layers;
            // std.debug.warn("ALLOC {} layers\n", self.l);
        }
        while (j < data.len) : (j += 1) {
            var num = data[j] - '0';
            if (num >= @enumToInt(Color.LAST)) num = @enumToInt(Color.OTHER);
            const color = @intToEnum(Color, num);
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

    pub fn find_layer_with_fewest_blacks(self: *Image) usize {
        var min_black: usize = std.math.maxInt(u32);
        var min_product: usize = 0;
        var l: usize = 0;
        while (l < self.l) : (l += 1) {
            var count_black: usize = 0;
            var count_white: usize = 0;
            var count_trans: usize = 0;
            var r: usize = 0;
            while (r < self.h) : (r += 1) {
                var c: usize = 0;
                while (c < self.w) : (c += 1) {
                    switch (self.data[self.pos(l, c, r)]) {
                        Color.Black => count_black += 1,
                        Color.White => count_white += 1,
                        Color.Transparent => count_trans += 1,
                        else => break,
                    }
                }
            }
            // std.debug.warn("LAYER {} has {} blacks\n", l, count_black);
            if (min_black > count_black) {
                min_black = count_black;
                min_product = count_white * count_trans;
            }
        }
        // std.debug.warn("LAYER MIN has {} blacks, product is {}\n", min_black, min_product);
        return min_product;
    }

    pub fn render(self: *Image) !void {
        const stdout = std.io.getStdOut() catch unreachable;
        const out = &stdout.outStream().stream;
        // std.debug.warn("TYPE [{}]\n", @typeName(@typeOf(out)));
        var r: usize = 0;
        while (r < self.h) : (r += 1) {
            var c: usize = 0;
            while (c < self.w) : (c += 1) {
                var l: usize = 0;
                while (l < self.l) : (l += 1) {
                    const color = self.data[self.pos(l, c, r)];
                    switch (color) {
                        Color.Transparent => continue,
                        Color.Black => {
                            try out.print(" ");
                            break;
                        },
                        Color.White => {
                            try out.print("\u{2588}");
                            break;
                        },
                        else => break,
                    }
                }
            }
            try out.print("\n");
        }
    }
};

test "total orbit count" {
    const data: []const u8 = "123456789012";
    var image = Image.init(std.heap.direct_allocator, 3, 2);
    defer image.deinit();

    image.parse(data);
    assert(image.l == 2);
    const result = image.find_layer_with_fewest_blacks();
}
