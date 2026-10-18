module css

import dom

fn test_media_list_retains_parsed_queries_while_rechecking_live_viewport_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut list := MediaList.create([MediaQueryListEntry{text: '(min-width: 400px)'}])
	document.set_viewport_rect(dom.Rect{0, 0, 500, 300})
	assert list.evaluate(document)
	parsed := list.media[0].parsed_query_?
	for width in [300.0, 600.0, 399.5, 400.0] {
		document.set_viewport_rect(dom.Rect{0, 0, width, 300})
		assert list.evaluate(document) == (width >= 400)
		assert voidptr(list.media[0].parsed_query_?) == voidptr(parsed)
	}
}

fn test_media_list_reparses_changed_text_and_caches_failed_single_query_parses() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{0, 0, 500, 300})
	mut list := MediaList.create([MediaQueryListEntry{text: '(min-width: 400px)'}])
	assert list.evaluate(document)
	before := list.media[0].parsed_query_?
	list.media[0].text = '(max-width: 400px)'
	assert !list.evaluate(document)
	assert voidptr(list.media[0].parsed_query_?) != voidptr(before)
	list.media[0].text = 'screen, print'
	assert !list.evaluate(document)
	assert list.media[0].has_parsed_query_ && list.media[0].parsed_query_ == none
	assert !list.evaluate(document)
	list.set_media_text('(min-width: 300px)')
	assert list.evaluate(document)
	assert list.media[0].parsed_query_ != none
	list.append_medium('print')
	assert list.evaluate(document) && list.length() == 2
	list.delete_medium('(min-width: 300px)')!
	assert !list.evaluate(document) && list.length() == 1
}

fn test_parsed_media_entries_keep_their_tree_and_evaluate_each_document_environment() {
	queries := parse_css_media_query_list_value_logic('(prefers-color-scheme: dark)')
	assert queries.len == 1
	mut list := MediaList.create(media_query_entries_from_queries(queries))
	assert voidptr(list.media[0].parsed_query_?) == voidptr(queries[0])
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_svg_image_color_scheme('dark')
	assert list.evaluate(document)
	document.set_svg_image_color_scheme('light')
	assert !list.evaluate(document)
	document.set_svg_image_color_scheme('dark')
	assert list.evaluate(document)
	assert voidptr(list.media[0].parsed_query_?) == voidptr(queries[0])
}
