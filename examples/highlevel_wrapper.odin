package example

import libart ".."

main :: proc() {
	t: libart.Tree(int)
	libart.init(&t)
	defer libart.destroy(&t)

	keys: []string = { "dad", "baby", "bank", "dance", "bad", "box" }
	values: []int = { 22, 39, 43, 95, 35, 10 }
	for key, i in keys {
		libart.insert(&t, key, &values[i])
	}
	assert(libart.len(t) == 6)

	present_key := "bank"
	assert(libart.search(&t, present_key)^ == 43)
	missing_key := "bandit"
	assert(libart.search(&t, missing_key) == nil)

	new_value := 100
	libart.insert_no_replace(&t, present_key, &new_value)
	libart.insert_no_replace(&t, missing_key, &new_value)

	assert(libart.search(&t, present_key)^ == 43)
	assert(libart.search(&t, missing_key)^ == 100)

	libart.delete(&t, missing_key)
	assert(libart.search(&t, missing_key) == nil)

	mink, minv, _ := libart.minimum(&t)
	assert(minv^ == 39 && mink == "baby")
	maxk, maxv, _ := libart.maximum(&t)
	assert(maxv^ == 95 && maxk == "dance")

	ThresholdKey :: struct {
		threshold: int,
		matching_value: int,
	}
	data := ThresholdKey { 80, 0 }
	prefix_ba := "ba"

	callback := proc (key: string, value: ^int, tk: ^ThresholdKey) -> (stop: bool) {
		if value^ > tk.threshold {
			tk.matching_value = value^
			stop = true
		}
		return
	}

	found := libart.for_each(&t, callback, &data)
	assert(found && data.matching_value == 95)
	found = libart.for_each_prefix(&t, prefix_ba, callback, &data)
	assert(!found)
}
