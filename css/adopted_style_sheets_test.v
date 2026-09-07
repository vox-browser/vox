module css

import dom

fn test_adopted_style_sheet_validates_ownership_and_participates_in_document_cascade() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut document_node := unsafe { &dom.Node(document) }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	element.set_attribute_value('class', 'adopted')
	document_node.append_child(element.as_node())!

	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('.adopted { color: red; }')!
	mut list := create_adopted_style_sheets_list(document_node)
	list.append(sheet)!

	assert list.length() == 1
	assert sheet.owning_documents_or_shadow_roots.len == 1
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	assert (computed.property(.color, .no) or { panic('adopted color missing') }).css_text == 'rgb(255, 0, 0)'

	mut other_document := dom.Document.create(dom.URL{ value: 'https://other.test/' })
	foreign_sheet := css_style_sheet_construct(none, other_document)!
	if _ := list.append(foreign_sheet) {
		assert false, 'a constructed stylesheet cannot be shared across documents'
	} else {
		assert err.msg().starts_with('NotAllowedError:')
	}

	list.clear()
	assert list.length() == 0
	assert sheet.owning_documents_or_shadow_roots.len == 0
}

fn test_adopted_style_sheet_participates_in_shadow_root_cascade() {
	document := dom.Document.create(dom.url_about_blank())
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node())!
	shadow_root := host.attach_shadow(dom.ShadowRootInit{
		mode: .open
	})!
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	child.set_attribute_value('class', 'inside')
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(child.as_node())!

	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('.inside { color: blue; }')!
	mut list := create_adopted_style_sheets_list(shadow_node)
	list.append(sheet)!

	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(child, none))
	assert (computed.property(.color, .no) or { panic('shadow adopted color missing') }).css_text == 'rgb(0, 0, 255)'
	assert sheet.owning_documents_or_shadow_roots[0] == shadow_node
}
