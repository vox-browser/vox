module css

import dom
import html

fn batch_pseudo_dom_target(pseudo PseudoElement) dom.PseudoElement {
	return match pseudo {
		.before { .before }
		.after { .after }
		.selection { .selection }
		.first_letter { .first_letter }
		.backdrop { .backdrop }
		else { .marker }
	}
}

fn batch_pseudo_assert_oracle(cache &RuleCache, element &dom.Element) {
	mut candidates := PseudoElementCandidates{}
	cache.collect_pseudo_candidates(element, mut candidates)
	for pseudo in [PseudoElement.before, .after, .selection, .first_letter, .backdrop, .marker]! {
		abstract := dom.AbstractElement.new(element, batch_pseudo_dom_target(pseudo))
		assert candidates.contains(pseudo) == cache.has_candidate_rule_for_pseudo_element(abstract, pseudo)
	}
}

fn batch_pseudo_rule(pseudo ?PseudoElement) &MatchingRule {
	selector := parse_selector_with_parser('div::before', map[string]bool{}) or { panic('invalid fixture selector') }
	return &MatchingRule{selector: selector.selectors[0], pseudo_element: pseudo}
}

fn test_batched_pseudo_candidates_match_each_bucket_and_current_mutable_rule_hint() {
	document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element('html') or { panic(err) }
	mut element := document.create_element('div') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(element.as_node()) or { panic(err) }
	for target in [root, element] {
		mut mutable := target
		mutable.set_attribute_value('class', 'CaRD')
		mutable.set_attribute_value('id', 'TARGET')
		mutable.set_attribute_value('data-mode', 'active')
		for fold in [false, true] {
			for slot in 0 .. 7 {
				mut cache := RuleCache.new()
				cache.fold_id_and_class_name_case = fold
				mut rule := batch_pseudo_rule(PseudoElement.before)
				rules := [batch_pseudo_rule(none), rule, rule]
				match slot {
					0 { cache.rules_by_class[if fold { 'card' } else { 'CaRD' }] = rules }
					1 { cache.rules_by_id[if fold { 'target' } else { 'TARGET' }] = rules }
					2 { cache.rules_by_tag_name[target.lowercased_local_name()] = rules }
					3 { cache.rules_by_pseudo_element[.before] = rules }
					4 { cache.root_rules = rules }
					5 { cache.rules_by_attribute_name['data-mode'] = rules }
					else { cache.other_rules = rules }
				}
				batch_pseudo_assert_oracle(cache, target)
				rule.pseudo_element = PseudoElement.after
				batch_pseudo_assert_oracle(cache, target)
				rule.pseudo_element = none
				batch_pseudo_assert_oracle(cache, target)
				rule.pseudo_element = PseudoElement.selection
				gc_collect()
				batch_pseudo_assert_oracle(cache, target)
			}
		}
	}
}

fn test_batched_pseudo_candidates_keep_layers_origins_and_invalidated_scope_identity() {
	mut document := html.parse_document('<!doctype html><style>@layer first { #target::before { content:"first" } } #target::after { content:"last" }</style><div id="target">text</div>')
	element := document.get_element_by_id('target') or { panic('target') }
	mut scope := css_style_scope_for_document(document)
	before := scope.pseudo_element_candidates(element)
	assert before.contains(.before) && before.contains(.after)
	assert before.is_current(scope)
	for pseudo in [PseudoElement.before, .after, .selection, .first_letter, .backdrop, .marker]! {
		assert before.contains(pseudo) == scope.has_candidate_rule_for_pseudo_element(
			dom.AbstractElement.new(element, batch_pseudo_dom_target(pseudo)), pseudo)
	}
	scope.invalidate_rule_cache()
	assert !before.is_current(scope)
	after := scope.pseudo_element_candidates(element)
	assert after.is_current(scope)
	assert before.bits == after.bits
	// Directly mutable layer records are inspected afresh on each collection.
	mut author := scope.author_rule_caches() or { panic('author') }
	mut layer := RuleCache.new()
	layer.other_rules = [batch_pseudo_rule(PseudoElement.selection)]
	author.by_layer['manual'] = layer
	assert scope.pseudo_element_candidates(element).contains(.selection)
	layer.other_rules = []&MatchingRule{}
	assert !scope.pseudo_element_candidates(element).contains(.selection)
}

fn test_batched_pseudo_candidates_keep_real_generated_styles_and_live_cssom() {
	mut document := html.parse_document('<!doctype html><style id="rules">#target::before {content:"first"; color:red} #target::after {content:"last"; color:blue}</style><div id="target">text</div>')
	document.set_browsing_context(&dom.BrowsingContext{})
	_ = css_style_computer_for(document)
	element := document.get_element_by_id('target') or { panic('target') }
	document.update_style()
	for pseudo in [dom.PseudoElement.before, .after]! {
		assert dom.AbstractElement.new(element, pseudo).computed_properties() != none
	}
	owner := document.get_element_by_id('rules') or { panic('rules') }
	mut sheet := style_sheet_for_owner_node(document, owner) or { panic('sheet') }
	sheet.delete_rule(0) or { panic(err) }
	document.update_style()
	assert dom.AbstractElement.new(element, dom.PseudoElement.before).computed_properties() == none
	assert dom.AbstractElement.new(element, dom.PseudoElement.after).computed_properties() != none
	sheet.insert_rule('#target::first-letter {color:green}', 0) or { panic(err) }
	document.update_style()
	scope := css_style_scope_for_document(document)
	assert scope.pseudo_element_candidates(element).contains(.first_letter)
}
fn test_batched_pseudo_candidates_keep_shadow_scopes_and_each_origin() {
	document := dom.Document.create(dom.url_about_blank())
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open}) or { panic(err) }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(element.as_node()) or { panic(err) }
	scope := css_style_scope_for_shadow_root(shadow)
	scope.build_rule_cache_if_needed()
	for origin in [CascadeOrigin.author, .user, .user_agent]! {
		mut cache := scope.rule_cache_for_cascade_origin(origin, none) or { panic('cache') }
		original := cache.other_rules
		cache.other_rules = [batch_pseudo_rule(PseudoElement.selection)]
		with_rule := scope.pseudo_element_candidates(element)
		assert with_rule.contains(.selection)
		for pseudo in [PseudoElement.before, .after, .selection, .first_letter, .backdrop, .marker]! {
			assert with_rule.contains(pseudo) == scope.has_candidate_rule_for_pseudo_element(
				dom.AbstractElement.new(element, batch_pseudo_dom_target(pseudo)), pseudo)
		}
		cache.other_rules = original
		assert !scope.pseudo_element_candidates(element).contains(.selection)
	}
}
