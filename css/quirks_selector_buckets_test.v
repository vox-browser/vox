module css

import dom

fn test_quirks_class_and_id_buckets_and_ancestor_filter_fold_ascii_case() {
	for quirks in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		if quirks {
			document.set_quirks_mode(.yes)
		}
		mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
		root.set_attribute_value('class', 'ANCESTOR')
		root.set_attribute_value('id', 'PARENT')
		mut document_node := unsafe { &dom.Node(document) }
		document_node.append_child(root.as_node())!
		mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
		target.set_attribute_value('class', 'TARGET')
		target.set_attribute_value('id', 'ITEM')
		mut root_node := root.as_node()
		root_node.append_child(target.as_node())!
		add_document_author_style_sheet(document, '.target { color: red; }
			#item { background-color: blue; }
			.ancestor #ITEM { width: 23px; }
			#parent :is(.target) { height: 41px; }
			:is(#item) { opacity: 0.75; }')
		mut computer := StyleComputer.new(document)
		computer.push_ancestor(root)
		computed := computer.compute_style(dom.AbstractElement.new(target, none))
		assert (computed.property(.color, .no) or { panic('color absent') }).css_text == if quirks {
			'rgb(255, 0, 0)'
		} else {
			'rgb(0 0 0)'
		}
		assert (computed.property(.background_color, .no) or { panic('background absent') }).css_text == if quirks {
			'rgb(0, 0, 255)'
		} else {
			'rgba(0, 0, 0, 0)'
		}
		assert (computed.property(.width, .no) or { panic('width absent') }).css_text == if quirks {
			'23px'
		} else {
			'auto'
		}
		assert (computed.property(.opacity, .no) or { panic('opacity absent') }).css_text == if quirks {
			'0.75'
		} else {
			'1'
		}
		assert (computed.property(.height, .no) or { panic('height absent') }).css_text == if quirks {
			'41px'
		} else {
			'auto'
		}
	}
}

fn test_constructed_shadow_sheet_shared_cache_is_not_reused_by_quirks_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('.target { color: red; }')!
	mut scopes := []&StyleScope{}
	mut children := []&dom.Element{}
	for _ in 0 .. 2 {
		mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
		root_node.append_child(host.as_node())!
		shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
		mut shadow_node := unsafe { &dom.Node(shadow) }
		mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
		target.set_attribute_value('class', 'TARGET')
		shadow_node.append_child(target.as_node())!
		mut sheets := create_adopted_style_sheets_list(shadow_node)
		sheets.append(sheet)!
		scopes << css_style_scope_for_node(shadow_node)
		children << target
	}
	scopes[0].build_rule_cache_if_needed()
	standard_cache := sheet.shared_single_constructed_sheet_style_cache or { panic('shared cache absent') }
	// Changing document mode creates a quirks scope using the same constructed
	// sheet. Its folded keys must never enter or reuse the standards cache.
	document.set_quirks_mode(.yes)
	scopes[1].build_rule_cache_if_needed()
	quirks_cache := scopes[1].rule_cache or { panic('quirks cache absent') }
	assert voidptr(quirks_cache) != voidptr(standard_cache)
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(children[1], none))
	assert (computed.property(.color, .no) or { panic('color absent') }).css_text == 'rgb(255, 0, 0)'
	assert sheet.shared_single_constructed_sheet_style_cache? == standard_cache
}
