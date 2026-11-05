module layout

import css
import dom

// Each comparison uses a new pool, releases producer scratch, and compares
// the scalar with the full uncached inline algorithm in another fresh probe.
fn retained_width_compare(container &BlockContainer, space AvailableSpace,
	height int, definite bool) bool {
	styled := unsafe { &NodeWithStyle(container) }
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	mut probe := source.new_measurement_for_subtree(styled)
	mut used := probe.get_mutable(styled)
	used.set_indefinite_content_width()
	used.set_content_height(CSSPixels.new(height))
	used.set_has_definite_height(definite)
	root := unsafe { &Node(container) }
	eligible := (space.width.is_min_content() || space.width.is_max_content())
		&& inline_layout_workspace_is_closed(root, true)
		&& intrinsic_inline_width_is_independent(root)
	reused := eligible && retained_intrinsic_inline_width(container, used, space) != none
	actual := measure_disposable_inline_width(mut probe, container, mut used, space)
	probe.release_measurement()
	source.release_measurement_chunk_pool()
	gc_collect()
	mut oracle := LayoutState.new()
	mut expected := oracle.get_mutable(styled)
	expected.set_indefinite_content_width()
	expected.set_content_height(CSSPixels.new(height))
	expected.set_has_definite_height(definite)
	result := run_uncached_inline_formatting_context(mut oracle, container, mut expected,
		.intrinsic_sizing, space, none)
	assert actual == result.automatic_content_width
	return reused
}

fn retained_width_space(minimum bool) AvailableSpace {
	return AvailableSpace.new(if minimum { AvailableSize.make_min_content() }
		else { AvailableSize.make_max_content() }, AvailableSize.make_indefinite())
}

fn test_intrinsic_inline_scalar_survives_dirty_flags_and_retired_pools() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	mut container := intrinsic_width_container(document, 'AV To á 😀 אבג longword and text  ', '')
	for minimum in [true, false] {
		space := retained_width_space(minimum)
		assert !retained_width_compare(container, space, 17, false)
		// Preserve normal invalidation: the ordinary box cache is still cleared.
		container.reset_needs_layout_update()
		container.set_needs_layout_update(true)
		assert container.cached_intrinsic_sizes_ == none
		for height in [17, 999, 0] {
			assert retained_width_compare(container, space, height, false) == !disable_retained_intrinsic_inline_width
		}
	}
}

fn test_intrinsic_inline_scalar_revalidates_text_style_tree_and_font_inputs() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut container := intrinsic_width_container(document, 'initial width', '')
	space := retained_width_space(false)
	assert !retained_width_compare(container, space, 0, false)
	assert retained_width_compare(container, space, 0, false) == !disable_retained_intrinsic_inline_width
	mut text := container.children()[0].as_text_node()?
	mut data := text.dom_node()?.as_character_data()?
	data.set_data('changed text has a much longer contribution')
	text.invalidate_text_for_rendering()
	assert !retained_width_compare(container, space, 0, false)
	mut style := unsafe { &css.ComputedProperties(container.computed_values()) }
	style.set_property(.color, css.parse_css_value(css.ParsingParams{}, 'red', .color)?, .no, .no)
	assert !retained_width_compare(container, space, 0, false)
	mut replacement := document.create_element('div')!
	replacement.set_attribute_value('style', 'display:block;font:28px/32px Arial;letter-spacing:4px')
	container.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(replacement, none)))
	assert !retained_width_compare(container, space, 0, false)
	container.append_child(unsafe { &Node(TextNode.new(document,
		document.create_text_node(' appended').as_node(), ' appended')) })
	assign_layout_indexes(unsafe { &Node(container) })
	assert !retained_width_compare(container, space, 0, false)
	container.remove_child(unsafe { &Node(text) })
	container.append_child(unsafe { &Node(TextNode.new(document,
		document.create_text_node('same count, different child').as_node(), 'same count, different child')) })
	assign_layout_indexes(unsafe { &Node(container) })
	assert !retained_width_compare(container, space, 0, false)
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('UnrelatedRetainedWidthFace')
	assert !retained_width_compare(container, space, 0, false)
	document.bump_style_environment_version()
	assert !retained_width_compare(container, space, 0, false)
	document.set_font_rendering_policy(.chromium)
	assert !retained_width_compare(container, space, 0, false)
}

