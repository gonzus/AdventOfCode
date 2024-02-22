const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub fn SimpleQueue(comptime E: type) type {
    return struct {
        const Self = @This();

        data: std.ArrayList(E),
        head: usize,

        pub fn init(allocator: Allocator) Self {
            return .{
                .data = std.ArrayList(E).init(allocator),
                .head = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn empty(self: Self) bool {
            return self.head >= self.data.items.len;
        }

        pub fn size(self: Self) usize {
            return self.data.items.len - self.head;
        }

        pub fn clear(self: *Self) void {
            self.data.clearRetainingCapacity();
            self.head = 0;
        }

        pub fn enqueue(self: *Self, value: E) !void {
            try self.data.append(value);
        }

        pub fn dequeue(self: *Self) !E {
            if (self.head >= self.data.items.len) return error.QueueEmpty;
            const v = self.data.items[self.head];
            self.head += 1;
            if (self.head == self.data.items.len) self.clear();
            return v;
        }
    };
}

test "SimpleQueue" {
    const Queue = SimpleQueue(usize);
    var q = Queue.init(testing.allocator);
    defer q.deinit();

    try testing.expectEqual(q.size(), 0);
    try testing.expect(q.empty());
    try testing.expectError(error.QueueEmpty, q.dequeue());

    const size = 5;
    for (0..size) |v| {
        try testing.expectEqual(q.size(), v);
        try q.enqueue(v);
    }
    try testing.expectEqual(q.size(), size);

    for (0..size) |v| {
        const d = try q.dequeue();
        try testing.expectEqual(d, v);
    }
    try testing.expectEqual(q.size(), 0);
    try testing.expect(q.empty());
    try testing.expectError(error.QueueEmpty, q.dequeue());
}
