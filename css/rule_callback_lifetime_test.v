module css

import dom

#include "rule_callback_lifetime_test.h"
$if gcboehm ? {
	fn C.vox_css_rule_lifetime_watch_owner(index u32, owner voidptr)
	fn C.vox_css_rule_lifetime_owners_alive() u32
	fn C.vox_css_rule_lifetime_collect(depth u32)
	fn C.vox_css_rule_lifetime_run_worker(work fn ())
}
@[noinline]
fn css_rule_lifetime_build_styled_document() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/styled-owner' })
	target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut node := document.as_node()
	node.append_child(target.as_node()) or { panic(err) }
	mut sheet :=
		parse_css_stylesheet_with_parser('div, .shared {color:red} span {color:blue} @keyframes pulse {from{opacity:0}to{opacity:1}} @function --retained() {result:red;}', none)
	sheet.add_owning_document_or_shadow_root(node)
	holder := css_author_style_sheets_for(document)
	unsafe { holder.sheets << sheet }
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache()
	assert scope.has_valid_rule_cache()
	assert (scope.author_rule_cache or { panic('missing author cache') }).main.rules_by_tag_name['div'].len == 1
	cache := (scope.author_rule_cache or { panic('missing author cache') }).main
	assert cache.rules_by_tag_name['div'][0].rule_index == 0
	assert cache.rules_by_class['shared'][0].rule_index == 0
	assert cache.rules_by_tag_name['span'][0].rule_index == 1
	assert cache.rules_by_tag_name['span'][0].style_sheet_index == 0
	assert 'pulse' in cache.rules_by_animation_keyframes
	assert (scope.rule_cache or { panic('missing cache') }).function_rules_by_name['--retained'].len == 1
	$if gcboehm ? {
		C.vox_css_rule_lifetime_watch_owner(0, voidptr(document))
		C.vox_css_rule_lifetime_watch_owner(1, voidptr(scope))
	}
	document.finalize()
}

fn test_styled_document_rule_cache_has_no_temporary_callback_owner() {
	$if gcboehm ? {
		C.vox_css_rule_lifetime_run_worker(css_rule_lifetime_build_styled_document)
		C.vox_css_rule_lifetime_collect(8)
		C.vox_css_rule_lifetime_collect(8)
		assert C.vox_css_rule_lifetime_owners_alive() == 0
	} $else {
		css_rule_lifetime_build_styled_document()
	}
}

struct EffectiveRuleLifetimeLog {
mut:
	rules []&CSSRule
}

fn rule_lifetime_record(context voidptr, rule &CSSRule) {
	mut log := unsafe { &EffectiveRuleLifetimeLog(context) }
	log.rules << rule
}

__global rule_lifetime_legacy_log &EffectiveRuleLifetimeLog

fn rule_lifetime_legacy_record(rule &CSSRule) {
	rule_lifetime_legacy_log.rules << rule
}

fn test_context_rule_traversal_keeps_import_media_container_and_postorder_semantics() {
	first := CSSRule.create(.style)
	mut imported := parse_css_stylesheet_with_parser('', none)
	imported.rules.set_rules([first])
	mut import_rule := CSSRule.create(.import_rule)
	import_rule.loaded_style_sheet = imported
	inside := CSSRule.create(.nested_declarations)
	media := CSSRule.create_grouping(.media, CSSRuleList.create([inside]))
	hidden := CSSRule.create(.style)
	// A supports rule without a matching Supports object is ineffective.
	inactive := CSSRule.create_grouping(.supports, CSSRuleList.create([hidden]))
	container_child := CSSRule.create(.style)
	container := CSSRule.create_grouping(.container_rule, CSSRuleList.create([
		container_child,
	]))
	keyframes := CSSRule.create(.keyframes)
	mut sheet := parse_css_stylesheet_with_parser('', none)
	sheet.rules.set_rules([import_rule, media, inactive, container, keyframes])
	preorder := [import_rule, first, media, inside, inactive, container, container_child, keyframes]
	postorder := [first, import_rule, inside, media, inactive, container_child, container, keyframes]
	for order, expected in {
		TraversalOrder.preorder:  preorder
		TraversalOrder.postorder: postorder
	} {
		log := &EffectiveRuleLifetimeLog{}
		sheet.for_each_effective_rule_with_context(order, voidptr(log), rule_lifetime_record)
		assert log.rules.len == expected.len
		for index, rule in expected {
			assert voidptr(log.rules[index]) == voidptr(rule)
		}
		rule_lifetime_legacy_log = &EffectiveRuleLifetimeLog{}
		sheet.for_each_effective_rule(order, rule_lifetime_legacy_record)
		assert rule_lifetime_legacy_log.rules.len == expected.len
		for index, rule in expected {
			assert voidptr(rule_lifetime_legacy_log.rules[index]) == voidptr(rule)
		}
	}
	rule_lifetime_legacy_log = &EffectiveRuleLifetimeLog{}
	sheet.for_each_effective_style_producing_rule(rule_lifetime_legacy_record)
	assert rule_lifetime_legacy_log.rules.len == 3
	assert voidptr(rule_lifetime_legacy_log.rules[0]) == voidptr(first)
	assert voidptr(rule_lifetime_legacy_log.rules[1]) == voidptr(inside)
	assert voidptr(rule_lifetime_legacy_log.rules[2]) == voidptr(container_child)
	rule_lifetime_legacy_log = &EffectiveRuleLifetimeLog{}
	sheet.for_each_effective_keyframes_at_rule(rule_lifetime_legacy_record)
	assert rule_lifetime_legacy_log.rules.len == 1
	assert voidptr(rule_lifetime_legacy_log.rules[0]) == voidptr(keyframes)
	rule_lifetime_legacy_log = unsafe { nil }
}

struct EffectiveRuleMutationState {
	group    &CSSRule
	appended &CSSRule
mut:
	log     []&CSSRule
	mutated bool
}

fn rule_lifetime_mutate_children(context voidptr, rule &CSSRule) {
	mut state := unsafe { &EffectiveRuleMutationState(context) }
	state.log << rule
	if voidptr(rule) == voidptr(state.group) && !state.mutated {
		state.mutated = true
		mut list := state.group.rules or { panic('missing group child list') }
		list.rules << state.appended
	}
}

fn test_context_rule_traversal_reads_children_after_preorder_callback() {
	for order in [TraversalOrder.preorder, .postorder] {
		first := CSSRule.create(.style)
		appended := CSSRule.create(.style)
		group := CSSRule.create_grouping(.media, CSSRuleList.create([first]))
		mut sheet := parse_css_stylesheet_with_parser('', none)
		sheet.rules.set_rules([group])
		state := &EffectiveRuleMutationState{
			group:    group
			appended: appended
		}
		sheet.for_each_effective_rule_with_context(order, voidptr(state),
			rule_lifetime_mutate_children)
		assert state.mutated
		if order == .preorder {
			assert state.log.len == 3
			assert voidptr(state.log[0]) == voidptr(group)
			assert voidptr(state.log[1]) == voidptr(first)
			assert voidptr(state.log[2]) == voidptr(appended)
		} else {
			assert state.log.len == 2
			assert voidptr(state.log[0]) == voidptr(first)
			assert voidptr(state.log[1]) == voidptr(group)
		}
	}
}
