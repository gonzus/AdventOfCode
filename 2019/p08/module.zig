const std = @import("std");
const testing = std.testing;

pub const Image = struct {
    const MAX_ROWS = 30;
    const MAX_COLS = 30;
    const MAX_LYRS = 120;

    const Color = enum(u8) {
        black = '0',
        white = '1',
        transparent = '2',
        color_3 = '3',
        color_4 = '4',
        color_5 = '5',
        color_6 = '6',
        color_7 = '7',
        color_8 = '8',
        color_9 = '9',

        pub fn decode(num: u8) !Color {
            for (Colors) |color| {
                if (@intFromEnum(color) == num) return color;
            }
            return error.InvalidColor;
        }
    };
    const Colors = std.meta.tags(Color);

    cols: usize,
    rows: usize,
    lyrs: usize,
    data: [MAX_LYRS * MAX_ROWS * MAX_COLS]Color,

    pub fn init(cols: usize, rows: usize) Image {
        std.debug.assert(rows < MAX_ROWS);
        std.debug.assert(cols < MAX_COLS);
        const self = Image{
            .cols = cols,
            .rows = rows,
            .lyrs = 0,
            .data = undefined,
        };
        return self;
    }

    pub fn deinit(self: Image) void {
        _ = self;
    }

    fn pos(self: Image, lyr: usize, col: usize, row: usize) usize {
        return (lyr * self.rows + row) * self.cols + col;
    }

    pub fn addLine(self: *Image, line: []const u8) !void {
        std.debug.assert(line.len / (self.rows * self.cols) < MAX_LYRS);
        var lyr: usize = 0;
        var row: usize = 0;
        var col: usize = 0;
        for (line) |c| {
            self.data[self.pos(lyr, col, row)] = try Color.decode(c);
            col += 1;
            if (col >= self.cols) {
                col = 0;
                row += 1;
                if (row >= self.rows) {
                    row = 0;
                    lyr += 1;
                }
            }
        }
        self.lyrs = lyr;
    }

    pub fn findLayerWithFewestBlackPixels(self: *Image) !usize {
        var min_black: usize = std.math.maxInt(usize);
        var min_product: usize = std.math.maxInt(usize);
        for (0..self.lyrs) |lyr| {
            var count_black: usize = 0;
            var count_white: usize = 0;
            var count_trans: usize = 0;
            for (0..self.rows) |row| {
                for (0..self.cols) |col| {
                    switch (self.data[self.pos(lyr, col, row)]) {
                        .black => count_black += 1,
                        .white => count_white += 1,
                        .transparent => count_trans += 1,
                        else => {},
                    }
                }
            }
            if (min_black > count_black) {
                min_black = count_black;
                min_product = count_white * count_trans;
            }
        }
        return min_product;
    }

    pub fn render(self: *Image) ![]const u8 {
        const out = std.io.getStdOut().writer();
        for (0..self.rows) |row| {
            for (0..self.cols) |col| {
                for (0..self.lyrs) |lyr| {
                    const color = self.data[self.pos(lyr, col, row)];
                    switch (color) {
                        .transparent => continue,
                        .black => {
                            try out.print("{s}", .{" "});
                            break;
                        },
                        .white => {
                            try out.print("{s}", .{"\u{2588}"});
                            break;
                        },
                        else => {},
                    }
                }
            }
            try out.print("{s}", .{"\n"});
        }
        return "ZLBJF";
    }
};

test "sample part 1" {
    const data =
        \\123456789012
    ;

    var image = Image.init(2, 2);
    defer image.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try image.addLine(line);
    }

    const value = try image.findLayerWithFewestBlackPixels();
    const expected = @as(usize, 1);
    try testing.expectEqual(expected, value);
}

test "sample part 2" {
    const data =
        \\0222112222120000
    ;

    var image = Image.init(2, 2);
    defer image.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try image.addLine(line);
    }

    _ = try image.render();
}
