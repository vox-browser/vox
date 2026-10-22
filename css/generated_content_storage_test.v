module css

import platform

#include "computed_property_store_test.h"

$if gcboehm ? {
	fn C.vox_property_store_watch(index u32, owner voidptr)
	fn C.vox_property_store_collect(depth u32)
	fn C.vox_property_store_worker(work fn ())
	fn C.vox_property_store_alive() u32
	fn C.GC_base(pointer voidptr) voidptr
}

fn test_ordinary_styles_reserve_no_generated_content_or_counter_payload() {
	mut style := &ComputedProperties{}
	assert sizeof(ComputedProperties) <= 600
	assert voidptr(style.computed_content_storage_) == unsafe { nil }
	assert voidptr(style.computed_list_style_storage_) == unsafe { nil }
	assert style.computed_content() == none
	assert style.computed_list_style_type() == ListStyleType{}
	style.set_content(none)
	style.set_list_style_type(ListStyleType{})
	assert voidptr(style.computed_content_storage_) == unsafe { nil }
	assert voidptr(style.computed_list_style_storage_) == unsafe { nil }
}

fn test_builtin_markers_share_storage_but_getters_return_value_snapshots() {
	for name in ['disc', 'decimal', 'circle', 'square', 'disclosure-open', 'disclosure-closed'] {
		counter := generated_content_builtin_counter(name)
		mut first := &ComputedProperties{}
		mut second := &ComputedProperties{}
		value := ListStyleType{ kind: .counter_style, name: name, counter_style: counter }
		first.set_list_style_type(value)
		second.set_list_style_type(value)
		assert voidptr(first.computed_list_style_storage_) == voidptr(second.computed_list_style_storage_)
		mut returned := first.computed_list_style_type()
		returned.name = 'changed copy'
		assert first.computed_list_style_type().name == name
		first.set_list_style_type(ListStyleType{ kind: .string, name: 'literal' })
		assert second.computed_list_style_type().name == name
		assert first.computed_list_style_type().name == 'literal'
	}
}

fn generated_content_builtin_counter(name string) CounterStyle {
	builtins := builtin_counter_styles()
	return match name {
		'disc' { builtins.disc }
		'decimal' { builtins.decimal }
		'circle' { builtins.circle }
		'square' { builtins.square }
		'disclosure-open' { builtins.disclosure_open }
		else { builtins.disclosure_closed }
	}
}

fn generated_content_marker_symbol(name string) string {
	return match name {
		'circle' { '◦' }
		'square' { '▪' }
		'disclosure-open' { '▾' }
		else { '▸' }
	}
}

fn test_additional_builtin_marker_names_do_not_replace_custom_counter_definitions() {
	for name in ['circle', 'square', 'disclosure-open', 'disclosure-closed'] {
		canonical := stored_list_style_type(ListStyleType{
			kind:          .counter_style
			name:          name
			counter_style: generated_content_builtin_counter(name)
		})
		mut custom := generated_content_builtin_counter(name)
		custom.prefix_ = 'custom '
		mut first := &ComputedProperties{}
		first.set_list_style_type(ListStyleType{ kind: .counter_style, name: name, counter_style: custom })
		assert voidptr(first.computed_list_style_storage_) != voidptr(canonical)
		retained := &ComputedProperties{ ...first }
		first.set_list_style_type(ListStyleType{})
		counter := retained.computed_list_style_type().counter_style or { panic('lost custom marker') }
		assert counter.prefix_ == 'custom '
		assert retained.computed_list_style_type().name == name
		builtin := canonical.counter_style or { panic('lost builtin marker') }
		assert builtin.prefix_ == ''
		assert stored_list_style_type(ListStyleType{ kind: .string, name: name }).kind == .string
		assert stored_list_style_type(ListStyleType{ kind: .counter_style, name: name }).counter_style == none
	}
}

