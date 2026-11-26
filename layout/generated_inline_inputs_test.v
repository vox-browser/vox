module layout

import dom
import html
import os

fn generated_inline_inputs_box(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic(id) }
	mirror := element.as_node().unsafe_layout_node() or { panic('no box for ${id}') }
	return unsafe { &Node(mirror.real_layout_handle()) }
}

fn generated_inline_inputs_match_full_layout(mut document dom.Document, label string) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before, label
}

// Generated boxes and text from authored strings are inline inputs like any
// other, so their contexts keep retained lines. An attr() value is computed
// into the style, which an attribute change replaces. Counters and quotes
// come from the document order outside the context, which keeps it on the
// uncached path. Either way the lines match a complete layout.
fn test_generated_content_from_authored_strings_is_an_inline_input() {
	enabled := os.getenv('VOX_DISABLE_GENERATED_INLINE_REUSE') == ''
	for content, collected in {
		'"\\2022  "':          true
		'attr(data-label)':   true
		'counter(list-item)': false
		'open-quote':         false
	} {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:16px/20px sans-serif}
			#row{display:flex;gap:4px}
			#label::before{content:${content}}
		</style><body><div id="row"><p id="label" data-label="Tag">Label <b>text</b></p><p id="other">other</p></div></body>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		root := generated_inline_inputs_box(document, 'label')
		mut generated := false
		for child in root.children() {
			if child.is_generated_for_pseudo_element() { generated = true }
		}
		assert generated, content
		assert inline_context_inputs_are_retainable(root) == (collected && enabled), content
		// A change beside the label lays the row out again.
		mut other := document.get_element_by_id('other') or { panic('other') }
		other.set_attribute_value('style', 'padding-top:3px')
		document.update_layout(.debugging)
		generated_inline_inputs_match_full_layout(mut document, content)
		// A longer attribute value changes the generated text.
		mut label := document.get_element_by_id('label') or { panic('label') }
		label.set_attribute_value('data-label', 'A longer tag')
		document.update_layout(.debugging)
		generated_inline_inputs_match_full_layout(mut document, '${content} after attribute')
	}
}
