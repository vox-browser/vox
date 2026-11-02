module layout

import css
import html

fn test_svg_path_data_attribute_refreshes_committed_bounds_and_paint_without_rebuilding_the_tree() {
	mut document := html.parse_document('<!doctype html><svg width="24" height="24" viewBox="0 0 24 24"><path id="path" d="M0 0H18V12H0Z" fill="red"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 200)
	mut path := document.get_element_by_id('path')?
	old := path.get_bounding_client_rect()
	assert old.width == 18 && old.height == 12
	path.set_attribute_value('d', 'M0 0H4V20H0Z')
	current := path.get_bounding_client_rect()
	assert current.width == 4 && current.height == 20
	before := (document.record_display_list() or { panic('missing paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('missing rebuilt paint') }).dump() == before
}

fn test_svg_css_path_data_changes_relayout_while_fill_changes_only_paint() {
	assert css.property_affects_layout(.d)
	assert !css.property_affects_layout(.fill)
	mut document := html.parse_document('<!doctype html><svg width="24" height="24" viewBox="0 0 24 24"><path id="path" style=\'d:path("M0 0H18V12H0Z");fill:red\'/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 200)
	mut path := document.get_element_by_id('path')?
	path.set_attribute_value('style', 'd:path("M0 0H4V20H0Z");fill:blue')
	current := path.get_bounding_client_rect()
	assert current.width == 4 && current.height == 20
}
