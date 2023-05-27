Given a preprocessed array, a [Range Minimum Query (RMQ)](https://en.wikipedia.org/wiki/Range_minimum_query) returns the minimum element in a chosen subarray:

![Find the minimum in a subarray](https://art-w.github.io/rmq/rmq.png)

This library provides various implementations with different trade-offs:

|         | Preprocessing and Memory | Query     |  |
|--------:|:-------------------------|:----------|:-|
| Naive   | `O(1)`                   | `O(N)`    | _No preprocessing_ |
| Dense   | `O(N²)`                  | `O(1)`    | _Precompute all queries_ |
| Sparse  | `O(N logN)`              | `O(1)`    | _Precompute queries with a power-of-two length_ |
| Hybrid  | `O(N)`                   | `O(1)`    | _Combine `Dense` and `Sparse` to shave a log!_ |
| Segment | `O(N)`                   | `O(logN)` | _Binary partitioning of precomputed queries_ |

[![benchmarks](https://art-w.github.io/rmq/bench.png)](https://art-w.github.io/rmq/bench.png)

Since RMQ is a useful building block for more advanced algorithms, this package exposes a low-level interface returning the index of the minimum element: **[online documentation](https://art-w.github.io/rmq/rmq/Rmq)**

```ocaml
let arr = [| "b" ; "a" ; "d" ; "c" ; "e" ; "a" |] (* given an array *)
let min_array = Rmq.of_array ( <= ) arr (* configure its [min] function *)
module Impl = Rmq.Hybrid (* choose an RMQ implementation *)
let t = Impl.preprocess min_array (* to precompute some answers *)
let found_index = Impl.minimum_index min_array t ~i:2 ~len:3 (* query range [2..4] for its minimum *)
let () = assert (arr.(found_index) = "c")
```

As an example application, consider finding the [Lowest Common Ancestor (LCA)](https://en.wikipedia.org/wiki/Lowest_common_ancestor) between any two nodes in a tree:
- An array of nodes is obtained by an in-order traversal of the tree from left to right (in dashed red)
- The minimum element (by depth) between any two nodes in the array is their lowest common ancestor

![LCA](https://art-w.github.io/rmq/lca.png)

When applied to a [suffix tree](https://en.wikipedia.org/wiki/Suffix_tree), this yields a constant time "Longest Common Prefix (LCP)" between any substrings! (with linear preprocessing)
