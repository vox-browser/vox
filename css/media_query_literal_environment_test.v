module css

import dom

fn test_cached_literal_font_and_viewport_lengths_match_fresh_evaluation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for text in ['(width >= 48rem)', '(width <= 47.999rem)', '(width > 48em)', '(height >= 25ex)',
		'(height < 30ch)', '(height >= 20lh)', '(height < 20rlh)', '(width > 50vw)', '(height <= 100vh)',
		'(height >= 75vmin)'] {
		mut list := MediaList.create_empty()
		list.set_media_text(text)
		oracle := parse_media_query_from_text(text)?

		for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
			document.set_font_rendering_policy(policy)
			for width in [767.0, 767.99, 768.0, 768.02, 1024.0] {
				document.set_viewport_rect(dom.Rect{0, 0, width, width / 2})
				expected := oracle.evaluate(document)
				assert list.evaluate(document) == expected, text
				// A public match-state edit cannot corrupt the retained result.
				list.media[0].matches = !expected
				assert list.evaluate(document) == expected, text
				assert list.media[0].viewport_query_cacheable_ == !disable_extended_literal_media_cache
			}
		}
	}
}

fn test_cached_boolean_media_expressions_track_cssom_viewport_and_live_preferences() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for text in ['(width >= 48rem) and (hover: hover) and (pointer: fine)',
		'(width < 40rem) or (height > 500px)', 'not ((width >= 48rem) and (hover: hover))',
		'(forced-colors: active)', 'print', 'screen'] {
		mut list := MediaList.create_empty()
		list.set_media_text(text)
		oracle := parse_media_query_from_text(text)?

		for width in [1024.0, 600.0, 400.0, 1200.0] {
			document.set_viewport_rect(dom.Rect{0, 0, width, width / 2})
			assert list.evaluate(document) == oracle.evaluate(document), text
			assert list.evaluate(document) == oracle.evaluate(document), text
			assert list.media[0].viewport_query_cacheable_ == !disable_extended_literal_media_cache, text
		}
		// Replacing an eligible query with a live preference discards its cache.
		list.media[0].text = '(prefers-color-scheme: dark)'
		document.set_svg_image_color_scheme('dark')
		assert list.evaluate(document)
		document.set_svg_image_color_scheme('light')
		assert !list.evaluate(document)
		assert !list.media[0].viewport_query_cacheable_
	}
}

fn test_shared_media_cache_retains_only_values_after_document_storage_is_released() {
	mut list := MediaList.create_empty()
	list.set_media_text('(width >= 48rem)')
	for width in [1024.0, 1024.0, 640.0, 640.0, 1024.0] {
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_viewport_rect(dom.Rect{0, 0, width, 400})
		mut storage := document.enter_native_storage()
		assert list.evaluate(document) == (width >= 768)
		storage.finish()
		document.finalize()
	}
}
