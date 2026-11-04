module css

import dom

fn test_empty_deleted_conditional_leaves_keep_computed_owners_and_detach_cssom_rules() {
	for group in ['@media all', '@supports (display:block)'] {
		mut document, mut sheet, target, bystander := deleted_rule_fixture('div{color:blue}${group}{div{}}')
		defer { document.finalize() }
		previous_target := target.el_computed_properties()?
		previous_bystander := bystander.el_computed_properties()?
		removed := sheet.rules.item(1)?
		leaf := removed.css_rules()?.item(0)?
		assert css_style_scope_for_document(document).has_valid_rule_cache()
		sheet.delete_rule(1)!
		assert removed.parent_style_sheet == none
		assert leaf.parent_style_sheet == none
		assert sheet.rules.length() == 1
		assert !css_style_scope_for_document(document).has_valid_rule_cache()
		document.update_style()
		assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
		assert (voidptr(target.el_computed_properties()?) == voidptr(previous_target)) == !retain_empty_deleted_conditional_targets
		assert (voidptr(bystander.el_computed_properties()?) == voidptr(previous_bystander)) == !retain_empty_deleted_conditional_targets
		mut detached := leaf.style()?
		detached.set_property('color','red','')!
		document.update_style()
		assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
	}
}

fn test_empty_deleted_conditional_universal_does_not_broaden_nonempty_sibling_invalidation() {
	mut document, mut sheet, target, bystander := deleted_rule_fixture('div{color:blue}@media all{*{} @supports(display:block){.target{color:red}}}')
	defer { document.finalize() }
	assert deleted_rule_color(target) == 'rgb(255, 0, 0)'
	previous := bystander.el_computed_properties()?
	sheet.delete_rule(1)!
	assert document.needs_full_style_update() == retain_empty_deleted_conditional_targets
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
	assert (voidptr(bystander.el_computed_properties()?) == voidptr(previous)) == !retain_empty_deleted_conditional_targets
}

fn test_empty_deleted_conditional_proof_preserves_custom_declarations_and_inheritance() {
	mut document, mut sheet, target, _ := deleted_rule_fixture('div{--tone:blue;color:var(--tone)} @media all{.target{--tone:red;--empty: ;}}')
	defer { document.finalize() }
	child := deleted_rule_element(document,target.as_node(),'span')
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(255, 0, 0)'
	assert deleted_rule_color(child) == 'rgb(255, 0, 0)'
	sheet.delete_rule(1)!
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
	assert deleted_rule_color(child) == 'rgb(0, 0, 255)'
}

fn test_empty_deleted_conditional_proof_materializes_deferred_declarations() {
	for source in ['@media all{div{unknown-property:x;width:invalid}}', '@media all{div{color:red}}', '@media all{div{--empty: ;}}'] {
		mut parser := RuleSelectorParser.create(ParsingParams{},source,'utf-8')
		parser.defer_style_declarations = true
		sheet := parser.parse_as_css_stylesheet('https://example.test/style.css',none)
		leaf := sheet.rules.item(0)?.css_rules()?.item(0)?
		declaration := leaf.declaration?
		assert declaration.deferred_declarations_ != none
		empty := source.contains('unknown-property')
		assert deleted_conditional_leaf_has_no_declarations(leaf) == (empty && !retain_empty_deleted_conditional_targets)
		if !retain_empty_deleted_conditional_targets {
			assert declaration.deferred_declarations_ == none
		}
		assert (leaf.style()?.length() == 0) == empty
	}
}

fn test_empty_deleted_conditional_leaf_preserves_pending_dirty_and_remaining_media_fallback() {
	mut document, mut sheet, target, bystander := deleted_rule_fixture('div{color:blue}@media(min-width:900px){.target{color:lime}}@media all{div{}}')
	defer { document.finalize() }
	mut pending := bystander.as_node()
	pending.set_needs_style_update_internal(true)
	document.set_viewport_rect(dom.Rect{width:1000,height:600})
	sheet.delete_rule(2)!
	assert pending.needs_style_update()
	assert document.needs_full_style_update()
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 255, 0)'
	assert deleted_rule_color(bystander) == 'rgb(0, 0, 255)'
}

fn test_empty_deleted_conditional_parent_does_not_skip_nested_style_or_global_effects() {
	for group in ['@media all{.target{& span{color:red}}}', '@media all{@layer retained{}}'] {
		mut document, mut sheet, _, _ := deleted_rule_fixture(group)
		defer { document.finalize() }
		assert !can_target_deleted_conditional_style_rule(sheet.rules.item(0)?)
		sheet.delete_rule(0)!
		assert document.needs_full_style_update()
		document.update_style()
	}
}
