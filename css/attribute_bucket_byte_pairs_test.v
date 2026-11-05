module css

import dom

fn pair_bucket_rule(index uint, text string) &MatchingRule {
	return &MatchingRule{rule_index: index, selector: selector_from_text(text), cascade_origin: .author}
}

fn test_attribute_pair_filter_admits_every_borrowed_byte_substring_and_ascii_fold() {
	mut bytes := []u8{}
	for i in 0 .. 256 { bytes << u8(i) }
	value := bytes.bytestr()
	mut pairs := AttributeBucketBytePairs{}
	assert attribute_bucket_pattern_might_match(value, '', mut pairs)
	assert attribute_bucket_pattern_might_match(value, 'x', mut pairs)
	assert !pairs.ready
	for start in 0 .. 255 {
		for size in 2 .. 34 {
			if start + size > value.len { continue }
			pattern := unsafe { value.substr_unsafe(start, start + size) }
			assert attribute_bucket_pattern_might_match(value, pattern, mut pairs)
			assert attribute_bucket_pattern_might_match(value, to_ascii_lowercase(pattern), mut pairs)
		}
	}
	for text in ['CAFÉ\x00İ', 'aBc-DeF', 'é中É'] {
		mut current := AttributeBucketBytePairs{}
		assert attribute_bucket_pattern_might_match(text, text, mut current)
		assert attribute_bucket_pattern_might_match(text, to_ascii_lowercase(text), mut current)
	}
}

fn test_attribute_pair_collisions_are_only_false_positives_and_lengths_stay_live() {
	mut pairs := AttributeBucketBytePairs{}
	assert !attribute_bucket_pattern_might_match('ab', 'abc', mut pairs)
	assert !pairs.ready
	assert attribute_bucket_pattern_might_match('ab', 'AB', mut pairs)
	mut collision := ''
	for a in 0 .. 256 {
		for b in 0 .. 256 {
			candidate := [u8(a), u8(b)].bytestr()
			if !equals_ignoring_ascii_case(candidate, 'ab')
				&& attribute_bucket_pair_hash(u8(a), u8(b)) == attribute_bucket_pair_hash(`a`, `b`) {
				collision = candidate
				break
			}
		}
		if collision.len > 0 { break }
	}
	assert collision.len == 2
	assert attribute_bucket_pattern_might_match('ab', collision, mut pairs)
	assert !selector_string_contains('ab', collision, .case_insensitive)
	mut absent := AttributeBucketBytePairs{}
	assert !attribute_bucket_pattern_might_match('abc', 'xy', mut absent)
	mut empty := AttributeBucketBytePairs{}
	assert !attribute_bucket_pattern_might_match('', 'ab', mut empty)
}

fn test_attribute_pair_filter_keeps_dynamic_scoped_and_namespace_sensitive_rules() {
	for text in ['[data-x*=absent]:hover', '[data-x*=absent]:is(div)', '[data-x*=absent]:not(.x)',
		'[data-x*=absent]:has(span)', 'main [data-x*=absent]', '[data-x*=absent] + div',
		'[data-x*=absent]::before', '[data-x*=absent]::part(label)', '::slotted([data-x*=absent])',
		'[*|data-x*=absent]', '[DATA-X*=absent]', '[data-x]', '[data-x*=a]', '[data-x=""]'] {
		mut pairs := AttributeBucketBytePairs{}
		assert !attribute_bucket_rule_is_impossible(pair_bucket_rule(1, text), 'data-x', 'content', mut pairs), text
	}
	for kind in 0 .. 5 {
		mut rule := pair_bucket_rule(1, '[data-x*=absent]')
		match kind {
			0 { rule.scope_rule = &CSSRule{} }
			1 { rule.container_rule = &CSSRule{} }
			2 { rule.slotted = true }
			3 { rule.contains_part_pseudo_element = true }
			else { rule.contains_pseudo_element = true }
		}
		mut pairs := AttributeBucketBytePairs{}
		assert !attribute_bucket_rule_is_impossible(rule, 'data-x', 'content', mut pairs)
	}
	mut pairs := AttributeBucketBytePairs{}
	assert attribute_bucket_rule_is_impossible(pair_bucket_rule(1, 'div[data-x*=absent]'), 'data-x', 'content', mut pairs)
}