fn test_additional_builtin_marker_storage_does_not_grow_per_style() {
	for name in ['circle', 'square', 'disclosure-open', 'disclosure-closed'] {
		value := ListStyleType{ kind: .counter_style, name: name, counter_style: generated_content_builtin_counter(name) }
		canonical := stored_list_style_type(value)
		before := platform.thread_arena_usage().used
		for _ in 0 .. 512 {
			assert voidptr(stored_list_style_type(value)) == voidptr(canonical)
		}
		$if prealloc {
			assert platform.thread_arena_usage().used - before < 4096
		}
	}
}

fn generated_content_equal_additional_builtin_payload(name_value string) {
	css_additional_builtin_list_styles_ = AdditionalBuiltinListStyles{}
	name := name_value.clone()
	counter := fixed_symbol_counter_style(name, generated_content_marker_symbol(name).clone())
	mut style := &ComputedProperties{}
	style.set_list_style_type(ListStyleType{ kind: .counter_style, name: name, counter_style: counter })
	$if gcboehm ? {
		C.vox_property_store_watch(0, C.GC_base(name.str))
		C.vox_property_store_watch(1, C.GC_base(counter.range_.data))
	}
}

fn generated_content_equal_circle_payload() {
	generated_content_equal_additional_builtin_payload('circle')
}

fn generated_content_equal_square_payload() {
	generated_content_equal_additional_builtin_payload('square')
}

fn generated_content_equal_disclosure_open_payload() {
	generated_content_equal_additional_builtin_payload('disclosure-open')
}

fn generated_content_equal_disclosure_closed_payload() {
	generated_content_equal_additional_builtin_payload('disclosure-closed')
}

fn generated_content_check_collected_additional_builtin(work fn ()) {
	$if gcboehm ? {
		C.vox_property_store_worker(work)
		for _ in 0 .. 4 { C.vox_property_store_collect(8) }
		assert C.vox_property_store_alive() == 0
	}
}

fn test_additional_builtin_markers_do_not_retain_equal_caller_payloads() {
	generated_content_check_collected_additional_builtin(generated_content_equal_circle_payload)
	generated_content_check_collected_additional_builtin(generated_content_equal_square_payload)
	generated_content_check_collected_additional_builtin(generated_content_equal_disclosure_open_payload)
	generated_content_check_collected_additional_builtin(generated_content_equal_disclosure_closed_payload)
}

fn test_additional_builtin_markers_outlive_the_first_callers_arena() {
	$if prealloc {
		for name_value in ['circle', 'square', 'disclosure-open', 'disclosure-closed'] {
			css_additional_builtin_list_styles_ = AdditionalBuiltinListStyles{}
			builtin := generated_content_builtin_counter(name_value)
			mut arena := platform.new_arena('additional builtin marker caller')
			entry := arena.enter()
			name := name_value.clone()
			caller := fixed_symbol_counter_style(name, generated_content_marker_symbol(name).clone())
			marker := stored_list_style_type(ListStyleType{ kind: .counter_style, name: name, counter_style: caller })
			arena.leave(entry)
			assert arena.contains(name.str)
			assert arena.contains(caller.range_.data)
			assert !arena.contains(marker)
			assert !arena.contains(marker.name.str)
			retained := marker.counter_style or { panic('lost builtin marker') }
			assert voidptr(retained.range_.data) == voidptr(builtin.range_.data)
			caller_algorithm := caller.algorithm_ as GenericCounterStyleAlgorithm
			retained_algorithm := retained.algorithm_ as GenericCounterStyleAlgorithm
			builtin_algorithm := builtin.algorithm_ as GenericCounterStyleAlgorithm
			assert arena.contains(caller_algorithm.symbol_list.data)
			assert arena.contains(caller_algorithm.symbol_list[0].str)
			assert voidptr(retained_algorithm.symbol_list.data) == voidptr(builtin_algorithm.symbol_list.data)
			arena.release()
			assert marker.name == name_value
			assert retained == builtin
			assert retained_algorithm.symbol_list[0] == generated_content_marker_symbol(name_value)
		}
	}
}

