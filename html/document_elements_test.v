module html

import dom

fn document_elements_find(node &dom.Node, name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := document_elements_find(child, name) {
			return element
		}
	}
	return none
}

fn test_base_frozen_url_and_unsafe_schemes() {
	mut base := HTMLBaseElementModel.create(dom.URL{ value: 'https://example.test/a/index.html' })
	base.set_href('../assets/')
	assert base.href() == 'https://example.test/assets/'
	assert base.frozen_base_url().serialize() == 'https://example.test/assets/'
	base.set_href('javascript:alert(1)')
	assert base.frozen_base_url().serialize() == 'https://example.test/a/index.html'
}

fn test_meta_referrer_language_refresh_theme_and_csp() {
	mut state := &MetaDocumentState{}
	mut referrer := HTMLMetaElementModel.create(state)
	referrer.set_name('referrer')
	referrer.set_content('never')
	referrer.inserted(false)
	assert state.referrer_policy == .no_referrer

	mut language := HTMLMetaElementModel.create(state)
	language.set_http_equiv('content-language')
	language.set_content('  en-GB  ')
	language.inserted(true)
	assert state.pragma_set_default_language? == 'en-GB'

	mut refresh := HTMLMetaElementModel.create(state)
	refresh.set_http_equiv('refresh')
	refresh.set_content('5; URL=/next')
	refresh.inserted(true)
	assert state.refresh_input? == '5; URL=/next'

	mut csp := HTMLMetaElementModel.create(state)
	csp.set_http_equiv('content-security-policy')
	csp.set_content("default-src 'self'; report-uri /report; sandbox")
	csp.inserted(true)
	assert state.enforced_meta_csp.len == 1
	assert state.enforced_meta_csp[0].directives.len == 1
	assert state.enforced_meta_csp[0].directives[0].name == 'default-src'
}

fn test_style_sheet_lifecycle_and_disabled() {
	mut style := HTMLStyleElementModel.create()
	style.set_text('body { color: red }')
	assert style.sheet() == none
	style.inserted()
	assert style.sheet()?.text == 'body { color: red }'
	style.set_media('screen')
	assert style.sheet()?.media == 'screen'
	style.set_disabled(true)
	assert style.disabled()
	style.set_type('text/less')
	assert style.sheet() == none
	style.removed()
}

fn test_body_hints_anchor_label_fieldset_and_output() {
	hints := html_body_presentational_hints({
		'bgcolor':     '#123'
		'text':        '#ffffff'
		'background':  '/paper.png'
		'marginwidth': '8'
	}, {
		'marginheight': '4'
	}, dom.URL{ value: 'https://example.test/' })
	assert hints.background_color?.r == 0x11
	assert hints.color?.g == 0xff
	assert hints.background_image?.serialize() == 'https://example.test/paper.png'
	assert hints.margin_left? == 8
	assert hints.margin_top? == 4

	mut document := parse_document('<a href="/go" rel="next noopener">old</a><label for="x">Name</label><input id="x"><fieldset><input><output for="x y">initial</output></fieldset>')
	document.set_url(dom.URL{ value: 'https://example.test/' })
	root := unsafe { &dom.Node(document) }
	mut anchor_element := document_elements_find(root, 'a')?
	anchor := unsafe { &dom.HTMLAnchorElement(anchor_element) }
	rel_list := html_anchor_element_rel_list(anchor)
	assert rel_list.token_set == ['next', 'noopener']
	anchor_element.set_attribute_value('rel', 'external')
	html_anchor_element_attribute_changed(anchor, 'rel', 'next noopener', 'external', none)
	assert html_anchor_element_rel_list(anchor) == rel_list
	assert rel_list.token_set == ['external']
	assert html_anchor_element_has_activation_behavior(anchor)
	assert html_anchor_element_default_tab_index_value(anchor) == 0
	assert html_anchor_element_default_role(anchor) == .link
	set_html_anchor_element_text(anchor, 'new')
	assert html_anchor_element_text(anchor) == 'new'
	activation := html_anchor_element_activation_behavior(anchor, true, true, 7, 9, .activation, false)?
	assert activation.url.serialize().ends_with('/go?7,9')

	label := unsafe { &dom.HTMLLabelElement(document_elements_find(root, 'label')?) }
	assert html_label_element_control(label)?.get_attribute_value('id') == 'x'
	fieldset := unsafe { &dom.HTMLFieldSetElement(document_elements_find(root, 'fieldset')?) }
	assert html_fieldset_element_elements(fieldset).len == 2
	assert html_fieldset_element_is_disabled(false, [
		FieldSetContext{ disabled: true },
	])
	output_element := unsafe { &dom.HTMLOutputElement(document_elements_find(root, 'output')?) }
	mut output := HTMLOutputElementModel.create(output_element)
	output.form_associated_element_attribute_changed('for', none, 'x y x', none)
	assert output.html_for() == ['x', 'y']
	output.set_value('result')
	assert output.value() == 'result'
	output.reset_algorithm()
	assert output.value() == 'initial'
	output.clear_algorithm()
	assert output.value() == ''
}

