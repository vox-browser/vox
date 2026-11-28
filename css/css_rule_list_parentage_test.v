module css

fn test_rule_list_set_owner_rule_updates_existing_children() {
	child := CSSRule.create(.style)
	mut children := CSSRuleList.create([child])
	owner := CSSRule.create(.media)

	children.set_owner_rule(owner)

	assert child.parent_rule? == owner
}

fn test_rule_list_set_parent_style_sheet_updates_existing_children() {
	child := CSSRule.create(.style)
	mut rules := CSSRuleList.create([child])
	sheet := CSSStyleSheet.create(CSSRuleList.create_empty(), MediaList.create_empty(), none)

	rules.set_parent_style_sheet(sheet)
	assert rules.owner_style_sheet? == sheet
	assert child.parent_style_sheet? == sheet

	rules.set_parent_style_sheet(none)
	assert rules.owner_style_sheet == none
	assert child.parent_style_sheet == none
}

fn test_grouping_rule_parent_sheet_updates_child_rule_list() {
	child := CSSRule.create(.style)
	children := CSSRuleList.create([child])
	group := CSSRule.create_grouping(.media, children)
	sheet := CSSStyleSheet.create(CSSRuleList.create([group]), MediaList.create_empty(), none)

	assert children.owner_rule? == group
	assert children.owner_style_sheet? == sheet
	assert child.parent_rule? == group
	assert child.parent_style_sheet? == sheet
}

fn test_cross_origin_sheet_rejects_cssom_access_but_keeps_its_rules_for_styling() {
	mut sheet := CSSStyleSheet.create(CSSRuleList.create_empty(), MediaList.create_empty(), none)
	assert sheet.insert_rule('p { color: red; }', 0)! == 0
	assert sheet.checked_css_rules()!.length() == 1
	sheet.base.origin_clean = false
	if _ := sheet.checked_css_rules() {
		assert false
	} else {
		assert err.msg().starts_with('SecurityError:')
	}
	if _ := sheet.insert_rule('p { color: blue; }', 1) {
		assert false
	} else {
		assert err.msg().starts_with('SecurityError:')
	}
	if _ := sheet.delete_rule(0) {
		assert false
	} else {
		assert err.msg().starts_with('SecurityError:')
	}
	assert sheet.css_rules().length() == 1
}
