module css

import dom

fn remote_link_test_append(mut parent dom.Node, document &dom.Document, name string, attributes map[string]string) !&dom.Element {
	mut element := document.create_element_ns(dom.namespace_html_uri, name)!
	for attribute, value in attributes {
		element.set_attribute_value(attribute, value)
	}
	parent.append_child(element.as_node())!
	return element
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
