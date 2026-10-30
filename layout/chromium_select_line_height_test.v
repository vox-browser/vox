module layout

import css
import html

fn test_chromium_native_select_resets_inherited_and_authored_line_height() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:14px/1.65 Arial}select{font:inherit;font-size:9px;padding:4px 6px;border:1px solid}
		#authored{line-height:40px}#plain{appearance:none;line-height:40px}
		#list,#multiple{line-height:40px}
	</style><select id="inherited"><option>Pick</option></select>
	<select id="authored"><option>Pick</option></select>
	<select id="plain"><option>Pick</option></select>
	<select id="list" size="2"><option>Pick</option></select>
	<select id="multiple" multiple><option>Pick</option></select>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut heights := map[string]f64{}
	for id in ['inherited', 'authored', 'plain', 'list', 'multiple'] {
		element := document.get_element_by_id(id) or { panic(id) }
		dom_style := element.el_computed_properties()?
		style := unsafe { &css.ComputedProperties(dom_style.css_handle) }
		assert style.line_height_is_normal() == (id in ['inherited', 'authored']), id
		heights[id] = element.get_bounding_client_rect().height
	}
	assert heights['inherited'] == heights['authored']
	assert heights['inherited'] < heights['plain']
	assert heights['plain'] == 50
}
