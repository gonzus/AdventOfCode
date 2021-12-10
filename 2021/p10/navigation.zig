const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

const desc_usize = std.sort.desc(usize);

pub const Navigation = struct {
    syntax_error_score: usize,
    completion_scores: std.ArrayList(usize),

    pub fn init() Navigation {
        var self = Navigation{
            .syntax_error_score = 0,
            .completion_scores = std.ArrayList(usize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Navigation) void {
        self.completion_scores.deinit();
    }

    pub fn process_line(self: *Navigation, data: []const u8) !void {
        var stack: [1024]u8 = undefined;
        var pos: usize = 0;
        var score: usize = 0;
        for (data) |c| {
            if (c == '(' or c == '[' or c == '{' or c == '<') {
                stack[pos] = c;
                pos += 1;
                continue;
            }
            if (c == ')' or c == ']' or c == '}' or c == '>') {
                pos -= 1;
                const p = stack[pos];
                if (p == '(' and c == ')') continue;
                if (p == '[' and c == ']') continue;
                if (p == '{' and c == '}') continue;
                if (p == '<' and c == '>') continue;

                if (c == ')') score = 3;
                if (c == ']') score = 57;
                if (c == '}') score = 1197;
                if (c == '>') score = 25137;
                break;
            }
            unreachable;
        }

        if (score > 0) {
            self.syntax_error_score += score;
            return;
        }

        while (pos > 0) {
            pos -= 1;
            const p = stack[pos];
            var s: usize = 0;
            if (p == '(') s = 1;
            if (p == '[') s = 2;
            if (p == '{') s = 3;
            if (p == '<') s = 4;
            score = 5 * score + s;
        }
        try self.completion_scores.append(score);
    }

    pub fn get_syntax_error_score(self: Navigation) usize {
        return self.syntax_error_score;
    }

    pub fn get_completion_middle_score(self: Navigation) usize {
        const size = self.completion_scores.items.len;
        if (size == 0) return 0;

        std.sort.sort(usize, self.completion_scores.items, {}, desc_usize);
        const middle = size / 2;
        return self.completion_scores.items[middle];
    }
};

test "sample part a" {
    const data: []const u8 =
        \\[({(<(())[]>[[{[]{<()<>>
        \\[(()[<>])]({[<{<<[]>>(
        \\{([(<{}[<>[]}>{[]{[(<()>
        \\(((({<>}<{<{<>}{[]{[]{}
        \\[[<[([]))<([[{}[[()]]]
        \\[{[{({}]{}}([{[{{{}}([]
        \\{<[[]]>}<{[{[{[]{()[[[]
        \\[<(<(<(<{}))><([]([]()
        \\<{([([[(<>()){}]>(<<{{
        \\<{([{{}}[<[[[<>{}]]]>[]]
    ;

    var navigation = Navigation.init();
    defer navigation.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try navigation.process_line(line);
    }
    const syntax_error_score = navigation.get_syntax_error_score();
    try testing.expect(syntax_error_score == 26397);
}

test "sample part b" {
    const data: []const u8 =
        \\[({(<(())[]>[[{[]{<()<>>
        \\[(()[<>])]({[<{<<[]>>(
        \\{([(<{}[<>[]}>{[]{[(<()>
        \\(((({<>}<{<{<>}{[]{[]{}
        \\[[<[([]))<([[{}[[()]]]
        \\[{[{({}]{}}([{[{{{}}([]
        \\{<[[]]>}<{[{[{[]{()[[[]
        \\[<(<(<(<{}))><([]([]()
        \\<{([([[(<>()){}]>(<<{{
        \\<{([{{}}[<[[[<>{}]]]>[]]
    ;

    var navigation = Navigation.init();
    defer navigation.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try navigation.process_line(line);
    }
    const middle_score = navigation.get_completion_middle_score();
    try testing.expect(middle_score == 288957);
}
