const std = @import("std");
const print = std.debug.print;
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const CARDS = "KQJ";
const MAXLEN = 3;

//const PLAYER = enum { FTA, STA, BOTH };

pub const Node = struct {
    regrets: [3][2]f32,
    sums: [3][2]f32,
    l: ?*Node,
    r: ?*Node,

    pub fn init(mem: Allocator) !*Node {
        var node = try mem.create(Node);
        node.regrets = std.mem.zeroes([3][2]f32);
        node.sums = std.mem.zeroes([3][2]f32);
        node.l = null;
        node.r = null;
        return node;
    }

    pub fn isTerm(state: [MAXLEN]u8, size: u8) bool {
        if (size < 2) return false;
        if (size >= 3) return true;
        // size == 2: terminal unless it's check-bet
        return !(state[0] == 'c' and state[1] == 'b');
    }

    fn build(self: *Node, mem: Allocator, state: *[MAXLEN]u8, size: u8) !void {
        if (isTerm(state.*, size)) {
            return;
        }

        const node = try Node.init(mem);
        if (state[size - 1] == 'c') {
            self.l = node;
        } else {
            self.r = node;
        }
        state[size] = 'c';
        try node.build(mem, state, size + 1);
        state[size] = 'b';
        try node.build(mem, state, size + 1);
    }

    pub fn make_tree(mem: Allocator) !*Node {
        var head = try Node.init(mem);
        var state: [MAXLEN]u8 = std.mem.zeroes([MAXLEN]u8);
        state[0] = 'c';
        try head.build(mem, &state, 1);
        state[0] = 'b';
        try head.build(mem, &state, 1);
        return head;
    }

    pub fn deinit(self: *Node, mem: Allocator) void {
        defer mem.destroy(self);
        if (self.l) |l| {
            l.deinit(mem);
        }
        if (self.r) |r| {
            r.deinit(mem);
        }
    }

    pub fn print_strategy(self: *Node, name: []const u8) void {
        const strat = self.get_average_strategy();
        print("{s}:\n", .{name});
        const cards = [_]u8{ 'K', 'Q', 'J' };
        for (0..3) |i| {
            print("  {c}: check={d:.3}, bet={d:.3}\n", .{ cards[i], strat[i][0], strat[i][1] });
        }
    }

    pub fn get_prct(self: *Node) [3][2]f32 {
        var strats: [3][2]f32 = undefined;
        for (0..3) |card| {
            strats[card][0], strats[card][1] = _get_prct(self.regrets[card][0], self.regrets[card][1]);
        }
        return strats;
    }

    fn _get_prct(c: f32, b: f32) struct { f32, f32 } {
        const check: f32 = if (c >= 0) c else 0.0;
        const bet: f32 = if (b >= 0) b else 0.0;
        const total = check + bet;
        if (total == 0) {
            return .{ 0.5, 0.5 };
        }
        return if (total > 0) .{ check / total, bet / total } else .{ 0.5, 0.5 };
    }

    pub fn print_nodes(self: *Node, str: *[MAXLEN]u8, size: u8, right: bool) void {
        if (size == 0) {
            print("\tHEAD NODE\n", .{});
        }
        const printStr = str[0..size];
        if (right) {
            print("\t\t{s}\n", .{printStr});
        } else {
            print("{s}\n", .{printStr});
        }
        if (self.l) |l| {
            str[size] = 'c';
            print_nodes(l, str, size + 1, false);
        }
        if (self.r) |r| {
            str[size] = 'b';
            print_nodes(r, str, size + 1, true);
        }
    }

    fn update_reach(reach: [2][3]f32, prcts: [2][3]f32) [2][3]f32 {
        var results = std.mem.zeroes([2][3]f32);
        for (0..2) |i| {
            for (0..3) |j| {
                results[i][j] = reach[i][j] * prcts[i][j];
            }
        }
        return results;
    }

    fn handle_showdown(pot: f32) [3][3]f32 {
        var results: [3][3]f32 = undefined;
        for (0..3) |i| {
            for (0..3) |j| {
                if (i != j) {
                    results[i][j] = if (i < j) pot else -pot;
                }
            }
        }
        return results;
    }

    fn handle_fold(pot: f32, size: u8) [3][3]f32 {
        const winnings = if (size == 3) -pot else pot;
        var results: [3][3]f32 = undefined;
        for (0..3) |i| {
            for (0..3) |j| {
                if (i != j) {
                    results[i][j] = winnings;
                }
            }
        }
        return results;
    }

    fn handleTerm(state: [MAXLEN]u8, size: u8) [3][3]f32 {
        const showdown = state[size - 1] == state[size - 2];

        var pot: f32 = 1;
        for (0..size) |i| {
            if (state[i] == 'b') pot += 1;
        }

        if (showdown) {
            return handle_showdown(pot);
        } else {
            const p1_wins = (size == 2);
            var results: [3][3]f32 = undefined;
            const winnings: f32 = if (p1_wins) 1 else -1;
            for (0..3) |i| {
                for (0..3) |j| {
                    if (i != j) {
                        results[i][j] = winnings;
                    }
                }
            }
            return results;
        }
    }

    fn update_sums(self: *Node, reach: [2][3]f32, probs: [3][2]f32, p1: bool) void {
        const player_idx: usize = if (p1) 0 else 1;

        for (0..3) |card| {
            // Weight by own reach probability
            const weight = reach[player_idx][card];
            self.sums[card][0] += weight * probs[card][0];
            self.sums[card][1] += weight * probs[card][1];
        }
    }

    fn update_regret(self: *Node, reach: [2][3]f32, check: [3][3]f32, bet: [3][3]f32, probs: [3][2]f32, p1: bool) void {
        const opp_idx: usize = if (p1) 1 else 0;

        for (0..3) |card| {
            var c_ev: f32 = 0;
            var b_ev: f32 = 0;
            var node_ev: f32 = 0;

            for (0..3) |opp_card| {
                if (card == opp_card) continue;

                const weight = reach[opp_idx][opp_card];

                // Utility is always [p1_card][p2_card]
                var c_util: f32 = undefined;
                var b_util: f32 = undefined;

                if (p1) {
                    c_util = check[card][opp_card];
                    b_util = bet[card][opp_card];
                } else {
                    // P2 acting: card is p2's card, opp_card is p1's
                    // Negate because P2 wants to minimize P1's utility
                    c_util = -check[opp_card][card];
                    b_util = -bet[opp_card][card];
                }

                c_ev += weight * c_util;
                b_ev += weight * b_util;
                node_ev += weight * (probs[card][0] * c_util + probs[card][1] * b_util);
            }

            self.regrets[card][0] += c_ev - node_ev;
            self.regrets[card][1] += b_ev - node_ev;
        }
    }

    pub fn get_average_strategy(self: *Node) [3][2]f32 {
        var strats: [3][2]f32 = undefined;
        for (0..3) |card| {
            const total = self.sums[card][0] + self.sums[card][1];
            if (total > 0) {
                strats[card][0] = self.sums[card][0] / total;
                strats[card][1] = self.sums[card][1] / total;
            } else {
                strats[card][0] = 0.5;
                strats[card][1] = 0.5;
            }
        }
        return strats;
    }

    pub fn _cfrm(self: *Node, reach: [2][3]f32, state: *[MAXLEN]u8, size: u8) [3][3]f32 {
        const p1 = (size % 2) == 0;
        const player: usize = if (p1) 0 else 1;
        const curStrat = self.get_prct();

        var left: [3][3]f32 = undefined;
        var right: [3][3]f32 = undefined;

        // Compute reach for each action
        var check_reach = reach;
        var bet_reach = reach;
        for (0..3) |card| {
            check_reach[player][card] = reach[player][card] * curStrat[card][0];
            bet_reach[player][card] = reach[player][card] * curStrat[card][1];
        }

        // Get utilities for each action
        if (self.l) |l| {
            state[size] = 'c';
            left = l._cfrm(check_reach, state, size + 1);
        }
        if (self.r) |r| {
            state[size] = 'b';
            right = r._cfrm(bet_reach, state, size + 1);
        }
        if (self.l == null and self.r == null) {
            state[size] = 'c';
            left = handleTerm(state.*, size + 1);
            state[size] = 'b';
            right = handleTerm(state.*, size + 1);
        }

        // Update regrets and strategy sums
        self.update_regret(reach, left, right, curStrat, p1);
        self.update_sums(reach, curStrat, p1);

        // Compute and return node values
        var result: [3][3]f32 = undefined;
        for (0..3) |p1_card| {
            for (0..3) |p2_card| {
                if (p1_card == p2_card) {
                    result[p1_card][p2_card] = 0;
                    continue;
                }
                if (p1) {
                    result[p1_card][p2_card] = curStrat[p1_card][0] * left[p1_card][p2_card] + curStrat[p1_card][1] * right[p1_card][p2_card];
                } else {
                    result[p1_card][p2_card] = curStrat[p2_card][0] * left[p1_card][p2_card] + curStrat[p2_card][1] * right[p1_card][p2_card];
                }
            }
        }

        return result;
    }

    pub fn cfrm(self: *Node, iterations: usize) void {
        const reach: [2][3]f32 = .{ .{ 1, 1, 1 }, .{ 1, 1, 1 } };
        for (0..iterations) |_| {
            var state = std.mem.zeroes([MAXLEN]u8);
            _ = self._cfrm(reach, &state, 0);
        }
    }
};

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    const mem = if (builtin.mode == .Debug)
        da.allocator()
    else
        std.heap.smp_allocator;
    defer _ = da.deinit();
    var tree = try Node.make_tree(mem);
    defer tree.deinit(mem);
    tree.cfrm(1000);

    tree.print_strategy("P1 initial");

    // Print P2's decisions
    if (tree.l) |l| l.print_strategy("P2 after check");
    if (tree.r) |r| r.print_strategy("P2 after bet");

    // Print P1's second decision (after check-bet)
    if (tree.l) |l| {
        if (l.r) |lr| lr.print_strategy("P1 after check-bet");
    }
}
