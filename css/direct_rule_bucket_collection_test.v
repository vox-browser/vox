module css

import dom

// These fixtures inject synthetic author rules. Give each scope its own cache
// instead of modifying the immutable UA-only template shared by empty scopes.

fn cached_rule_fixture_rule(index uint, text string) &MatchingRule {
 return &MatchingRule{rule_index: index, selector: selector_from_text(text), cascade_origin: .author}
}
fn cached_rule_fixture_indices(rules []ScopedMatchingRule) []uint {
 mut indices := []uint{}
 for rule in rules { indices << rule.rule.rule_index }
 return indices
}

fn test_direct_cached_rules_keep_bucket_order_empty_entries_and_attempt_metadata() {
 mut document := dom.Document.create(dom.url_about_blank())
 mut root := document.create_element('html')!
 mut document_node := unsafe { &dom.Node(document) }
 document_node.append_child(root.as_node())!
 mut target := document.create_element('div')!
 target.set_attribute_value('class', 'empty card missing')
 target.set_attribute_value('id', 'target')
 target.set_attribute_value('title', 'value')
 mut root_node := root.as_node()
 root_node.append_child(target.as_node())!
 mut scope := css_style_scope_for_document(document)
 scope.populate_new_rule_cache()
 mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('cache absent') }
 cache.rules_by_class['empty'] = []&MatchingRule{}
 cache.rules_by_class['card'] = [cached_rule_fixture_rule(1, '.card'), cached_rule_fixture_rule(9, '.card:hover')]
 cache.rules_by_id['target'] = [cached_rule_fixture_rule(2, '#target')]
 cache.rules_by_tag_name['div'] = [cached_rule_fixture_rule(3, 'div')]
 cache.rules_by_attribute_name['title'] = [cached_rule_fixture_rule(4, '[title]')]
 cache.other_rules = [cached_rule_fixture_rule(5, '*'), cached_rule_fixture_rule(8, '.absent')]
 cache.root_rules = [cached_rule_fixture_rule(7, ':root')]
 before := cached_rule_fixture_rule(6, '*::before')
 mut before_rule := unsafe { &MatchingRule(before) }
 before_rule.contains_pseudo_element = true
 before_rule.pseudo_element = PseudoElement.before
 cache.rules_by_pseudo_element[.before] = [before]
 // These are collected by their separate scope paths, not ordinary buckets.
 cache.slotted_rules = [cached_rule_fixture_rule(20, '*')]
 cache.part_rules = [cached_rule_fixture_rule(21, '*')]
 computer := StyleComputer.new(document)
 mut attempted := PseudoClassBitmap{}
 actual := style_computer_collect_matching_rules_in_scope(computer, dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
 assert cached_rule_fixture_indices(actual) == [uint(1), 2, 3, 4, 5]
 assert attempted.get(.hover)
 assert voidptr(actual[0].rule) == voidptr(cache.rules_by_class['card'][0])
 assert cached_rule_fixture_indices(style_computer_collect_matching_rules_in_scope(computer, dom.AbstractElement.new(target, dom.PseudoElement.before), .author, mut attempted, none, scope)) == [uint(6)]
 assert cached_rule_fixture_indices(style_computer_collect_matching_rules_in_scope(computer, dom.AbstractElement.new(root, none), .author, mut attempted, none, scope)) == [uint(7), 5]
 gc_collect()
 assert cached_rule_fixture_indices(actual) == [uint(1), 2, 3, 4, 5]
 assert cache.rules_by_class['empty'].len == 0
 assert 'missing' !in cache.rules_by_class
}

fn test_direct_cached_rules_preserve_duplicate_rule_identity_and_quirks_folding() {
 document := dom.Document.create(dom.url_about_blank())
 mut target := document.create_element('div')!
 target.set_attribute_value('class', 'Mixed')
 target.set_attribute_value('id', 'TARGET')
 mut scope := css_style_scope_for_document(document)
 scope.populate_new_rule_cache()
 mut cache := scope.rule_cache_for_cascade_origin(.author, none) or { panic('cache absent') }
 cache.fold_id_and_class_name_case = true
 shared_rule := cached_rule_fixture_rule(3, '*')
 cache.rules_by_class['mixed'] = [shared_rule]
 cache.rules_by_id['target'] = [shared_rule]
 computer := StyleComputer.new(document)
 mut attempted := PseudoClassBitmap{}
 actual := style_computer_collect_matching_rules_in_scope(computer, dom.AbstractElement.new(target, none), .author, mut attempted, none, scope)
 assert cached_rule_fixture_indices(actual) == [uint(3), 3]
 assert voidptr(actual[0].rule) == voidptr(actual[1].rule)
 assert voidptr(actual[0].rule) == voidptr(shared_rule)
}

fn test_direct_cached_rules_include_own_shadow_host_scope_with_its_identity() {
 mut document := dom.Document.create(dom.url_about_blank())
 mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
 mut document_node := unsafe { &dom.Node(document) }
 document_node.append_child(root.as_node())!
 mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
 host.set_attribute_value('class', 'host')
 mut root_node := root.as_node()
 root_node.append_child(host.as_node())!
 shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
 mut scope := css_style_scope_for_document(document)
 scope.populate_new_rule_cache()
 mut own_scope := css_style_scope_for_shadow_root(shadow)
 own_scope.populate_new_rule_cache()
 mut primary := scope.rule_cache_for_cascade_origin(.author, none) or { panic('primary cache absent') }
 mut own := own_scope.rule_cache_for_cascade_origin(.author, none) or { panic('own cache absent') }
 primary.rules_by_class['host'] = [cached_rule_fixture_rule(10, '.host')]
 own.other_rules = [cached_rule_fixture_rule(11, ':host')]
 computer := StyleComputer.new(document)
 mut attempted := PseudoClassBitmap{}
 actual := style_computer_collect_matching_rules_in_scope(computer, dom.AbstractElement.new(host, none), .author, mut attempted, none, scope)
 assert cached_rule_fixture_indices(actual) == [uint(10), 11]
 assert actual[0].shadow_root == none
 actual_shadow := actual[1].shadow_root or { panic('missing own scope identity') }
 assert voidptr(actual_shadow) == voidptr(shadow)
 assert voidptr(actual[1].rule) == voidptr(own.other_rules[0])
}
