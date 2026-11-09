module layout

import dom
import html
import math

fn first_letter_wrappers(root &Node) []&Node {
	mut result := []&Node{}
	if generated := root.generated_for_pseudo_element() {
		if generated == .first_letter { result << root }
	}
	for child in root.children() {
		result << first_letter_wrappers(child)
	}
	return result
}

fn test_first_letter_pattern_preserves_unicode_graphemes_and_punctuation_rules() {
	assert (first_letter_end('“  À,”word', false) or { panic('missing letter') }) == 6
	assert (first_letter_end('A-b', false) or { panic('missing letter') }) == 1
	assert (first_letter_end('A(b', false) or { panic('missing letter') }) == 1
	assert (first_letter_end('?!', false) or { panic('missing punctuation') }) == 2
	assert (first_letter_end('𐐀\u0301b', false) or { panic('missing supplementary letter') }) == 3
	assert (first_letter_end('👩‍💻x', false) or { panic('missing emoji') }) == 5
	assert first_letter_end('\nHello', true) == none
	assert (first_letter_end('\nHello', false) or { panic('missing collapsed letter') }) == 2
}

fn test_first_letter_inserts_a_styled_wrapper_inside_inline_ancestors() {
	document :=
		html.parse_document('<!doctype html><style>html,body,p{margin:0} p {font-size:16px} p::first-letter {font-size:32px;color:red}</style><p id="p"><span><em>“A,”bc</em></span></p>')
	result := run_document_layout(document, 300, 100) or { panic('missing layout') }
	wrappers := first_letter_wrappers(result.root)
	assert wrappers.len == 1
	wrapper := wrappers[0]
	inline_parent := wrapper.parent() or { panic('missing inline parent') }
	inline_dom := inline_parent.dom_node() or { panic('missing inline DOM') }
	inline_element := inline_dom.as_element() or { panic('missing inline element') }
	assert inline_element.local_name() == 'em'
	assert wrapper.computed_values().font_size().to_double() == 32
	first := wrapper.children()[0].as_text_node() or { panic('missing first slice') }
	assert first.text_for_rendering() == '“A,”'
	parent := wrapper.parent() or { panic('missing inline parent') }
	remainder := parent.children()[1].as_text_node() or { panic('missing remainder') }
	assert remainder.text_for_rendering() == 'bc'
	assert remainder.source_range_start_ == 4
	assert (remainder.first_letter_ or { panic('missing first slice link') }) == first
	assert !first.attach_to_dom_node_
	assert remainder.attach_to_dom_node_
	dom_text := remainder.dom_node() or { panic('missing DOM text') }
	assert dom_text == (first.dom_node() or { panic('missing first DOM identity') })
	text_layout := dom_text.layout_node() or { panic('missing DOM layout') }
	assert text_layout.layout_handle == voidptr(remainder)
	assert text_layout.rendered_text_ == '“A,”bc'
	p := document.get_element_by_id('p') or { panic('missing p') }
	assert p.get_pseudo_element_node(int(dom.PseudoElement.first_letter)) != none
}

fn test_first_letter_can_target_generated_before_content() {
	document :=
		html.parse_document('<!doctype html><style>p::before{content:"Quote"}p::first-letter{color:red;font-size:32px}</style><p>body</p>')
	root := build_layout_tree(document) or { panic('missing tree') }
	wrappers := first_letter_wrappers(root)
	assert wrappers.len == 1
	first := wrappers[0].children()[0].as_text_node() or { panic('missing generated slice') }
	assert first.text_for_rendering() == 'Q'
	assert first.dom_node() == none
	parent := wrappers[0].parent() or { panic('missing generated parent') }
	remainder := parent.children()[1].as_text_node() or { panic('missing generated remainder') }
	assert remainder.text_for_rendering() == 'uote'
	assert remainder.dom_node() == none
}

fn test_block_descendant_own_first_letter_stops_ancestor_capture() {
	document :=
		html.parse_document('<!doctype html><style>#outer::first-letter{color:red}#inner::first-letter{color:green}</style><div id="outer"><div id="inner">Hello</div></div>')
	root := build_layout_tree(document) or { panic('missing tree') }
	wrappers := first_letter_wrappers(root)
	assert wrappers.len == 1
	owner := wrappers[0].pseudo_element_generator() or { panic('missing owner') }
	assert owner.get_attribute_value('id') == 'inner'
}

