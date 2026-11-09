module css

import dom

fn test_chained_part_rules_index_the_target_pseudo_element() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut node := document.as_node()
	node.append_child(root.as_node())!
	add_document_author_style_sheet(document, '::part(label)::before{content:"";height:46px} ::part(label)::after{content:"";height:77px} ::part(label)::first-line{font-size:86px}')
	computer := css_style_computer_for(document)
	document.update_style()
	scope := css_style_scope_for(dom.AbstractElement.new(root, none))
	cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('author cache') }
	assert cache.part_rules.len == 3
	assert (cache.part_rules[0].pseudo_element or { panic('before') }) == .before
	assert (cache.part_rules[1].pseudo_element or { panic('after') }) == .after
	assert (cache.part_rules[2].pseudo_element or { panic('first-line') }) == .first_line
	_ = computer
	selectors := parse_selector_with_parser('::part(label)::cue', map[string]bool{}) or { panic('cue selector') }
	assert selectors.selectors[0].serialize() == '::part(label)::cue'
}

fn test_part_pseudo_candidates_include_rules_from_the_outer_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html')!
	mut host := document.create_element_ns(dom.namespace_html_uri, 'div')!
	shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open})!
	mut part := document.create_element_ns(dom.namespace_html_uri, 'div')!
	part.set_attribute_value('part', 'label')
	mut doc_node := document.as_node()
	doc_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(host.as_node())!
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(part.as_node())!
	add_document_author_style_sheet(document, '::part(label)::before{content:"part"} ::part(label)::first-letter{color:red}')
	computer := css_style_computer_for(document)
	document.update_style()
	scope := css_style_scope_for_shadow_root(shadow)
	assert scope.has_candidate_rule_for_pseudo_element(dom.AbstractElement.new(part, .before), .before)
	before := computer.compute_pseudo_element_style_if_needed(dom.AbstractElement.new(part, .before)) or { panic('before style') }
	assert (before.property(.content, .no) or { panic('content') }).css_text == '"part"'
	letter := computer.compute_pseudo_element_style_if_needed(dom.AbstractElement.new(part, .first_letter)) or { panic('letter style') }
	color := (letter.property(.color, .no) or { panic('color') }).css_text
	assert color == 'rgb(255, 0, 0)', color
}
