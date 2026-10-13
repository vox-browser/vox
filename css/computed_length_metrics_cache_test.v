module css

import dom

fn test_length_metrics_cache_reuses_font_inputs_and_observes_live_changes() {
	mut style := ComputedProperties.new()
	style.set_property(.font_size, &dom.StyleValue{css_text: '20px'}, .no, .no)
	style.set_property(.line_height, &dom.StyleValue{css_text: '2'}, .no, .no)
	first := style.length_resolution_context()
	cache := style.cached_length_metrics_
	assert first.font_metrics.font_size.to_double() == 20
	assert first.font_metrics.line_height.to_double() == 40
	assert style.length_resolution_context().font_metrics == first.font_metrics
	assert voidptr(style.cached_length_metrics_) == voidptr(cache)
	style.viewport_rect_ = CSSPixelRect.new(0, 0, 640, 480)
	assert style.length_resolution_context().viewport_rect.width.to_double() == 640
	assert voidptr(style.cached_length_metrics_) == voidptr(cache)
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

fn test_layout_length_accessors_retain_metrics_on_the_owning_style() {
	mut style := ComputedProperties.new()
	style.set_property(.font_size, &dom.StyleValue{css_text: '20px'}, .no, .no)
	style.set_property(.padding_left, &dom.StyleValue{css_text: '2em'}, .no, .no)
	values := resolve_computed_values(style)
	style.cached_length_metrics_ = unsafe { nil }
	assert values.length_percentage_to_px(.padding_left, 100) or { -1 } == 40
	cache := style.cached_length_metrics_
	assert cache != unsafe { nil }
	assert values.length_percentage_to_px(.padding_left, 200) or { -1 } == 40
	assert voidptr(style.cached_length_metrics_) == voidptr(cache)
}
