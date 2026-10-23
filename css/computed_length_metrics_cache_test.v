module css

import dom
import platform

fn test_length_metrics_observe_live_font_and_line_height_changes() {
	mut style := ComputedProperties.new()
	style.set_property(.font_size, &dom.StyleValue{css_text: '20px'}, .no, .no)
	style.set_property(.line_height, &dom.StyleValue{css_text: '2'}, .no, .no)
	first := style.length_resolution_context()
	assert first.font_metrics.font_size.to_double() == 20
	assert first.font_metrics.line_height.to_double() == 40
	assert style.length_resolution_context().font_metrics == first.font_metrics
	style.viewport_rect_ = CSSPixelRect.new(0, 0, 640, 480)
	assert style.length_resolution_context().viewport_rect.width.to_double() == 640
	style.set_animated_property(.font_size, &dom.StyleValue{css_text: '30px'}, .no, .no)
	assert style.length_resolution_context().font_metrics.font_size.to_double() == 30
	assert style.length_resolution_context().font_metrics.line_height.to_double() == 60
	style.remove_animated_property(.font_size)
	assert style.length_resolution_context().font_metrics.font_size.to_double() == 20
	style.line_height_ = CSSPixels.new(25)
	assert style.length_resolution_context().font_metrics.line_height.to_double() == 25
	style.root_font_size_px_ = 12
	style.root_line_height_px_ = 18
	context := LengthResolutionContext.for_computed_properties(style)
	assert context.root_font_metrics.font_size.to_double() == 12
	assert context.root_font_metrics.line_height.to_double() == 18
	assert first.font_metrics.font_size.to_double() == 20
	assert first.font_metrics.line_height.to_double() == 40
}

fn test_length_metrics_reuse_does_not_share_container_query_lookup_state() {
	document := dom.Document.create(dom.url_about_blank())
	subject := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic('${err}') }
	mut style := ComputedProperties.new()
	style.subject_element_ = subject
	first := style.length_resolution_context()
	second := LengthResolutionContext.for_computed_properties(style)
	first_cache := first.query_container_cache or { panic('missing first cache') }
	second_cache := second.query_container_cache or { panic('missing second cache') }
	assert voidptr(first_cache) != voidptr(second_cache)
	mut first_mutable := unsafe { &LengthQueryContainerCache(first_cache) }
	first_mutable.width_was_computed = true
	assert !second_cache.width_was_computed
}

fn test_layout_length_accessors_use_the_owning_style_metrics() {
	mut style := ComputedProperties.new()
	style.set_property(.font_size, &dom.StyleValue{css_text: '20px'}, .no, .no)
	style.set_property(.padding_left, &dom.StyleValue{css_text: '2em'}, .no, .no)
	values := resolve_computed_values(style)
	assert values.length_percentage_to_px(.padding_left, 100) or { -1 } == 40
	assert values.length_percentage_to_px(.padding_left, 200) or { -1 } == 40
}

fn test_length_contexts_share_size_metrics_without_per_style_records() {
	font_size := dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(20))))
	line_height := dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(2)))
	mut styles := []&ComputedProperties{cap: 256}
	for _ in 0 .. 256 {
		mut style := ComputedProperties.new()
		style.set_property(.font_size, font_size, .no, .no)
		style.set_property(.line_height, line_height, .no, .no)
		styles << style
	}
	// Warm the shared size cache before measuring all other style contexts.
	first := styles[0].length_resolution_context()
	before := platform.thread_arena_usage().used
	for style in styles {
		context := style.length_resolution_context()
		assert context.font_metrics == first.font_metrics
		assert context.root_font_metrics == first.root_font_metrics
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}
