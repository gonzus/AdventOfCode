const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;
const DEQueue = @import("./util/queue.zig").DoubleEndedQueue;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const StringId = StringTable.StringId;
    const INFINITY = std.math.maxInt(usize);

    const Signal = enum(u3) {
        FALSE = 0,
        TRUE = 1,
        UNDEF = 2,

        pub fn parse(num: u3) !Signal {
            for (Signals) |signal| {
                if (@intFromEnum(signal) == num) return signal;
            }
            return error.InvalidSignal;
        }
    };
    const Signals = std.meta.tags(Signal);

    const Op = enum(u3) {
        AND = 0,
        OR = 1,
        XOR = 2,

        pub fn parse(str: []const u8) !Op {
            for (Ops) |op| {
                if (std.mem.eql(u8, str, @tagName(op))) return op;
            }
            return error.InvalidOp;
        }
    };
    const Ops = std.meta.tags(Op);

    const OpSet = struct {
        mask: u8,

        pub fn init() OpSet {
            return .{ .mask = 0 };
        }

        pub fn add(self: *OpSet, op: Op) void {
            self.mask |= @intFromEnum(op);
        }

        pub fn equals(self: OpSet, other: OpSet) bool {
            return self.mask == other.mask;
        }
    };

    const OpBool = struct {
        mask: u8,

        pub fn init(op: Op, numeric: bool) OpBool {
            const num: u8 = if (numeric) 1 else 0;
            return .{ .mask = num * 10 + @intFromEnum(op) };
        }

        pub fn equals(self: OpBool, other: OpBool) bool {
            return self.mask == other.mask;
        }
    };

    const Gate = struct {
        op: Op,
        wl: Wire,
        wr: Wire,
        wo: Wire,

        pub fn init(op: Op, wl: Wire, wr: Wire, wo: Wire) Gate {
            return .{ .op = op, .wl = wl, .wr = wr, .wo = wo };
        }

        pub fn eval(self: Gate, wl: Signal, wr: Signal) Signal {
            if (wl == .UNDEF or wr == .UNDEF) return .UNDEF;
            const nl = @intFromEnum(wl);
            const nr = @intFromEnum(wr);
            return @enumFromInt(switch (self.op) {
                .AND => nl & nr,
                .OR => nl | nr,
                .XOR => nl ^ nr,
            });
        }
    };

    const WireParts = struct {
        letter: u8,
        number: usize,

        pub fn init(letter: u8, number: usize) WireParts {
            return .{ .letter = letter, .number = number };
        }

        pub fn isNumeric(self: WireParts) bool {
            return self.number != INFINITY;
        }
    };

    const State = enum { wires, gates };

    const Wire = StringId;
    const WireMap = std.AutoHashMap(Wire, Signal);

    allocator: Allocator,
    strtab: StringTable,
    state: State,
    gates: std.ArrayList(Gate),
    wires: WireMap,
    values: WireMap,
    swapped: [1024]u8,

    pub fn init(allocator: Allocator) Module {
        return .{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .state = .wires,
            .gates = std.ArrayList(Gate).init(allocator),
            .wires = WireMap.init(allocator),
            .values = WireMap.init(allocator),
            .swapped = undefined,
        };
    }

    pub fn deinit(self: *Module) void {
        self.values.deinit();
        self.wires.deinit();
        self.gates.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (line.len == 0) {
            self.state = .gates;
            return;
        }
        switch (self.state) {
            .wires => {
                var it = std.mem.tokenizeAny(u8, line, ": ");
                const name = try self.strtab.add(it.next().?);
                const signal = try Signal.parse(try std.fmt.parseUnsigned(u3, it.next().?, 10));
                _ = try self.wires.put(name, signal);
            },
            .gates => {
                var it = std.mem.tokenizeAny(u8, line, "-> ");
                const wl = try self.strtab.add(it.next().?);
                const op = try Op.parse(it.next().?);
                const wr = try self.strtab.add(it.next().?);
                const wo = try self.strtab.add(it.next().?);
                try self.gates.append(Gate.init(op, wl, wr, wo));
            },
        }
    }

    // pub fn show(self: Module) void {
    //     std.debug.print("Device\n", .{});
    //
    //     {
    //         std.debug.print(" Wires: {}\n", .{self.wires.count()});
    //         var it = self.wires.iterator();
    //         while (it.next()) |e| {
    //             std.debug.print("  {s}: {}\n", .{ self.strtab.get_str(e.key_ptr.*) orelse "***", e.value_ptr.* });
    //         }
    //     }
    //
    //     {
    //         std.debug.print(" Gates: {}\n", .{self.gates.items.len});
    //         for (self.gates.items) |gate| {
    //             std.debug.print("  {s} {s} {s} -> {s}\n", .{
    //                 self.strtab.get_str(gate.wl) orelse "***",
    //                 @tagName(gate.op),
    //                 self.strtab.get_str(gate.wr) orelse "***",
    //                 self.strtab.get_str(gate.wo) orelse "***",
    //             });
    //         }
    //     }
    // }

    pub fn getOutputNumber(self: *Module) !u64 {
        // self.show();
        try self.seedValues();

        while (true) {
            // set values for all output wires that we can
            var touched = false;
            for (self.gates.items) |gate| {
                if (self.values.get(gate.wo)) |v| {
                    if (v != .UNDEF) continue;
                }
                if (self.values.get(gate.wl)) |wl| {
                    if (self.values.get(gate.wr)) |wr| {
                        try self.values.put(gate.wo, gate.eval(wl, wr));
                        touched = true;
                    }
                }
            }

            // no changes? we are done
            if (!touched) break;
        }

        // collect output number
        var pos: u6 = 0;
        var num: u64 = 0;
        while (true) : (pos += 1) {
            const id = self.getWireByParts(WireParts.init('z', pos));
            if (id == INFINITY) break;
            if (self.values.get(id)) |w| {
                if (w == .TRUE) {
                    num |= @as(u64, 1) << pos;
                }
            } else break;
        }
        return num;
    }

    pub fn getSwappedWires(self: *Module) ![]const u8 {
        // self.show();
        try self.seedValues();

        var inp = std.AutoHashMap(Wire, OpSet).init(self.allocator);
        defer inp.deinit();
        var out = std.AutoHashMap(Wire, OpBool).init(self.allocator);
        defer out.deinit();

        var bot: usize = INFINITY;
        var top: usize = 0;
        var zcarry: Wire = undefined;
        const x00 = self.getWireByParts(WireParts.init('x', 0));
        const y00 = self.getWireByParts(WireParts.init('y', 0));
        for (self.gates.items) |gate| {
            if (gate.wl == x00 and gate.wr == y00 and gate.op == .AND) {
                zcarry = gate.wo;
            }
            const po = self.parseWire(gate.wo);
            if (po.letter == 'z' and po.isNumeric()) {
                if (bot > po.number) bot = po.number;
                if (top < po.number) top = po.number;
            }

            const pl = self.parseWire(gate.wl);
            try out.put(gate.wo, OpBool.init(gate.op, pl.isNumeric()));

            const el = try inp.getOrPut(gate.wl);
            if (!el.found_existing) {
                el.value_ptr.* = OpSet.init();
            }
            el.value_ptr.*.add(gate.op);

            const er = try inp.getOrPut(gate.wr);
            if (!er.found_existing) {
                er.value_ptr.* = OpSet.init();
            }
            er.value_ptr.*.add(gate.op);
        }

        const zbot = self.getWireByParts(WireParts.init('z', bot));
        const ztop = self.getWireByParts(WireParts.init('z', top));

        const OS_OR = blk: {
            var os = OpSet.init();
            os.add(.OR);
            break :blk os;
        };
        const OS_AX = blk: {
            var os = OpSet.init();
            os.add(.AND);
            os.add(.XOR);
            break :blk os;
        };

        const OB_XF = OpBool.init(.XOR, false);
        const OB_AF = OpBool.init(.AND, false);
        const OB_OF = OpBool.init(.OR, false);
        const OB_XT = OpBool.init(.XOR, true);
        const OB_AT = OpBool.init(.AND, true);

        var problems = std.ArrayList(Wire).init(self.allocator);
        defer problems.deinit();
        var it = self.values.iterator();
        while (it.next()) |e| {
            const wire = e.key_ptr.*;
            if (wire == zbot) continue;
            if (wire == ztop) continue;
            if (wire == zcarry) continue;

            const parts = self.parseWire(wire);
            if (parts.isNumeric()) {
                if (parts.letter != 'z') continue;
                if (out.get(wire)) |o| {
                    if (o.equals(OB_XF)) continue;
                }
            } else {
                if (inp.get(wire)) |i| {
                    if (out.get(wire)) |o| {
                        if (i.equals(OS_OR) and o.equals(OB_AF)) continue;
                        if (i.equals(OS_AX) and o.equals(OB_XT)) continue;
                        if (i.equals(OS_OR) and o.equals(OB_AT)) continue;
                        if (i.equals(OS_AX) and o.equals(OB_OF)) continue;
                    }
                }
            }
            try problems.append(wire);
        }

        std.sort.heap(Wire, problems.items, self, isWireLessThan);

        var pos: usize = 0;
        for (0..problems.items.len) |p| {
            if (p > 0) {
                self.swapped[pos] = ',';
                pos += 1;
            }
            const name = self.strtab.get_str(problems.items[p]) orelse return error.InvalidWire;
            std.mem.copyForwards(u8, self.swapped[pos..], name);
            pos += name.len;
        }

        return self.swapped[0..pos];
    }

    fn seedValues(self: *Module) !void {
        self.values.clearRetainingCapacity();
        var it = self.wires.iterator();
        while (it.next()) |e| {
            const wire = e.key_ptr.*;
            try self.values.put(wire, e.value_ptr.*);
            for (self.gates.items) |gate| {
                const r = try self.values.getOrPutValue(gate.wo, .UNDEF);
                if (r.value_ptr.* != .UNDEF) continue;
                if (self.values.get(gate.wl)) |wl| {
                    if (self.values.get(gate.wr)) |wr| {
                        r.value_ptr.* = gate.eval(wl, wr);
                    }
                }
            }
        }
    }

    fn parseWire(self: *Module, w: Wire) WireParts {
        var parts = WireParts.init('@', INFINITY);
        if (self.strtab.get_str(w)) |wire| {
            parts.letter = wire[0];
            parts.number = std.fmt.parseUnsigned(usize, wire[1..], 10) catch INFINITY;
        }
        return parts;
    }

    fn getWireByParts(self: *Module, parts: WireParts) Wire {
        var buf: [10]u8 = undefined;
        const txt = std.fmt.bufPrint(&buf, "{c}{d:0>2}", .{ parts.letter, parts.number }) catch return INFINITY;
        if (self.strtab.get_pos(txt)) |id| return id;
        return INFINITY;
    }

    fn isWireLessThan(self: *Module, l: Wire, r: Wire) bool {
        const sl = self.strtab.get_str(l) orelse "***";
        const sr = self.strtab.get_str(r) orelse "***";
        return std.mem.order(u8, sl, sr).compare(std.math.CompareOperator.lt);
    }
};

