# Kuhn Poker Solver (Zig)

This is a prototype Kuhn Poker solver written in **Zig**. The project implements **Counterfactual Regret Minimization (CFR)** to compute approximate optimal strategies for the simple three-card Kuhn Poker game.

> ⚠️ **Note:** The current implementation is intentionally over-engineered for such a small game.
> The design uses recursive node structures, dynamic memory allocation, and full tree traversal.
> This might seem excessive for Kuhn Poker, but it is done **deliberately** to prepare for a more realistic and general-purpose poker solver that can scale to larger games.

---

## Features

* Tree-based representation of the game, with `Node` structs storing regrets, cumulative strategy sums, and child nodes.
* CFR implementation with iterative updates to regrets and strategies.
* Functions to compute:

  * Current strategy from regrets (`getStrat`)
  * Average strategy across iterations (`getAverageStrategy`)
  * Terminal utilities (`getTermUtil`)
* Safe memory management: Nodes are dynamically allocated and can be deinitialized.
* Printable strategies in a human-readable format.

---

## Project Structure

```
Kuhn/
├─ build.zig          # Zig build script
├─ build.zig.zon      # Zig package metadata
├─ src/
│  ├─ main.zig        # Entry point, calls CFR solver
│  └─ kuhn.zig        # Node struct and CFR implementation
└─ README.md
```

---

## Usage

1. **Build the project**

```bash
zig build
```

2. **Run the solver**

```bash
zig build -Doptimize=ReleaseFast
```

OR if you want to run it in debug mode:

```bash
zig build 
```


3. The program prints the computed average strategies for each card (`J`, `Q`, `K`) in terms of check/fold and bet/call probabilities.

---

## Design Notes

* **Abstraction over optimization:**
  Even though Kuhn Poker is small enough to solve trivially, the solver is structured as a general tree-based framework.
  Each node tracks regrets and strategy sums separately, allowing this design to scale to larger poker variants in the future.

* **Dynamic memory and recursion:**
  Nodes are dynamically allocated with an allocator and built recursively.
  This is more flexible than hand-encoding branches and prepares the project for full-scale poker games with deeper trees.

* **Threading considerations:**
  The current solver is single-threaded, but the design anticipates per-node or per-iteration parallelization in larger implementations.

* **Overkill is intentional:**
  While this is more complex than necessary for Kuhn Poker, it serves as **training and infrastructure** for future work on realistic poker solvers.

---

## Future Work

* Extend the solver to larger poker variants (e.g., Leduc Poker, Texas Hold’em abstractions).
* Implement multi-threaded CFR iterations for performance.
* Optimize memory usage and stack allocations while maintaining a flexible tree representation.
* Possibly add persistent storage of strategies for repeated training runs.

---

## License

This project is MIT-licensed. Feel free to explore, modify, and build upon it.

---

If you want, I can also write a **short “TL;DR” explanation section** for the README that explains *why you deliberately over-engineered Kuhn Poker* in just 3–4 sentences — it’s nice to have for GitHub readers who just glance at it.

Do you want me to add that?
