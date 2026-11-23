package client

import "core:mem"
import "core:strconv"
import "core:encoding/hex"
import "core:fmt"
import "core:bufio"
import "core:os"
import "core:strings"

import libart ".."

EMPTY := []u8{}

lines :: proc(reader: ^bufio.Reader, allocator := context.allocator) -> (string, bool) {
	s, err := bufio.reader_read_string(reader, '\n', allocator)
	return s, err == nil
}

decode_bytes :: proc(input: string) -> (output: []u8, ok: bool) {
	if input == "$EMPTY" {
		return EMPTY, true
	}
	output, ok = hex.decode(transmute([]u8)input)
	return
}

handle_insert :: proc(cmd: ^[]string, trie: ^libart.Tree(i64)) -> (err: bool) {
	if len(cmd) != 2 {
		return true
	}

	key := decode_bytes(cmd[0]) or_return
	defer delete(key)
	value := strconv.parse_i64(cmd[1]) or_return
	value_ptr, _ := new(i64)
	value_ptr^ = value

	libart.insert(trie, key, value_ptr)
	// fmt.eprintfln("inserted bytes(0x%s) as %d", cmd[0], value)

	return false
}

handle_delete :: proc(cmd: ^[]string, trie: ^libart.Tree(i64)) -> (err: bool) {
	if len(cmd) != 1 {
		return true
	}

	key := decode_bytes(cmd[0]) or_return
	defer delete(key)

	_, found := libart.delete(trie, key)
	if !found {
		return true
	}
	// fmt.eprintfln("deleted bytes(0x%s)", cmd[0])

	return false
}

handle_search :: proc(cmd: ^[]string, trie: ^libart.Tree(i64)) -> (err: bool) {
	if len(cmd) != 1 {
		return true
	}

	key := decode_bytes(cmd[0]) or_return
	defer delete(key)

	value, found := libart.search(trie, key)
	if !found {
		// fmt.eprintfln("search bytes(0x%s) == nil", cmd[0])
		fmt.printfln("not found")
	} else {
		// fmt.eprintfln("search bytes(0x%s) == %d", cmd[0], value^)
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
		// fmt.eprintfln("length is %d", libart.len(trie^))
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
