const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var maps: [4]Map = undefined;
    var j: usize = 0;
    while (j < 4) : (j += 1) {
        maps[j] = Map.init();
    }
    var r: usize = 0;
    var first: []const u8 = undefined;
    while (std.io.readLine(&buf)) |line| {
        if (r == 0) {
            first = line;
        }
        if (r < 39) {
            maps[0].parse(line[0..41]);
            maps[1].parse(line[40..]);
        } else if (r == 39) {
            line[39] = '@';
            line[40] = '#';
            line[41] = '@';
            maps[0].parse(line[0..41]);
            maps[1].parse(line[40..]);
        } else if (r == 41) {
            line[39] = '@';
            line[40] = '#';
            line[41] = '@';
            maps[2].parse(line[0..41]);
            maps[3].parse(line[40..]);
        } else if (r > 41) {
            maps[2].parse(line[0..41]);
            maps[3].parse(line[40..]);
        } else {
            maps[0].parse(first[0..41]);
            maps[1].parse(first[40..]);
            maps[2].parse(first[0..41]);
            maps[3].parse(first[40..]);
        }
        r += 1;
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }

    var sum: usize = 0;
    j = 0;
    while (j < 4) : (j += 1) {
        var mk = std.AutoHashMap(u8, void).init(std.heap.direct_allocator);
        defer mk.deinit();
        var ik = maps[j].keys.iterator();
        while (ik.next()) |kv| {
            const k = kv.value;
            _ = mk.put(k, {}) catch unreachable;
            // std.debug.warn("MAP {}: mapping key {c}\n", j, k);
        }
        var id = maps[j].doors.iterator();
        while (id.next()) |kv| {
            const d = kv.value;
            const k = d - 'A' + 'a';
            // std.debug.warn("MAP {}: checking door {c}\n", j, d);
            if (mk.contains(k)) continue;
            const p = kv.key;
            // std.debug.warn("MAP {}: removing door {c} without key {c}\n", j, d, k);
            maps[j].set_pos(p, Map.Tile.Empty);
        }

        // maps[j].show();
        maps[j].walk_map();
        const dist = maps[j].walk_graph();
        sum += dist;
    }
    try out.print("TOTAL {}\n", sum);
    j = 0;
    while (j < 4) : (j += 1) {
        maps[j].deinit();
    }
}
