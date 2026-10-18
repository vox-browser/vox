module layout

import css
import dom
import html

fn test_paint_url_session_matches_uncached_resolution_and_separates_inputs() {
	mut document := html.parse_document('<!doctype html><p>image owner</p>')
	defer { document.finalize() }
	viewport := Viewport.new(document, css.ComputedProperties.new())
	root := unsafe { &Node(viewport) }
	scope := begin_paint_svg_source_session(root)
	defer { scope.finish() }
	inputs := [
		['sprite.png', 'https://paint-url.test/css/site.css'],
		['sprite.png', 'https://paint-url.test/other/site.css'],
		['#shape', 'https://paint-url.test/icons.svg'],
		['https://elsewhere.test/image.png', 'https://paint-url.test/style.css'],
		['http://[invalid', 'https://paint-url.test/style.css'],
		['relative.png', ''],
		// Identical concatenations of base + source must not alias.
		['xhttps://e/y', 'https://e/'],
		['https://e/y', 'https://e/x'],
	]
	for input in inputs {
		expected := if parsed := dom.dom_url_parse(input[0], dom.URL{value: input[1]}, '') {
			parsed.to_string()
		} else { input[0] }
		for _ in 0 .. 3 {
			assert resolve_css_paint_image_url(root, input[0], input[1]) == expected
		}
	}
	assert viewport.paint_svg_sources_.resolved_urls.len == inputs.len
}

fn test_paint_url_session_expires_and_document_relative_urls_follow_live_base() {
	mut document := html.parse_document('<!doctype html><p>image owner</p>')
	defer { document.finalize() }
	document.set_url(dom.URL{value: 'https://paint-url.test/first/page'})
	viewport := Viewport.new(document, css.ComputedProperties.new())
	root := unsafe { &Node(viewport) }
	assert resolve_css_paint_image_url(root, 'sprite.png', none) == 'https://paint-url.test/first/sprite.png'
	assert viewport.paint_svg_sources_ == unsafe { nil }
	scope := begin_paint_svg_source_session(root)
	outer := viewport.paint_svg_sources_
	assert resolve_css_paint_image_url(root, 'sprite.png', 'https://paint-url.test/css/style.css') == 'https://paint-url.test/css/sprite.png'
	assert outer.resolved_urls.len == 1
	assert resolve_css_paint_image_url(root, 'sprite.png', none) == 'https://paint-url.test/first/sprite.png'
	assert outer.resolved_urls.len == 2
	document.set_url(dom.URL{value: 'https://paint-url.test/second/page'})
	assert resolve_css_paint_image_url(root, 'sprite.png', none) == 'https://paint-url.test/second/sprite.png'
	assert outer.resolved_urls.len == 3
	document.set_encoding('windows-1252')
	assert resolve_css_paint_image_url(root, 'sprite.png', none) == document.encoding_parse_and_serialize_url('sprite.png')?
	assert outer.resolved_urls.len == 4
	nested := begin_paint_svg_source_session(root)
	assert viewport.paint_svg_sources_.resolved_urls.len == 0
	assert resolve_css_paint_image_url(root, 'sprite.png', 'https://paint-url.test/nested/style.css') == 'https://paint-url.test/nested/sprite.png'
	nested.finish()
	assert voidptr(viewport.paint_svg_sources_) == voidptr(outer)
	assert outer.resolved_urls.len == 4
	scope.finish()
	assert viewport.paint_svg_sources_ == unsafe { nil }
	next := begin_paint_svg_source_session(root)
	assert viewport.paint_svg_sources_.resolved_urls.len == 0
	next.finish()
}

fn test_paint_url_session_reads_changed_base_elements_and_separates_foreign_owners() {
	mut document := html.parse_document('<!doctype html><base href="https://paint-url.test/first/"><p>image owner</p>')
	defer { document.finalize() }
	mut foreign := html.parse_document('<!doctype html><p>foreign image owner</p>')
	defer { foreign.finalize() }
	foreign.set_url(dom.URL{value: 'https://foreign.test/dir/page'})
	mut viewport := Viewport.new(document, css.ComputedProperties.new())
	root := unsafe { &Node(viewport) }
	foreign_node := Node.new(foreign, none)
	viewport.append_child(foreign_node)
	scope := begin_paint_svg_source_session(root)
	defer { scope.finish() }
	for _ in 0 .. 3 {
		assert resolve_css_paint_image_url(root, 'sprite.png', none) == 'https://paint-url.test/first/sprite.png'
		assert resolve_css_paint_image_url(foreign_node, 'sprite.png', none) == 'https://foreign.test/dir/sprite.png'
	}
	mut base := document.head()?.as_node().first_child()?.as_element()?
	base.set_attribute_value('href', 'https://paint-url.test/second/')
	assert resolve_css_paint_image_url(root, 'sprite.png', none) == document.encoding_parse_and_serialize_url('sprite.png')?
	assert resolve_css_paint_image_url(root, 'sprite.png', none) == 'https://paint-url.test/second/sprite.png'
	assert viewport.paint_svg_sources_.resolved_urls.len == 3
}