fn test_attribute_pair_filter_reads_mutated_selector_payloads_and_multiple_requirements() {
	mut rule := pair_bucket_rule(1, 'div[data-x*=absent][data-other*=absent]')
	mut pairs := AttributeBucketBytePairs{}
	assert attribute_bucket_rule_is_impossible(rule, 'data-x', 'content', mut pairs)
	mut compounds := rule.selector.compound_selectors()
	compounds[0].simple_selectors[1] = SimpleSelector.with_attribute(.attribute, SelectorAttribute{
		match_type: .contains_string
		qualified_name: SelectorQualifiedName{name: SelectorName.new('data-x')}
		value: 'tent'
	})
	assert !attribute_bucket_rule_is_impossible(rule, 'data-x', 'content', mut pairs)
	rule.selector = selector_from_text('div[data-x*=absent]:hover')
	assert !attribute_bucket_rule_is_impossible(rule, 'data-x', 'content', mut pairs)
	rule.selector = selector_from_text('[data-x*=tent][data-x*=absent]')
	assert attribute_bucket_rule_is_impossible(rule, 'data-x', 'content', mut pairs)
}

fn pair_bucket_compare_with_matcher(computer &StyleComputer, scope &StyleScope, element &dom.Element, rules []&MatchingRule) {
	mut expected := []&MatchingRule{}
	mut attempted := PseudoClassBitmap{}
	for rule in rules {
		mut context := MatchContext{collect_per_element_selector_involvement_metadata: true}
		if matches(rule.selector, element, none, mut context, none, none, .normal, none) { expected << rule }
		attempted.merge(context.attempted_pseudo_class_matches)
	}
	mut actual_attempted := PseudoClassBitmap{}
	actual := style_computer_collect_matching_rules_in_scope(computer, dom.AbstractElement.new(element, none), .author, mut actual_attempted, none, scope)
	assert actual.len == expected.len
	for i, rule in expected { assert voidptr(actual[i].rule) == voidptr(rule) }
	for pseudo in [PseudoClass.hover, .active, .focus] {
		assert actual_attempted.get(pseudo) == attempted.get(pseudo)
	}
}

fn test_attribute_pair_collection_matches_full_oracle_with_live_values_duplicates_and_attempts() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element('div')!
	mut scope := css_style_scope_for_document(document)
	scope.populate_new_rule_cache()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('no cache') }
	mut rules := []&MatchingRule{}
	for i, text in ['[data-x="Alpha two en-US"]', '[data-x~=two]', '[data-x*=pha]',
		'[data-x^=Alpha]', '[data-x$=US]', '[data-x|=en]', '[data-x*=ALPHA i]',
		'[data-x*=absent]', '[data-x=""]', '[data-x*=""]', '[data-x]',
		'[data-x*=absent]:hover', '[data-x*=absent]:active', '[data-x*=absent]:focus'] {
		rules << pair_bucket_rule(uint(i), text)
	}
	rules << rules[2]
	cache.rules_by_attribute_name['data-x'] = rules
	computer := StyleComputer.new(document)
	for value in ['Alpha two en-US', '', 'en-US', 'absent', 'alpha', 'a'.repeat(512), 'a'.repeat(513)] {
		target.set_attribute_value('data-x', value)
		pair_bucket_compare_with_matcher(computer, scope, target, rules)
		gc_collect()
	}
	target.remove_attribute('data-x')
	pair_bucket_compare_with_matcher(computer, scope, target, rules)
	// Late bucket growth, clearing and mutation never reuse stale summaries.
	cache.rules_by_attribute_name['data-x'] = [rules[2]]
	target.set_attribute_value('data-x', 'Alpha')
	pair_bucket_compare_with_matcher(computer, scope, target, [rules[2]])
	cache.rules_by_attribute_name['data-x'] = []&MatchingRule{}
	pair_bucket_compare_with_matcher(computer, scope, target, []&MatchingRule{})
}

fn test_attribute_pair_collection_uses_matcher_attribute_identity_in_html_svg_and_xml() {
	for html_document in [true, false] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_document_type(if html_document { .html } else { .xml })
		for namespace in [dom.namespace_html_uri, 'http://www.w3.org/2000/svg'] {
			mut target := document.create_element_ns(namespace, 'g')!
			target.set_attribute_value('data-x', 'plain')
			target.set_attribute_ns_for_bindings('urn:a', 'a:data-x', 'namespaced')!
			target.set_attribute_value('type', 'TeXt')
			mut scope := css_style_scope_for_document(document)
			scope.populate_new_rule_cache()
			mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('no cache') }
			mut rules := []&MatchingRule{}
			for i, text in ['[data-x*=plain]', '[data-x*=absent]', '[*|data-x*=namespaced]',
				'[|data-x*=plain]', '[DATA-X*=plain]', '[data-x*=PLAIN i]', '[data-x]', '[data-x*=la]'] {
				rules << pair_bucket_rule(uint(i), text)
			}
			cache.rules_by_attribute_name['data-x'] = rules
			computer := StyleComputer.new(document)
			pair_bucket_compare_with_matcher(computer, scope, target, rules)
			target.set_attribute_value('data-x', 'changed')
			pair_bucket_compare_with_matcher(computer, scope, target, rules)
			cache.rules_by_attribute_name.delete('data-x')
			mut type_rules := []&MatchingRule{}
			for i, text in ['[type=text]', '[type=text i]', '[type=TeXt s]', '[type=absent]',
				'[type*=ex]', '[type]', '[type*=EX i]', '[*|TYPE=TeXt]'] { type_rules << pair_bucket_rule(uint(i), text) }
			cache.rules_by_attribute_name['type'] = type_rules
			pair_bucket_compare_with_matcher(computer, scope, target, type_rules)
		}
	}
}

