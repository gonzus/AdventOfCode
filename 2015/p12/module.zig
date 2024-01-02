const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Document = struct {
    allocator: Allocator,
    text: std.ArrayList(u8),
    ignore_red: bool,

    pub fn init(allocator: Allocator, ignore_red: bool) Document {
        const self = Document{
            .allocator = allocator,
            .text = std.ArrayList(u8).init(allocator),
            .ignore_red = ignore_red,
        };
        return self;
    }

    pub fn deinit(self: *Document) void {
        self.text.deinit();
    }

    pub fn addLine(self: *Document, line: []const u8) !void {
        self.text.clearRetainingCapacity();
        try self.text.appendSlice(line);
    }

    pub fn getSumOfNumbers(self: *Document) !isize {
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, self.text.items, .{});
        defer parsed.deinit();
        return try self.getSumOfJSONValueElements(parsed.value);
    }

    fn getSumOfJSONValueElements(self: Document, value: std.json.Value) !isize {
        return switch (value) {
            .integer => |i| i,
            .array => |a| blk: {
                var sum: isize = 0;
                for (a.items) |v| {
                    sum += try self.getSumOfJSONValueElements(v);
                }
                break :blk sum;
            },
            .object => |o| blk: {
                var sum: isize = 0;
                var it = o.iterator();
                while (it.next()) |e| {
                    const v = e.value_ptr.*;
                    if (self.shouldIgnoreObject(v)) {
                        sum = 0;
                        break;
                    }
                    sum += try self.getSumOfJSONValueElements(v);
                }
                break :blk sum;
            },
            .string => 0,
            else => unreachable,
        };
    }

    fn shouldIgnoreObject(self: Document, value: std.json.Value) bool {
        if (!self.ignore_red) return false;
        return switch (value) {
            .string => |s| std.mem.eql(u8, s, "red"),
            else => false,
        };
    }
};

test "sample part 1" {
    {
        var document = Document.init(std.testing.allocator, false);
        defer document.deinit();
        try document.addLine(
            \\[]
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 0);
        try testing.expectEqual(expected, sum);
    }
    {
        var document = Document.init(std.testing.allocator, false);
        defer document.deinit();
        try document.addLine(
            \\{}
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 0);
        try testing.expectEqual(expected, sum);
    }
    {
        var document = Document.init(std.testing.allocator, false);
        defer document.deinit();
        try document.addLine(
            \\[1,2,3]
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 6);
        try testing.expectEqual(expected, sum);
    }
    {
        var document = Document.init(std.testing.allocator, false);
        defer document.deinit();
        try document.addLine(
            \\{"a":2,"b":4}
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 6);
        try testing.expectEqual(expected, sum);
    }
    {
        var document = Document.init(std.testing.allocator, false);
        defer document.deinit();
        try document.addLine(
            \\[[[3]]]
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 3);
        try testing.expectEqual(expected, sum);
    }
    {
        var document = Document.init(std.testing.allocator, false);
        defer document.deinit();
        try document.addLine(
            \\{"a":{"b":4},"c":-1}
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 3);
        try testing.expectEqual(expected, sum);
    }
    {
        var document = Document.init(std.testing.allocator, false);
        defer document.deinit();
        try document.addLine(
            \\{"a":[-1,1]}
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 0);
        try testing.expectEqual(expected, sum);
    }
    {
        var document = Document.init(std.testing.allocator, false);
        defer document.deinit();
        try document.addLine(
            \\[-1,{"a":1}]
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 0);
        try testing.expectEqual(expected, sum);
    }
}

test "sample part 2" {
    {
        var document = Document.init(std.testing.allocator, true);
        defer document.deinit();
        try document.addLine(
            \\[1,2,3]
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 6);
        try testing.expectEqual(expected, sum);
    }
    {
        var document = Document.init(std.testing.allocator, true);
        defer document.deinit();
        try document.addLine(
            \\[1,{"c":"red","b":2},3]
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 4);
        try testing.expectEqual(expected, sum);
    }
    {
        var document = Document.init(std.testing.allocator, true);
        defer document.deinit();
        try document.addLine(
            \\{"d":"red","e":[1,2,3,4],"f":5}
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 0);
        try testing.expectEqual(expected, sum);
    }
    {
        var document = Document.init(std.testing.allocator, true);
        defer document.deinit();
        try document.addLine(
            \\[1,"red",5]
        );
        const sum = try document.getSumOfNumbers();
        const expected = @as(isize, 6);
        try testing.expectEqual(expected, sum);
    }
}
