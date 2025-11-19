const std = @import("std");
const print = std.debug.print;
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const CARDS = "KQJ";
const MAXLEN = 3;

const PLAYER = enum { FTA, STA, BOTH };

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

    pub fn get_result(state: [MAXLEN]u8, size: u8, p1: usize, p2: usize, pot: f32) f32 {
        //means there is a showdown
        if (state[size - 1] == state[size - 2]) {
            return if (p1 > p2) pot else -pot;
        }
        //no showdown p1 only loses when size 3
        return if (size == 3) -pot else pot;
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

    pub fn cfrm(self: *Node) void {
        var p1: [3]f32 = undefined;
        var p2: [3]f32 = undefined;
        for (0..3) |i| {
            p1[i] = 1.0;
            p2[i] = 1.0;
        }
        var state = std.mem.zeroes([MAXLEN]u8);
        try self._cfrm(&p1, &p2, &state, 0);
    }

    pub fn get_term(self: *Node, p1: [3]f32, p2: [3]f32, state: *[MAXLEN]u8, size: u8) void {}

    pub fn _cfrm(self: *Node, prct: *[3][2]f32, state: *[MAXLEN]u8, size: u8) void {}
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
