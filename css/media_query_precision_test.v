module css

import dom

fn media_precision_document(width f64, height f64) &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	document.set_viewport_rect(dom.Rect{0, 0, width, height})
	document.set_font_rendering_policy(.chromium)
	return document
}

fn media_precision_matches(document &dom.Document, text string) bool {
	query := parse_media_query(ParsingParams{}, text) or { panic('invalid query: ${text}') }
	return query.evaluate(document)
}

fn test_chromium_inclusive_media_lengths_allow_one_layout_unit() {
	mut document := media_precision_document(800, 600)
	defer { document.finalize() }
	for text in ['(min-width:800.01px)', '(width>=800.015625px)', '(max-width:799.99px)',
		'(width<=799.984375px)', '(width:800.01px)', '(width=799.984375px)', '(800.015625px<=width)',
		'(799.984375px>=width)', '(800.01px<=width<=799.99px)', '(799.99px>=width>=800.01px)',
		'(min-height:600.01px)', '(height<=599.99px)', '(device-width:800.01px)',
		'(device-height:599.99px)', '(min-width:calc(50rem + .01px))'] {
		assert media_precision_matches(document, text), text
	}
	for text in ['(min-width:800.016px)', '(max-width:799.984px)', '(width:800.016px)',
		'(width=799.984px)', '(800.016px<=width)', '(799.984px>=width)',
		'(width>=800.01px) and (width<=799.98px)', 'not all and (width>=800.01px)'] {
		assert !media_precision_matches(document, text), text
	}
}

fn test_chromium_strict_media_comparisons_keep_unrounded_lengths() {
	mut document := media_precision_document(800, 600)
	defer { document.finalize() }
	for text in ['(width<800.001px)', '(width>799.999px)', '(800.001px>width)', '(799.999px<width)',
		'(799.999px<width<800.001px)'] {
		assert media_precision_matches(document, text), text
	}
	for text in ['(width>800px)', '(width<800px)', '(width>800.001px)', '(width<799.999px)',
		'(800px<width)', '(800px>width)'] {
		assert !media_precision_matches(document, text), text
	}
}

fn test_media_length_precision_is_css_pixels_and_tracks_viewport_changes() {
	mut document := media_precision_document(800.5, 600.25)
	defer { document.finalize() }
	for density in [1.0, 2.0] {
		document.set_display_device_pixel_ratio(density)
		assert media_precision_matches(document, '(width>=800.51px)')
		assert !media_precision_matches(document, '(width>=800.516px)')
		assert media_precision_matches(document, '(height=600.26px)')
		assert !media_precision_matches(document, '(height=600.266px)')
	}
	document.set_viewport_rect(dom.Rect{0, 0, 768, 600})
	assert media_precision_matches(document, '(width>=48rem)')
	assert !media_precision_matches(document, '(width<=47.999rem)')
	document.set_viewport_rect(dom.Rect{0, 0, 767, 600})
	assert !media_precision_matches(document, '(width>=48rem)')
	assert media_precision_matches(document, '(width<=47.999rem)')
}

fn test_media_length_precision_preserves_other_policies_features_and_negative_queries() {
	mut document := media_precision_document(800, 600)
	defer { document.finalize() }
	assert !media_precision_matches(document, '(resolution:1.01dppx)')
	assert !media_precision_matches(document, '(aspect-ratio:1.34)')
	document.set_viewport_rect(dom.Rect{})
	assert !media_precision_matches(document, '(width:-.01px)')
	assert !media_precision_matches(document, '(max-width:-.01px)')
	assert media_precision_matches(document, '(min-width:-.01px)')
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	document.set_font_rendering_policy(.libweb)
	assert !media_precision_matches(document, '(min-width:800.01px)')
	assert !media_precision_matches(document, '(max-width:799.99px)')
	assert !media_precision_matches(document, '(width:800.01px)')
	assert media_precision_matches(document, '(width<800.001px)')
}

fn test_fractional_media_breakpoint_changes_live_styles() {
	mut document := media_precision_document(800, 600)
	defer { document.finalize() }
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(target.as_node())!
	add_document_author_style_sheet(document, 'div {color:red} @media (width>=800.01px) and (pointer:fine) {div {color:green}}')
	css_style_computer_for(document)
	for width, color in {
		800: 'rgb(0, 128, 0)'
		799: 'rgb(255, 0, 0)'
		801: 'rgb(0, 128, 0)'
	} {
		document.set_viewport_rect(dom.Rect{0, 0, f64(width), 600})
		document.evaluate_media_queries_and_report_changes()
		document.update_style()
		assert computed_value_for(target, .color) or { '' } == color
	}
}
