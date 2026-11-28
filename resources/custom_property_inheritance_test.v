module main

import css
import dom
import html
import layout

fn test_literal_custom_properties_survive_unrelated_ancestor_updates() {
	mut document := html.parse_document('<!doctype html><style>
		html{--unrelated:red;--inherited:10px}
		#holder{--size:8px;--ink:#c00}
		#watch{display:flex}
		#watch::before{content:"";width:var(--size);height:8px;background:var(--ink)}
		#inherited{width:var(--inherited);height:1px}
	</style><div id="holder"><a id="watch"></a></div><div id="inherited"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 100, 80)
	holder := document.get_element_by_id('holder') or { panic('holder') }
	watch := document.get_element_by_id('watch') or { panic('watch') }
	inherited := document.get_element_by_id('inherited') or { panic('inherited') }
	before := css.computed_properties_for_pseudo_element(watch, .before) or { panic('before') }
	assert before.size_value(.width).to_string() == '8px'
	assert inherited.get_bounding_client_rect().width == 10
	mut root := document.document_element() or { panic('root') }
	root.set_attribute_value('style', '--unrelated:blue;--inherited:14px')
	document.update_layout(.debugging)
	value := dom.AbstractElement.new(holder, none).get_custom_property('--size') or {
		panic("ancestor refresh discarded the holder's own custom property")
	}
	assert value.css_text == '8px'
	after := css.computed_properties_for_pseudo_element(watch, .before) or { panic('after') }
	assert after.size_value(.width).to_string() == '8px'
	assert watch.get_bounding_client_rect().width == holder.get_bounding_client_rect().width
	assert watch.get_bounding_client_rect().height == 8
	assert inherited.get_bounding_client_rect().width == 14
}

fn test_removed_custom_declarations_resume_inheritance() {
	mut document := html.parse_document('<!doctype html><style>
		html{--size:10px}#holder{--size:8px}
		#watch::before{content:"";display:block;width:var(--size);height:1px}
	</style><div id="holder"><a id="watch"></a></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 100, 80)
	mut holder := document.get_element_by_id('holder') or { panic('holder') }
	watch := document.get_element_by_id('watch') or { panic('watch') }
	before := css.computed_properties_for_pseudo_element(watch, .before) or { panic('before') }
	assert before.size_value(.width).to_string() == '8px'
	holder.remove_attribute('id')
	document.update_layout(.debugging)
	mut root := document.document_element() or { panic('root') }
	root.set_attribute_value('style', '--size:14px')
	document.update_layout(.debugging)
	after := css.computed_properties_for_pseudo_element(watch, .before) or { panic('after') }
	assert after.size_value(.width).to_string() == '14px'
}
