module libjs

fn test_string_creation_reuses_vm_owned_cells() {
	mut vm := VM.create()
	assert voidptr(vm.create_string(Utf16String.new())) == voidptr(vm.empty_string())
	assert voidptr(vm.create_string(utf16_string('z'))) == voidptr(vm.single_ascii_character_string(`z`))
	assert vm.single_ascii_character_string(0).length_in_utf16_code_units() == 1
	first := vm.create_string(utf16_string('short'))
	second := vm.create_string(utf16_string('short'))
	assert voidptr(first) == voidptr(second)
	assert first.str() == 'short'
	long_text := utf16_string('this string is longer than the inline ascii storage upstream keeps')
	assert voidptr(vm.create_string(long_text)) != voidptr(vm.create_string(long_text))
	unicode := vm.create_string(utf16_string('ünïcödé'))
	assert unicode.utf16_string() == utf16_string('ünïcödé')
	// Fly strings still dedupe through the cache regardless of storage.
	assert voidptr(vm.create_fly_string(long_text)) == voidptr(vm.create_fly_string(long_text))
	non_ascii := utf16_string('é')
	assert voidptr(vm.create_string(non_ascii)) != voidptr(vm.empty_string())
	assert vm.create_string_from_str('abc').str() == 'abc'
}

fn test_source_short_ascii_storage_cache_respects_native_width_and_ipc_storage_form() {
	mut vm := VM.create()
	limit := int(sizeof(voidptr)) - int(sizeof(u8))
	inline_text := utf16_string_from_code_units([]u16{len: limit, init: u16(65)})
	assert inline_text.has_short_ascii_storage()
	assert voidptr(vm.create_string(inline_text)) == voidptr(vm.create_string(inline_text))
	long_ascii := utf16_string_from_code_units([]u16{len: limit + 1, init: u16(65)})
	assert long_ascii.has_ascii_storage() && !long_ascii.has_short_ascii_storage()
	assert voidptr(vm.create_string(long_ascii)) != voidptr(vm.create_string(long_ascii))
	decoded_utf16 := utf16_string_from_code_units_with_storage([u16(65), 66], false)!
	assert !decoded_utf16.has_short_ascii_storage()
	first := vm.create_string(decoded_utf16)
	assert voidptr(first) != voidptr(vm.create_string(decoded_utf16))
	assert !first.utf16.has_ascii_storage()
	// PrimitiveString's single-ASCII cache precedes its inline-storage check.
	single := utf16_string_from_code_units_with_storage([u16(65)], false)!
	assert voidptr(vm.create_string(single)) == voidptr(vm.single_ascii_character_string(`A`))
}

fn test_numeric_string_caches_cover_small_and_large_numbers() {
	mut vm := VM.create()
	small := vm.create_string_from_unsigned_integer(42)
	assert small.str() == '42'
	assert voidptr(vm.create_string_from_unsigned_integer(42)) == voidptr(small)
	large := vm.create_string_from_unsigned_integer(123456789)
	assert large.str() == '123456789'
	assert voidptr(vm.create_string_from_unsigned_integer(123456789)) == voidptr(large)
	// A colliding slot in the large cache is replaced; the fly string cache still
	// hands back the original cell for the same digits.
	colliding := vm.create_string_from_unsigned_integer(123456789 + u64(large_numeric_string_cache_size))
	assert colliding.str() == (123456789 + u64(large_numeric_string_cache_size)).str()
	assert voidptr(colliding) != voidptr(large)
	assert vm.create_string_from_unsigned_integer(123456789).str() == '123456789'
	roots := vm.heap_roots()
	assert roots.contains(voidptr(small))
	assert roots.contains(voidptr(vm.empty_string()))
}

fn test_symbols_report_descriptions_keys_and_registry_membership() {
	mut vm := VM.create()
	unique := Symbol.create(utf16_string('local'), .unique)
	assert unique.descriptive_string().str() == 'Symbol(local)'
	assert unique.key() == none
	assert !unique.is_global()
	anonymous := Symbol.create(none, .unique)
	assert anonymous.descriptive_string().str() == 'Symbol()'
	private := Symbol.create_private()
	assert private.is_private()
	global := Symbol.create(utf16_string('shared.key'), .global)
	assert global.is_global()
	assert global.key()?.str() == 'shared.key'
	vm.global_symbol_registry_set(utf16_string('shared.key'), global)
	assert voidptr(vm.global_symbol_registry_lookup(utf16_string('shared.key'))?) == voidptr(global)
	assert vm.global_symbol_registry_lookup(utf16_string('other')) == none
	assert vm.global_symbol_registry().len == 1
	assert vm.heap_roots().contains(voidptr(global))
	for index, name in well_known_symbol_names {
		symbol := vm.well_known_symbol(unsafe { WellKnownSymbol(index) })
		assert symbol.description?.str() == 'Symbol.${name}'
		assert vm.heap_roots().contains(voidptr(symbol))
	}
	assert voidptr(vm.well_known_symbol_unscopables()) == voidptr(vm.well_known_symbol(.unscopables))
	assert voidptr(vm.well_known_symbol_match()) == voidptr(vm.well_known_symbol(.match_))
}
