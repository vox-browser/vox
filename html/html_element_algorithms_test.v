module html

import dom

fn first_element_with_local_name(node &dom.Node, local_name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == local_name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := first_element_with_local_name(child, local_name) {
			return element
		}
	}
	return none
}

fn parsed_html_element(markup string, local_name string) &dom.HTMLElement {
	document := parse_document(markup)
	element := first_element_with_local_name(unsafe { &dom.Node(document) }, local_name) or {
		panic('missing ${local_name}')
	}
	return unsafe { &dom.HTMLElement(element) }
}

fn test_html_element_reflected_algorithms() {
	element := parsed_html_element('<div dir="RTL" draggable="false" accesskey="é"></div>', 'div')
	assert html_element_dir(element) == 'rtl'
	assert !html_element_draggable(element)
	assert html_element_access_key_label(element) == 'é'
	set_html_element_translate(element, false)
	assert !html_element_translate(element)
	set_html_element_content_editable(element, 'plaintext-only')!
	assert html_element_content_editable(element) == 'plaintext-only'
	if _ := set_html_element_content_editable(element, 'invalid') {
		assert false
	} else {
		assert err.msg().starts_with('SyntaxError:')
	}
}

fn test_html_element_hidden_and_text_behaviors() {
	element := parsed_html_element('<div writingsuggestions="false"><span></span></div>', 'span')
	assert html_element_writing_suggestions(element) == 'false'
	set_html_element_hidden(element, HiddenValue('UNTIL-FOUND'))
	hidden := html_element_hidden(element)
	assert hidden is string
	assert hidden as string == 'until-found'
	set_html_element_hidden(element, HiddenValue(false))
	assert !dom_element_from_html_element(element).has_attribute('hidden')
	set_html_element_autocapitalize(element, 'WORDS')
	assert html_element_autocapitalize(element, none) == 'words'
}

fn test_html_element_autocapitalization_and_autocorrection_form_inheritance() {
	form := parsed_html_element('<form autocapitalize="characters" autocorrect="off"></form>',
		'form')
	button := parsed_html_element('<button></button>', 'button')
	assert html_element_autocapitalize(button, form) == 'characters'
	assert !html_element_autocorrect(button, form)

	set_html_element_autocapitalize(button, 'words')
	assert html_element_autocapitalize(button, form) == 'words'
	set_html_element_autocorrect(button, true)
	assert html_element_autocorrect(button, form)

	url_input := parsed_html_element('<input type="url" autocorrect="on">', 'input')
	assert !html_element_autocorrect(url_input, form)
}

fn test_title_and_list_element_algorithms() {
	document := parse_document('<title>old</title><ol start="oops"><li value="7">one</li></ol>')
	title := document.title_element() or { panic('missing title') }
	assert html_title_element_text(title) == 'old'
	set_html_title_element_text(title, 'new title')
	assert html_title_element_text(title) == 'new title'

	document_node := unsafe { &dom.Node(document) }
	ol_element := first_element_with_local_name(document_node, 'ol') or { panic('missing ol') }
	li_element := first_element_with_local_name(document_node, 'li') or { panic('missing li') }
	ol := unsafe { &dom.HTMLOListElement(ol_element) }
	li := unsafe { &dom.HTMLLIElement(li_element) }
	assert html_olist_element_start(ol) == 1
	assert html_olist_element_starting_value(ol) == 1
	assert html_li_element_value(li) == 7
	set_html_olist_element_start(ol, -4)
	set_html_li_element_value(li, 12)
	assert html_olist_element_start(ol) == -4
	assert html_li_element_value(li) == 12
}

fn test_computed_heading_level_with_offsets() {
	document :=
		parse_document('<section headingoffset="2"><div headingoffset="3"><h4 id="x">x</h4></div></section>')
	heading_element := first_element_with_local_name(unsafe { &dom.Node(document) }, 'h4') or {
		panic('missing heading')
	}
	heading := unsafe { &dom.HTMLHeadingElement(heading_element) }
	assert html_heading_element_computed_heading_level(heading) == 9
}

fn test_canvas_gradient_and_navigator_information() {
	mut gradient := CanvasGradient.create_linear(0, 0, 100, 100)
	gradient.add_color_stop(0.25, '#ff0000')!
	assert gradient.color_stops.len == 1
	assert gradient.color_stops[0].color.r == 255
	if _ := gradient.add_color_stop(2, 'red') {
		assert false
	} else {
		assert err.msg().starts_with('IndexSizeError:')
	}
	if _ := CanvasGradient.create_radial(0, 0, -1, 0, 0, 1) {
		assert false
	} else {
		assert err.msg().starts_with('IndexSizeError:')
	}
	assert navigator_hardware_concurrency() > 0
	assert compute_device_memory_value(512 * 1024 * 1024) == 1.0
	assert compute_device_memory_value(3 * 1024 * 1024 * 1024) == 4.0
}