fn test_preserved_initial_empty_line_has_no_first_letter_box() {
	document :=
		html.parse_document('<!doctype html><style>p{white-space:pre}p::first-letter{color:red}</style><p>\nHello</p>')
	root := build_layout_tree(document) or { panic('missing tree') }
	assert first_letter_wrappers(root).len == 0
}

fn test_first_letter_range_geometry_and_caret_projection_use_source_offsets() {
	document :=
		html.parse_document('<!doctype html><style>html,body,p{margin:0}p{font-size:16px}p::first-letter{font-size:32px}</style><p id="p">Abc</p>')
	result := run_document_layout(document, 300, 100) or { panic('missing layout') }
	wrapper := first_letter_wrappers(result.root)[0]
	first := wrapper.children()[0].as_text_node() or { panic('missing first slice') }
	text := first.dom_node() or { panic('missing DOM text') }
	first_range := dom.Range.create_from_boundary_points(text, 0, text, 1)
	first_rects := first_range.get_client_rects()
	assert first_rects.length() >= 1
	first_rect := first_rects.item(0) or { panic('missing first rect') }
	assert first_rect.width > 0
	second_range := dom.Range.create_from_boundary_points(text, 1, text, 2)
	second_rects := second_range.get_client_rects()
	assert second_rects.length() >= 1
	mut positive_second := ?dom.DOMRect(none)
	for index in 0 .. second_rects.length() {
		rect := second_rects.item(index) or { continue }
		if rect.width > 1 {
			positive_second = rect
			break
		}
	}
	second_rect := positive_second or { panic('missing remainder glyph rect') }
	assert second_rect.height < first_rect.height
	assert math.abs(second_rect.x - (first_rect.x + first_rect.width)) < 0.01
	placeholder := text.layout_node() or { panic('missing text layout') }
	assert placeholder.visual_lines().len >= 2
	assert placeholder.visual_lines()[0].start_offset == 0
	assert placeholder.visual_lines()[0].end_offset == 1
	assert placeholder.visual_lines()[1].start_offset == 1
	assert placeholder.visual_lines()[1].end_offset == 3
	assert placeholder.visual_lines()[0].caret_stops.last().offset == 1
	assert placeholder.visual_lines()[1].caret_stops[0].offset == 1
}

fn test_first_letter_contextual_casing_and_expanding_unicode_source_offsets() {
	document :=
		html.parse_document('<!doctype html><style>html,body,p{margin:0}p{font-size:16px}p::first-letter{font-size:32px}#greek{text-transform:lowercase}#title{text-transform:capitalize}#expanded{text-transform:uppercase}</style><p id="greek">ΟΣ</p><p id="title">hello</p><p id="expanded">ßbc</p>')
	result := run_document_layout(document, 300, 160) or { panic('missing layout') }
	wrappers := first_letter_wrappers(result.root)
	assert wrappers.len == 3
	first_greek := wrappers[0].children()[0].as_text_node() or { panic('missing Greek slice') }
	greek_parent := wrappers[0].parent() or { panic('missing Greek parent') }
	greek_remainder := greek_parent.children()[1].as_text_node() or {
		panic('missing Greek remainder')
	}
	assert first_greek.text_for_rendering() == 'ο'
	assert greek_remainder.text_for_rendering() == 'ς'
	title_parent := wrappers[1].parent() or { panic('missing title parent') }
	title_remainder := title_parent.children()[1].as_text_node() or {
		panic('missing title remainder')
	}
	assert title_remainder.text_for_rendering() == 'ello'
	expanded := wrappers[2].children()[0].as_text_node() or { panic('missing expanding slice') }
	assert expanded.text_for_rendering() == 'SS'
	assert expanded.source_offset_for_rendered_text_offset(1, .start) == 0
	assert expanded.source_offset_for_rendered_text_offset(1, .end) == 1
	assert expanded.rendered_text_offset_for_source_offset(1, .end) == 2
	text := expanded.dom_node() or { panic('missing DOM source') }
	first_range := dom.Range.create_from_boundary_points(text, 0, text, 1)
	rects := first_range.get_client_rects()
	mut total_width := f64(0)
	for index in 0 .. rects.length() {
		rect := rects.item(index) or { continue }
		if rect.height > 20 { total_width += rect.width }
	}
	assert total_width > 20
	placeholder := text.layout_node() or { panic('missing primary text') }
	assert placeholder.visual_lines()[0].end_offset == 1
	stops := placeholder.visual_lines()[0].caret_stops
	assert stops.len == 2
	assert stops[1].offset == 1
	assert stops[1].inline_coordinate - stops[0].inline_coordinate > 20
}

