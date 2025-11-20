const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const Node = @import("kuhn.zig").Node;

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    const mem = if (builtin.mode == .Debug)
        da.allocator()
    else
        std.heap.smp_allocator;

    defer _ = da.deinit();

    const tree = try Node.makeTree(mem);
    defer tree.deinit(mem);

    const iterations: usize = 10000;
    tree.cfrm(iterations);
    tree.printResults(iterations);
}
