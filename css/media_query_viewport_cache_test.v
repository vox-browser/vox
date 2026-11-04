module css

import dom

fn test_literal_viewport_media_results_track_size_policy_and_text_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{0, 0, 399.99, 300})
	mut list := MediaList.create([MediaQueryListEntry{ text: '(min-width: 400px)' }])
	assert !list.evaluate(document)
	assert list.media[0].viewport_query_cacheable_ && list.media[0].viewport_result_valid_
	parsed := list.media[0].parsed_query_?
	document.set_font_rendering_policy(.chromium)
	assert list.evaluate(document)
	assert voidptr(list.media[0].parsed_query_?) == voidptr(parsed)
	list.media[0].matches = false
	assert list.evaluate(document)
	document.set_viewport_rect(dom.Rect{0, 0, 399, 300})
	assert !list.evaluate(document)
	list.media[0].text = '(max-width: 398px)'
	assert !list.evaluate(document)
	document.set_viewport_rect(dom.Rect{0, 0, 398, 300})
	assert list.evaluate(document)
}

fn test_height_orientation_ranges_and_cssom_edits_keep_live_results() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{0, 0, 600, 300})
	mut list := MediaList.create_empty()
	list.set_media_text('(orientation: landscape)')
	assert list.evaluate(document)
	assert list.media[0].viewport_query_cacheable_
	document.set_viewport_rect(dom.Rect{0, 0, 300, 600})
	assert !list.evaluate(document)
	list.set_media_text('(400px <= height <= 700px)')
	assert list.evaluate(document)
	document.set_viewport_rect(dom.Rect{0, 0, 300, 701})
	assert !list.evaluate(document)
	list.append_medium('(min-height: 701px)')
	assert list.evaluate(document)
	list.delete_medium('(min-height: 701px)')!
	assert !list.evaluate(document)
}

fn test_relative_calculated_preference_and_compound_queries_keep_ordinary_evaluation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{0, 0, 600, 300})
	for text in ['(min-width: 20em)', '(min-width: calc(100px + 1px))', '(prefers-color-scheme: dark)',
		'(width >= 100px) and (height >= 100px)'] {
		mut list := MediaList.create([MediaQueryListEntry{ text: text }])
		_ = list.evaluate(document)
		assert !list.media[0].viewport_query_cacheable_, text
	}
	mut preferences := MediaList.create([MediaQueryListEntry{ text: '(prefers-color-scheme: dark)' }])
	document.set_svg_image_color_scheme('dark')
	assert preferences.evaluate(document)
	document.set_svg_image_color_scheme('light')
	assert !preferences.evaluate(document)
}

fn test_one_media_list_can_follow_distinct_document_viewports() {
	mut first := dom.Document.create(dom.url_about_blank())
	mut second := dom.Document.create(dom.url_about_blank())
	defer {
		first.finalize()
		second.finalize()
	}
	first.set_viewport_rect(dom.Rect{0, 0, 700, 300})
	second.set_viewport_rect(dom.Rect{0, 0, 300, 700})
	mut list := MediaList.create([MediaQueryListEntry{ text: '(min-width: 500px)' }])
	assert list.evaluate(first)
	assert !list.evaluate(second)
	assert list.evaluate(first)
}
