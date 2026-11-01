module browserjs

fn test_indexed_protections_keep_duplicate_roots_and_moved_positions() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	baseline := runtime.protected_values_.len
	a := runtime.evaluate_host_value('({answer:41})')!
	b := runtime.evaluate_host_value('({answer:42})')!
	c := runtime.evaluate_host_value('({answer:43})')!
	runtime.retain_javascript_value(a)!
	runtime.retain_javascript_value(b)!
	assert runtime.protected_values_.len == baseline + 5
	for value in [a, c, a, b] {
		runtime.release_javascript_value(value)
	}
	assert runtime.protected_values_.len == baseline + 1
	assert runtime.protected_values_.filter(it == b).len == 1
	// Releasing an absent handle must not unprotect a different root. The
	// remaining duplicate stays alive through an actual JSC collection.
	runtime.release_javascript_value(a)
	runtime.release_javascript_value(c)
	C.JSGarbageCollect(runtime.context)
	reader := runtime.evaluate_host_value('(value => value.answer)')!
	assert js_string_to_v(runtime.context, runtime.call_javascript_function(reader,
		C.JSValueMakeUndefined(runtime.context), [b])!)! == '42'
	runtime.release_javascript_value(reader)
	runtime.release_javascript_value(b)
	assert runtime.protected_values_.len == baseline
	if !disable_protected_value_index {
		assert runtime.protected_value_positions_.len == baseline
		for value, indices in runtime.protected_value_indices_ {
			for position, index in indices {
				assert runtime.protected_values_[index] == value
				assert runtime.protected_value_positions_[index] == position
			}
		}
	}
	runtime.close()
	assert runtime.protected_values_.len == 0
	assert runtime.protected_value_indices_.len == 0
	assert runtime.protected_value_positions_.len == 0
	runtime.release_javascript_value(b)
}

fn test_indexed_protections_handle_interleaved_duplicate_removals() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	baseline := runtime.protected_values_.len
	mut values := []voidptr{}
	for index in 0 .. 37 {
		values << runtime.evaluate_host_value('({index:${index}})')!
	}
	for round in 0 .. 5 {
		for index in 0 .. values.len {
			runtime.retain_javascript_value(values[(index * 13 + round) % values.len])!
		}
	}
	for round in 0 .. 6 {
		for index in 0 .. values.len {
			runtime.release_javascript_value(values[(index * 17 + round) % values.len])
		}
	}
	assert runtime.protected_values_.len == baseline
	for value in values {
		assert runtime.protected_values_.filter(it == value).len == 0
	}
}
