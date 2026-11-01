module layout

import css
import dom
import html

fn font_validation_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn font_validation_assert_full_layout(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}

fn test_retained_font_validation_survives_repeated_layout_and_rechecks_each_generation() {
	for display in ['block', 'flow-root', 'grid'] {
		mut document := html.parse_document('<!doctype html><style>body{font:16px/20px monospace}#stable{display:${display};width:190px}</style><div id="changed"></div><div id="stable">Unchanged <span>nested text wraps onto several lines.</span></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		root := font_validation_node(document, 'stable')
		key := u64(voidptr(root))
		initial := document_layout_result(document)?
		inline_cache := initial.state.inline_layouts_[key]
		block_cache := initial.state.block_layouts_[key]
		assert (display == 'block' && inline_cache != unsafe { nil })
			|| (display != 'block' && block_cache != unsafe { nil })
		mut computer := css.css_style_computer_for(document).font_computer()
		mut changed := document.get_element_by_id('changed')?
		for epoch in 0 .. 2 {
			computer.did_load_font('UnrelatedValidationFamily${epoch}')
			generation := computer.environment_generation()
			for iteration in 0 .. 3 {
				changed.set_attribute_value('style', 'height:${10 + epoch * 30 + iteration * 5}px')
				document.update_layout(.debugging)
				current := document_layout_result(document)?
				if display == 'block' {
					reused := current.state.inline_layouts_[key] or { panic('lost inline cache') }
					assert voidptr(reused) == voidptr(inline_cache)
					assert reused.font_generation != generation
					assert reused.font_validation_.valid == !disable_retained_font_validation
					if !disable_retained_font_validation { assert reused.font_validation_.generation == generation }
				} else {
					reused := current.state.block_layouts_[key] or { panic('lost block cache') }
					assert voidptr(reused) == voidptr(block_cache)
					assert reused.font_generation != generation
					assert reused.font_validation_.valid == !disable_retained_font_validation
					if !disable_retained_font_validation { assert reused.font_validation_.generation == generation }
				}
			}
		}
		font_validation_assert_full_layout(mut document)
	}
}

fn test_retained_font_validation_does_not_remember_failed_font_metric_checks() {
	mut document := html.parse_document('<!doctype html><p id="stable" style="font:16px/20px monospace">Stable text</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	root := font_validation_node(document, 'stable')
	result := document_layout_result(document)?
	cached := result.state.inline_layouts_[u64(voidptr(root))] or { panic('uncached text') }
	mut mismatched := cached.inputs.clone()
	mismatched[0] = RetainedInlineInput{...cached.inputs[0], line_height: CSSPixels.new(999)}
	mut validation := RetainedFontValidation{}
	assert !validation.matches(mismatched, 1, 2)
	assert !validation.valid
	assert validation.matches(cached.inputs, 1, 2)
	if !disable_retained_font_validation { assert validation.valid && validation.generation == 2 }
	assert !validation.matches(mismatched, 1, 3)
	assert !validation.matches(mismatched, 1, 3)
	if !disable_retained_font_validation { assert validation.generation == 2 }
	assert validation.matches(cached.inputs, 1, 3)
	if !disable_retained_font_validation { assert validation.generation == 3 }
}

fn test_retained_font_validation_keeps_style_text_and_tree_invalidation_live() {
	mut document := html.parse_document('<!doctype html><style>body{font:16px/20px monospace}</style><div id="changed"></div><p id="stable" style="width:190px">Original nested text wraps onto several lines.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('UnrelatedValidationFamily')
	mut changed := document.get_element_by_id('changed')?
	for height in [10, 20] {
		changed.set_attribute_value('style', 'height:${height}px')
		document.update_layout(.debugging)
	}
	mut stable := document.get_element_by_id('stable')?
	stable.set_attribute_value('style', 'width:130px;font:24px/28px serif')
	document.update_layout(.debugging)
	font_validation_assert_full_layout(mut document)
	stable.set_inner_html('<strong>New children</strong> and longer replacement text that changes line wrapping.')!
	document.update_layout(.debugging)
	font_validation_assert_full_layout(mut document)
}
