module indexeddb

import math

fn test_key_ordering_matches_indexeddb_type_and_value_order() {
	keys := [
		number_key(4),
		date_key(0),
		string_key('a'),
		binary_key([u8(1)]),
		array_key([number_key(1)]),
	]
	for i in 0 .. keys.len {
		for j in 0 .. keys.len {
			comparison := compare_two_keys(keys[i], keys[j]) or { panic(err) }
			assert comparison == compare_int(i, j)
		}
	}
	assert compare_two_keys(string_key('alpha'), string_key('beta'))! == -1
	// U+10000 begins with UTF-16 high surrogate D800, so IndexedDB orders it
	// before the BMP private-use character U+E000. UTF-8/scalar ordering gives
	// the opposite result and would violate Infra::code_unit_less_than.
	supplementary := rune(0x10000).str()
	bmp_after_surrogates := rune(0xe000).str()
	assert compare_two_keys(string_key(supplementary), string_key(bmp_after_surrogates))! == -1
	assert compare_two_keys(string_key(bmp_after_surrogates), string_key(supplementary))! == 1
	assert compare_two_keys(string_key('x' + supplementary), string_key('x' + bmp_after_surrogates))! == -1
	assert compare_two_keys(binary_key([u8(1), 2]), binary_key([u8(1), 3]))! == -1
	assert compare_two_keys(array_key([number_key(1)]), array_key([
		number_key(1),
		number_key(2),
	]))! == -1
}

fn test_invalid_keys_and_key_range_validation() {
	assert !number_key(math.nan()).is_valid()
	if _ := compare_two_keys(invalid_key(), number_key(1)) {
		assert false
	} else {
		assert err.msg().contains('DataError')
	}
	closed := IDBKeyRange.bound(number_key(1), number_key(3), false, false)!
	assert closed.includes(number_key(1))!
	assert closed.includes(number_key(2))!
	assert closed.includes(number_key(3))!
	open := IDBKeyRange.bound(number_key(1), number_key(3), true, true)!
	assert !open.includes(number_key(1))!
	assert open.includes(number_key(2))!
	assert !open.includes(number_key(3))!
	empty := IDBKeyRange.bound(number_key(2), number_key(2), true, false)!
	assert !empty.includes(number_key(2))!
	if _ := IDBKeyRange.bound(number_key(4), number_key(3), false, false) {
		assert false
	} else {
		assert err.msg().contains('DataError')
	}
}

fn test_key_path_evaluation_and_generated_key_injection() {
	value := object_value({
		'user': object_value({
			'id':   number_value(42)
			'name': string_value('Ada')
		})
		'tag':  string_value('math')
	})
	key := evaluate_key_path(value, 'user.id') or { panic('missing key') }
	assert key.kind == .number
	assert key.number == 42
	compound := evaluate_key_path(value, ['tag', 'user.name']) or { panic('missing key') }
	assert compound.kind == .array
	assert compound.items[0].text == 'math'
	injected := inject_key(object_value(map[string]Value{}), 'meta.id', number_key(7))!
	extracted := evaluate_key_path(injected, 'meta.id') or { panic('missing injected key') }
	assert extracted.number == 7
	// Structured clone isolation: mutating the original binary does not affect Value.
	mut bytes := [u8(1), 2]
	stored := binary_value(bytes)
	bytes[0] = 9
	assert stored.bytes == [u8(1), 2]
}

fn test_key_path_string_and_array_lengths() {
	supplementary := rune(0x10000).str()
	string_length := evaluate_key_path(string_value(supplementary), 'length') or {
		panic('missing string length')
	}
	assert string_length.kind == .number
	assert string_length.number == 2
	array_length := evaluate_key_path(array_value([string_value('a'),
		string_value('b')]), 'length') or { panic('missing array length') }
	assert array_length.kind == .number
	assert array_length.number == 2
	nested_length := evaluate_key_path(object_value({
		'value': string_value(supplementary + 'a')
	}), 'value.length') or { panic('missing nested string length') }
	assert nested_length.number == 3
}
