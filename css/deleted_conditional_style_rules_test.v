module css

import dom

fn deleted_conditional_uses_broad_control() bool {
	return retain_broad_conditional_rule_deletion || disable_deleted_style_rule_invalidation
}

fn test_deleted_conditional_rules_restore_cascade_and_inheritance_without_restyling_bystanders() {
	for group in ['@media all', '@supports (display:block)', '@media all {@supports (display:block)'] {
		closing := if group.ends_with(')') && group.contains('{') { '}' } else { '' }
		mut document, mut sheet, target, bystander := deleted_rule_fixture('div{color:blue}${group}{.target{color:red}}${closing}')
		defer { document.finalize() }
		child := deleted_rule_element(document, target.as_node(), 'span')
		document.update_style()
		assert deleted_rule_color(child) == 'rgb(255, 0, 0)'
		previous := bystander.el_computed_properties()?
		removed := sheet.rules.item(1)?
		sheet.delete_rule(1)!
		assert removed.parent_style_sheet == none
		assert document.needs_full_style_update() == deleted_conditional_uses_broad_control()
		document.update_style()
		assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
		assert deleted_rule_color(child) == 'rgb(0, 0, 255)'
		assert (voidptr(bystander.el_computed_properties()?) == voidptr(previous)) == !deleted_conditional_uses_broad_control()
	}
}

fn test_deleted_conditional_rules_preserve_pending_invalidations_and_future_media_changes() {
	mut document, mut sheet, target, bystander := deleted_rule_fixture('div{color:blue}@media (max-width:700px){.target{color:red}}')
	defer { document.finalize() }
	mut unrelated := bystander.as_node()
	unrelated.set_needs_style_update_internal(true)
	sheet.delete_rule(1)!
	assert unrelated.needs_style_update()
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
	document.set_viewport_rect(dom.Rect{width:600,height:600})
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
}

fn test_deleted_conditional_rules_preserve_namespace_context() {
	mut document, mut sheet, target, bystander := deleted_rule_fixture('@namespace h "http://www.w3.org/1999/xhtml"; h|div{color:blue} @media all{h|*.target{color:red}}')
	defer { document.finalize() }
	assert deleted_rule_color(target) == 'rgb(255, 0, 0)'
	previous := bystander.el_computed_properties()?
	sheet.delete_rule(2)!
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
	assert (voidptr(bystander.el_computed_properties()?) == voidptr(previous)) == !deleted_conditional_uses_broad_control()
}

fn test_deleted_conditional_rules_keep_global_nested_and_universal_fallbacks() {
	for source in ['@media all{@font-face{font-family:Test;src:url(test.woff2)}}',
		'@supports (display:block){@layer L{.target{color:red}}}',
		'@media all{.target{color:red;& span{color:lime}}}', '@media all{*{color:red}}'] {
		mut document, mut sheet, _, _ := deleted_rule_fixture(source)
		defer { document.finalize() }
		sheet.delete_rule(0)!
		assert document.needs_full_style_update()
		document.update_style()
	}
}

fn test_deleted_conditional_rules_recheck_remaining_media_after_viewport_changes() {
	mut document, mut sheet, target, bystander := deleted_rule_fixture('div{color:blue}@media (min-width:900px){.other{color:lime}}@media all{.target{color:red}}')
	defer { document.finalize() }
	mut other := unsafe { &dom.Element(bystander) }
	other.set_attribute_value('class','other')
	document.update_style()
	document.set_viewport_rect(dom.Rect{width:1000,height:600})
	sheet.delete_rule(2)!
	assert document.needs_full_style_update()
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
	assert deleted_rule_color(bystander) == 'rgb(0, 255, 0)'
}

fn test_deleted_conditional_rules_invalidate_formerly_active_subjects_with_stale_media_state() {
	mut document, mut sheet, target, _ := deleted_rule_fixture('div{color:blue}@media (min-width:700px){.target{color:red}}')
	defer { document.finalize() }
	assert deleted_rule_color(target) == 'rgb(255, 0, 0)'
	document.set_viewport_rect(dom.Rect{width:600,height:600})
	sheet.delete_rule(1)!
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
}

fn test_deleted_conditional_shadow_rules_update_hosts_and_assigned_node_inheritance() {
	mut document, _, host, _ := deleted_rule_fixture('div{color:blue}')
	defer { document.finalize() }
	mut mutable_host := unsafe { &dom.Element(host) }
	shadow := mutable_host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	shadow_node := unsafe { &dom.Node(shadow) }
	style := deleted_rule_element(document, shadow_node, 'style')
	slot := deleted_rule_element(document, shadow_node, 'slot')
	child := deleted_rule_element(document, host.as_node(), 'span')
	mut sheet := parse_css_stylesheet_with_parser('@media all{:host{color:red}slot{color:lime}}', none)
	sheet.set_owner_node(style)
	sheet.add_owning_document_or_shadow_root(shadow_node)
	mut scope := css_style_scope_for_shadow_root(shadow)
	scope.author_style_sheets << sheet
	document.set_needs_full_style_update(true)
	document.update_style()
	assert deleted_rule_color(host) == 'rgb(255, 0, 0)'
	assert deleted_rule_color(slot) == 'rgb(0, 255, 0)'
	assert deleted_rule_color(child) == 'rgb(0, 255, 0)'
	sheet.delete_rule(0)!
	document.update_style()
	assert deleted_rule_color(host) == 'rgb(0, 0, 255)'
	assert deleted_rule_color(slot) == 'rgb(0, 0, 255)'
	assert deleted_rule_color(child) == 'rgb(0, 0, 255)'
}
