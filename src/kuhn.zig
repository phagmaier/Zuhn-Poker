const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const SSIZE = 3;

pub const Node = struct {
    regrets: [2][3]f32,
    sums: [2][3]f32,
    l: ?*Node,
    r: ?*Node,

    pub fn init(mem: Allocator) !*Node {
        const self = try mem.create(Node);
        self.regrets = std.mem.zeroes([2][3]f32);
        self.sums = std.mem.zeroes([2][3]f32);
        self.l = null;
        self.r = null;
        return self;
    }

    fn isTerm(state: [SSIZE]u8, size: u8) bool {
        if (size < 2) return false;
        if (size >= 3) return true;
        return !(state[0] == 'c' and state[1] == 'b');
    }

    pub fn makeTree(mem: Allocator) !*Node {
        const head = try Node.init(mem);
        var state = std.mem.zeroes([SSIZE]u8);
        try head._makeTree(mem, &state, 0);
        return head;
    }

    fn _makeTree(self: *Node, mem: Allocator, state: *[SSIZE]u8, size: u8) !void {
        state[size] = 'c';
        if (!isTerm(state.*, size + 1)) {
            self.l = try Node.init(mem);
            try self.l.?._makeTree(mem, state, size + 1);
        }

        state[size] = 'b';
        if (!isTerm(state.*, size + 1)) {
            self.r = try Node.init(mem);
            try self.r.?._makeTree(mem, state, size + 1);
        }
    }

    pub fn deinit(self: *Node, mem: Allocator) void {
        if (self.l) |l| l.deinit(mem);
        if (self.r) |r| r.deinit(mem);
        mem.destroy(self);
    }

    pub fn getStrat(self: *Node) [2][3]f32 {
        var probs: [2][3]f32 = undefined;
        for (0..3) |i| {
            const r0 = if (self.regrets[0][i] > 0) self.regrets[0][i] else 0;
            const r1 = if (self.regrets[1][i] > 0) self.regrets[1][i] else 0;
            const total = r0 + r1;
            if (total == 0) {
                probs[0][i] = 0.5;
                probs[1][i] = 0.5;
            } else {
                probs[0][i] = r0 / total;
                probs[1][i] = r1 / total;
            }
        }
        return probs;
    }

    fn getTermUtil(state: [SSIZE]u8, size: u8) [3][3]f32 {
        var util = std.mem.zeroes([3][3]f32);
        const showdown = state[size - 1] == state[size - 2];

        if (showdown) {
            var has_bet = false;
            for (0..size) |i| {
                if (state[i] == 'b') {
                    has_bet = true;
                    break;
                }
            }
            const pot: f32 = if (has_bet) 2 else 1;
            for (0..3) |i| {
                for (0..3) |j| {
                    if (i != j) {
                        util[i][j] = if (i > j) pot else -pot;
                    }
                }
            }
        } else {
            const winnings: f32 = if (size == 2) 1 else -1;
            for (0..3) |i| {
                for (0..3) |j| {
                    if (i != j) {
                        util[i][j] = winnings;
                    }
                }
            }
        }
        return util;
    }

    fn updateReach(reach: [2][3]f32, strat: [2][3]f32, player: usize, action: usize) [2][3]f32 {
        var new_reach = reach;
        for (0..3) |card| {
            new_reach[player][card] *= strat[action][card];
        }
        return new_reach;
    }

    fn updateUtil(utils: [2][3][3]f32, hero: usize, strat: [2][3]f32) [3][3]f32 {
        var node_util = std.mem.zeroes([3][3]f32);
        for (0..3) |p1_card| {
            for (0..3) |p2_card| {
                if (p1_card == p2_card) continue;
                const my_card = if (hero == 0) p1_card else p2_card;
                node_util[p1_card][p2_card] = strat[0][my_card] * utils[0][p1_card][p2_card] +
                    strat[1][my_card] * utils[1][p1_card][p2_card];
            }
        }
        return node_util;
    }

    fn updateRegret(self: *Node, utils: [2][3][3]f32, node_util: [3][3]f32, reach: [2][3]f32, strat: [2][3]f32, hero: usize) void {
        const opponent: usize = 1 - hero;
        for (0..3) |card| {
            var c_regret: f32 = 0;
            var b_regret: f32 = 0;

            for (0..3) |opp_card| {
                if (card == opp_card) continue;

                const weight = reach[opponent][opp_card];

                var c_util: f32 = undefined;
                var b_util: f32 = undefined;
                var n_util: f32 = undefined;

                if (hero == 0) {
                    c_util = utils[0][card][opp_card];
                    b_util = utils[1][card][opp_card];
                    n_util = node_util[card][opp_card];
                } else {
                    c_util = -utils[0][opp_card][card];
                    b_util = -utils[1][opp_card][card];
                    n_util = -node_util[opp_card][card];
                }

                c_regret += weight * (c_util - n_util);
                b_regret += weight * (b_util - n_util);
            }

            self.regrets[0][card] += c_regret;
            self.regrets[1][card] += b_regret;

            self.sums[0][card] += reach[hero][card] * strat[0][card];
            self.sums[1][card] += reach[hero][card] * strat[1][card];
        }
    }

    fn _cfrm(self: *Node, state: *[SSIZE]u8, size: u8, reach: [2][3]f32) [3][3]f32 {
        const hero: usize = size % 2;
        const strat = self.getStrat();
        var utils: [2][3][3]f32 = undefined;

        state[size] = 'c';
        if (self.l) |l| {
            utils[0] = l._cfrm(state, size + 1, updateReach(reach, strat, hero, 0));
        } else {
            utils[0] = getTermUtil(state.*, size + 1);
        }

        state[size] = 'b';
        if (self.r) |r| {
            utils[1] = r._cfrm(state, size + 1, updateReach(reach, strat, hero, 1));
        } else {
            utils[1] = getTermUtil(state.*, size + 1);
        }

        const node_util = updateUtil(utils, hero, strat);
        self.updateRegret(utils, node_util, reach, strat, hero);
        return node_util;
    }

    pub fn cfrm(self: *Node, iterations: usize) void {
        const reach: [2][3]f32 = .{ .{ 1, 1, 1 }, .{ 1, 1, 1 } };
        for (0..iterations) |_| {
            var state = std.mem.zeroes([SSIZE]u8);
            _ = self._cfrm(&state, 0, reach);
        }
    }

    pub fn getAverageStrategy(self: *Node) [2][3]f32 {
        var result: [2][3]f32 = undefined;
        for (0..3) |card| {
            const total = self.sums[0][card] + self.sums[1][card];
            if (total > 0) {
                result[0][card] = self.sums[0][card] / total;
                result[1][card] = self.sums[1][card] / total;
            } else {
                result[0][card] = 0.5;
                result[1][card] = 0.5;
            }
        }
        return result;
    }

    fn computeEVUtil(self: *Node, state: *[SSIZE]u8, size: u8) [3][3]f32 {
        const hero: usize = size % 2;
        const strat = self.getAverageStrategy(); // Use average strategy, not current regrets
        var utils: [2][3][3]f32 = undefined;

        state[size] = 'c';
        if (self.l) |l| {
            utils[0] = l.computeEVUtil(state, size + 1);
        } else {
            utils[0] = getTermUtil(state.*, size + 1);
        }

        state[size] = 'b';
        if (self.r) |r| {
            utils[1] = r.computeEVUtil(state, size + 1);
        } else {
            utils[1] = getTermUtil(state.*, size + 1);
        }

        return updateUtil(utils, hero, strat);
    }

    pub fn computeEV(self: *Node) f32 {
        var state = std.mem.zeroes([SSIZE]u8);
        const util_matrix = self.computeEVUtil(&state, 0);

        // Average over all card combinations
        var ev: f32 = 0;
        var count: f32 = 0;
        for (0..3) |p1| {
            for (0..3) |p2| {
                if (p1 != p2) {
                    ev += util_matrix[p1][p2];
                    count += 1;
                }
            }
        }
        return ev / count;
    }

    pub fn printResults(self: *Node, iterations: usize) void {
        print("\n", .{});
        print("=" ** 70, .{});
        print("\n", .{});
        print("  KUHN POKER - NASH EQUILIBRIUM SOLUTION\n", .{});
        print("  Iterations: {d}\n", .{iterations});
        print("=" ** 70, .{});
        print("\n\n", .{});

        // Expected values
        const ev = self.computeEV();
        print("EXPECTED VALUES (per hand):\n", .{});
        print("  Player 1 (P1): {d: >7.4}\n", .{ev});
        print("  Player 2 (P2): {d: >7.4}\n", .{-ev});
        print("  Theoretical:   -0.0556 (= -1/18)\n\n", .{});

        // P1 initial strategy
        print("PLAYER 1 - INITIAL ACTION:\n", .{});
        self.printStrategyNode("  ", true);

        // P2 after check
        if (self.l) |l| {
            print("\nPLAYER 2 - AFTER P1 CHECKS:\n", .{});
            l.printStrategyNode("  ", false);
        }

        // P2 after bet
        if (self.r) |r| {
            print("\nPLAYER 2 - AFTER P1 BETS:\n", .{});
            r.printStrategyNode("  ", false);
        }

        // P1 after check-bet
        if (self.l) |l| {
            if (l.r) |lr| {
                print("\nPLAYER 1 - AFTER CHECK-BET:\n", .{});
                lr.printStrategyNode("  ", true);
            }
        }

        print("\n", .{});
        print("-" ** 70, .{});
        print("\n", .{});
        print("NASH EQUILIBRIUM PROPERTIES:\n", .{});
        print("  • K should bet ~3x as often as J (makes P2's Q indifferent)\n", .{});
        print("  • P2's K always bets/calls (strongest hand)\n", .{});
        print("  • P2's J bluffs ~33%% after check, always folds to bet\n", .{});
        print("  • P2's Q is indifferent, mixes between actions\n", .{});
        print("  • Game slightly favors P2 (acts last with information)\n", .{});
        print("=" ** 70, .{});
        print("\n\n", .{});
    }

    fn printStrategyNode(self: *Node, indent: []const u8, is_p1: bool) void {
        const strat = self.getAverageStrategy();
        const cards = [_]u8{ 'J', 'Q', 'K' };
        const actions = if (is_p1)
            [2][]const u8{ "Check", "Bet  " }
        else
            [2][]const u8{ "Check/Fold", "Bet/Call  " };

        print("{s}┌────────────────────────────────────┐\n", .{indent});
        print("{s}│  Card  │  {s}  │  {s}  │\n", .{ indent, actions[0], actions[1] });
        print("{s}├────────┼────────────┼────────────┤\n", .{indent});

        for (0..3) |i| {
            print("{s}│   {c}    │   {d: >5.1}%   │   {d: >5.1}%   │\n", .{
                indent,
                cards[i],
                strat[0][i] * 100,
                strat[1][i] * 100,
            });
        }

        print("{s}└────────┴────────────┴────────────┘\n", .{indent});
    }
};
