module browserjs

fn C.JSGarbageCollect(context voidptr)

// Validate the registry without formatting the owning Runtime/VM graph.
fn assert_protected_value_registry(runtime &Runtime) {
	if disable_protected_value_index {
		assert runtime.protected_value_positions_.len == 0
		assert runtime.protected_value_links_.len == 0
		return
	}
	mut seen := []bool{len: runtime.protected_values_.len}
	if retain_protected_value_array_index {
		assert runtime.protected_value_positions_.len == seen.len
		for value, indices in runtime.protected_value_indices_ {
			assert indices.len > 0
			for position, index in indices {
				assert index >= 0 && index < seen.len
				assert !seen[index]
				seen[index] = true
				assert runtime.protected_values_[index] == value
				assert runtime.protected_value_positions_[index] == position
			}
		}
	} else {
		assert runtime.protected_value_links_.len == seen.len
		assert runtime.protected_value_indices_.len == 0
		assert runtime.protected_value_positions_.len == 0
		for value, tail in runtime.protected_value_tails_ {
			mut index := tail
			mut next := -1
			for index >= 0 {
				assert index < seen.len
				assert !seen[index]
				seen[index] = true
				assert runtime.protected_values_[index] == value
				assert runtime.protected_value_links_[index].next == next
				next = index
				index = runtime.protected_value_links_[index].previous
			}
		}
	}
	for present in seen {
		assert present
	}
}

fn test_protected_value_links_move_an_older_duplicate_into_the_removed_tail() {
	// The final array slot need not be a handle's newest protection after
	// other removals move newer roots into earlier holes.
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	a := voidptr(0x1000)
	b := voidptr(0x2000)
	c := voidptr(0x3000)
	for value in [a, b, a, c] {
		runtime.remember_protected_value(value)
	}
	assert runtime.forget_protected_value(b)
	runtime.remember_protected_value(a)
	assert runtime.forget_protected_value(c)
	assert_protected_value_registry(runtime)
	for remaining in [2, 1, 0] {
		assert runtime.forget_protected_value(a)
		assert runtime.protected_values_.len == remaining
		assert_protected_value_registry(runtime)
	}
	assert !runtime.forget_protected_value(a)
}

fn test_protected_value_links_match_a_multiset_through_churn_and_full_drain() {
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close() }
	mut counts := []int{len: 23}
	for step in 0 .. 4096 {
		key := (step * 17 + step / 11) % counts.len
		value := voidptr(0x10000 + key * 16)
		if step % 5 < 3 {
			runtime.remember_protected_value(value)
			counts[key]++
		} else {
			assert runtime.forget_protected_value(value) == (counts[key] > 0)
			if counts[key] > 0 {
				counts[key]--
			}
		}
		assert_protected_value_registry(runtime)
		if step % 31 == 0 {
			for item, expected in counts {
				needle := voidptr(0x10000 + item * 16)
				assert runtime.protected_values_.filter(it == needle).len == expected
			}
		}
	}
	for key, count in counts {
		for _ in 0 .. count {
			assert runtime.forget_protected_value(voidptr(0x10000 + key * 16))
			assert_protected_value_registry(runtime)
		}
	}
	assert runtime.protected_values_.len == 0
}

fn test_protected_value_links_keep_actual_roots_alive_until_the_last_release_and_close() {
	mut runtime := Runtime.create()
	baseline := runtime.protected_values_.len
	value := runtime.evaluate_host_value('({answer:73})')!
	for _ in 0 .. 257 {
		runtime.retain_javascript_value(value)!
	}
	for _ in 0 .. 257 {
		runtime.release_javascript_value(value)
	}
	assert runtime.protected_values_.len == baseline + 1
	assert_protected_value_registry(runtime)
	C.JSGarbageCollect(runtime.context)
	reader := runtime.evaluate_host_value('(object => object.answer)')!
	assert js_string_to_v(runtime.context, runtime.call_javascript_function(reader,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [value])!)! == '73'
	// Close owns the remaining duplicate roots and is idempotent.
	runtime.close()
	runtime.close()
	assert runtime.protected_values_.len == 0
	assert runtime.protected_value_links_.len == 0
	assert runtime.protected_value_tails_.len == 0
}
