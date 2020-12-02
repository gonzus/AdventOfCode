const std = @import("std");
const assert = std.debug.assert;

pub const Shift = struct {
    const allocator = std.heap.direct_allocator;

    // data{guard}{julian}{stamp} => asleep

    pub const SData = struct {
        asleep: bool,

        pub fn init() SData {
            return SData{
                .asleep = undefined,
            };
        }

        pub fn deinit(self: *SData) void {
            // std.debug.warn("SData deinit\n");
        }

        pub fn add_entry(self: *SData, a: bool) void {
            self.asleep = a;
            // std.debug.warn("SData add_entry {}\n", a);
        }
    };

    pub const JData = struct {
        j: usize,
        sdata: std.AutoHashMap(usize, SData),
        smin: usize,
        smax: usize,

        pub fn init(j: usize) JData {
            // std.debug.warn("JData init {}\n", j);
            return JData{
                .j = j,
                .sdata = std.AutoHashMap(usize, SData).init(allocator),
                .smin = std.math.maxInt(usize),
                .smax = 0,
            };
        }

        pub fn deinit(self: *JData) void {
            var it = self.sdata.iterator();
            while (it.next()) |data| {
                data.value.deinit();
            }
            self.sdata.deinit();
            // std.debug.warn("JData deinit\n");
        }

        pub fn show(self: *JData) void {
            std.debug.warn("JData [{}]:\n", self.j);
            var it = self.sdata.iterator();
            while (it.next()) |data| {
                std.debug.warn("sdata {} = {}\n", data.key, data.value.asleep);
            }
        }

        pub fn add_entry(self: *JData, s: usize, a: bool) void {
            var d: SData = undefined;
            if (self.sdata.contains(s)) {
                d = self.sdata.get(s).?.value;
            } else {
                d = SData.init();
            }
            d.add_entry(a);
            _ = self.sdata.put(s, d) catch unreachable;
            if (self.smin > s) self.smin = s;
            if (self.smax < s) self.smax = s;
            // std.debug.warn("JData add_entry {} {}\n", s, a);
        }
    };

    pub const GData = struct {
        g: usize,
        jdata: std.AutoHashMap(usize, JData),
        jmin: usize,
        jmax: usize,

        pub fn init(g: usize) GData {
            // std.debug.warn("GData init {}\n", g);
            return GData{
                .g = g,
                .jdata = std.AutoHashMap(usize, JData).init(allocator),
                .jmin = std.math.maxInt(usize),
                .jmax = 0,
            };
        }

        pub fn deinit(self: *GData) void {
            var it = self.jdata.iterator();
            while (it.next()) |data| {
                // std.debug.warn("Calling deinit for jdata {}\n", data.key);
                data.value.deinit();
            }
            self.jdata.deinit();
            // std.debug.warn("GData deinit\n");
        }

        pub fn show(self: *GData) void {
            std.debug.warn("GData [{}]:\n", self.g);
            var it = self.jdata.iterator();
            while (it.next()) |data| {
                std.debug.warn("jdata {} =\n", data.key);
                data.value.show();
            }
        }

        pub fn add_entry(self: *GData, j: usize, s: usize, a: bool) void {
            // std.debug.warn("jdata {} has {} elements\n", self.g, self.jdata.count());
            var d: JData = undefined;
            if (self.jdata.contains(j)) {
                d = self.jdata.get(j).?.value;
            } else {
                d = JData.init(j);
                // std.debug.warn("GData created jdata for {}\n", j);
            }
            // std.debug.warn("jdata {} has {} elements\n", self.g, self.jdata.count());
            // if (!self.jdata.contains(j)) {
            //     std.debug.warn("GData stil does not have jdata for {}\n", j);
            // } else {
            //     std.debug.warn("GData now has jdata for {}\n", j);
            // }
            // std.debug.warn("GData got jdata for {}\n", j);
            d.add_entry(s, a);
            _ = self.jdata.put(j, d) catch unreachable;
            if (self.jmin > j) self.jmin = j;
            if (self.jmax < j) self.jmax = j;
            // std.debug.warn("GData add_entry {} {} {}\n", j, s, a);
            // self.show();
        }
    };

    gdata: std.AutoHashMap(usize, GData),
    gcur: usize,

    pub fn init() Shift {
        // std.debug.warn("Shift init\n");
        return Shift{
            .gdata = std.AutoHashMap(usize, GData).init(allocator),
            .gcur = std.math.maxInt(usize),
        };
    }

    pub fn deinit(self: *Shift) void {
        var it = self.gdata.iterator();
        while (it.next()) |data| {
            // std.debug.warn("Calling deinit for gdata {}\n", data.key);
            data.value.deinit();
        }
        self.gdata.deinit();
        // std.debug.warn("Shift deinit\n");
    }

    pub fn show(self: *Shift) void {
        std.debug.warn("Shift:\n");
        var itg = self.gdata.iterator();
        while (itg.next()) |dg| {
            const g = dg.key;
            var itj = dg.value.jdata.iterator();
            while (itj.next()) |dj| {
                const j = dj.key;
                var Y: usize = 0;
                var M: usize = 0;
                var D: usize = 0;
                julian_to_YMD(j, &Y, &M, &D);
                std.debug.warn("{:2}-{:2}  #{:2}  ", M, D, g);
                var la: bool = false;
                var ls: usize = 0;
                var its = dj.value.sdata.iterator();
                while (its.next()) |ds| {
                    const s = ds.key;
                    const a = ds.value;
                    var l: u8 = '.';
                    if (a.asleep) l = '#';
                    std.debug.warn(" {}:{c}", s, l);
                }
                std.debug.warn("\n");
            }
        }
    }

    pub fn add_entry(self: *Shift, g: usize, j: usize, s: usize, a: bool, t: []const u8) void {
        if (g != std.math.maxInt(usize)) {
            self.gcur = g;
        }
        // std.debug.warn("CUT [{}]: {} - {} - {} - {}\n", t, self.gcur, j, s, a);
        // std.debug.warn("gdata has {} elements\n", self.gdata.count());
        var d: GData = undefined;
        if (self.gdata.contains(self.gcur)) {
            d = self.gdata.get(self.gcur).?.value;
        } else {
            d = GData.init(self.gcur);
            // std.debug.warn("Shift created gdata for {}\n", self.gcur);
        }
        // std.debug.warn("gdata has {} elements\n", self.gdata.count());
        // std.debug.warn("Shift got gdata for {}\n", self.gcur);
        d.add_entry(j, s, a);
        _ = self.gdata.put(self.gcur, d) catch unreachable;
    }

    // data{guard}{julian}{stamp} => asleep
    pub fn parse_line(self: *Shift, line: []const u8) void {
        std.debug.warn("CUT [{}]\n", line);
        // @breakpoint();
        const Y = std.fmt.parseInt(isize, line[1..5], 10) catch 0;
        const M = std.fmt.parseInt(isize, line[6..8], 10) catch 0;
        const D = std.fmt.parseInt(isize, line[9..11], 10) catch 0;
        const j = YMD_to_julian(Y, M, D);

        const h = std.fmt.parseInt(isize, line[12..14], 10) catch 0;
        const m = std.fmt.parseInt(isize, line[15..17], 10) catch 0;
        const s = hms_to_stamp(h, m, 0);

        const t = line[19..];

        var a: bool = undefined;
        var g: usize = std.math.maxInt(usize);
        var it = std.mem.separate(t, " ");
        var p: bool = false;
        var q: usize = 0;
        while (it.next()) |piece| {
            q += 1;
            if (q == 1) {
                if (std.mem.compare(u8, piece, "Guard") == std.mem.Compare.Equal) {
                    a = false;
                    p = true;
                    continue;
                }
                if (std.mem.compare(u8, piece, "falls") == std.mem.Compare.Equal) {
                    a = true;
                    continue;
                }
                if (std.mem.compare(u8, piece, "wakes") == std.mem.Compare.Equal) {
                    a = false;
                    continue;
                }
                continue;
            }
            if (q == 2) {
                if (p) {
                    g = std.fmt.parseInt(usize, piece[1..], 10) catch 0;
                    p = false;
                }
                continue;
            }
        }
        self.add_entry(g, j, s, a, t);
        self.show();
    }

    fn YMD_to_julian(Y: isize, M: isize, D: isize) usize {
        const p = @divTrunc(M - 14, 12);
        const x = @divTrunc(1461 * (Y + 4800 + p), 4) +
            @divTrunc(367 * (M - 2 - 12 * p), 12) -
            @divTrunc(3 * @divTrunc(Y + 4900 + p, 100), 4) +
            (D - 32075);
        return @intCast(usize, x);
    }

    fn julian_to_YMD(j: usize, Y: *usize, M: *usize, D: *usize) void {
        var l: isize = @intCast(isize, j + 68569);
        const n = @divTrunc(4 * l, 146097);
        l -= @divTrunc(146097 * n + 3, 4);
        const i = @divTrunc(4000 * (l + 1), 1461001);
        l -= @divTrunc(1461 * i, 4) - 31;
        const h = @divTrunc(80 * l, 2447);
        const k = @divTrunc(h, 11);
        const dd = l - @divTrunc(2447 * h, 80);
        const mm = h + 2 - (12 * k);
        const yy = 100 * (n - 49) + i + k;
        D.* = @intCast(usize, dd);
        M.* = @intCast(usize, mm);
        Y.* = @intCast(usize, yy);
    }

    fn hms_to_stamp(h: isize, m: isize, s: isize) usize {
        const x = (h * 60 + m) * 60 + s;
        return @intCast(usize, x);
    }
};

test "simple" {
    std.debug.warn("\n");
    const data =
        \\[1518-11-01 00:00] Guard #10 begins shift
        \\[1518-11-01 00:05] falls asleep
        \\[1518-11-01 00:25] wakes up
        \\[1518-11-01 00:30] falls asleep
        \\[1518-11-01 00:55] wakes up
        \\[1518-11-01 23:58] Guard #99 begins shift
        \\[1518-11-02 00:40] falls asleep
        \\[1518-11-02 00:50] wakes up
        \\[1518-11-03 00:05] Guard #10 begins shift
        \\[1518-11-03 00:24] falls asleep
        \\[1518-11-03 00:29] wakes up
        \\[1518-11-04 00:02] Guard #99 begins shift
        \\[1518-11-04 00:36] falls asleep
        \\[1518-11-04 00:46] wakes up
        \\[1518-11-05 00:03] Guard #99 begins shift
        \\[1518-11-05 00:45] falls asleep
        \\[1518-11-05 00:55] wakes up
    ;

    var shift = Shift.init();
    defer shift.deinit();

    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        shift.parse_line(line);
    }
}