fn test_label_activation_form_and_fieldset_disabled_legend_exception() {
	document := parse_document('<form><label for="control">Caption</label><input id="control"><fieldset disabled><legend><fieldset id="inside"></fieldset></legend><fieldset id="outside"></fieldset></fieldset></form>')
	root := unsafe { &dom.Node(document) }
	label_element := document_elements_find(root, 'label') or { panic('label') }
	label := unsafe { &dom.HTMLLabelElement(label_element) }
	control := html_label_element_control(label) or { panic('control') }
	assert html_label_element_has_activation_behavior(label)
	assert html_label_element_form(label) != none
	html_label_element_set_being_activated(label, true)
	assert label_element.is_being_activated()
	assert control.is_being_activated()
	html_label_element_set_being_activated(label, false)
	click := dom.MouseEvent.create('click', dom.MouseEventInit{ detail: 1 })
	html_label_element_activation_behavior(label, unsafe { &dom.Event(click) })
	assert document.focused_area()? == control.as_node()

	inside := document.get_element_by_id('inside') or { panic('inside fieldset') }
	outside := document.get_element_by_id('outside') or { panic('outside fieldset') }
	assert !html_field_set_element_is_disabled(unsafe { &dom.HTMLFieldSetElement(inside) })
	assert html_field_set_element_is_disabled(unsafe { &dom.HTMLFieldSetElement(outside) })
	assert html_field_set_element_elements(unsafe { &dom.HTMLFieldSetElement(outside) }).len == 0
}

fn test_map_areas_and_modification_and_quote_default_roles() {
	document := parse_document('<map><area id="one"><div><area id="two"></div><a id="not-area"></a></map><del></del><ins></ins><blockquote></blockquote><q></q>')
	root := unsafe { &dom.Node(document) }
	map_element := unsafe {
		&dom.HTMLMapElement(document_elements_find(root, 'map') or {
			panic('map')
		})
	}
	areas := html_map_element_areas(map_element)
	assert areas.length() == 2
	assert areas.item(0)?.get_attribute_value('id') == 'one'
	assert areas.item(1)?.get_attribute_value('id') == 'two'
	assert html_map_element_areas(map_element) == areas

	del_element := unsafe {
		&dom.HTMLModElement(document_elements_find(root, 'del') or {
			panic('del')
		})
	}
	ins_element := unsafe {
		&dom.HTMLModElement(document_elements_find(root, 'ins') or {
			panic('ins')
		})
	}
	blockquote := unsafe {
		&dom.HTMLQuoteElement(document_elements_find(root, 'blockquote') or {
			panic('blockquote')
		})
	}
	quote := unsafe {
		&dom.HTMLQuoteElement(document_elements_find(root, 'q') or {
			panic('q')
		})
	}
	assert html_mod_element_default_role(del_element) == .deletion
	assert html_mod_element_default_role(ins_element) == .insertion
	assert html_quote_element_default_role(blockquote) == .blockquote
	assert html_quote_element_default_role(quote) == .generic
}

