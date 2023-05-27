(lang dune 3.3)

(name rmq)

(generate_opam_files true)

(source (github art-w/rmq))

(authors "Arthur Wendling")

(maintainers "art.wendling@gmail.com")

(documentation "https://art-w.github.io/rmq/rmq/Rmq")

(license MIT)

(package
 (name rmq)
 (synopsis "Range Minimum Query")
 (depends
   (ocaml (>= 4.0.8))
   dune))
