module css

import dom

// Ladybird 70df302eeebc40488afc780ca53a7307f24fe5f0. Reusing a cached
// response must enforce the same MIME decision as the link fetch completion.
fn test_remote_link_cache_retains_response_mime_and_final_url() {
	for content_type in ['text/plain', 'text/css; charset=utf-8', '', 'invalid'] {
		for quirks in [false, true] {
			for same_origin in [false, true] {
				mut document := dom.Document.create(dom.URL{value: 'https://cache-styles.test/'})
				defer { document.finalize() }
				document.set_origin(document.url.origin())
				document.set_quirks_mode(if quirks { .yes } else { .no })
				mut link := document.create_element_ns(dom.namespace_html_uri, 'link')!
				link.set_attribute_value('type', 'text/css')
				response_url := if same_origin { 'https://cache-styles.test/final.css' } else { 'https://other.test/final.css' }
				set_remote_link_style_sheet_response('https://cache-styles.test/resource', ImportedStyleSheetSource{
					css_text: 'p { color: red }'
					response_url: response_url
					content_type: content_type
				})
				if text, final_url := read_link_stylesheet(link, '/resource', document.url.serialize()) {
					assert content_type != 'text/plain' || (quirks && same_origin)
					assert text == 'p { color: red }'
					assert final_url == response_url
				} else {
					assert content_type == 'text/plain' && !(quirks && same_origin)
				}
				link.set_attribute_value('type', '')
				assert read_link_stylesheet(link, '/resource', document.url.serialize()) == none
			}
		}
	}
}

fn remote_link_test_append(mut parent dom.Node, document &dom.Document, name string, attributes map[string]string) !&dom.Element {
	mut element := document.create_element_ns(dom.namespace_html_uri, name)!
	for attribute, value in attributes {
		element.set_attribute_value(attribute, value)
	}
	parent.append_child(element.as_node())!
	return element
}

fn test_remote_link_cache_preserves_request_location_and_redirect_base() {
	for same_origin in [false, true] {
		mut document := dom.Document.create(dom.URL{value: 'https://redirect-cache.test/page.html'})
		defer { document.finalize() }
		document.set_origin(document.url.origin())
		mut document_node := document.as_node()
		root := remote_link_test_append(mut document_node, document, 'html', map[string]string{})!
		mut root_node := root.as_node()
		mut link := remote_link_test_append(mut root_node, document, 'link', {
			'rel': 'stylesheet'
			'href': '/first.css'
		})!
		response_url := if same_origin { 'https://redirect-cache.test/assets/final.css' } else { 'https://cdn.redirect-cache.test/assets/final.css' }
		// Keep the response bytes encoded so this path also exercises the cache's
		// BOM decoder before it parses the redirected sheet.
		mut bytes := [u8(0xff), 0xfe]
		for byte in 'html { --image: url(image.png) }'.bytes() {
			bytes << byte
			bytes << u8(0)
		}
		for reference in ['/first.css', '/second.css'] {
			request_url := 'https://redirect-cache.test${reference}'
			set_remote_link_style_sheet_response(request_url, ImportedStyleSheetSource{
				css_text: bytes.bytestr()
				response_url: response_url
				content_type: 'text/css; charset=windows-1252'
			})
			// Both requests redirect to identical bytes at the same response URL.
			// Changing href must still refresh the CSSOM location.
			link.set_attribute_value('href', reference)
			sync_document_style_elements(document)
			sheet := style_sheet_for_owner_node(document, link) or { panic('missing cached sheet') }
			assert sheet.href()? == request_url
			assert sheet.base_url_for_bindings()? == response_url
			assert sheet.base.origin_clean == same_origin
			assert sheet.rules.rules.len == 1
			declaration := sheet.rules.rules[0].style() or { panic('missing decoded style rule') }
			assert declaration.custom_property('--image') != none
			assert css_author_style_sheets_for(document).link_sheets.len == 1
			sync_document_style_elements(document)
			unchanged := style_sheet_for_owner_node(document, link) or { panic('missing unchanged sheet') }
			assert voidptr(unchanged) == voidptr(sheet)
		}
	}
}

// A script-inserted remote link, such as 4chan's catalog theme, uses the text
// the browser fetched for its resolved URL. A parsed link that the browser
// inlined as the <style> after it is not installed a second time.
fn test_remote_link_style_sheets_install_once_their_text_is_fetched() {
	mut document := dom.Document.create(dom.URL{ value: 'https://boards.4chan.org/pol/catalog' })
	mut document_node := unsafe { &dom.Node(document) }
	root := remote_link_test_append(mut document_node, document, 'html', map[string]string{})!
	mut root_node := root.as_node()
	theme := remote_link_test_append(mut root_node, document, 'link', {
		'rel':  'stylesheet'
		'href': '//s.4cdn.org/css/catalog_theme.css'
	})!
	inlined := remote_link_test_append(mut root_node, document, 'link', {
		'rel':  'stylesheet'
		'href': '//s.4cdn.org/css/inlined.css'
	})!
	mut style := remote_link_test_append(mut root_node, document, 'style', {
		'data-libweb-v-source-url': 'https://s.4cdn.org/css/inlined.css'
	})!
	mut style_node := style.as_node()
	style_node.set_text_content('p { margin: 0 }')!

	theme_url := link_style_sheet_url(theme.get_attribute_value('href'), document.base_url().to_string()) or {
		panic('unresolved theme URL')
	}
	assert theme_url == 'https://s.4cdn.org/css/catalog_theme.css'
	sync_document_style_elements(document)
	assert css_author_style_sheets_for(document).link_sheets.len == 0
	set_remote_link_style_sheet(theme_url, 'p { color: rgb(128, 0, 0) }')
	set_remote_link_style_sheet('https://s.4cdn.org/css/inlined.css', 'p { color: blue }')
	assert has_remote_link_style_sheet(theme_url)
	sync_document_style_elements(document)
	holder := css_author_style_sheets_for(document)
	assert holder.link_sheets.len == 1
	sheet := style_sheet_for_owner_node(document, theme) or { panic('missing fetched theme sheet') }
	assert voidptr(holder.link_sheets[0]) == voidptr(sheet)
	assert sheet.css_rules().length() == 1
	if owner := sheet.base.owner_node {
		assert voidptr(owner) == voidptr(theme)
	} else {
		assert false
	}
	_ = inlined
}
