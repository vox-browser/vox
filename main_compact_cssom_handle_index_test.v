module main

import css
import dom
import x.json2

fn cssom_index_binding() &CompactElementQueryBinding {
	return &CompactElementQueryBinding{
		document: dom.Document.create(dom.url_about_blank())
		runtime: unsafe { nil }
	}
}

fn cssom_index_rule_id(value json2.Any) string {
	return value.as_map()['id'].str()
}

fn test_cssom_handle_index_preserves_distinct_rules_and_live_type_metadata() {
	mut binding := cssom_index_binding()
	mut rules := []&css.CSSRule{}
	mut keys := []string{}
	for _ in 0 .. 512 {
		rule := css.CSSRule.create(.style)
		rules << rule
		keys << cssom_index_rule_id(binding.rule_key(rule))
	}
	assert binding.css_rules.len == 512
	for i := rules.len - 1; i >= 0; i-- {
		assert cssom_index_rule_id(binding.rule_key(rules[i])) == keys[i]
	}
	mut changed := rules[257]
	changed.type_ = .media
	state := binding.rule_key(changed).as_map()
	assert state['id'].str() == keys[257]
	assert state['type'].int() == int(changed.type_for_bindings())
	assert binding.next_key == 512
}

fn test_cssom_handle_index_checks_forward_ownership_before_reusing_keys() {
	mut binding := cssom_index_binding()
	first := css.CSSRule.create(.style)
	other := css.CSSRule.create(.media)
	old := cssom_index_rule_id(binding.rule_key(first))
	binding.css_rules[old] = other
	new_key := cssom_index_rule_id(binding.rule_key(first))
	assert new_key != old
	assert cssom_index_rule_id(binding.rule_key(other)) == old
	assert voidptr(binding.css_rules[new_key] or { panic('missing rule') }) == voidptr(first)
	binding.css_rules.clear()
	assert cssom_index_rule_id(binding.rule_key(first)) != new_key
}

fn test_cssom_sheet_and_list_indexes_recover_existing_and_rebound_handles() {
	mut binding := cssom_index_binding()
	list := css.CSSRuleList.create_empty()
	other_list := css.CSSRuleList.create_empty()
	sheet := css.CSSStyleSheet.create(list, css.MediaList.create_empty(), none)
	other_sheet := css.CSSStyleSheet.create(other_list, css.MediaList.create_empty(), none)
	binding.style_sheets['existing-sheet'] = sheet
	binding.css_rule_lists['existing-list'] = list
	assert binding.sheet_key(sheet) == 'existing-sheet'
	assert binding.sheet_key(sheet) == 'existing-sheet'
	assert binding.rule_list_key(list) == 'existing-list'
	assert binding.rule_list_key(list) == 'existing-list'
	binding.style_sheets['existing-sheet'] = other_sheet
	binding.css_rule_lists['existing-list'] = other_list
	sheet_key := binding.sheet_key(sheet)
	list_key := binding.rule_list_key(list)
	assert sheet_key != 'existing-sheet'
	assert list_key != 'existing-list'
	assert binding.sheet_key(other_sheet) == 'existing-sheet'
	assert binding.rule_list_key(other_list) == 'existing-list'
	binding.style_sheets.clear()
	binding.css_rule_lists.clear()
	assert binding.sheet_key(sheet) != sheet_key
	assert binding.rule_list_key(list) != list_key
}

fn test_cssom_handle_indexes_are_binding_local_and_keep_detached_rules() {
	mut first := cssom_index_binding()
	mut second := cssom_index_binding()
	second.next_key = 19
	rule := css.CSSRule.create(.style)
	mut list := css.CSSRuleList.create([rule])
	key := cssom_index_rule_id(first.rule_key(rule))
	other_key := cssom_index_rule_id(second.rule_key(rule))
	assert key != other_key
	list.set_parent_style_sheet(none)
	gc_collect()
	assert cssom_index_rule_id(first.rule_key(rule)) == key
	assert cssom_index_rule_id(second.rule_key(rule)) == other_key
	assert first.css_rules.len == 1
	assert second.css_rules.len == 1
}
