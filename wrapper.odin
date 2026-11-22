package libart

import "base:builtin"
import "base:runtime"
import "core:c"

Tree :: struct($V: typeid) {
	raw: art_tree,
}

init :: proc(t: ^Tree($V)) -> bool {
	return art_tree_init(&t.raw) == 0
}

destroy :: proc(t: ^Tree($v)) {
	art_tree_destroy(&t.raw)
}

len :: proc(t: Tree($v)) -> int {
	return int(t.raw.size)
}

@(private)
klen :: #force_inline proc(n: int) -> c.int {
	assert(n <= int(max(c.int)))
	return c.int(n)
}

insert_string :: proc(t: ^Tree($V), key: string, value: ^V) -> (old: ^V) {
	return cast(^V)art_insert(&t.raw, raw_data(key), klen(builtin.len(key)), value)
}
insert_bytes :: proc(t: ^Tree($V), key: []byte, value: ^V) -> (old: ^V) {
	return cast(^V)art_insert(&t.raw, raw_data(key), klen(builtin.len(key)), value)
}
insert :: proc{insert_string, insert_bytes}

search_string :: proc(t: ^Tree($V), key: string) -> (value: ^V, found: bool) #optional_ok {
	value = cast(^V)art_search(&t.raw, raw_data(key), klen(builtin.len(key)))
	return value, value != nil
}
search_bytes :: proc(t: ^Tree($V), key: []byte) -> (value: ^V, found: bool) #optional_ok {
	value = cast(^V)art_search(&t.raw, raw_data(key), klen(builtin.len(key)))
	return value, value != nil
}
search :: proc{search_string, search_bytes}

insert_string_no_replace :: proc(t: ^Tree($V), key: string, value: ^V) -> (old: ^V) {
	return cast(^V)art_insert_no_replace(&t.raw, raw_data(key), klen(builtin.len(key)), value)
}
insert_bytes_no_replace :: proc(t: ^Tree($V), key: []byte, value: ^V) -> (old: ^V) {
	return cast(^V)art_insert_no_replace(&t.raw, raw_data(key), klen(builtin.len(key)), value)
}
insert_no_replace :: proc{insert_string_no_replace, insert_bytes_no_replace}

delete_string :: proc(t: ^Tree($V), key: string) -> (value: ^V, found: bool) #optional_ok {
	value = cast(^V)art_delete(&t.raw, raw_data(key), klen(builtin.len(key)))
	return value, value != nil
}
delete_bytes :: proc(t: ^Tree($V), key: []byte) -> (value: ^V, found: bool) #optional_ok {
	value = cast(^V)art_delete(&t.raw, raw_data(key), klen(builtin.len(key)))
	return value, value != nil
}
delete :: proc{delete_string, delete_bytes}

minimum :: proc(t: ^Tree($V)) -> (key: string, value: ^V, ok: bool) {
	leaf := art_minimum(&t.raw)
	if leaf == nil { return }
	return string(([^]u8)(&leaf.key)[:leaf.key_len]), cast(^V)leaf.value, true
}

maximum :: proc(t: ^Tree($V)) -> (key: string, value: ^V, ok: bool) {
	leaf := art_maximum(&t.raw)
	if leaf == nil { return }
	return string(([^]u8)(&leaf.key)[:leaf.key_len]), cast(^V)leaf.value, true
}

ForEachState :: struct($V: typeid, $U: typeid) {
	ctx: runtime.Context,
	callback: proc(key: string, value: ^V, data: ^U) -> bool,
	data: ^U,
}

for_each :: proc(
	t: ^Tree($V),
	callback: proc(key: string, value: ^V, data: ^$U) -> (stop: bool),
	data: ^U = nil,
) -> (stopped: bool) {
	state := ForEachState(V, U){context, callback, data}

	callback_inner :: proc "c" (data: rawptr, key: ^u8, key_len: u32, value: rawptr) -> i32 {
		s := cast(^ForEachState(V, U))data
		context = s.ctx
		k := string(([^]u8)(key)[:key_len]) // only valid during the callback
		return 1 if s.callback(k, cast(^V)value, s.data) else 0
	}
	return art_iter(&t.raw, callback_inner, &state) != 0
}

for_each_prefix :: proc(
	t: ^Tree($V),
	prefix: string,
	callback: proc(key: string, value: ^V, data: ^$U) -> (stop: bool),
	data: ^U = nil,
) -> (stopped: bool) {
	state := ForEachState(V, U){context, callback, data}

	callback_inner :: proc "c" (data: rawptr, key: ^u8, key_len: u32, value: rawptr) -> i32 {
		s := cast(^ForEachState(V, U))data
		context = s.ctx
		k := string(([^]u8)(key)[:key_len]) // only valid during the callback
		return 1 if s.callback(k, cast(^V)value, s.data) else 0
	}
	return art_iter_prefix(&t.raw, raw_data(prefix), klen(builtin.len(prefix)), callback_inner, &state) != 0
}
