# libart bindings for Odin

Odin bindings for Armon Dadgar's [libart](https://github.com/armon/libart).

## Setup

Clone the submodule and build the library with the provided Makefile.

These bindings should work directly on the resulting `.so`.

## Usage

See `examples` for both low-level bindings-based usage and high-level wrapper usage.

Low-level bindings use the `art_*` format: `art_tree`, `art_insert`, etc.
The wrapper provides a similar interface without `art_`: `Tree`, `insert`, etc.

## License

libart is licensed under the BSD 3-Clause License. A copy is included at `LICENSE-LIBART`.

These bindings are also licensed under the BSD 3-Clause License. See `LICENSE`.
