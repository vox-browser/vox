module main

import dom
import html

fn table_wrapper_margin_document(markup string) &dom.Document {
	address := dom.URL{value: 'https://table-wrapper.test/'}
	mut document := html.parse_navigation_document(markup, address, address.origin(), none) or {
		panic(err)
	}
	document.set_scripting_enabled_by_embedder(false)
	document.set_viewport_rect(dom.Rect{width: 1024, height: 768})
	return document
}

fn table_wrapper_margin_x(document &dom.Document) f64 {
	table := document.get_element_by_id('blotter') or { panic('missing table') }
	return table.get_bounding_client_rect().x
}

// The table wrapper takes the table's margins. That transfer must leave the
// element's style intact, or 4chan's centered news table (#blotter, with
// margin: auto) moved to the left edge whenever its layout tree was rebuilt.
fn test_table_auto_margins_survive_layout_tree_rebuilds_and_restyles() {
	mut document := table_wrapper_margin_document('<!doctype html><html><head><style>#blotter { width: 468px; margin: auto; } #blotter.wide { width: 600px; }</style></head><body><table id="blotter"><tr><td>08/21/20</td><td>New boards added</td></tr></table></body></html>')
	defer { document.finalize() }
	mut app := BrowserApp{
		document: document
	}
	app.relayout(1024, 768 + app.chrome_height())
	assert table_wrapper_margin_x(document) == 278
	document.tear_down_layout_tree()
	app.relayout(1024, 768 + app.chrome_height())
	assert table_wrapper_margin_x(document) == 278
	mut table := document.get_element_by_id('blotter') or { panic('missing table') }
	table.set_attribute_value('class', 'wide')
	app.relayout(1024, 768 + app.chrome_height())
	assert table_wrapper_margin_x(document) == 212
}
