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

pub fn SimpleDeque(comptime E: type) type {
    return struct {
        const Self = @This();

        data: std.ArrayList(E),
        head: usize,
        tail: usize,

        pub fn init(allocator: Allocator) Self {
            return .{
                .data = std.ArrayList(E).init(allocator),
                .head = 0,
                .tail = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn format(
            q: Self,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("dequeue", .{});
            for (q.head..q.tail) |p| {
                const c: u8 = if (p == q.head) '[' else ',';
                _ = try writer.print("{c}{}", .{ c, q.data.items[p] });
            }
            _ = try writer.print("]", .{});
        }

        pub fn empty(self: Self) bool {
            return self.tail <= self.head;
        }

        pub fn size(self: Self) usize {
            if (self.empty()) return 0;
            return self.tail - self.head;
        }

        pub fn items(self: Self) []E {
            return self.data.items[self.head..self.tail];
        }

        pub fn clear(self: *Self) void {
            self.data.clearRetainingCapacity();
            self.head = self.data.items.len / 2;
            self.tail = self.head;
        }

        pub fn appendTail(self: *Self, value: E) !void {
            if (self.tail < self.data.items.len) {
                self.data.items[self.tail] = value;
            } else {
                try self.data.append(value);
            }
            self.tail += 1;
        }

        pub fn appendTailItems(self: *Self, values: []const E) !void {
            for (values) |value| {
                try self.appendTail(value);
            }
        }

        pub fn popTail(self: *Self) !E {
            if (self.empty()) return error.DequeEmpty;
            self.tail -= 1;
            return self.data.items[self.tail];
        }

        pub fn append(self: *Self, value: E) !void {
            try self.appendTail(value);
        }

        pub fn appendItems(self: *Self, values: []const E) !void {
            try self.appendTailItems(values);
        }

        pub fn pop(self: *Self) !E {
            return try self.popTail();
        }

        pub fn rotate(self: *Self, count: isize) !void {
            const sz = self.size();
            if (sz <= 1) return;
            if (count < 0) {
                var shift: usize = @intCast(-count);
                shift %= sz;
                const available = self.data.items.len - self.tail;
                if (available < shift) {
                    const extra = shift - available;
                    _ = try self.data.addManyAt(self.data.items.len, extra);
                }
                for (0..shift) |s| {
                    self.data.items[self.tail + s] = self.data.items[self.head + s];
                }
                self.head += shift;
                self.tail += shift;
            } else if (count > 0) {
                var shift: usize = @intCast(count);
                shift %= sz;
                const available = self.head;
                if (available < shift) {
                    const extra = shift - available;
                    _ = try self.data.addManyAt(0, extra);
                    self.head += extra;
                    self.tail += extra;
                }
                for (0..shift) |n| {
                    self.data.items[self.head - shift + n] = self.data.items[self.tail - shift + n];
                }
                self.head -= shift;
                self.tail -= shift;
            }
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

test "SimpleDeque basic" {
    const DQ = SimpleDeque(usize);
    var q = DQ.init(testing.allocator);
    defer q.deinit();

    try testing.expectEqual(q.size(), 0);
    try testing.expect(q.empty());

    const items = [_]usize{ 1, 2, 3 };
    for (0..items.len) |v| {
        const i = items[v];
        try q.append(i);
        try testing.expectEqual(q.size(), v + 1);
        try testing.expect(!q.empty());
    }
    for (0..items.len) |n| {
        const v = items.len - n - 1;
        const i = items[v];
        const e = try q.pop();
        try testing.expectEqual(e, i);
        try testing.expectEqual(q.size(), v);
    }
    try testing.expect(q.empty());
}

test "SimpleDeque rotate positive" {
    const DQ = SimpleDeque(usize);
    var q = DQ.init(testing.allocator);
    defer q.deinit();
    var len: usize = 0;

    {
        const items = [_]usize{ 1, 2, 3, 4, 5, 6 };
        try q.appendTailItems(&items);
        len += items.len;
        try testing.expectEqual(q.size(), len);

        try q.rotate(2); // [5, 6, 1, 2, 3, 4]
        try testing.expectEqual(q.size(), len);

        const rotated = q.items();
        const expected = [_]usize{ 5, 6, 1, 2, 3, 4 };
        try testing.expectEqualSlices(usize, rotated, &expected);
    }

    {
        const items = [_]usize{ 7, 8 };
        try q.appendTailItems(&items); // [ 5, 6, 1, 2, 3, 4, 7, 8 ]
        len += items.len;
        try testing.expectEqual(q.size(), len);

        try q.rotate(-2); // [ 1, 2, 3, 4, 7, 8, 5, 6 ]
        try testing.expectEqual(q.size(), len);

        const rotated = q.items();
        const expected = [_]usize{ 1, 2, 3, 4, 7, 8, 5, 6 };
        try testing.expectEqualSlices(usize, rotated, &expected);

        for (0..expected.len) |n| {
            const p = expected.len - 1 - n;
            const popped = try q.pop();
            len -= 1;
            try testing.expectEqual(expected[p], popped);
            try testing.expectEqual(q.size(), len);
        }
        try testing.expect(q.empty());
    }
}

test "SimpleDeque rotate negative" {
    const DQ = SimpleDeque(usize);
    var q = DQ.init(testing.allocator);
    defer q.deinit();
    var len: usize = 0;

    {
        const items = [_]usize{ 1, 2, 3, 4, 5, 6 };
        try q.appendTailItems(&items);
        len += items.len;
        try testing.expectEqual(q.size(), len);

        try q.rotate(-2); // [3, 4, 5, 6, 1, 2]
        try testing.expectEqual(q.size(), len);

        const rotated = q.items();
        const expected = [_]usize{ 3, 4, 5, 6, 1, 2 };
        try testing.expectEqualSlices(usize, rotated, &expected);
    }

    {
        const items = [_]usize{ 7, 8 };
        try q.appendTailItems(&items); // [ 3, 4, 5, 6, 1, 2, 7, 8 ]
        len += items.len;
        try testing.expectEqual(q.size(), len);

        try q.rotate(2); // [ 7, 8, 3, 4, 5, 6, 1, 2 ]
        try testing.expectEqual(q.size(), len);

        const rotated = q.items();
        const expected = [_]usize{ 7, 8, 3, 4, 5, 6, 1, 2 };
        try testing.expectEqualSlices(usize, rotated, &expected);

        for (0..expected.len) |n| {
            const p = expected.len - 1 - n;
            const popped = try q.pop();
            len -= 1;
            try testing.expectEqual(expected[p], popped);
            try testing.expectEqual(q.size(), len);
        }
        try testing.expect(q.empty());
    }
}