fn test_intrinsic_inline_scalar_matches_nested_styled_spans_and_percentage_edges() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut container := intrinsic_width_container(document, 'leading ', 'text-indent:10%')
	mut element := document.create_element('span')!
	element.set_attribute_value('style', 'font:23px/27px Arial;padding-inline:7%;margin-inline:3px;border:2px solid')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut span := InlineNode.new(document, element.as_node(), style)
	span.append_child(unsafe { &Node(TextNode.new(document,
		document.create_text_node('nested 😀 longword').as_node(), 'nested 😀 longword')) })
	container.append_child(unsafe { &Node(span) })
	span.recompute_containing_block()
	assign_layout_indexes(unsafe { &Node(container) })
	for minimum in [true, false] {
		space := retained_width_space(minimum)
		assert !retained_width_compare(container, space, 0, false)
		assert retained_width_compare(container, space, 0, false) == !disable_retained_intrinsic_inline_width
	}
	mut replacement := document.create_element('span')!
	replacement.set_attribute_value('style', 'font:31px/36px Arial;padding:5px')
	span.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(replacement, none)))
	assert !retained_width_compare(container, retained_width_space(false), 0, false)
}

fn test_intrinsic_inline_scalar_keeps_definite_heights_and_bounded_history() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	container := intrinsic_width_container(document, 'a b c', '')
	space := retained_width_space(false)
	for height in [17, 40, 90, 120, 200, 300] {
		assert !retained_width_compare(container, space, height, true)
		assert retained_width_compare(container, space, height, true) == !disable_retained_intrinsic_inline_width
	}
	if !disable_retained_intrinsic_inline_width {
		assert container.retained_intrinsic_inline_widths_.entries.len == 4
	}
	assert !retained_width_compare(container, space, 17, true)
	assert !retained_width_compare(container, space, 17, false)
}

fn test_intrinsic_inline_scalar_rejects_contexts_requiring_full_geometry() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for extra in ['position:relative', 'float:left', 'direction:rtl', 'writing-mode:vertical-rl',
		'text-align:justify', 'text-overflow:ellipsis', 'max-lines:1;continue:collapse'] {
		container := intrinsic_width_container(document, 'alpha beta gamma', extra)
		for minimum in [true, false] {
			for _ in 0 .. 2 {
				assert !retained_width_compare(container, retained_width_space(minimum), 0, false)
			}
		}
		assert container.retained_intrinsic_inline_widths_ == unsafe { nil }
	}
}

fn test_intrinsic_inline_scalar_revalidates_resolved_context_without_raw_mutation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	container := intrinsic_width_container(document, 'context dependent text', 'text-indent:1rem')
	space := retained_width_space(false)
	assert !retained_width_compare(container, space, 0, false)
	assert retained_width_compare(container, space, 0, false) == !disable_retained_intrinsic_inline_width
	mut style := unsafe { &css.ComputedProperties(container.computed_values()) }
	revision := style.mutation_revision()
	style.root_font_size_px_ += 5
	assert style.mutation_revision() == revision
	assert !retained_width_compare(container, space, 0, false)
	style.root_line_height_px_ += 5
	assert !retained_width_compare(container, space, 0, false)
	style.viewport_rect_ = css.CSSPixelRect.new(0, 0, 999, 777)
	assert !retained_width_compare(container, space, 0, false)
	document.set_viewport_rect(dom.Rect{0, 0, 901, 701})
	assert !retained_width_compare(container, space, 0, false)
	document.set_layout_coordinate_scale(2)
	assert !retained_width_compare(container, space, 0, false)
	assert style.mutation_revision() == revision
}
