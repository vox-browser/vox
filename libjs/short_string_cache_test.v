module libjs

fn test_short_string_cache_preserves_utf16_and_owns_input_bytes() {
	mut vm := VM.create()
	for text in ['', 'a', 'comtr noshow', 'Привет', '😀', '\x00', 'a'.repeat(65)] {
		first := vm.create_string_from_str(text)
		second := vm.create_string_from_str(text)
		assert first.utf16 == utf16_string(text) && second.utf16 == first.utf16
	}
	mut bytes := 'mutable'.bytes()
	value := vm.create_string_from_str(bytes.bytestr())
	bytes[0] = `X`
	assert value.str() == 'mutable'
	assert vm.create_string_from_str('mutable').str() == 'mutable'
}

fn test_short_string_cache_bound_and_testing_control() {
	mut vm := VM.create()
	for index in 0 .. 1024 { vm.create_string_from_str('entry-${index}') }
	assert vm.short_utf8_strings.len <= 128
	for enabled in [false, true] {
		set_short_string_cache_for_testing(enabled)
		diagnose_short_string_cache_for_testing(true)
		vm.create_string_from_str('repeat');vm.create_string_from_str('repeat')
		assert (diagnose_short_string_cache_for_testing(false) > 0) == enabled
	}
	set_short_string_cache_for_testing(true)
}

fn test_short_string_cache_values_are_reported_as_heap_roots() {
	mut vm := VM.create()
	cached := vm.create_string_from_str('retained cached text')
	mut roots := HeapRoots{}
	vm.gather_roots(mut roots)
	assert roots.contains(voidptr(cached))
}
