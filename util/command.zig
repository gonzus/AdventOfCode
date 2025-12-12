const std = @import("std");

pub const Part = enum { part1, part2 };

pub const Command = struct {
    // const Allocator = std.heap.DebugAllocator(.{});
    const Allocator = std.heap.GeneralPurposeAllocator(.{});

    gpa: Allocator,
    timer: std.time.Timer,
    input: ?[]const u8,

    pub fn init() !Command {
        return .{
            .gpa = Allocator{},
            .timer = try std.time.Timer.start(),
            .input = null,
        };
    }

    pub fn deinit(self: *Command) void {
        if (self.input) |inp| self.allocator().free(inp);
        _ = self.gpa.deinit();
    }

    pub fn allocator(self: *Command) std.mem.Allocator {
        return self.gpa.allocator();
    }

    pub fn choosePart(self: Command) Part {
        _ = self;
        var args = std.process.args();
        // skip my own exe name
        _ = args.skip();
        var part: u8 = 0;
        while (args.next()) |arg| {
            part = std.fmt.parseInt(u8, arg, 10) catch 0;
            break;
        }
        return switch (part) {
            1 => .part1,
            2 => .part2,
            else => @panic("Invalid part"),
        };
    }

    pub fn readInput(self: *Command) ![]const u8 {
        var reader = std.fs.File.stdin().readerStreaming(&.{});
        self.input = try reader.interface.allocRemaining(self.allocator(), .limited(1 << 20));
        return std.mem.trim(u8, self.input.?, "\r\n");
    }

    pub fn showResults(self: *Command, part: Part, answer: anytype) !void {
        var writer = std.fs.File.stdout().writer(&.{});
        try writer.interface.print("--- {s} ---\n", .{@tagName(part)});
        try writer.interface.print("Answer: {}\n", .{answer});
        try writer.interface.print("Elapsed: {}us\n", .{self.getElapsedUs()});
        try writer.interface.flush();
    }

    fn getElapsedMs(self: *Command) u64 {
        return self.timer.read() / std.time.ns_per_ms;
    }

    fn getElapsedUs(self: *Command) u64 {
        return self.timer.read() / std.time.ns_per_us;
    }
};
