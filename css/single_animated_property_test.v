module css

import platform

fn test_single_animated_property_reads_live_store_without_allocating_or_copying() {
	mut style := ComputedProperties.new()
	value := parse_css_value(ParsingParams{}, '0.25', .opacity) or { panic('opacity') }
	assert !style.has_only_animated_property(.opacity)
	style.set_animated_property(.opacity, value, .no, .no)
	assert style.has_only_animated_property(.opacity)
	assert !style.has_only_animated_property(.width)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1000 { assert style.has_only_animated_property(.opacity) }
	assert platform.thread_arena_usage().used == before
	width := parse_css_value(ParsingParams{}, '20px', .width) or { panic('width') }
	style.set_animated_property(.width, width, .yes, .yes)
	assert !style.has_only_animated_property(.opacity)
	assert !style.has_only_animated_property(.width)
	style.remove_animated_property(.opacity)
	assert style.has_only_animated_property(.width)
	style.remove_animated_property(.width)
	assert !style.has_only_animated_property(.width)
}

fn test_single_animated_property_distinguishes_custom_storage_and_observes_alias_writes() {
	mut style := ComputedProperties.new()
	value := parse_css_value(ParsingParams{}, '0.25', .opacity) or { panic('opacity') }
	style.set_animated_custom_property('--alpha', value)
	assert !style.has_only_animated_property(.opacity)
	style.set_animated_property(.opacity, value, .no, .yes)
	assert style.has_only_animated_property(.opacity)
	assert style.has_animated_custom_properties()
	mut alias := *style
	alias.remove_animated_property(.opacity)
	assert !style.has_only_animated_property(.opacity)
	alias.set_animated_property(.opacity, value, .yes, .no)
	assert style.has_only_animated_property(.opacity)
}
