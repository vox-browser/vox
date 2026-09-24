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
