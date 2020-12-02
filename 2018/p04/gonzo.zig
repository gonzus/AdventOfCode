const std = @import("std");
const assert = std.debug.assert;

pub const Gonzo = struct {
    const allocator = std.heap.direct_allocator;

    pub const Data = struct {
        id: usize,
        map: std.AutoHashMap(usize, usize),

        pub fn init(id: usize) Data {
            std.debug.warn("Data init {}\n", id);
            return Data{
                .id = id,
                .map = std.AutoHashMap(usize, usize).init(allocator),
            };
        }

        pub fn deinit(self: *Data) void {
            self.map.deinit();
            std.debug.warn("Data {} deinit\n", self.id);
        }

        pub fn show(self: *Data) void {
            // std.debug.warn("Data {}: {} entries\n", self.id, self.map.count());
            var it = self.map.iterator();
            while (it.next()) |data| {
                std.debug.warn("data {} = {}\n", data.key, data.value);
            }
        }

        pub fn add_entry(self: *Data, k: usize, v: usize) void {
            _ = self.map.put(k, v) catch unreachable;
            std.debug.warn("Data {}: add_entry {} {}\n", self.id, k, v);
        }
    };

    pub const Meta = struct {
        id: usize,
        map: std.AutoHashMap(usize, Data),

        pub fn init(id: usize) Data {
            std.debug.warn("Meta init {}\n", id);
            return Meta{
                .id = id,
                .map = std.AutoHashMap(usize, Data).init(allocator),
            };
        }

        pub fn deinit(self: *Meta) void {
            var it = self.map.iterator();
            while (it.next()) |data| {
                data.value.deinit();
            }
            self.map.deinit();
            std.debug.warn("Meta {} deinit\n", self.id);
        }

        pub fn show(self: *Meta) void {
            // std.debug.warn("Meta {}: {} entries\n", self.id, self.map.count());
            var it = self.map.iterator();
            while (it.next()) |data| {
                std.debug.warn("data {} =\n", data.key);
                data.value.show();
            }
        }

        pub fn add_entry(self: *Meta, m: usize, k: usize, v: usize) void {
            var d: Data = undefined;
            if (self.map.contains(m)) {
                d = self.map.get(m).?.value;
            } else {
                d = Data.init(m);
                _ = self.map.put(m, d) catch unreachable;
                std.debug.warn("Meta created data for {}\n", m);
            }
            _ = d.put(k, v) catch unreachable;
            std.debug.warn("Meta {}: add_entry {} {}\n", m, k, v);
        }
    };

    blurb: Data,

    pub fn init() Gonzo {
        std.debug.warn("Gonzo init\n");
        return Gonzo{
            .blurb = Meta.init(11),
        };
    }

    pub fn deinit(self: *Gonzo) void {
        self.blurb.deinit();
        std.debug.warn("Gonzo deinit\n");
    }

    pub fn show(self: *Gonzo) void {
        self.blurb.show();
    }

    // map: std.AutoHashMap(usize, Meta),

    // pub fn init() Data {
    //     std.debug.warn("Gonzo init\n");
    //     return Gonzo{
    //         .map = std.AutoHashMap(usize, Meta).init(allocator),
    //     };
    // }

    // pub fn deinit(self: *Gonzo) void {
    //     var it = self.map.iterator();
    //     while (it.next()) |data| {
    //         data.value.deinit();
    //     }
    //     self.map.deinit();
    //     std.debug.warn("Gonzo {} deinit\n", self.id);
    // }

    // pub fn show(self: *Gonzo) void {
    //     std.debug.warn("Gonzo: {} entries\n", self.map.cont());
    //     var it = self.map.iterator();
    //     while (it.next()) |data| {
    //         std.debug.warn("meta {} =\n", data.key);
    //         data.value.show();
    //     }
    // }
};

test "simple" {
    @breakpoint();
    std.debug.warn("\n");
    var g = Gonzo.init();
    defer g.deinit();
    g.show();
}
