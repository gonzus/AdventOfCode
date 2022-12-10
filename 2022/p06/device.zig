const std = @import("std");
const testing = std.testing;

pub const Device = struct {
    message: []const u8,
    count: [256]usize,

    pub fn init() Device {
        var self = Device{
            .message = undefined,
            .count = undefined,
        };
        return self;
    }

    pub fn feed(self: *Device, line: []const u8) !void {
        self.message = line;
        self.count = [_]usize{0}**256;
    }

    fn find_marker(self: *Device, length: usize) usize {
        var len = length - 1;
        var end: usize = 0;
        while (end < self.message.len) : (end += 1) {
            self.count[self.message[end]] += 1;
            if (end < len) continue;
            var unique = true;
            var beg: usize = end - len;
            while (beg <= end) : (beg += 1) {
                const count = self.count[self.message[beg]];
                if (count != 1) {
                    unique = false;
                    break;
                }
            }
            if (unique) {
                return end + 1;
            }
            self.count[self.message[end-len]] -= 1;
        }
        return 0;
    }

    pub fn find_packet_marker(self: *Device) usize {
        return self.find_marker(4);
    }

    pub fn find_message_marker(self: *Device) usize {
        return self.find_marker(14);
    }
};

const TestData = struct {
    text: []const u8,
    marker: usize,
};

test "sample part 1" {
    const cases = [_]TestData{
        TestData{ .text = "mjqjpqmgbljsphdztnvjfqwrcgsmlb", .marker = 7},
        TestData{ .text = "bvwbjplbgvbhsrlpgdmjqwftvncz", .marker = 5},
        TestData{ .text = "nppdvjthqldpwncqszvftbrmjlhg", .marker = 6},
        TestData{ .text = "nznrnfrfntjfmvfwmzdfjlvtqnbhcprsg", .marker = 10},
        TestData{ .text = "zcfzfwzzqfrljwzlrfnpqdbhtmscgvjw", .marker = 11},
    };

    var device = Device.init();
    for (cases) |case| {
        try device.feed(case.text);
        const offset = device.find_packet_marker();
        try testing.expectEqual(offset, case.marker);
    }
}

test "sample part 2" {
    const cases = [_]TestData{
        TestData{ .text = "mjqjpqmgbljsphdztnvjfqwrcgsmlb", .marker = 19},
        TestData{ .text = "bvwbjplbgvbhsrlpgdmjqwftvncz", .marker = 23},
        TestData{ .text = "nppdvjthqldpwncqszvftbrmjlhg", .marker = 23},
        TestData{ .text = "nznrnfrfntjfmvfwmzdfjlvtqnbhcprsg", .marker = 29},
        TestData{ .text = "zcfzfwzzqfrljwzlrfnpqdbhtmscgvjw", .marker = 26},
    };

    var device = Device.init();
    for (cases) |case| {
        try device.feed(case.text);
        const offset = device.find_message_marker();
        try testing.expectEqual(offset, case.marker);
    }
}
