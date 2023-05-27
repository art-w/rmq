open Rmq

let () = Random.self_init ()

let bench (module Rmq : S) arr =
  Gc.full_major () ;
  let len = Array.length arr in
  let input = of_array ( <= ) arr in
  let nb_queries = ref 0 in
  let t0 = Unix.gettimeofday () in
  let t = Rmq.preprocess input in
  let t1 = Unix.gettimeofday () in
  for i = 0 to len - 1 do
    for len = 1 to len - i do
      let _ = Rmq.minimum_index input t ~i ~len in
      incr nb_queries
    done
  done ;
  let t2 = Unix.gettimeofday () in
  Format.printf "%i\t%f\t%f\t%i@." len
    (1_000_000.0 *. (t1 -. t0))
    (1_000_000.0 *. (t2 -. t1) /. float !nb_queries)
    (Obj.reachable_words (Obj.repr t))

let benchmark name impl ~max_len =
  Format.printf "; %s | preprocess | query | memory@." name ;
  let step = 100 in
  for len = 1 to max_len / step do
    let len = 100 * len in
    let arr = Array.init len (fun _ -> Random.int 10_000) in
    bench impl arr
  done ;
  Format.printf "@.@."

let () =
  benchmark "Naive" (module Naive) ~max_len:500 ;
  benchmark "Dense" (module Dense) ~max_len:10_000 ;
  benchmark "Sparse" (module Sparse) ~max_len:10_000 ;
  benchmark "Hybrid" (module Hybrid) ~max_len:10_000 ;
  benchmark "Segment" (module Segment) ~max_len:10_000