test "sample part 1 example 1" {
    const data =
        \\x00: 1
        \\x01: 1
        \\x02: 1
        \\y00: 0
        \\y01: 1
        \\y02: 0
        \\
        \\x00 AND y00 -> z00
        \\x01 XOR y01 -> z01
        \\x02 OR y02 -> z02
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const sum = try module.getOutputNumber();
    const expected = @as(u64, 4);
    try testing.expectEqual(expected, sum);
}

test "sample part 1 example 2" {
    const data =
        \\x00: 1
        \\x01: 0
        \\x02: 1
        \\x03: 1
        \\x04: 0
        \\y00: 1
        \\y01: 1
        \\y02: 1
        \\y03: 1
        \\y04: 1
        \\
        \\ntg XOR fgs -> mjb
        \\y02 OR x01 -> tnw
        \\kwq OR kpj -> z05
        \\x00 OR x03 -> fst
        \\tgd XOR rvg -> z01
        \\vdt OR tnw -> bfw
        \\bfw AND frj -> z10
        \\ffh OR nrd -> bqk
        \\y00 AND y03 -> djm
        \\y03 OR y00 -> psh
        \\bqk OR frj -> z08
        \\tnw OR fst -> frj
        \\gnj AND tgd -> z11
        \\bfw XOR mjb -> z00
        \\x03 OR x00 -> vdt
        \\gnj AND wpb -> z02
        \\x04 AND y00 -> kjc
        \\djm OR pbm -> qhw
        \\nrd AND vdt -> hwm
        \\kjc AND fst -> rvg
        \\y04 OR y02 -> fgs
        \\y01 AND x02 -> pbm
        \\ntg OR kjc -> kwq
        \\psh XOR fgs -> tgd
        \\qhw XOR tgd -> z09
        \\pbm OR djm -> kpj
        \\x03 XOR y03 -> ffh
        \\x00 XOR y04 -> ntg
        \\bfw OR bqk -> z06
        \\nrd XOR fgs -> wpb
        \\frj XOR qhw -> z04
        \\bqk OR frj -> z07
        \\y03 OR x01 -> nrd
        \\hwm AND bqk -> z03
        \\tgd XOR rvg -> z12
        \\tnw OR pbm -> gnj
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const sum = try module.getOutputNumber();
    const expected = @as(u64, 2024);
    try testing.expectEqual(expected, sum);
}
