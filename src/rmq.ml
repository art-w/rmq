type min_array = {length: int; cmp: int -> int -> bool}

let of_array cmp arr =
  {length= Array.length arr; cmp= (fun i j -> cmp arr.(i) arr.(j))}

module type S = sig
  type t

  val preprocess : min_array -> t

  val minimum_index : min_array -> t -> i:int -> len:int -> int
end

let check_range ~i ~len ~length =
  if len <= 0
  then invalid_arg "Rmq.query: negative or zero length"
  else if i < 0
  then invalid_arg "Rmq.query: negative index"
  else if i + len > length
  then invalid_arg "Rmq.query: outside array bounds"

module Naive = struct
  type t = unit

  let preprocess _ = ()

  let minimum_index {cmp; length} () ~i ~len =
    check_range ~i ~len ~length ;
    let found = ref i in
    for k = i + 1 to i + len - 1 do
      if not (cmp !found k) then found := k
    done ;
    !found
end

module Dense = struct
  type t = int array array

  let preprocess {cmp; length= len} =
    if len <= 1
    then [||]
    else
      let t = Array.make (len - 1) [||] in
      for range = 2 to len do
        assert (len - range + 1 > 0) ;
        let results =
          Array.init
            (len - range + 1)
            (fun left ->
              let ix, iy =
                if range <= 2
                then left, left + 1
                else
                  let ix = t.(range - 3).(left) in
                  let iy = t.(range - 3).(left + 1) in
                  ix, iy
              in
              let r = if cmp ix iy then ix else iy in
              r )
        in
        t.(range - 2) <- results
      done ;
      t

  let unsafe_query dense ~i ~len = if len = 1 then i else dense.(len - 2).(i)

  let minimum_index {length; _} dense ~i ~len =
    check_range ~i ~len ~length ;
    unsafe_query dense ~i ~len

  let unsafe_minimum t =
    let max_len = Array.length t - 1 in
    t.(max_len).(0)
end

let rec log2 acc n = if n = 0 then acc else log2 (acc + 1) (n / 2)

let log2 n = log2 0 n

let pow2 n = 1 lsl n

module Sparse = struct
  type t = int array array

  let preprocess {cmp; length= len} =
    let sparse_len = log2 len - 1 in
    let t = Array.make (max 0 sparse_len) [||] in
    for i = 0 to sparse_len - 1 do
      let prev_range = pow2 i in
      let range = pow2 (i + 1) in
      let results =
        Array.init
          (len - range + 1)
          (fun left ->
            let ix, iy =
              if i <= 0
              then left, left + 1
              else
                let ix = t.(i - 1).(left) in
                let iy = t.(i - 1).(left + prev_range) in
                ix, iy
            in
            if cmp ix iy then ix else iy )
      in
      t.(i) <- results
    done ;
    t

  let unsafe_query ~cmp sparse ~i ~len =
    if len = 1
    then i
    else
      let sparse_len = log2 len - 1 in
      let range = pow2 sparse_len in
      let left = sparse.(sparse_len - 1).(i) in
      if len = range
      then left
      else
        let j = i + len - range in
        let right = sparse.(sparse_len - 1).(j) in
        if cmp left right then left else right

  let minimum_index {cmp; length} sparse ~i ~len =
    check_range ~i ~len ~length ;
    unsafe_query ~cmp sparse ~i ~len
end

