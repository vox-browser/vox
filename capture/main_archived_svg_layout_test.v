module main

import html

fn test_archived_svg_layout_selects_only_the_explicit_visible_svg_policy() {
	for source in ['<svg></svg>', '<div><svg><path d="M0 0L4 4"/></svg></div>'] {
		mut document := html.parse_document('<!doctype html>${source}')
		defer { document.finalize() }
		assert browser_document_supports_device_layout(document) == !retain_css_layout_for_svg
	}
	for source in ['<div>Text</div>', '<svg style="display:none"></svg>',
		'<div style="display:none"><svg></svg></div>'] {
		mut document := html.parse_document('<!doctype html>${source}')
		defer { document.finalize() }
		assert browser_document_supports_device_layout(document)
	}
}

fn test_archived_svg_layout_keeps_live_visibility_and_document_density() {
	mut document := html.parse_document('<!doctype html><svg id="icon" style="display:none"><rect width="10" height="10"/></svg>')
	defer { document.finalize() }
	document.set_display_device_pixel_ratio(2)
	mut icon := document.get_element_by_id('icon')?
	assert browser_document_supports_device_layout(document)
	icon.remove_attribute('style')
	assert browser_document_supports_device_layout(document) == !retain_css_layout_for_svg
	assert document.display_device_pixel_ratio() == 2
	icon.set_attribute_value('style', 'display:none')
	assert browser_document_supports_device_layout(document)
}
