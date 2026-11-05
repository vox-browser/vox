module css

import dom

fn exact_bucket_rule(index uint, text string, pseudo ?PseudoElement) &MatchingRule {
	return &MatchingRule{rule_index: index, selector: selector_from_text(text), cascade_origin: .author,
		contains_pseudo_element: pseudo != none, pseudo_element: pseudo}
}

fn exact_bucket_compare(document &dom.Document, target &dom.Element, rules []&MatchingRule,
	pseudo ?PseudoElement) []uint {
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('cache absent') }
	for rule in rules { cache.add_rule(rule, rule.pseudo_element, false) }
	mut computer := StyleComputer.new(document)
	mut ancestor := target.as_node().parent_element()
	for ancestor != none {
		parent := ancestor or { break }
		computer.push_ancestor(parent)
		ancestor = parent.as_node().parent_element()
	}
	mut attempted := PseudoClassBitmap{}
	abstract := dom.AbstractElement.new(target, if pseudo != none {
		?dom.PseudoElement(dom.PseudoElement.before)
	} else { none })
	actual := style_computer_collect_matching_rules_in_scope(computer, abstract, .author,
		mut attempted, none, scope)
	mut expected := []uint{}
	for rule in rules {
		if rule.contains_pseudo_element != (pseudo != none) { continue }
		mut context := MatchContext{}
		if matches(rule.selector, target, none, mut context, pseudo, none, .normal, none) {
			expected << rule.rule_index
		}
	}
	mut indices := actual.map(it.rule.rule_index)
	indices.sort()
	expected.sort()
	assert indices == expected
	return indices
}

fn test_exact_attribute_buckets_filter_values_and_read_live_replacements() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut target := document.create_element('div')!
	mut rules := []&MatchingRule{}
	mut cache := RuleCache.new()
	for index in 0 .. 100 {
		rule := exact_bucket_rule(uint(index), 'div[data-testid="card-${index}"]', none)
		rules << rule
		cache.add_rule(rule, none, false)
	}
	for index in [0, 99, 21, 99] {
		target.set_attribute_value('data-testid', 'card-${index}')
		buckets := cache.matching_rule_buckets(dom.AbstractElement.new(target, none))
		mut count := 0
		for bucket in buckets { count += bucket.len }
		assert count == if disable_exact_attribute_buckets { 100 } else { 1 }
		assert exact_bucket_compare(document, target, rules, none) == [uint(index)]
		gc_collect()
	}
	mut attributes := target.attributes()
	attributes.set_attribute(&dom.Attr_{name_: 'data-testid', local_name_: 'data-testid', value_: 'card-37'})!
	mut live_candidates := []uint{}
	for bucket in cache.matching_rule_buckets(dom.AbstractElement.new(target, none)) {
		for rule in bucket { live_candidates << rule.rule_index }
	}
	if !disable_exact_attribute_buckets { assert live_candidates == [uint(37)] }
	assert exact_bucket_compare(document, target, rules, none) == [uint(37)]
	target.remove_attribute('data-testid')
	assert exact_bucket_compare(document, target, rules, none).len == 0
}

fn test_exact_attribute_buckets_preserve_flags_namespaces_and_class_id_priority() {
	for text in ['[data-x="Card" i]', '[type="text"]', '[*|data-x="Card"]',
		'[x|data-x="Card"]', '[xml\\:lang="en"]', '.card[data-x="Card"]',
		'#target[data-x="Card"]', ':is(.card)[data-x="Card"]', '[data-x^="Card"]'] {
		mut cache := RuleCache.new()
		cache.add_rule(exact_bucket_rule(1, text, none), none, false)
		assert cache.rules_by_exact_attribute.len == 0, text
	}
	for html_document in [true, false] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_document_type(if html_document { .html } else { .xml })
		for namespace in [dom.namespace_html_uri, 'http://www.w3.org/2000/svg'] {
			mut target := document.create_element_ns(namespace, 'a')!
			target.set_attribute_value('type', 'TeXt')
			target.set_attribute_value('data-x', 'Card')
			target.set_attribute_value('data-empty', '')
			rules := [exact_bucket_rule(1, '[type=text]', none),
				exact_bucket_rule(2, '[type=TeXt s]', none),
				exact_bucket_rule(3, '[data-x=card i]', none),
				exact_bucket_rule(4, '[data-x=Card]', none),
				exact_bucket_rule(5, '[data-empty=""]', none),
				exact_bucket_rule(6, '[|data-x=Card]', none),
				exact_bucket_rule(7, '[*|data-x=Card]', none)]
			_ = exact_bucket_compare(document, target, rules, none)
		}
	}
}

