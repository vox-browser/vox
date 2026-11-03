module css

import dom
import platform

fn batch_candidate_rule(pseudo ?PseudoElement) &MatchingRule {
	selectors := parse_selector_with_parser('div::before', map[string]bool{}) or { panic('selector') }
	return &MatchingRule{ selector: selectors.selectors[0], pseudo_element: pseudo }
}

fn batch_candidate_abstract(element &dom.Element, pseudo PseudoElement) dom.AbstractElement {
	selected := match pseudo {
		.before { dom.PseudoElement.before }
		.after { dom.PseudoElement.after }
		.selection { dom.PseudoElement.selection }
		.first_letter { dom.PseudoElement.first_letter }
		.marker { dom.PseudoElement.marker }
		.backdrop { dom.PseudoElement.backdrop }
		else { dom.PseudoElement.unknown_webkit }
	}
	return dom.AbstractElement.new(element, selected)
}

fn batch_scope_candidate(scope &StyleScope, element &dom.Element, pseudo PseudoElement) bool {
	mut batch := PseudoCandidateBatch{}
	return batch.has_candidate(scope, batch_candidate_abstract(element, pseudo), pseudo)
}

fn test_batched_pseudo_candidates_preserve_every_originating_and_dedicated_bucket() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut node := document.as_node()
	node.append_child(root.as_node())!
	for namespace in ['http://www.w3.org/1999/xhtml', 'http://www.w3.org/2000/svg'] {
		mut child := document.create_element_ns(namespace, 'div')!
		mut root_node := root.as_node()
		root_node.append_child(child.as_node())!
		for entry in [root, child] {
			mut element := entry
			element.set_attribute_value('class', 'CaRD empty')
			element.set_attribute_value('id', 'TARGET')
			element.set_attribute_value('DATA-X', 'value')
			for fold in [false, true] {
				for slot in 0 .. 7 {
					mut cache := RuleCache.new()
					cache.fold_id_and_class_name_case = fold
					rules := [batch_candidate_rule(none), batch_candidate_rule(PseudoElement.after),
						batch_candidate_rule(PseudoElement.selection)]
					match slot {
						0 { cache.rules_by_class[if fold { 'card' } else { 'CaRD' }] = rules }
						1 { cache.rules_by_id[if fold { 'target' } else { 'TARGET' }] = rules }
						2 { cache.rules_by_tag_name[element.lowercased_local_name()] = rules }
						3 { cache.rules_by_pseudo_element[.before] = rules }
						4 { cache.root_rules = rules }
						5 { cache.rules_by_attribute_name['data-x'] = rules }
						else { cache.other_rules = rules }
					}
					for queried in [PseudoElement.before, .after, .selection, .first_letter, .marker,
						.backdrop, .unknown_webkit] {
						mut mask := PseudoCandidateMask{}
						found := cache.find_pseudo_candidate_and_common_mask(element, queried, mut mask)
						assert found == cache.has_candidate_rule_for_pseudo_element(batch_candidate_abstract(element, queried), queried)
						if !found {
							for next in [PseudoElement.before, .after, .selection, .first_letter,
								.marker, .backdrop, .unknown_webkit] {
								actual := mask.bits & pseudo_candidate_bit(next) != 0 || cache.has_direct_pseudo_candidate(next)
								assert actual == cache.has_candidate_rule_for_pseudo_element(batch_candidate_abstract(element, next), next)
							}
						}
					}
				}
			}
		}
	}
}

fn test_batched_pseudo_candidate_union_observes_mutable_rules_layers_and_shadow_scopes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(element.as_node())!
	element.set_attribute_value('class', 'target')
	mut scope := css_style_scope_for_shadow_root(shadow)
	scope.build_rule_cache_if_needed()
	scope.author_rule_cache = RuleCaches.new()
	scope.user_rule_cache = RuleCaches.new()
	scope.user_agent_rule_cache = RuleCaches.new()
	for origin in [CascadeOrigin.author, .user, .user_agent] {
		mut cache := scope.rule_cache_for_cascade_origin(origin, none)?
		mut rule := batch_candidate_rule(PseudoElement.after)
		cache.rules_by_class['target'] = [rule, rule]
		assert batch_scope_candidate(scope, element, .after)
		rule.pseudo_element = PseudoElement.selection
		assert !batch_scope_candidate(scope, element, .after)
		assert batch_scope_candidate(scope, element, .selection)
		cache.rules_by_class['target'] = []&MatchingRule{}
	}
	mut author := scope.author_rule_caches()?
	mut layer := RuleCache.new()
	layer.other_rules = [batch_candidate_rule(PseudoElement.first_letter)]
	author.by_layer['layer'] = layer
	assert batch_scope_candidate(scope, element, .first_letter)
	layer.other_rules = []&MatchingRule{}
	assert !batch_scope_candidate(scope, element, .first_letter)
}

fn test_batched_pseudo_queries_expire_before_cascade_work_can_change_rules_and_attributes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	element.set_attribute_value('class', 'first')
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	scope.author_rule_cache = RuleCaches.new()
	scope.user_rule_cache = RuleCaches.new()
	scope.user_agent_rule_cache = RuleCaches.new()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none)?
	cache.rules_by_class['first'] = [batch_candidate_rule(PseudoElement.after)]
	mut batch := PseudoCandidateBatch{}
	assert !batch.has_candidate(scope, batch_candidate_abstract(element, .before), .before)
	assert batch.has_candidate(scope, batch_candidate_abstract(element, .after), .after)
	// A positive query can compute a style, load fonts and run a checkpoint.
	// Simulate its changes before the next query; no old mask may survive it.
	element.set_attribute_value('class', 'second')
	cache.rules_by_class['second'] = [batch_candidate_rule(PseudoElement.selection)]
	gc_collect()
	assert batch.has_candidate(scope, batch_candidate_abstract(element, .selection), .selection)
	cache.rules_by_class['second'] = []&MatchingRule{}
	assert !batch.has_candidate(scope, batch_candidate_abstract(element, .first_letter), .first_letter)
}

fn test_empty_pseudo_candidate_batches_do_not_allocate_query_vectors() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	abstract := batch_candidate_abstract(element, .unknown_webkit)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		mut batch := PseudoCandidateBatch{}
		for pseudo in [PseudoElement.unknown_webkit, .unknown, .known_pseudo_element_count]! {
			assert !batch.has_candidate(scope, abstract, pseudo)
		}
	}
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
}

fn test_positive_dedicated_pseudo_query_does_not_publish_an_incomplete_common_mask() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	element.set_attribute_value('class', 'target')
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	scope.author_rule_cache = RuleCaches.new()
	scope.user_rule_cache = RuleCaches.new()
	scope.user_agent_rule_cache = RuleCaches.new()
	mut cache := scope.rule_cache_for_cascade_origin(.author, none)?
	cache.rules_by_pseudo_element[.before] = [batch_candidate_rule(PseudoElement.before)]
	cache.rules_by_class['target'] = [batch_candidate_rule(PseudoElement.after)]
	mut batch := PseudoCandidateBatch{}
	assert batch.has_candidate(scope, batch_candidate_abstract(element, .before), .before)
	// Cascading the admitted ::before can change later candidates. The first
	// early exit did not inspect the class bucket and cannot cache its absence.
	cache.rules_by_class['target'] = [batch_candidate_rule(PseudoElement.selection)]
	assert !batch.has_candidate(scope, batch_candidate_abstract(element, .after), .after)
	assert batch.has_candidate(scope, batch_candidate_abstract(element, .selection), .selection)
}
