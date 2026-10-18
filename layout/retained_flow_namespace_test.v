module layout

import html

fn test_retained_flow_keeps_svg_foreign_object_reference_instances_independent() {
	mut document := html.parse_document('<!doctype html><div id="changed"></div><svg width="160" height="40"><defs><pattern id="tile" patternUnits="userSpaceOnUse" width="80" height="40"><foreignObject width="80" height="40"><div xmlns="http://www.w3.org/1999/xhtml" id="label" style="font:12px sans-serif;background:lime">pattern text</div></foreignObject></pattern></defs><rect width="80" height="40" fill="url(#tile)"/><rect x="80" width="80" height="40" fill="url(#tile)"/></svg>')
	_ = layout_document_typed_in_viewport(document, 400, 300)
	label := document.get_element_by_id('label')?
	before := label.as_node().unsafe_layout_node()?.real_layout_handle()
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('<p>unrelated mutation</p>')!
	document.update_layout(.debugging)
	assert label.as_node().unsafe_layout_node()?.real_layout_handle() != before
	paint := (document.record_display_list()?).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list()?).dump() == paint
}
