module css

import platform

#include "length_percentage_storage_test.h"

$if gcboehm ? {
	fn C.vox_length_percentage_watch(owner voidptr)
	fn C.vox_length_percentage_array_kind(data voidptr) int
	fn C.vox_length_percentage_collect(depth u32)
	fn C.vox_length_percentage_run_worker(work fn ())
	fn C.vox_length_percentage_alive() int
}

__global inline_length_percentage_kept []LengthPercentage

fn test_inline_length_percentage_defaults_and_scalar_operations_allocate_nothing() {
	assert sizeof(LengthPercentage) <= 16
	context := LengthResolutionContext.default()
	reference := CSSPixels.new(200)
	before := platform.thread_arena_usage().used
	mut sum := f64(0)
	for index in 0 .. 4096 {
		length := LengthPercentage.from_length(Length.make_px(f64(index) / 8))
		percentage := LengthPercentage.from_percentage(Percentage.new(25))
		assert length.is_length() && !length.contains_percentage()
		assert percentage.is_percentage() && percentage.contains_percentage()
		assert length == LengthPercentage.from_length(length.length())
		assert percentage == LengthPercentage.from_percentage(percentage.percentage())
		sum += length.to_px(context, reference).to_double()
		sum += percentage.to_px(context, reference).to_double()
	}
	after := platform.thread_arena_usage().used
	assert sum > 200000
	$if prealloc { assert after == before }
	assert LengthPercentage{} == LengthPercentage.from_length(Length.make_px(0))
	assert LengthPercentage.from_length(Length.new(1, .em)) != LengthPercentage.from_length(Length.make_px(1))
	assert LengthPercentage.from_percentage(Percentage.new(1)) != LengthPercentage.from_length(Length.make_px(1))
}

@[noinline]
fn inline_length_percentage_calculations() []LengthPercentage {
	mut values := []LengthPercentage{}
	for text in ['calc(2px + 25%)', 'calc(3px + 25%)'] {
		parsed := parse_css_value_logic(.width, text) or { panic(text) }
		values << LengthPercentage.from_style_value_logic(parsed)
	}
	return values
}

fn test_inline_length_percentage_keeps_calculation_owners_through_copies_and_collection() {
	values := inline_length_percentage_calculations()
	first := values[0]
	assert values[0] == first
	assert values[0] != values[1]
	for _ in 0 .. 3 {
		gc_collect()
		assert first.is_calculated() && first.contains_percentage()
		assert first.to_px(LengthResolutionContext.default(), CSSPixels.new(200)).to_double() == 52
		assert values[1].to_px(LengthResolutionContext.default(), CSSPixels.new(200)).to_double() == 53
	}
}

fn inline_length_percentage_create_sole_owner() {
	$if gcboehm ? {
		inline_length_percentage_kept = inline_length_percentage_calculations()
		assert C.vox_length_percentage_array_kind(inline_length_percentage_kept.data) == 1
		C.vox_length_percentage_watch(unsafe { inline_length_percentage_kept[0].payload_.calculation })
	}
}

fn inline_length_percentage_verify_sole_owner() {
	assert inline_length_percentage_kept[0].to_px(LengthResolutionContext.default(), CSSPixels.new(200)).to_double() == 52
}

fn inline_length_percentage_replace_calculations() {
	for index in 0 .. inline_length_percentage_kept.len {
		inline_length_percentage_kept[index] = LengthPercentage.from_length(Length.make_px(7))
	}
}

fn test_inline_length_percentage_union_is_traced_and_replacement_drops_its_owner() {
	$if gcboehm ? {
		C.vox_length_percentage_run_worker(inline_length_percentage_create_sole_owner)
		for _ in 0 .. 6 { C.vox_length_percentage_collect(8) }
		assert C.vox_length_percentage_alive() == 1
		C.vox_length_percentage_run_worker(inline_length_percentage_verify_sole_owner)
		C.vox_length_percentage_run_worker(inline_length_percentage_replace_calculations)
		for _ in 0 .. 8 { C.vox_length_percentage_collect(8) }
		assert C.vox_length_percentage_alive() == 0
		inline_length_percentage_kept = []LengthPercentage{}
	}
}
