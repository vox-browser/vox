module layout

import css
import dom
import html

fn hidden_rendering_assert_eager_oracle(mut document dom.Document) {
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	mut computer := css.css_style_computer_for(document)
	css.recompute_style_for_subtree(mut computer, document.as_node())
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing eager paint') }).dump() == before
}

fn test_hidden_style_deferral_preserves_paint_when_revealed_resized_and_hidden_again() {
	mut document := html.parse_document('<!doctype html><style>#hidden{display:none;color:red;--size:90px}#target{width:var(--size);border:1px solid}</style><p>Visible before.</p><section id="hidden"><div><span id="target">Hidden text to wrap.</span></div></section><p>Visible after.</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	hidden_rendering_assert_eager_oracle(mut document)
	mut hidden := document.get_element_by_id('hidden')?
	for style in ['display:block;color:blue;--size:50px','display:none;color:green','display:block;--size:120px'] {
		hidden.set_attribute_value('style', style)
		document.update_layout(.debugging)
		hidden_rendering_assert_eager_oracle(mut document)
	}
}

fn test_hidden_style_queries_keep_zero_geometry_then_layout_current_inherited_values() {
	mut document := html.parse_document('<!doctype html><section id="hidden" style="display:none;font-size:20px"><div><p id="target" style="width:4em">Some hidden text.</p></div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	target := document.get_element_by_id('target')?
	assert target.get_bounding_client_rect().width == 0
	assert css.computed_value_for(target,.width)? == '80px'
	assert target.get_bounding_client_rect().width == 0
	mut hidden := document.get_element_by_id('hidden')?
	hidden.set_attribute_value('style','display:block;font-size:30px')
	document.update_layout(.debugging)
	assert target.get_bounding_client_rect().width == 120
	hidden_rendering_assert_eager_oracle(mut document)
}
