module layout

import html

fn test_svg_model_reads_only_filter_properties_and_observes_live_style_changes() {
	document := html.parse_document('<!doctype html><style>svg { color:rgb(12 34 56); color-interpolation-filters:sRGB } #flood { flood-color:currentColor; flood-opacity:.25 }</style><svg><filter><feFlood id="flood"/><feDropShadow id="shadow" style="flood-color:red; flood-opacity:.5"/></filter><path id="path" d="M0 0 L10 10"/></svg>')
	_ = run_document_layout(document, 800, 600) or { panic('missing layout') }
	mut flood := document.get_element_by_id('flood') or { panic('missing flood') }
	shadow := document.get_element_by_id('shadow') or { panic('missing shadow') }
	path := document.get_element_by_id('path') or { panic('missing path') }
	first := svg_element_model(flood)
	assert first.attributes['flood-color'] == '#0c2238ff'
	assert first.attributes['flood-opacity'] == '0.25'
	assert first.attributes['color-interpolation-filters'] == 'sRGB'
	assert svg_element_model(shadow).attributes['flood-color'] == '#ff0000ff'
	assert svg_element_model(shadow).attributes['flood-opacity'] == '0.5'
	assert svg_element_model(path).attributes['color-interpolation-filters'] == 'sRGB'
	flood.set_attribute_value('style', 'color:blue; flood-opacity:.75; color-interpolation-filters:linearRGB')
	_ = run_document_layout(document, 800, 600) or { panic('missing updated layout') }
	updated := svg_element_model(flood)
	assert updated.attributes['flood-color'] == '#0000ffff'
	assert updated.attributes['flood-opacity'] == '0.75'
	assert updated.attributes['color-interpolation-filters'] == 'linearRGB'
}
