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

fn first_element_with_attribute(node &dom.Node, attribute_name string) ?&dom.Element {
	if element := node.as_element() {
		if element.has_attribute(attribute_name) {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := first_element_with_attribute(child, attribute_name) {
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

fn test_html_element_inner_and_outer_text_setters() {
	inner := parsed_html_element('<div><span>old</span></div>', 'div')
	html_element_set_inner_text(inner, 'a\r\nb\nc')
	inner_children := dom_element_from_html_element(inner).as_node().children_as_vector()
	assert inner_children.len == 5
	assert inner_children[0].is_text()
	assert unsafe { &dom.Text(inner_children[0]) }.data() == 'a'
	assert inner_children[1].as_element() or { panic('missing first br') }.local_name() == 'br'
	assert unsafe { &dom.Text(inner_children[2]) }.data() == 'b'
	assert inner_children[3].as_element() or { panic('missing second br') }.local_name() == 'br'
	assert unsafe { &dom.Text(inner_children[4]) }.data() == 'c'

	document := parse_document('<div>before<b>old</b>after</div>')
	b := first_element_with_local_name(unsafe { &dom.Node(document) }, 'b') or {
		panic('missing b')
	}
	parent := b.as_node().parent() or { panic('missing parent') }
	html_element_set_outer_text(unsafe { &dom.HTMLElement(b) }, 'middle')!
	children := parent.children_as_vector()
	assert children.len == 1
	assert children[0].is_text()
	assert unsafe { &dom.Text(children[0]) }.data() == 'beforemiddleafter'

	detached := document.create_element('div')!
	if _ := html_element_set_outer_text(unsafe { &dom.HTMLElement(detached) }, 'x') {
		assert false
	} else {
		assert err.msg().starts_with('NoModificationAllowedError:')
	}
}

fn test_html_element_spellcheck_inheritance_and_setter() {
	document := parse_document('<div spellcheck="false"><span></span><textarea></textarea></div>')
	span := first_element_with_local_name(unsafe { &dom.Node(document) }, 'span') or {
		panic('missing span')
	}
	textarea := first_element_with_local_name(unsafe { &dom.Node(document) }, 'textarea') or {
		panic('missing textarea')
	}
	assert !html_element_spellcheck(unsafe { &dom.HTMLElement(span) })
	// Text controls use the true-by-default state only when no ancestor supplies a state.
	assert html_element_spellcheck(unsafe { &dom.HTMLElement(textarea) })
	html_element_set_spellcheck(unsafe { &dom.HTMLElement(span) }, true)
	assert html_element_spellcheck(unsafe { &dom.HTMLElement(span) })
}

fn test_html_element_autocapitalization_and_autocorrection_form_inheritance() {
	form := parsed_html_element('<form autocapitalize="characters" autocorrect="off"></form>', 'form')
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
	mut ol_node := unsafe { &dom.Node(ol_element) }
	ol_node.set_needs_layout_tree_update(false, .html_ol_list_element_ordinal_values)
	set_html_li_element_value(li, 12)
	assert html_olist_element_start(ol) == -4
	assert html_li_element_value(li) == 12

	ol_node.set_needs_layout_tree_update(false, .html_ol_list_element_ordinal_values)
	html_olist_element_attribute_changed(ol, 'reversed', none, '', none)
	assert ol_node.needs_layout_tree_update_()
	assert htmlol_list_element_start(ol) == -4
	assert htmlol_list_element_starting_value(ol) == -4
}

fn test_title_children_changed_notifies_the_traversable_page() {
	mut document := parse_document('<title>translated title</title>')
	mut page := &dom.Page{}
	document.set_page(page)
	navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	document.set_cached_navigable(navigable)
	title := document.title_element() or { panic('missing title') }
	html_title_element_children_changed(title, dom.ChildrenChangedMetadata{
		type_: .mutation
	})
	assert page.last_changed_title() == 'translated title'
	assert page.title_change_count() == 1
}

fn test_slot_name_attribute_change_updates_the_internal_slot_name() {
	document := parse_document('<slot></slot>')
	element := first_element_with_local_name(unsafe { &dom.Node(document) }, 'slot') or {
		panic('missing slot')
	}
	slot := unsafe { &dom.HTMLSlotElement(element) }
	assert slot.slot_name() == ''
	html_slot_element_attribute_changed(slot, 'name', none, 'named', none)
	assert slot.slot_name() == 'named'
	html_slot_element_attribute_changed(slot, 'name', 'named', none, none)
	assert slot.slot_name() == ''
}

fn test_computed_heading_level_with_offsets() {
	document := parse_document('<section headingoffset="2"><div headingoffset="3"><h4 id="x">x</h4></div></section>')
	heading_element := first_element_with_local_name(unsafe { &dom.Node(document) }, 'h4') or {
		panic('missing heading')
	}
	heading := unsafe { &dom.HTMLHeadingElement(heading_element) }
	assert html_heading_element_computed_heading_level(heading) == 9

	reset_document := parse_document('<section headingoffset="2"><div headingreset headingoffset="1"><h2>x</h2></div></section>')
	reset_heading := first_element_with_local_name(unsafe { &dom.Node(reset_document) }, 'h2') or {
		panic('missing reset heading')
	}
	assert html_element_computed_heading_offset(unsafe { &dom.HTMLElement(reset_heading) }) == 1
	assert html_heading_element_computed_heading_level(unsafe { &dom.HTMLHeadingElement(reset_heading) }) == 3
}

fn test_html_element_base_lifecycle_labels_roles_and_editing_focus() {
	document := parse_document('<label for="control">caption</label><div inert><span></span></div><input id="control"><article><header></header></article><section aria-label="named"></section><div contenteditable>text</div>')
	input := first_element_with_local_name(unsafe { &dom.Node(document) }, 'input') or {
		panic('missing input')
	}
	labels := html_element_labels(unsafe { &dom.HTMLElement(input) }) or { panic('missing labels') }
	assert labels.length() == 1
	assert html_element_labels(unsafe { &dom.HTMLElement(input) })? == labels

	header := first_element_with_local_name(unsafe { &dom.Node(document) }, 'header') or {
		panic('missing header')
	}
	section := first_element_with_local_name(unsafe { &dom.Node(document) }, 'section') or {
		panic('missing section')
	}
	assert html_element_default_role(unsafe { &dom.HTMLElement(header) })? == .sectionheader
	assert html_element_default_role(unsafe { &dom.HTMLElement(section) })? == .region

	span := first_element_with_local_name(unsafe { &dom.Node(document) }, 'span') or {
		panic('missing span')
	}
	html_element_inserted(unsafe { &dom.HTMLElement(span) })
	assert unsafe { &dom.HTMLElement(span) }.inert()

	editable_element := first_element_with_attribute(unsafe { &dom.Node(document) }, 'contenteditable') or {
		panic('missing editable host')
	}
	html_element_attribute_changed(unsafe { &dom.HTMLElement(editable_element) }, 'contenteditable', none, '', none)
	assert html_element_is_focusable(unsafe { &dom.HTMLElement(editable_element) })
	html_element_did_receive_focus(unsafe { &dom.HTMLElement(editable_element) })
	assert document.editing_host_manager().is_within_active_contenteditable(editable_element.as_node())
	html_element_did_lose_focus(unsafe { &dom.HTMLElement(editable_element) })
	assert !document.editing_host_manager().is_within_active_contenteditable(editable_element.as_node())

	mut editable_html := unsafe { &dom.HTMLElement(editable_element) }
	editable_html.set_cryptographic_nonce('secret')
	copy := editable_element.as_node().clone_single_node(document)!
	html_element_cloned(editable_html, copy, false)!
	assert unsafe { &dom.HTMLElement(copy.as_element()?) }.cryptographic_nonce() == 'secret'
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
	assert (&NavigatorConcurrentHardwareMixin{}).hardware_concurrency() > 0
	assert compute_device_memory_value(512 * 1024 * 1024) == 1.0
	assert compute_device_memory_value(3 * 1024 * 1024 * 1024) == 4.0
}

fn test_offset_dimensions_round_fractional_border_boxes() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(element.as_node())!
	mut element_node := element.as_node()
	element_node.set_layout_node(&dom.LayoutNode{
		dom_node_: element.as_node()
		has_geometry_: true
		border_box_: dom.Rect{
			x: 10.6
			y: 20.4
			width: 10.4
			height: 20.6
		}
	})
	html_element := unsafe { &dom.HTMLElement(element) }
	assert html_element_offset_left(html_element) == 11
	assert html_element_offset_top(html_element) == 20
	assert html_element_offset_width(html_element) == 10
	assert html_element_offset_height(html_element) == 21
}
