package libart

import "core:c"
foreign import lib "libart/src/libart.so"

NODE4          :: 1
NODE16         :: 2
NODE48         :: 3
NODE256        :: 4
MAX_PREFIX_LEN :: 10

art_callback :: proc "c" (data: rawptr, key: ^u8, key_len: u32, value: rawptr) -> c.int

// This struct is included as part of all the various node sizes
art_node :: struct {
	partial_len:  u32,
	type:         u8,
	num_children: u8,
	partial:      [10]u8,
}

// Small node with only 4 children
art_node4 :: struct {
	n:        art_node,
	keys:     [4]u8,
	children: [4]^art_node,
}

// Node with 16 children
art_node16 :: struct {
	n:        art_node,
	keys:     [16]u8,
	children: [16]^art_node,
}

// Node with 48 children, but a full 256 byte field
art_node48 :: struct {
	n:        art_node,
	keys:     [256]u8,
	children: [48]^art_node,
}

// Full node with 256 children
art_node256 :: struct {
	n:        art_node,
	children: [256]^art_node,
}

// Represents a leaf. These are of arbitrary size, as they include the key
art_leaf :: struct {
	value:   rawptr,
	key_len: u32,
	key:     [0]u8,
}

// Main struct, points to root
art_tree :: struct {
	root: ^art_node,
	size: u64,
}

@(default_calling_convention="c")
foreign lib {
	/*
	Initializes an ART tree

	Returns:
	- 0 on success.
	*/
	art_tree_init :: proc(t: ^art_tree) -> c.int ---

	/*
	Destroys an ART tree

	Returns:
	- 0 on success.
	*/
	art_tree_destroy :: proc(t: ^art_tree) -> c.int ---

	/*
	Inserts a new value into the art tree

	Inputs:
	- `t`: the tree
	- `key`: the key
	- `key_len`: the length of the key
	- `value`: opaque value

	Returns:
	- nil if the item was newly inserted, otherwise the old value pointer is returned
	*/
	art_insert :: proc(t: ^art_tree, key: ^u8, key_len: c.int, value: rawptr) -> rawptr ---

	/*
	Inserts a new value into the art tree (not replacing)

	Inputs:
	- `t`: the tree
	- `key`: the key
	- `key_len`: the length of the key
	- `value`: opaque value

	Returns:
	- nil if the item was newly inserted, otherwise the old value pointer is returned
	*/
	art_insert_no_replace :: proc(t: ^art_tree, key: ^u8, key_len: c.int, value: rawptr) -> rawptr ---

	/*
	Deletes a value from the ART tree

	Inputs:
	- `t`: The tree
	- `key`: The key
	- `key_len`: The length of the key

	Returns:
	- nil if the item was not found, otherwise the value pointer is returned
	*/
	art_delete :: proc(t: ^art_tree, key: ^u8, key_len: c.int) -> rawptr ---

	/*
	Searches for a value in the ART tree

	Inputs:
	`t`: The tree
	`key`: The key
	`key_len`: The length of the key

	Returns:
	- nil if the item was not found, otherwise the value pointer is returned
	*/
	art_search :: proc(t: ^art_tree, key: ^u8, key_len: c.int) -> rawptr ---

	/*
	Returns the minimum valued leaf

	Returns:
	- The minimum leaf or nil
	*/
	art_minimum :: proc(t: ^art_tree) -> ^art_leaf ---

	/*
	Returns the maximum valued leaf

	Returns:
	- The maximum leaf or nil
	*/
	art_maximum :: proc(t: ^art_tree) -> ^art_leaf ---

	/*
	Iterates through the entries pairs in the map, invoking a callback for each.

	The callback gets a key, value for each and returns an integer stop value.
	If the callback returns non-zero, then the iteration stops.

	Inputs:
	- `t`: The tree to iterate over
	- `cb`: The callback function to invoke
	- `data`: Opaque handle passed to the callback

	Returns:
	- 0 on success, or the return of the callback.
	*/
	art_iter :: proc(t: ^art_tree, cb: art_callback, data: rawptr) -> c.int ---

	/*
	Iterates through the entries pairs in the map, invoking a callback for each that matches a given prefix.

	The callback gets a key, value for each and returns an integer stop value.
	If the callback returns non-zero, then the iteration stops.

	Inputs:
	- `t`: The tree to iterate over
	- `prefix`: The prefix of keys to read
	- `prefix_len`: The length of the prefix
	- `cb`: The callback function to invoke
	- `data`: Opaque handle passed to the callback

	Returns:
	- 0 on success, or the return of the callback
	*/
	art_iter_prefix :: proc(t: ^art_tree, prefix: ^u8, prefix_len: c.int, cb: art_callback, data: rawptr) -> c.int ---
}
