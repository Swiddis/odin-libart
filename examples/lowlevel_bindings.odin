package example

import libart ".."

main :: proc() {
	t: libart.art_tree
	libart.art_tree_init(&t)
	defer libart.art_tree_destroy(&t)

	keys: []string = { "dad", "baby", "bank", "dance", "bad", "box" }
	values: []int = { 22, 39, 43, 95, 35, 10 }
	for key, i in keys {
		libart.art_insert(&t, raw_data(key), i32(len(key)), &values[i])
	}

	present_key := "bank"
	assert((cast(^int)libart.art_search(&t, raw_data(present_key), 4))^ == 43)
	missing_key := "bandit"
	assert(libart.art_search(&t, raw_data(missing_key), 6) == nil)

	new_value := 100
	libart.art_insert_no_replace(&t, raw_data(present_key), 4, &new_value)
	libart.art_insert_no_replace(&t, raw_data(missing_key), 6, &new_value)

	assert((cast(^int)libart.art_search(&t, raw_data(present_key), 4))^ == 43)
	assert((cast(^int)libart.art_search(&t, raw_data(missing_key), 6))^ == 100)

	libart.art_delete(&t, raw_data(missing_key), 6)
	assert(libart.art_search(&t, raw_data(missing_key), 6) == nil)

	// min key is "baby"
	assert((cast(^int)libart.art_minimum(&t).value)^ == 39)
	// max key is "dance"
	assert((cast(^int)libart.art_maximum(&t).value)^ == 95)

	threshold := 80
	prefix_ba := "ba"
	callback := proc "c" (data: rawptr, key: ^u8, key_len: u32, value: rawptr) -> i32 {
		x := cast(^int)value
		if x^ > (cast(^int)data)^ {
			return i32(x^)
		}
		return 0
	}
	result := libart.art_iter(&t, callback, &threshold)
	assert(result == 95)
	result = libart.art_iter_prefix(&t, raw_data(prefix_ba), 2, callback, &threshold)
	assert(result == 0)
}
