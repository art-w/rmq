type min_array =
  { length: int  (** Number of elements in the array *)
  ; cmp: int -> int -> bool
        (** [cmp i j] returns [true] if the element at index [i] is less than or equal to the element at index [j] in the array *)
  }
(** An abstract representation of an array supporting the comparison of its elements. *)

val of_array : ('a -> 'a -> bool) -> 'a array -> min_array
(** [of_array cmp arr] returns an implementation of [min_array] using [cmp] to compare the elements of the array [arr]. The function [cmp x y] should return [true] if [x] is less than or equal to the value [y]. *)

module type S = sig
  type t
  (** The type of a preprocessed array optimized for fast range-minimum queries. *)

  val preprocess : min_array -> t
  (** Preprocess the array argument to enable fast range-minimum queries. *)

  val query : min_array -> t -> i:int -> len:int -> int
  (** [query min_array t ~i ~len] returns the index [j] in the range [i, i+len-1] of [min_array], such that the element at position [j] is the minimum over that range (according to the comparison function provided by [min_array]). The preprocessed [t] argument must have been created from the same unmodified [min_array], otherwise the results are unspecified.
   @raise Invalid_argument if the range is outside the bounds of the array.
  *)
end

module Naive : S with type t = unit
(** {b O(N)} query, {b O(1)} preprocessing and memory. *)

module Dense : S
(** {b O(1)} query, {b O(N^2)} preprocessing and memory. *)

module Sparse : S
(** {b O(1)} query, {b O(N logN)} preprocessing and memory. *)

module Hybrid : S
(** {b O(1)} query, {b O(N)} preprocessing and memory. *)
