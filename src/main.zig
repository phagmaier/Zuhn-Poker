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
        if (size < 2) {
            return false;
        }
        return ((state[size - 1] == state[size - 2]) or (state[size - 1] == 'b' and state[size - 2] == 'c'));
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
        const total = c + b;
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
                    results[i][j] = if (i > j) pot else -pot;
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
        const pot = if (size == 3) 2 else 1;
        return if (showdown) handle_showdown(pot) else handle_fold(pot, size);
    }

    fn update_regret(self:*Node, reach:check:[3][3]f32, bet:[3][3]f32,)

    pub fn _cfrm(self: *Node, reach: [2][3]f32, state: *[MAXLEN]u8, size: u8) [3][3]f32 {
        const curStrat = self.get_prct();
        const curReach = update_reach(reach, curStrat);
        var left: [3][3]f32 = undefined;
        var right: [3][3]f32 = undefined;
        if (self.l) |l| {
            state[size] = 'c';
            left = l._cfrm(curReach, state, size + 1);
        }
        if (self.r) |r| {
            state[size] = 'b';
            right = r._cfrm(curReach, state, size + 1);
        }
        if (self.l == null and self.r == null) {
            state[size] = 'c';
            left = self.handleTerm(state, size + 1);
            state[size] = 'b';
            right = self.handleTerm(state, size + 1);
        }
    }

    pub fn cfrm(self: *Node) void {
        const reach = std.mem.zeroes([2][3]f32);
        var state = std.mem.zeroes([MAXLEN]u8);
        _ = self._cfrm(reach, &state, 0);
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
    var str: [MAXLEN]u8 = std.mem.zeroes([MAXLEN]u8);
    //tree.cfrm();
    tree.print_nodes(&str, 0, false);
}
