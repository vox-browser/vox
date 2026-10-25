module css

import dom

fn pseudo_value_selector(text string) Selector {
 list := parse_selector_with_parser(text,map[string]bool{}) or {panic(text)}
 return list.selectors[0]
}
fn pseudo_value_element(document &dom.Document, namespace string) &dom.Element {
 return document.create_element_ns(namespace,'div') or {panic('invalid pseudo-element fixture')}
}
fn pseudo_value_single_result(computer &StyleComputer, selector Selector, element &dom.Element, pseudo dom.PseudoElement) []MatchingRuleCandidate {
 // Inconsistent legacy rule hints must not replace the selector's target accessor.
 rule := &MatchingRule{selector:selector cascade_origin:.author contains_pseudo_element:false pseudo_element:PseudoElement.after}
 mut output := []MatchingRuleCandidate{}
 style_scope_add_rules_to_run(computer,dom.AbstractElement.new(element,pseudo),[rule],none,none,none,mut output)
 return output
}
fn test_cached_target_type_filter_matches_public_accessor_and_chained_targets() {
 document := dom.Document.create(dom.url_about_blank())
 element := pseudo_value_element(document,'http://www.w3.org/1999/xhtml')
 computer := StyleComputer.new(document)
 mut selectors := [Selector{}]
 for text in ['*','.target','div:hover','div::before','div::after','::selection','::first-letter','::part(label)','::part(label)::before','::part(label)::selection','::slotted(span)','::placeholder'] {
  selectors << pseudo_value_selector(text)
 }
 for selector in selectors {
  for pseudo in [dom.PseudoElement.before,.after,.selection,.first_letter,.part,.slotted,.placeholder,.unknown_webkit] {
   mut expected := false
   if target := selector.target_pseudo_element() { expected = target.type_ == style_scope_pseudo_element_from_dom(pseudo) }
   actual := pseudo_value_single_result(computer,selector,element,pseudo)
   assert actual.len == if expected {1} else {0}
   if actual.len != 0 { assert actual[0].rule.selector.data_ == selector.data_ }
  }
 }
 assert pseudo_value_single_result(computer,pseudo_value_selector('::part(label)::before'),element,.before).len == 1
 assert pseudo_value_single_result(computer,pseudo_value_selector('::part(label)::before'),element,.part).len == 0
}
fn test_cached_target_type_filter_keeps_namespaces_shadow_relevance_and_base_path() {
 document := dom.Document.create(dom.url_about_blank())
 mut host := pseudo_value_element(document,'http://www.w3.org/1999/xhtml')
 shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open}) or {panic('invalid pseudo-element fixture')}
 html_element := pseudo_value_element(document,'http://www.w3.org/1999/xhtml')
 svg_element := pseudo_value_element(document,'http://www.w3.org/2000/svg')
 computer := StyleComputer.new(document)
 rules := [&MatchingRule{selector:pseudo_value_selector('div') cascade_origin:.author rule_index:1},
 &MatchingRule{selector:pseudo_value_selector('div::before') cascade_origin:.author rule_index:2},
 &MatchingRule{selector:pseudo_value_selector('div::after') cascade_origin:.user_agent rule_index:3},
 &MatchingRule{selector:pseudo_value_selector('::part(label)::before') cascade_origin:.author contains_part_pseudo_element:true rule_index:4},
 &MatchingRule{selector:pseudo_value_selector('*::before') cascade_origin:.author default_namespace:'http://www.w3.org/2000/svg' rule_index:5},
 &MatchingRule{selector:pseudo_value_selector('*::before') cascade_origin:.author default_namespace:'http://www.w3.org/1999/xhtml' rule_index:6}]
 for element in [html_element,svg_element] {
  for include_pseudo in [false,true] {
   abstract_element := if include_pseudo {dom.AbstractElement.new(element,dom.PseudoElement.before)} else {dom.AbstractElement.new(element,none)}
   for same_tree in [false,true] {
    mut actual := []MatchingRuleCandidate{}
    mut expected := []MatchingRuleCandidate{}
    if same_tree {
     style_scope_add_rules_to_run(computer,abstract_element,rules,shadow,shadow,none,mut actual)
     pseudo_value_filter_oracle(computer,abstract_element,rules,shadow,shadow,none,mut expected)
    } else {
     style_scope_add_rules_to_run(computer,abstract_element,rules,shadow,none,none,mut actual)
     pseudo_value_filter_oracle(computer,abstract_element,rules,shadow,none,none,mut expected)
    }
    assert actual == expected
   }
  }
 }
}
fn test_cached_target_type_filter_observes_retained_cache_edits_and_gc_ownership() {
 document := dom.Document.create(dom.url_about_blank())
 element := pseudo_value_element(document,'http://www.w3.org/1999/xhtml')
 computer := StyleComputer.new(document)
 selector := pseudo_value_selector('div::before')
 mut data := selector.data_
 data.pseudo_element = PseudoElementSelector{type_:.selection name:'retained β' ident_list:['label','中😀'] value_kind:.ident_list}
 for _ in 0 .. 3 {
  gc_collect()
  assert pseudo_value_single_result(computer,selector,element,.before).len == 0
  assert pseudo_value_single_result(computer,selector,element,.selection).len == 1
  target := selector.target_pseudo_element() or {panic('retained target absent')}
  assert target.name == 'retained β' && target.ident_list == ['label','中😀']
 }
 data.pseudo_element = none
 assert pseudo_value_single_result(computer,selector,element,.selection).len == 0
 assert selector.target_pseudo_element() == none
}

fn pseudo_value_filter_oracle(style_computer &StyleComputer, abstract_element dom.AbstractElement, rules []&MatchingRule, rule_root ?&dom.ShadowRoot, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []MatchingRuleCandidate) {
	element_namespace_uri := abstract_element.element().namespace_uri()
	if queried_pseudo_element := style_scope_pseudo_element_from_abstract_element(abstract_element) {
		for rule in rules {
			// Only selectors targeting the queried pseudo-element can match. This avoids
			// evaluating ordinary selectors and selectors for a different pseudo-element.
			// FIXME: Once exportparts can forward pseudo-elements as parts, a bare
			// ::part(name) rule may need to match a different pseudo-element type.
			target_pseudo_element := rule.selector.target_pseudo_element() or { continue }
			if target_pseudo_element.type_ != queried_pseudo_element {
				continue
			}
			if !style_scope_filter_namespace_rule(element_namespace_uri, rule) {
				continue
			}
			style_scope_add_rule_to_run(style_computer, abstract_element, rule, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
		}
	} else {
		for rule in rules {
			if (rule.slotted || rule.contains_part_pseudo_element || !rule.contains_pseudo_element) && style_scope_filter_namespace_rule(element_namespace_uri, rule) {
				style_scope_add_rule_to_run(style_computer, abstract_element, rule, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
			}
		}
	}
}
