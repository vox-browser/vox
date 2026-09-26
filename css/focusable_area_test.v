module css

import dom

fn focusable_area_test_document() &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	css_style_computer_for(document)
	return document
}

fn focusable_area_test_append(document &dom.Document, parent &dom.Node, local_name string, attributes map[string]string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', local_name) or { panic(err) }
	for name, value in attributes {
		element.set_attribute_value(name, value)
	}
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(element.as_node()) or { panic(err) }
	return element
}

fn test_elements_in_display_none_subtrees_are_not_focusable_areas() {
	document := focusable_area_test_document()
	html := focusable_area_test_append(document, unsafe { &dom.Node(document) }, 'html', {})
	body := focusable_area_test_append(document, html.as_node(), 'body', {})
	visible := focusable_area_test_append(document, body.as_node(), 'button', {})
	hidden := focusable_area_test_append(document, body.as_node(), 'div', {
		'style': 'display: none'
	})
	hidden_button := focusable_area_test_append(document, hidden.as_node(), 'button', {})
	tabbable := focusable_area_test_append(document, body.as_node(), 'span', {
		'tabindex': '0'
	})

	assert visible.is_focusable()
	assert !hidden_button.is_focusable()
	assert tabbable.is_focusable()
	assert !body.is_focusable()
}

fn test_media_elements_are_focusable_areas_without_controls() {
	document := focusable_area_test_document()
	html := focusable_area_test_append(document, unsafe { &dom.Node(document) }, 'html', {})
	video := focusable_area_test_append(document, html.as_node(), 'video', {})
	assert video.is_focusable()
}

fn test_area_focusability_follows_its_rendered_associated_image() {
	document := focusable_area_test_document()
	html := focusable_area_test_append(document, unsafe { &dom.Node(document) }, 'html', {})
	body := focusable_area_test_append(document, html.as_node(), 'body', {})
	map_element := focusable_area_test_append(document, body.as_node(), 'map', {
		'name': 'shapes'
	})
	area := focusable_area_test_append(document, map_element.as_node(), 'area', {
		'href': '/target'
	})
	assert !area.is_focusable()

	mut image := focusable_area_test_append(document, body.as_node(), 'img', {
		'usemap': '#shapes'
	})
	assert area.is_focusable()

	image.set_attribute_value('style', 'display: none')
	assert !area.is_focusable()
}
