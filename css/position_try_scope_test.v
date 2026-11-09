module css

import dom

fn test_position_try_rule_lookup_uses_layers_and_ancestor_tree_scopes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml','html')!
	document.as_node().append_child(root.as_node())!
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml','div')!
	root.as_node().append_child(target.as_node())!
	add_document_author_style_sheet(document,'@layer low,high;@layer high{@position-try --a{left:100px}}@layer low{@position-try --a{left:300px}}@position-try --doc{left:200px}')
	computer := css_style_computer_for(document)
	abstract := dom.AbstractElement.new(target,none)
	mut computed_target := abstract
	computer.recompute_style(mut computed_target)
	rule := position_try_rule_for_element(abstract,'--a') or { panic('a') }
	assert rule.style()?.get_property_value('left') == '100px'
	mut shadow := target.attach_shadow(dom.ShadowRootInit{mode:.open})!
	inside := document.create_element_ns('http://www.w3.org/1999/xhtml','span')!
	shadow.as_node().append_child(inside.as_node())!
	add_shadow_root_author_style_sheet(shadow,'@position-try --shadow{left:400px}')
	mut computed_inside := dom.AbstractElement.new(inside,none)
	computer.recompute_style(mut computed_inside)
	assert position_try_rule_for_element(computed_inside,'--doc')?.style()?.get_property_value('left') == '200px'
	assert position_try_rule_for_element(abstract,'--shadow') == none
}

fn test_position_try_rule_lookup_survives_cssom_rule_replacement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml','html')!
	document.as_node().append_child(root.as_node())!
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml','div')!
	root.as_node().append_child(target.as_node())!
	add_document_author_style_sheet(document,'div{position-try-fallbacks:--a}@position-try --a{left:100px}')
	computer := css_style_computer_for(document)
	mut element := dom.AbstractElement.new(target,none)
	computer.recompute_style(mut element)
	mut scope := style_scope_for_abstract_element(element)
	mut sheet := scope.stylesheets_for_cascade_origin(.author)[0]
	for index in 0..10 {
		sheet.insert_rule('@position-try --a{left:${200+index}px}',u32(sheet.css_rules().length()))!
		computer.recompute_style(mut element)
		gc_collect()
		rule := position_try_rule_for_element(element,'--a') or { panic('missing rule') }
		assert rule.style()?.get_property_value('left') == '${200+index}px'
	}
}