module Hybrid : S = struct
  type t = {top: Sparse.t; bot: Dense.t array}

  let cartesian_index {cmp; length} =
    let rec go result stack i =
      if i >= length
      then result lsl (List.length stack - 1)
      else
        let elt = i in
        let rec pop result stack =
          match stack with
          | [] -> result, stack
          | top :: _ when cmp top elt -> result, stack
          | _ :: stack -> pop (result lsl 1) stack
        in
        let result, stack = pop result stack in
        let result = (result lsl 1) + 1 in
        let stack = elt :: stack in
        go result stack (i + 1)
    in
    go 0 [] 0

  module H = Hashtbl.Make (struct
    type t = int

    let equal = Int.equal

    let hash = Hashtbl.hash
  end)

  let bot_min bot ~block_size a =
    (a * block_size) + Dense.unsafe_minimum bot.(a)

  let of_bot ~cmp ~block_size bot =
    { length= Array.length bot
    ; cmp=
        (fun a b -> cmp (bot_min bot ~block_size a) (bot_min bot ~block_size b))
    }

  let preprocess ({cmp; length= len} as input) =
    let block_size = log2 len * 1 / 2 in
    if block_size <= 1
    then {top= Sparse.preprocess input; bot= [||]}
    else
      let nb_blocks = len / block_size in
      let counts = H.create 16 in
      let nb_blocks =
        if (nb_blocks * block_size) + 1 < len then nb_blocks + 1 else nb_blocks
      in
      let bot =
        Array.init nb_blocks (fun i ->
            let j = i * block_size in
            let sub =
              { length= min block_size (len - j)
              ; cmp= (fun a b -> cmp (j + a) (j + b)) }
            in
            assert (sub.length >= 2) ;
            let it = cartesian_index sub in
            try H.find counts it
            with Not_found ->
              let dense = Dense.preprocess sub in
              H.add counts it dense ; dense )
      in
      let top = Sparse.preprocess (of_bot ~cmp ~block_size bot) in
      {top; bot}

  let minimum_index {cmp; length} {top; bot} ~i ~len =
    let block_size = log2 length / 2 in
    if block_size <= 1
    then (
      assert (Array.length bot = 0) ;
      Sparse.unsafe_query ~cmp top ~i ~len )
    else
      let top_i = i / block_size in
      let top_len = ((i + len) / block_size) - top_i in
      let has_left = i mod block_size <> 0 || len <= block_size in
      let has_right = (i + len) mod block_size <> 0 in
      let bot_i = i - (top_i * block_size) in
      let bot_left =
        if not has_left
        then None
        else if top_i >= Array.length bot
        then Some i
        else
          let bt = bot.(top_i) in
          let ofs = top_i * block_size in
          let bot_len = min len (block_size - bot_i) in
          let r = Dense.unsafe_query bt ~i:bot_i ~len:bot_len in
          Some (ofs + r)
      in
      let top_i, top_len =
        if has_left then top_i + 1, top_len - 1 else top_i, top_len
      in
      let top =
        if top_len <= 0
        then None
        else
          let top_cmp a b =
            cmp (bot_min bot ~block_size a) (bot_min bot ~block_size b)
          in
          let found =
            Sparse.unsafe_query ~cmp:top_cmp top ~i:top_i ~len:top_len
          in
          let bt = bot.(found) in
          let ofs = found * block_size in
          Some (ofs + Dense.unsafe_minimum bt)
      in
      let bot_right =
        if len <= block_size - bot_i || not has_right
        then None
        else
          let j = top_i + top_len in
          if j >= Array.length bot
          then Some (i + len - 1)
          else
            let bt = bot.(j) in
            let ofs = j * block_size in
            let bot_len = i + len - (j * block_size) in
            Some (ofs + Dense.unsafe_query bt ~i:0 ~len:bot_len)
      in
      let min a b = if cmp a b then a else b in
      let bot =
        match bot_left, bot_right with
        | Some a, Some b -> Some (min a b)
        | opt, None | None, opt -> opt
      in
      match bot, top with
      | None, None -> assert false
      | Some result, None | None, Some result -> result
      | Some bot, Some top -> min bot top
end

module Segment = struct
  type t = int array

  let preprocess {cmp; length} =
    let t = Array.make ((2 * length) + 1) (-1) in
    let rec go loc i len =
      let result =
        if len = 1
        then i
        else if len = 2
        then
          let j = i + 1 in
          if cmp i j then i else j
        else
          let len2 = len / 2 in
          let left = go (2 * loc) i len2 in
          let right = go ((2 * loc) + 1) (i + len2) (len - len2) in
          if cmp left right then left else right
      in
      t.(loc - 1) <- result ;
      result
    in
    let _ = go 1 0 length in
    t

  let preprocess min_array =
    if min_array.length <= 1 then [||] else preprocess min_array

  let minimum_index {cmp; length} t ~i ~len =
    check_range ~i ~len ~length ;
    let rec go loc i' len' =
      if len' = 0 || i' + len' <= i || i + len <= i'
      then None
      else if i' >= i && i' + len' <= i + len
      then if len' = 1 then Some i' else Some t.(loc - 1)
      else
        let len2 = len' / 2 in
        let left = go (2 * loc) i' len2 in
        let right = go ((2 * loc) + 1) (i' + len2) (len' - len2) in
        match left, right with
        | None, opt | opt, None -> opt
        | Some left, Some right -> Some (if cmp left right then left else right)
    in
    match go 1 0 length with
    | None -> assert false
    | Some result -> result
end
