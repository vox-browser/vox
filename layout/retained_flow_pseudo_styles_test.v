module layout

import css
import dom
import html

fn covered_anchor_paint_oracle(mut document dom.Document) string {
	document.update_layout(.debugging)
	actual := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	expected := (document.record_display_list() or { panic('rebuilt paint') }).dump()
	if actual != expected {
		left := actual.split_into_lines()
		right := expected.split_into_lines()
		mut differences := 0
		for index, line in left {
			if index < right.len && line == right[index] { continue }
			eprintln('Anchor paint actual ${index}: ${line}')
			if index < right.len { eprintln('Anchor paint rebuilt ${index}: ${right[index]}') }
			differences++
			if differences == 3 { break }
		}
	}
	assert expected == actual
	return actual
}

fn test_style_anchor_insert_and_remove_rebuild_generated_geometry() {
	for selector in ['.target ::before', '.target > *', '.target + *', '.target ~ *'] {
		eprintln('Anchor selector ${selector}')
		mut document := html.parse_document('<!doctype html><style id="sheet">body{margin:0}span{display:block}</style><section class="target"><span>child</span></section><p>sibling</p>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 300, 200)
		before := covered_anchor_paint_oracle(mut document)
		owner := document.get_element_by_id('sheet') or { panic('sheet') }
		mut sheet := css.style_sheet_for_owner_node(document, owner) or { panic('CSS sheet') }
		document.set_needs_full_style_update(true)
		sheet.insert_rule('${selector} { color:red;content:"generated";padding:7px }', u32(sheet.rules.rules.len))!
		changed := covered_anchor_paint_oracle(mut document)
		assert changed != before
		document.set_needs_full_style_update(true)
		sheet.delete_rule(u32(sheet.rules.rules.len - 1))!
		assert covered_anchor_paint_oracle(mut document) == before
	}
}

fn test_cached_flow_validation_rejects_new_generated_pseudo_styles() {
	for pseudo in ['before', 'after'] {
		mut document := html.parse_document('<!doctype html><style id="sheet">body{margin:0}span{display:block}</style><section><span id="subject">child</span><i id="changed">changed</i></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 300, 200)
		mut changed := document.get_element_by_id('changed') or { panic('changed') }
		for text in ['different', 'changed'] {
			changed.set_text_content(text)!
			document.update_layout(.debugging)
		}
		subject := document.get_element_by_id('subject') or { panic('subject') }
		mirror := subject.as_node().unsafe_layout_node() or { panic('layout') }
		typed := unsafe { &Node(mirror.real_layout_handle()) }
		assert typed.flow_validation_cache_ != unsafe { nil }
		before := (document.record_display_list() or { panic('paint') }).dump()
		owner := document.get_element_by_id('sheet') or { panic('sheet') }
		mut sheet := css.style_sheet_for_owner_node(document, owner) or { panic('CSS sheet') }
		document.set_needs_full_style_update(true)
		sheet.insert_rule('#subject::${pseudo} { content:"generated";color:blue }', u32(sheet.rules.rules.len))!
		assert covered_anchor_paint_oracle(mut document) != before
	}
}
