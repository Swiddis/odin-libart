# libart bindings for Odin

Odin bindings for Armon Dadgar's [libart](https://github.com/armon/libart).

## Setup

Clone the submodule and build the library with the provided Makefile.

These bindings should work directly on the resulting `.so` (as of 2026-11-21).

## Usage

See `examples` for a tour of both low-level bindings-based usage and high-level wrapper usage.

Low-level bindings use the `art_*` format: `art_tree`, `art_insert`, etc.
The wrapper provides a similar interface without `art_`: `Tree`, `insert`, etc.

```odin
example :: proc() {
	t: libart.Tree(int)
	libart.init(&t)
	defer libart.destroy(&t)
	
	keys: []string = { "dad", "baby", "bank", "dance", "bad", "box" }
	values: []int = { 22, 39, 43, 95, 35, 10 }
	search_key := "bank"
	
	for key, i in keys {
		libart.insert(&t, key, &values[i])
	}
	assert(libart.len(t) == 6)
	assert(libart.search(&t, present_key)^ == 43)
}
```

Notes:
- High-level bindings currently do not support iteration, as the callback interface is Weird.
- It currently only suppports pointers as values, so you usually will want to pair the trie with some sort of auxiliary storage structure like an array. I may try to make an owned variant later that stores values directly.

## License

libart is licensed under the BSD 3-Clause License. A copy is included at `LICENSE-LIBART`.

These bindings are also licensed under the BSD 3-Clause License. See `LICENSE`.