fn test_concrete_area_base_meta_source_and_style_element_algorithms() {
	mut document := parse_document('<head><base href="assets/"><meta id="language" http-equiv="content-language" content="en-GB"><meta id="referrer" name="referrer" content="never"><style media="screen">body { color: red }</style></head><body><map><area id="area" rel="next noopener" href="target"></map><audio><source></audio></body>')
	document.set_url(dom.URL{ value: 'https://example.test/root/page.html' })
	root := unsafe { &dom.Node(document) }

	base_element := unsafe {
		&dom.HTMLBaseElement(document_elements_find(root, 'base') or {
			panic('base')
		})
	}
	html_base_element_inserted(base_element)
	assert html_base_element_href(base_element) == 'https://example.test/root/assets/'
	assert document.base_url().serialize() == 'https://example.test/root/assets/'

	mut area_element := document.get_element_by_id('area') or { panic('area') }
	area := unsafe { &dom.HTMLAreaElement(area_element) }
	rel_list := html_area_element_rel_list(area)
	assert rel_list.contains('next')
	assert html_area_element_default_tab_index_value(area) == 0
	assert html_area_element_default_role(area) == .link
	area_element.set_attribute_value('rel', 'external')
	html_area_element_attribute_changed(area, 'rel', 'next noopener', 'external', none)
	assert rel_list.contains('external')

	language := unsafe {
		&dom.HTMLMetaElement(document.get_element_by_id('language') or {
			panic('language meta')
		})
	}
	referrer := unsafe {
		&dom.HTMLMetaElement(document.get_element_by_id('referrer') or {
			panic('referrer meta')
		})
	}
	assert html_meta_element_http_equiv_state(language)? == .content_language
	html_meta_element_inserted(language)
	html_meta_element_inserted(referrer)
	assert document.pragma_set_default_language_value()? == 'en-GB'
	assert document.meta_referrer_policy() == 'no-referrer'

	style := unsafe {
		&dom.HTMLStyleElement(document_elements_find(root, 'style') or {
			panic('style')
		})
	}
	html_style_element_inserted(style)
	assert html_style_element_sheet(style) != none
	assert html_style_element_sheet(style)?.media == 'screen'
	html_style_element_attribute_changed(style, 'media', 'screen', 'print', none)
	assert html_style_element_sheet(style)?.media == 'print'
	set_html_style_element_disabled(style, true)
	assert html_style_element_disabled(style)

	source := unsafe {
		&dom.HTMLSourceElement(document_elements_find(root, 'source') or {
			panic('source')
		})
	}
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	html_source_element_inserted(source)
	parent := unsafe { &dom.Element(source) }.as_node().parent_element() or { panic('audio') }
	media := html_media_element_for_dom_element(parent) or { panic('media state') }
	assert media.network_state() == .no_source
}

fn test_body_link_background_and_window_event_targets() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/root/' })
	mut body_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or {
		panic(err)
	}
	body := unsafe { &dom.HTMLBodyElement(body_element) }
	html_body_element_attribute_changed(body, 'link', none, '#123456', none)
	html_body_element_attribute_changed(body, 'alink', none, 'red', none)
	html_body_element_attribute_changed(body, 'vlink', none, 'blue', none)
	html_body_element_attribute_changed(body, 'background', none, 'tile.png', none)
	assert document.normal_link_color()?.r == 0x12
	assert document.active_link_color()?.r == 0xff
	assert document.visited_link_color()?.b == 0xff
	assert body.background_url_?.serialize() == 'https://example.test/root/tile.png'

	mut window := &dom.Window{}
	document.set_window(window)
	load_target := html_body_element_global_event_handlers_to_event_target(body, 'load') or {
		panic('missing load target')
	}
	click_target := html_body_element_global_event_handlers_to_event_target(body, 'click') or {
		panic('missing click target')
	}
	assert voidptr(load_target) == voidptr(unsafe { &dom.EventTarget(window) })
	assert voidptr(click_target) == voidptr(unsafe { &dom.EventTarget(body_element.as_node()) })
	assert voidptr(html_body_element_window_event_handlers_to_event_target(body)?) == voidptr(unsafe { &dom.EventTarget(window) })
}