fn test_attribute_pair_collection_preserves_live_cascade_after_value_changes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element_ns(dom.namespace_html_uri, 'div')!
	mut node := unsafe { &dom.Node(document) }
	node.append_child(target.as_node())!
	mut sheet := css_style_sheet_construct(none, document)!
	mut source := ''
	for i in 0 .. 12 { source += 'div[data-x*="needle${i}"] {width:${20 + i}px;}\n' }
	sheet.replace_sync(source)!
	mut list := create_adopted_style_sheets_list(node)
	list.append(sheet)!
	computer := StyleComputer.new(document)
	expectations := ['23px', 'auto', '28px', 'auto', '23px']
	for index, value in ['needle3', 'absent', 'needle8', 'NEEDLE8', 'needle3'] {
		target.set_attribute_value('data-x', value)
		computed := computer.compute_style(dom.AbstractElement.new(target, none))
		assert (computed.property(.width, .no) or { panic('missing width') }).css_text == expectations[index]
	}
	target.remove_attribute('data-x')
	computed := computer.compute_style(dom.AbstractElement.new(target, none))
	assert (computed.property(.width, .no) or { panic('missing width') }).css_text == 'auto'
}

fn test_attribute_pair_collection_prunes_only_proven_false_rules_and_preserves_scope_wrappers() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns(dom.namespace_html_uri, 'div')!
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	mut target := document.create_element('span')!
	target.set_attribute_value('data-x', 'content')
	computer := StyleComputer.new(document)
	mut rules := []&MatchingRule{}
	for i in 0 .. 8 { rules << pair_bucket_rule(uint(i), '[data-x*=absent${i}]') }
	keep := pair_bucket_rule(8, '[data-x*=tent]')
	rules << keep
	rules << keep
	abstract := dom.AbstractElement.new(target, none)
	mut collected := []ScopedMatchingRule{}
	style_scope_add_attribute_bucket_rules_to_run(computer, abstract, 'data-x', rules, shadow, shadow, none, mut collected)
	assert collected.len == if retain_attribute_bucket_candidates { 10 } else { 2 }
	for i, scoped in collected {
		assert voidptr(scoped.rule) == voidptr(if retain_attribute_bucket_candidates { rules[i] } else { keep })
		assert voidptr(scoped.shadow_root or { panic('lost shadow scope') }) == voidptr(shadow)
	}
	// Small buckets, unbounded values and pseudo-element queries stay on the
	// original collector, including public rule-hint behavior.
	for count in [7, 10] {
		if count == 10 { target.set_attribute_value('data-x', 'x'.repeat(513)) }
		mut original := []ScopedMatchingRule{}
		mut filtered := []ScopedMatchingRule{}
		style_scope_add_rules_to_run(computer, abstract, rules[..count], shadow, shadow, none, mut original)
		style_scope_add_attribute_bucket_rules_to_run(computer, abstract, 'data-x', rules[..count], shadow, shadow, none, mut filtered)
		assert original.len == filtered.len
		for i, rule in original { assert voidptr(filtered[i].rule) == voidptr(rule.rule) }
	}
	target.set_attribute_value('data-x', 'content')
	for rule in rules {
		mut writable := unsafe { &MatchingRule(rule) }
		writable.selector = selector_from_text('[data-x*=absent]::before')
		writable.contains_pseudo_element = true
		writable.pseudo_element = PseudoElement.before
	}
	pseudo := dom.AbstractElement.new(target, dom.PseudoElement.before)
	mut original := []ScopedMatchingRule{}
	mut filtered := []ScopedMatchingRule{}
	style_scope_add_rules_to_run(computer, pseudo, rules, shadow, shadow, none, mut original)
	style_scope_add_attribute_bucket_rules_to_run(computer, pseudo, 'data-x', rules, shadow, shadow, none, mut filtered)
	assert original.len == 10 && filtered.len == 10
	for i, rule in original { assert voidptr(filtered[i].rule) == voidptr(rule.rule) }
}
