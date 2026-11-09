module layout

import css
import html

fn test_size_query_font_change_rechecks_below_an_unchanged_inheritance_boundary() {
	mut document := html.parse_document('<!doctype html><style>
		body{font-size:10px}body.larger{font-size:20px}
		#container{container-type:inline-size;width:100px;color:red}
		#intermediate{font-size:8px}
		@container (width:calc(1em + 80px)){#target{color:green}}
	</style><div id="container"><div id="intermediate"><div id="target"></div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document,800,600)
	target := document.get_element_by_id('target') or { panic('target') }
	assert (css.up_to_date_computed_properties_for_element(target).property(.color,.no) or { panic('color') }).css_text == 'rgb(255, 0, 0)'
	mut body := document.body() or { panic('body') }
	body.set_attribute_value('class','larger')
	document.update_layout(.debugging)
	assert (css.up_to_date_computed_properties_for_element(target).property(.color,.no) or { panic('color') }).css_text == 'rgb(0, 128, 0)'
}
