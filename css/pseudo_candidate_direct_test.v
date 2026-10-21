module css

import dom
import platform

fn pseudo_candidate_fixture_selector(text string) Selector {
	list := parse_selector_with_parser(text, map[string]bool{}) or { panic(text) }
	return list.selectors[0]
}

fn pseudo_candidate_fixture_element(document &dom.Document, namespace string) &dom.Element {
	return document.create_element_ns(namespace, 'div') or { panic(err) }
}

fn pseudo_candidate_old_buckets_oracle(cache &RuleCache, element dom.AbstractElement, pseudo PseudoElement) bool {
	for bucket in cache.matching_rule_buckets(element) {
		for rule in bucket {
			if target := rule.pseudo_element {
				if target == pseudo { return true }
			}
		}
	}
	return false
}

fn pseudo_candidate_fixture_rule(target ?PseudoElement) &MatchingRule {
	// The coarse predicate reads the retained rule hint, independently of its selector.
	return &MatchingRule{ selector: pseudo_candidate_fixture_selector('div::before') pseudo_element: target }
}

fn test_direct_pseudo_candidate_preserves_every_bucket_and_abstract_target() {
	document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut svg_child := document.create_element_ns('http://www.w3.org/2000/svg', 'rect') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic(err) }
	root_node.append_child(svg_child.as_node()) or { panic(err) }
	for entry in [root, child, svg_child] {
		mut element := entry
		element.set_attribute_value('class', 'empty CaRD missing')
		element.set_attribute_value('id', 'TARGET')
		element.set_attribute_value('DATA-X', 'value')
		for fold in [false, true] {
			for slot in 0 .. 7 {
				mut cache := RuleCache.new()
				cache.fold_id_and_class_name_case = fold
				cache.rules_by_class['empty'] = []&MatchingRule{}
				rules := [pseudo_candidate_fixture_rule(none), pseudo_candidate_fixture_rule(PseudoElement.after), pseudo_candidate_fixture_rule(PseudoElement.selection)]
				match slot {
					0 { cache.rules_by_class[if fold { 'card' } else { 'CaRD' }] = rules }
					1 { cache.rules_by_id[if fold { 'target' } else { 'TARGET' }] = rules }
					2 { cache.rules_by_tag_name[element.lowercased_local_name()] = rules }
					3 { cache.rules_by_pseudo_element[.before] = rules }
					4 { cache.root_rules = rules }
					5 { cache.rules_by_attribute_name['data-x'] = rules }
					else { cache.other_rules = rules }
				}
				for mode in 0 .. 3 {
					mut pseudo := ?dom.PseudoElement(none)
					if mode == 1 { pseudo = dom.PseudoElement.before }
					if mode == 2 { pseudo = dom.PseudoElement.unknown_webkit }
					abstract := dom.AbstractElement.new(element, pseudo)
					for queried in [PseudoElement.before, .after, .selection, .first_letter, .part, .slotted, .unknown_webkit] {
						actual := cache.has_candidate_rule_for_pseudo_element(abstract, queried)
						assert actual == pseudo_candidate_old_buckets_oracle(cache, abstract, queried)
						included := (slot != 3 || mode == 1) && (slot != 4 || voidptr(element) == voidptr(root))
						assert actual == (included && (queried == .after || queried == .selection))
					}
				}
			}
		}
	}
}

fn test_direct_pseudo_candidate_observes_mutations_duplicates_empty_buckets_and_gc() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := pseudo_candidate_fixture_element(document, 'http://www.w3.org/1999/xhtml')
	element.set_attribute_value('class', 'Äcard duplicate')
	element.set_attribute_value('id', 'ID')
	mut cache := RuleCache.new()
	cache.fold_id_and_class_name_case = true
	abstract := dom.AbstractElement.new(element, dom.PseudoElement.before)
	assert !cache.has_candidate_rule_for_pseudo_element(abstract, .after)
	mut rule := pseudo_candidate_fixture_rule(PseudoElement.after)
	cache.rules_by_class[cache.selector_name_bucket_key('Äcard')] = [rule]
	cache.rules_by_id['id'] = [rule]
	cache.other_rules = [rule, rule]
	for _ in 0 .. 3 {
		gc_collect()
		assert cache.has_candidate_rule_for_pseudo_element(abstract, .after)
		assert !cache.has_candidate_rule_for_pseudo_element(abstract, .before)
		assert pseudo_candidate_old_buckets_oracle(cache, abstract, .after)
		assert cache.other_rules.len == 2 && voidptr(cache.other_rules[0]) == voidptr(rule)
	}
	rule.pseudo_element = none
	assert !cache.has_candidate_rule_for_pseudo_element(abstract, .after)
	rule.pseudo_element = PseudoElement.selection
	assert cache.has_candidate_rule_for_pseudo_element(abstract, .selection)
	cache.rules_by_class[cache.selector_name_bucket_key('Äcard')] = []&MatchingRule{}
	cache.rules_by_id['id'] = []&MatchingRule{}
	cache.other_rules = []&MatchingRule{}
	assert !cache.has_candidate_rule_for_pseudo_element(abstract, .selection)
	assert cache.matching_rule_buckets(abstract).len == 3
}

fn test_direct_pseudo_candidate_keeps_origin_layer_and_shadow_scope_queries() {
	document := dom.Document.create(dom.url_about_blank())
	mut host := pseudo_candidate_fixture_element(document, 'http://www.w3.org/1999/xhtml')
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut element := pseudo_candidate_fixture_element(document, 'http://www.w3.org/1999/xhtml')
	element.set_attribute_value('class', 'target')
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(element.as_node()) or { panic(err) }
	scope := css_style_scope_for_shadow_root(shadow)
	scope.build_rule_cache_if_needed()
	abstract := dom.AbstractElement.new(element, dom.PseudoElement.before)
	for origin in [CascadeOrigin.author, .user, .user_agent] {
		mut caches := scope.rule_cache_for_cascade_origin(origin, none) or { panic('cache absent') }
		original := caches.other_rules
		caches.other_rules = [pseudo_candidate_fixture_rule(PseudoElement.after)]
		assert scope.has_candidate_rule_for_pseudo_element(abstract, .after)
		caches.other_rules = original
	}
	mut author := scope.author_rule_caches() or { panic('author absent') }
	mut layered := RuleCache.new()
	layered.rules_by_class['target'] = [pseudo_candidate_fixture_rule(PseudoElement.selection)]
	author.by_layer['manual'] = layered
	assert author.has_candidate_rule_for_pseudo_element(abstract, .selection)
	assert scope.has_candidate_rule_for_pseudo_element(abstract, .selection)
	layered.rules_by_class['target'] = []&MatchingRule{}
	assert !author.has_candidate_rule_for_pseudo_element(abstract, .selection)
}

fn test_scope_pseudo_candidate_queries_do_not_allocate_origin_lists() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := pseudo_candidate_fixture_element(document, 'http://www.w3.org/1999/xhtml')
	scope := css_style_scope_for_document(document)
	abstract := dom.AbstractElement.new(element, none)
	assert !scope.has_candidate_rule_for_pseudo_element(abstract, .unknown_webkit)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		assert !scope.has_candidate_rule_for_pseudo_element(abstract, .unknown_webkit)
	}
	$if prealloc { assert platform.thread_arena_usage().used == before }
}
