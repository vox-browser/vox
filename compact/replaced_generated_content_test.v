module main

import css
import dom
import html
import layout

fn test_generated_content_is_suppressed_on_control_hosts_with_internal_children() {
	mut document := html.parse_document('<!doctype html><style>input::before{content:"X";display:block;width:10%}</style><input id="text"><input id="checkbox" type="checkbox"><input id="plain" type="checkbox" style="appearance:none;width:100px">')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	for id, generated in {'text':false, 'checkbox':false, 'plain':true} {
		element := document.get_element_by_id(id) or { panic(id) }
		style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(element, .before))
		width := style.get_property_value('width')
		assert width.ends_with('px') == generated, '${id}: ${width}'
	}
}
