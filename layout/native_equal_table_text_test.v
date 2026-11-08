module layout

import dom
import html

fn test_timestamp_refresh_reuses_geometry_beside_a_transferred_table_style() {
	$if !prealloc {
		return
	}
	u := dom.URL{ value: 'https://table-timestamp.test/' }
	mut document := html.create_navigation_document(u, u.origin(), none)!
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>table{margin:17px}td{padding:4px}</style><p>Timestamp <time id="stamp">2 days ago</time></p><table><tr><td>Stable table text</td></tr></table>')
	allocation.finish()
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	defer {
		handle := document.layout_engine_handle()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		retire_native_document_layout(handle)
		document.release_native_storage()
	}
	mut stamp := document.get_element_by_id('stamp')?.as_node()
	handle := document.layout_engine_handle()
	list := document.record_display_list()?
	before := list.dump()
	for _ in 0 .. 3 {
		old := stamp.first_child()?
		stamp.set_text_content('2 days ago')!
		assert voidptr(stamp.first_child()?) != voidptr(old)
		document.update_layout(.debugging)
		assert document.layout_engine_handle() == handle
		assert document.record_display_list()?.dump() == before
	}
	stamp.set_text_content('3 days ago')!
	document.update_layout(.debugging)
	assert document.layout_engine_handle() != handle
	assert document.record_display_list()?.dump() != before
}
