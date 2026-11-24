package client

import "core:strconv"
import "core:encoding/hex"
import "core:fmt"
import "core:bufio"
import "core:os"
import "core:strings"
import "core:c/libc"

import libart ".."

EMPTY := []u8{}

lines :: proc(reader: ^bufio.Reader, allocator := context.allocator) -> (string, bool) {
	s, err := bufio.reader_read_string(reader, '\n', allocator)
	return s, err == nil
}

// Keys live in exactly-sized libc allocations so that, under ASan, any read
// past key_len hits a redzone (Odin's heap allocator pads for alignment).
decode_bytes :: proc(input: string) -> (output: []u8, ok: bool) {
	src := EMPTY
	if input != "$EMPTY" {
		src = hex.decode(transmute([]u8)input) or_return
	}
	defer if input != "$EMPTY" { delete(src) }
	buf := ([^]u8)(libc.malloc(uint(len(src))))
	copy(buf[:len(src)], src)
	return buf[:len(src)], true
}

free_key :: proc(key: []u8) {
	libc.free(raw_data(key))
}

handle_insert :: proc(cmd: ^[]string, trie: ^libart.Tree(i64)) -> (err: bool) {
	if len(cmd) != 2 {
		return true
	}

	key := decode_bytes(cmd[0]) or_return
	defer free_key(key)
	value := strconv.parse_i64(cmd[1]) or_return
	value_ptr, _ := new(i64)
	value_ptr^ = value

	if old := libart.insert(trie, key, value_ptr); old != nil {
		free(old)
	}

	return false
}

handle_delete :: proc(cmd: ^[]string, trie: ^libart.Tree(i64)) -> (err: bool) {
	if len(cmd) != 1 {
		return true
	}

	key := decode_bytes(cmd[0]) or_return
	defer free_key(key)

	old, found := libart.delete(trie, key)
	if !found {
		return true
	}
	free(old)

	return false
}

handle_search :: proc(cmd: ^[]string, trie: ^libart.Tree(i64)) -> (err: bool) {
	if len(cmd) != 1 {
		return true
	}

	key := decode_bytes(cmd[0]) or_return
	defer free_key(key)

	value, found := libart.search(trie, key)
	if !found {
		fmt.printfln("not found")
	} else {
		fmt.printfln("value=%d", value^)
	}

	return false
}

handle_command :: proc(cmd: ^[]string, trie: ^libart.Tree(i64)) {
	if len(cmd) == 0 {
		return
	}
	tail := cmd[1:]

	switch (cmd[0]) {
	case "insert":
		handle_insert(&tail, trie)
	case "delete":
		handle_delete(&tail, trie)
	case "search":
		handle_search(&tail, trie)
	case "length":
		fmt.printfln("%d", libart.len(trie^))
	case:
		fmt.eprintfln("unrecognized command: %s", cmd[0])
	}
}

main :: proc() {
	trie: libart.Tree(i64)
	libart.init(&trie)
	defer libart.destroy(&trie)
	defer libart.for_each(&trie, proc(key: string, value: ^i64) -> bool {
		free(value)
		return false
	})

	reader: bufio.Reader
	bufio.reader_init(&reader, os.to_stream(os.stdin))
	defer bufio.reader_destroy(&reader)

	for line in lines(&reader, context.temp_allocator) {
		fields := strings.fields(line, context.temp_allocator)
		handle_command(&fields, &trie)
		delete(fields, context.temp_allocator)
		delete(line, context.temp_allocator)
	}
}