fn test_content_and_nonbuiltin_marker_snapshots_survive_replacement_and_collection() {
	mut style := &ComputedProperties{}
	mut counter := CounterStyle.decimal()
	counter.prefix_ = 'custom '
	style.set_list_style_type(ListStyleType{ kind: .counter_style, name: 'disc', counter_style: counter })
	style.set_content(ContentData{
		type_: .list
		text:  'retained content'
		items: [ContentItem{ type_: .text, value: 'retained item' }]
	})
	retained := &ComputedProperties{ ...style }
	style.set_content(none)
	style.set_list_style_type(ListStyleType{})
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.vox_property_store_collect(4)
		}
		content := retained.computed_content() or { panic('lost content') }
		assert content.text == 'retained content'
		assert content.items[0].value == 'retained item'
		marker := retained.computed_list_style_type()
		retained_counter := marker.counter_style or { panic('lost custom counter') }
		assert retained_counter.prefix_ == 'custom '
		assert marker.name == 'disc'
		assert style.computed_content() == none
		assert style.computed_list_style_type() == ListStyleType{}
	}
}

fn generated_content_collectible_payloads() {
	mut style := &ComputedProperties{}
	style.set_content(ContentData{ type_: .list, text: 'temporary content'.repeat(30) })
	style.set_list_style_type(ListStyleType{ kind: .string, name: 'temporary marker'.repeat(30) })
	$if gcboehm ? {
		C.vox_property_store_watch(0, style.computed_content_storage_)
		C.vox_property_store_watch(1, style.computed_list_style_storage_)
	}
}

fn test_custom_generated_content_has_no_global_cache_owner() {
	$if gcboehm ? {
		C.vox_property_store_worker(generated_content_collectible_payloads)
		for _ in 0 .. 4 { C.vox_property_store_collect(8) }
		assert C.vox_property_store_alive() == 0
	}
}

fn generated_content_equal_builtin_payload() {
	mut builtins := builtin_counter_styles()
	// Exercise the first publication with equal, independently owned inputs.
	// The global result must borrow the builtin's storage, not this caller's.
	builtins.disc_list_style = unsafe { nil }
	name := 'disc'.clone()
	counter := CounterStyle.disc()
	mut style := &ComputedProperties{}
	style.set_list_style_type(ListStyleType{ kind: .counter_style, name: name, counter_style: counter })
	$if gcboehm ? {
		C.vox_property_store_watch(0, C.GC_base(name.str))
		C.vox_property_store_watch(1, C.GC_base(counter.range_.data))
	}
}

fn test_shared_builtin_markers_do_not_retain_the_callers_equal_payload() {
	$if gcboehm ? {
		C.vox_property_store_worker(generated_content_equal_builtin_payload)
		for _ in 0 .. 4 { C.vox_property_store_collect(8) }
		assert C.vox_property_store_alive() == 0
		marker := builtin_counter_styles().disc_list_style
		assert marker.name == 'disc'
		counter := marker.counter_style or { panic('lost builtin counter') }
		assert counter.name() == 'disc'
	}
}

fn test_shared_builtin_markers_outlive_the_callers_arena() {
	$if prealloc {
		mut builtins := builtin_counter_styles()
		builtins.disc_list_style = unsafe { nil }
		mut arena := platform.new_arena('generated content caller')
		entry := arena.enter()
		name := 'disc'.clone()
		caller_counter := CounterStyle.disc()
		marker := stored_list_style_type(ListStyleType{
			kind:          .counter_style
			name:          name
			counter_style: caller_counter
		})
		arena.leave(entry)
		assert arena.contains(name.str)
		assert arena.contains(caller_counter.range_.data)
		assert !arena.contains(marker)
		assert !arena.contains(marker.name.str)
		retained_counter := marker.counter_style or { panic('lost builtin counter') }
		assert !arena.contains(retained_counter.range_.data)
		arena.release()
		assert marker.name == 'disc'
		assert retained_counter.name() == 'disc'
	}
}
