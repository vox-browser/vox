module webassembly

import math
import webidl

fn test_external_cache_keys_actual_records_without_platform_or_property_aliasing() {
	mut cache := WebAssemblyCache.create()
	first := webidl.platform_object_value_with_id(11)
	second := webidl.platform_object_value_with_id(12)
	cache.add_extern_value(0, first)
	cache.add_extern_value(1, second)
	assert cache.get_extern_address(first)? == 0
	assert cache.get_extern_address(second)? == 1
	object := webidl.object_value_with_id({
		'before': webidl.number_value(1)
	}, 13)
	cache.add_extern_value(2, object)
	changed := webidl.object_value_with_id({
		'after': webidl.number_value(2)
	}, 13)
	assert cache.get_extern_address(changed)? == 2
	assert cache.get_extern_address(webidl.object_value_with_id(object.object_value, 14)) == none
	cache.add_extern_value(0, webidl.string_value('replacement'))
	assert cache.get_extern_address(first) == none
	assert cache.get_extern_address(second)? == 1
	assert cache.get_extern_address(webidl.string_value('replacement'))? == 0
}

fn test_external_cache_retains_signed_zero_promise_and_actual_runtime_owner_identity() {
	mut cache := WebAssemblyCache.create()
	cache.add_extern_value(0, webidl.number_value(0.0))
	cache.add_extern_value(1, webidl.number_value(-0.0))
	assert cache.get_extern_address(webidl.number_value(0.0))? == 0
	assert cache.get_extern_address(webidl.number_value(-0.0))? == 1
	cache.add_extern_value(2, webidl.number_value(math.nan()))
	assert cache.get_extern_address(webidl.number_value(math.f64_from_bits(0x7ff0000000000001)))? == 2
	first := webidl.create_promise()
	second := webidl.create_promise()
	cache.add_extern_value(3, webidl.promise_value(first))
	cache.add_extern_value(4, webidl.promise_value(second))
	assert cache.get_extern_address(webidl.promise_value(first))? == 3
	assert cache.get_extern_address(webidl.promise_value(second))? == 4
	owner_a := &WebAssemblyCache{}
	owner_b := &WebAssemblyCache{}
	cell := &WebAssemblyCache{}
	actual := webidl.runtime_value(webidl.RuntimeValue{
		context:           voidptr(owner_a)
		value:             voidptr(cell)
		string_conversion: fn () !string { panic('cache hashing must not invoke ToString') }
	})
	cache.add_extern_value(5, actual)
	assert cache.get_extern_address(actual)? == 5
	other_owner := webidl.runtime_value(webidl.RuntimeValue{
		context:           voidptr(owner_b)
		value:             voidptr(cell)
		string_conversion: fn () !string { panic('cache hashing must not invoke ToString') }
	})
	assert cache.get_extern_address(other_owner) == none
}

fn test_unboxed_typed_dictionary_values_are_retained_without_fabricated_identity() {
	mut cache := WebAssemblyCache.create()
	first := webidl.object_value({
		'name': webidl.string_value('first')
	})
	second := webidl.object_value({
		'name': webidl.string_value('second')
	})
	cache.add_extern_value(0, first)
	cache.add_extern_value(1, second)
	assert cache.get_extern_value(0)?.object_value['name'].string_value == 'first'
	assert cache.get_extern_value(1)?.object_value['name'].string_value == 'second'
	assert cache.get_extern_address(first) == none
	assert cache.get_extern_address(second) == none
}

fn test_full_width_external_bigints_do_not_alias_their_signed_projection() {
	mut cache := WebAssemblyCache.create()
	zero := webidl.bigint_value(0)
	wide := webidl.bigint_value_for_record(webidl.value_to_bigint(webidl.string_value('18446744073709551616'))!)
	assert wide.bigint_value == 0
	cache.add_extern_value(0, zero)
	cache.add_extern_value(1, wide)
	assert cache.get_extern_address(zero)? == 0
	assert cache.get_extern_address(wide)? == 1
	equal_wide := webidl.bigint_value_for_record(webidl.value_to_bigint(webidl.string_value('0x10000000000000000'))!)
	assert cache.get_extern_address(equal_wide)? == 1
	assert webidl.to_string(cache.get_extern_value(1)?)! == '18446744073709551616'
}
