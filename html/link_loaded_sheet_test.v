module html

import css
import dom

fn test_fetched_link_owns_the_same_css_sheet_updated_by_live_media() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/page.html' })
	mut navigable := &dom.Navigable{
		active_document_:          document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut element := document.create_element_ns(dom.namespace_html_uri, 'link')!
	element.set_attribute_value('rel', 'stylesheet')
	element.set_attribute_value('href', '/sheet.css')
	element.set_attribute_value('media', 'screen')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(element.as_node())!
	link := unsafe { &dom.HTMLLinkElement(element) }
	mut model := html_link_element_model_for_dom_element(link)
	model.process_stylesheet_resource(true, LinkResourceResponse{
		content_type: 'text/css'
		body:         'div { color: red }'.bytes()
		url:          dom.URL{ value: 'https://example.test/redirected/sheet.css' }
	})
	mut sheet := css.style_sheet_for_owner_node(document, element) or { panic('missing sheet') }
	assert sheet.base.owner_node? == element
	assert sheet.base.location? == 'https://example.test/redirected/sheet.css'
	assert sheet.insert_rule('span { color: blue }', 1)! == 1
	element.set_attribute_value('media', 'print')
	assert sheet.base.media.media_text() == 'print'
	sheet.evaluate_media_queries(document)
	assert !sheet.base.media.matches()
	element.set_attribute_value('media', 'screen')
	sheet.evaluate_media_queries(document)
	assert sheet.base.media.matches()
	assert sheet.css_rules().length() == 2
	assert voidptr(css.style_sheet_for_owner_node(document, element)?) == voidptr(sheet)
}