fn test_exact_attribute_buckets_keep_pseudo_candidates_and_complete_selectors() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element('div')!
	rules := [exact_bucket_rule(1, 'div[data-x=card]::before', .before),
		exact_bucket_rule(2, 'span[data-x=card]::before', .before),
		exact_bucket_rule(3, 'div[data-x=other]::before', .before),
		exact_bucket_rule(4, 'div[data-x=card][title=yes]', none)]
	for value in ['card', 'other', 'missing', 'card'] {
		target.set_attribute_value('data-x', value)
		target.set_attribute_value('title', 'yes')
		_ = exact_bucket_compare(document, target, rules, none)
		_ = exact_bucket_compare(document, target, rules, .before)
		scope := css_style_scope_for_document(document)
		if value in ['card', 'other'] {
			assert scope.has_candidate_rule_for_pseudo_element(dom.AbstractElement.new(target, none), .before)
		}
	}
}

fn test_exact_attribute_buckets_do_not_filter_attributes_of_an_ancestor_or_is_argument() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element('div')!
	mut target := document.create_element('span')!
	parent.set_attribute_value('data-x', 'card')
	mut parent_node := parent.as_node()
	parent_node.append_child(target.as_node())!
	rules := [exact_bucket_rule(1, '[data-x=card] span', none),
		exact_bucket_rule(2, ':is([data-x=card],span)', none),
		exact_bucket_rule(3, ':not([data-x=card])', none)]
	assert exact_bucket_compare(document, target, rules, none) == [uint(1), 2, 3]
}

fn test_exact_attribute_buckets_keep_cascade_and_attribute_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element('html')!
	mut target := document.create_element('div')!
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(target.as_node())!
	add_document_author_style_sheet(document, 'div{color:blue}[data-x=card]{color:red}[data-x=other]{color:green}[data-x=card]{color:purple}')
	for value, color in {'card':'rgb(128, 0, 128)', 'other':'rgb(0, 128, 0)', 'missing':'rgb(0, 0, 255)'} {
		target.set_attribute_value('data-x', value)
		computed := css_style_computer_for(document).compute_style(dom.AbstractElement.new(target, none))
		assert (computed.property(.color, .no) or { panic('color absent') }).css_text == color
	}
}

fn test_exact_attribute_buckets_keep_has_mutation_filtering_live() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element('html')!
	mut anchor := document.create_element('section')!
	mut trigger := document.create_element('i')!
	mut document_node := document.as_node()
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(anchor.as_node())!
	mut anchor_node := anchor.as_node()
	anchor_node.append_child(trigger.as_node())!
	anchor.set_attribute_value('data-kind', 'card')
	add_document_author_style_sheet(document, 'section{color:blue}[data-kind=card]:has(> .on){color:red}')
	css_style_computer_for(document)
	for on in [false, true, false, true] {
		trigger.set_attribute_value('class', if on { 'on' } else { '' })
		document.update_style()
		computed := computed_properties_for_element(anchor) or { panic('style absent') }
		assert (computed.property(.color, .no) or { panic('color absent') }).css_text == if on {
			'rgb(255, 0, 0)'
		} else { 'rgb(0, 0, 255)' }
	}
}
