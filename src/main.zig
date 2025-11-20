const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const Node = @import("kuhn.zig").Node;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const mem = gpa.allocator();

    const tree = try Node.makeTree(mem);
    defer tree.deinit(mem);

    tree.cfrm(10000);

    print("\n=== Kuhn Poker Nash Equilibrium ===\n\n", .{});

    tree.printStrategy("P1 initial (check/bet)");
    print("\n", .{});

    if (tree.l) |l| l.printStrategy("P2 after check (check/bet)");
    print("\n", .{});

    if (tree.r) |r| r.printStrategy("P2 after bet (fold/call)");
    print("\n", .{});

    if (tree.l) |l| {
        if (l.r) |lr| lr.printStrategy("P1 after check-bet (fold/call)");
    }
}
