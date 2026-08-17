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

	document :=
		parse_document('<a href="/go" rel="next noopener">old</a><label for="x">Name</label><input id="x"><fieldset><input><output for="x y">initial</output></fieldset>')
	root := unsafe { &dom.Node(document) }
	anchor_element := document_elements_find(root, 'a')?
	anchor := unsafe { &dom.HTMLAnchorElement(anchor_element) }
	assert html_anchor_element_rel_list(anchor) == ['next', 'noopener']
	set_html_anchor_element_text(anchor, 'new')
	assert html_anchor_element_text(anchor) == 'new'
	activation := activate_html_anchor_element(anchor, true, true, 7, 9, .activation, false)?
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
	output.set_html_for('x y x')
	assert output.html_for() == ['x', 'y']
	output.set_value('result')
	assert output.value() == 'result'
	output.reset()
	assert output.value() == 'initial'
}