fn test_first_letter_text_mutation_rebuilds_owner_and_removes_stale_slice() {
	mut document :=
		html.parse_document('<!doctype html><style>p::first-letter{font-size:32px}</style><p id="p"><em>Alpha</em></p>')
	document.set_browsing_context(&dom.BrowsingContext{})
	_ = run_document_layout(document, 300, 100) or { panic('missing layout') }
	p := document.get_element_by_id('p') or { panic('missing p') }
	em := p.as_node().first_child() or { panic('missing em') }
	text := em.first_child() or { panic('missing text') }
	mut data := text.as_character_data() or { panic('missing character data') }
	data.replace_data_with_mutation_steps(0, 5, '?!Beta') or { panic(err) }
	assert p.as_node().needs_layout_tree_update_()
	document.update_layout(.debugging)
	result := document_layout_result(document) or { panic('missing updated layout') }
	wrappers := first_letter_wrappers(result.root)
	assert wrappers.len == 1
	first := wrappers[0].children()[0].as_text_node() or { panic('missing new slice') }
	assert first.text_for_rendering() == '?!B'
	primary := text.layout_node() or { panic('missing primary layout') }
	assert primary.rendered_text_ == '?!Beta'
	data.replace_data_with_mutation_steps(0, 6, '') or { panic(err) }
	document.update_layout(.debugging)
	final_result := document_layout_result(document) or { panic('missing final layout') }
	assert first_letter_wrappers(final_result.root).len == 0
	has_stale_first_letter := p.get_pseudo_element_node(int(dom.PseudoElement.first_letter)) != none
	assert !has_stale_first_letter
}

fn test_first_letter_reselects_after_inline_subtree_removal_and_style_change() {
 mut document := html.parse_document('<!doctype html><style>p::first-letter{font-size:32px}p.big::first-letter{font-size:48px}</style><p id="p"><em>Alpha</em><span>Beta</span></p>')
 _ = run_document_layout(document, 300, 130) or { panic('missing layout') }
 mut p := document.get_element_by_id('p') or { panic('missing p') }
 mut em := p.as_node().first_child() or { panic('missing em') }
 em.remove(false)
 document.update_layout(.debugging)
 result := document_layout_result(document) or { panic('missing current layout') }
 wrappers := first_letter_wrappers(result.root)
 assert wrappers.len == 1
 first := wrappers[0].children()[0].as_text_node() or { panic('missing new first') }
 assert first.text_for_rendering() == 'B'
 p.set_attribute_value('class', 'big')
 document.update_layout(.debugging)
 changed := document_layout_result(document) or { panic('missing changed layout') }
 changed_wrappers := first_letter_wrappers(changed.root)
 assert changed_wrappers.len == 1
 assert changed_wrappers[0].computed_values().font_size().to_double() == 48
}

fn test_first_letter_skips_markers_and_floating_inline_subtrees() {
 document := html.parse_document('<!doctype html><style>li::first-letter{font-size:32px;float:left}</style><ul><li><span style="float:right">Ignored</span>Actual</li></ul>')
 root := build_layout_tree(document) or { panic('missing layout') }
 wrappers := first_letter_wrappers(root)
 assert wrappers.len == 1
 assert wrappers[0].computed_values().float_() == .left
 first := wrappers[0].children()[0].as_text_node() or { panic('missing letter') }
 assert first.text_for_rendering() == 'A'
}

fn test_first_letter_stops_before_atomic_inline_flex_and_grid_content() {
 for display in ['inline-flex','inline-grid','flex','grid','inline-block'] {
  mut document := html.parse_document('<!doctype html><style>#outer::first-letter{font-size:200px}#inner{display:${display}}#inner::first-letter{font-size:300px}</style><div id="outer"><div id="inner"><span>Text</span></div><div id="later">Later text</div></div>')
  defer { document.finalize() }
  root := build_layout_tree(document) or { panic('tree') }
  wrappers := first_letter_wrappers(root)
  if display == 'inline-block' { assert wrappers.len == 1 }
  else { assert wrappers.len == 0 }
 }
}
