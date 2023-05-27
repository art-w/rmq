open Rmq

let () = Random.self_init ()

let test name (module Rmq : S) arr =
  Format.printf "%s: %i@." name (Array.length arr) ;
  let input = of_array ( <= ) arr in
  let naive = Naive.preprocess input in
  let t = Rmq.preprocess input in
  for i = 0 to Array.length arr - 1 do
    for len = 1 to Array.length arr - i do
      let result = Rmq.query input t ~i ~len in
      let expect = Naive.query input naive ~i ~len in
      if arr.(result) <> arr.(expect) (* TODO: result = expect *)
      then begin
        Format.printf "INPUT:@." ;
        Array.iteri (fun i _ -> Format.printf " %4i" i) arr ;
        Format.printf "@." ;
        Array.iter (Format.printf " %4i") arr ;
        Format.printf "@." ;
        Format.printf "RANGE: i=%i len=%i@." i len ;
        Format.printf "EXPECTED arr.(%i) = %i@.FOUND arr.(%i) = %i@." expect
          arr.(expect) result arr.(result) ;
        assert false
      end
    done
  done

let () =
  for len = 0 to 300 do
    let arr = Array.init len (fun _ -> Random.int 10_000) in
    test "Dense" (module Dense) arr ;
    test "Sparse" (module Sparse) arr ;
    test "Hybrid" (module Hybrid) arr
  done
