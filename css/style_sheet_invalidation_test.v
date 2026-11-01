module css

import dom

const style_sheet_invalidation_html_namespace = 'http://www.w3.org/1999/xhtml'

fn style_sheet_invalidation_test_element(document &dom.Document, local_name string) &dom.Element {
	return document.create_element_ns(style_sheet_invalidation_html_namespace, local_name) or {
		panic(err)
	}
}

fn clear_style_sheet_invalidation_test_flags(nodes ...&dom.Node) {
	for node in nodes {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.set_needs_style_update_internal(false)
		mutable_node.set_child_needs_style_update(false)
		mutable_node.set_entire_subtree_needs_style_update(false)
	}
}

fn install_inline_style_sheet_for_invalidation_test(mut sheet CSSStyleSheet, owner &dom.Element, root &dom.Node) {
	sheet.set_owner_node(owner)
	sheet.add_owning_document_or_shadow_root(root)
	if shadow_root := root.as_shadow_root() {
		mut scope := css_style_scope_for_shadow_root(shadow_root)
		scope.author_style_sheets << sheet
	} else {
		holder := css_author_style_sheets_for(root.document())
		unsafe {
			holder.sheets << sheet
		}
	}
}

fn set_style_sheet_invalidation_test_animation_name(mut element dom.Element, pseudo_element ?dom.PseudoElement, name string) {
	mut computed := computed_properties_with_initial_values()
	value := parse_css_value_logic(.animation_name, name) or {
		panic('could not parse animation-name ${name}')
	}
	computed.set_property(.animation_name, dom_style_value_from_value_logic(value), .no, .no)
	mut abstract_element := dom.AbstractElement.new(element, pseudo_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(computed))
}

fn test_insert_rule_targets_matching_elements_in_inline_style_sheet() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'div')
	target.set_attribute_value('class', 'target')
	mut bystander := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	assert sheet.insert_rule('.target { color: red }', 0)! == 0
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	counters := document.style_invalidation_counters()
	assert counters.full_style_invalidations == 0
	assert counters.style_invalidations == 1
}

fn test_insert_rule_with_only_has_feature_invalidates_whole_tree() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node())
	document.set_needs_full_style_update(false)

	assert sheet.insert_rule(':has(.flag) { color: red }', 0)! == 0
	assert document.needs_full_style_update()
}

fn test_style_rule_declaration_mutation_keeps_and_uses_rule_cache() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'div')
	target.set_attribute_value('class', 'target')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(target.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('.target { color: red }', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	mut computer := StyleComputer.new(document)
	before := computer.compute_style(dom.AbstractElement.new(target, none))
	assert (before.property(.color, .no) or { panic('missing initial color') }).css_text == 'rgb(255, 0, 0)'
	assert scope.has_valid_rule_cache()

	style_rule := sheet.css_rules().item(0) or { panic('missing style rule') }
	mut declaration := unsafe { &CSSStyleProperties(style_rule.style() or { panic('missing declaration') }) }
	declaration.set_property('color', 'blue', '')!
	assert scope.has_valid_rule_cache()
	after := computer.compute_style(dom.AbstractElement.new(target, none))
	assert (after.property(.color, .no) or { panic('missing updated color') }).css_text == 'rgb(0, 0, 255)'
}

fn test_inserted_character_data_schedules_has_ancestor_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document, 'div:has(:empty) { color: red; }')
	parent := style_sheet_invalidation_test_element(document, 'div')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(parent.as_node()) or { panic(err) }
	mut scope := css_style_scope_for_document(document)
	assert scope.may_have_has_selectors()
	scope.clear_pending_has_invalidations()

	text := document.create_text_node('content').as_node()
	mut parent_node := parent.as_node()
	parent_node.append_child(text) or { panic(err) }
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 1
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has[0] == parent.as_node()
}

fn test_structural_has_invalidation_filters_unrelated_inserted_subtrees() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document, 'section:has(.flag) { color: red }')
	mut document_node := unsafe { &dom.Node(document) }
	mut subject := style_sheet_invalidation_test_element(document, 'section')
	document_node.append_child(subject.as_node()) or { panic(err) }
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	scope.clear_pending_has_invalidations()

	mut unrelated := style_sheet_invalidation_test_element(document, 'span')
	mut subject_node := subject.as_node()
	subject_node.append_child(unrelated.as_node()) or { panic(err) }
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 0

	mut matching_subtree := style_sheet_invalidation_test_element(document, 'div')
	mut flag := style_sheet_invalidation_test_element(document, 'span')
	flag.set_attribute_value('class', 'flag')
	mut matching_subtree_node := matching_subtree.as_node()
	matching_subtree_node.append_child(flag.as_node()) or { panic(err) }
	scope.clear_pending_has_invalidations()
	subject_node.append_child(matching_subtree.as_node()) or { panic(err) }
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 1
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has[0] == subject.as_node()
}

fn test_featureless_has_argument_keeps_structural_invalidation_conservative() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document, 'section:has(*) { color: red }')
	mut document_node := unsafe { &dom.Node(document) }
	mut subject := style_sheet_invalidation_test_element(document, 'section')
	document_node.append_child(subject.as_node()) or { panic(err) }
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	scope.clear_pending_has_invalidations()

	mut child := style_sheet_invalidation_test_element(document, 'span')
	mut subject_node := subject.as_node()
	subject_node.append_child(child.as_node()) or { panic(err) }
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 1
	features := scope.pending_has_invalidation_features[subject.as_node().unique_id().value()] or {
		panic('missing conservative child-list invalidation')
	}
	assert features.is_conservative
	assert features.may_affect_sibling_relationships
	assert features.may_affect_pseudo_classes

	mut second_child := style_sheet_invalidation_test_element(document, 'target-tag')
	subject_node.append_child(second_child.as_node()) or { panic(err) }
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 1
	coalesced_features := scope.pending_has_invalidation_features[subject.as_node().unique_id().value()] or {
		panic('missing coalesced child-list invalidation')
	}
	assert coalesced_features == features
}

fn test_has_descendant_fanout_ignores_rules_for_other_anchors() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	add_document_author_style_sheet(document, '.outer:has(.watched) .target { color: red } .other:has(.unrelated) { color: blue }')
	mut outer := style_sheet_invalidation_test_element(document, 'section')
	mut container := style_sheet_invalidation_test_element(document, 'div')
	mut watched := style_sheet_invalidation_test_element(document, 'span')
	mut target := style_sheet_invalidation_test_element(document, 'p')
	mut unrelated := style_sheet_invalidation_test_element(document, 'i')
	mut another_watched := style_sheet_invalidation_test_element(document, 'b')
	outer.set_attribute_value('class', 'outer')
	watched.set_attribute_value('class', 'watched')
	target.set_attribute_value('class', 'target')
	unrelated.set_attribute_value('class', 'unrelated')
	another_watched.set_attribute_value('class', 'watched')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(outer.as_node()) or { panic(err) }
	mut outer_node := outer.as_node()
	outer_node.append_child(container.as_node()) or { panic(err) }
	mut container_node := container.as_node()
	container_node.append_child(watched.as_node()) or { panic(err) }
	outer_node.append_child(target.as_node()) or { panic(err) }

	_ := css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	assert outer.affected_by_has_pseudo_class_in_non_subject_position
	assert container.in_has_scope
	mut scope := css_style_scope_for_document(document)
	mut invalidator := document.style_invalidator()
	assert invalidator.pending_invalidations.len == 0

	container_node.append_child(unrelated.as_node()) or { panic(err) }
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
	scope.invalidate_style_of_elements_affected_by_has()
	assert invalidator.pending_invalidations.len == 0

	container_node.append_child(another_watched.as_node()) or { panic(err) }
	assert scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
	scope.invalidate_style_of_elements_affected_by_has()
	assert invalidator.pending_invalidations.len > 0
}

fn test_has_sibling_scan_preserves_a_feature_filtered_anchor_skip() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	add_document_author_style_sheet(document, '.subgrid:has(+ .right) .target { color: red } .decoy:has(.unrelated) { color: blue }')
	mut parent := style_sheet_invalidation_test_element(document, 'section')
	mut subgrid := style_sheet_invalidation_test_element(document, 'div')
	mut right := style_sheet_invalidation_test_element(document, 'div')
	subgrid.set_attribute_value('class', 'subgrid')
	right.set_attribute_value('class', 'right')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(parent.as_node()) or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(subgrid.as_node()) or { panic(err) }
	parent_node.append_child(right.as_node()) or { panic(err) }
	// Reproduce the selector-involvement metadata established when this
	// non-subject :has() anchor matches a descendant selector.
	subgrid.affected_by_has_pseudo_class_in_non_subject_position = true
	subgrid.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator = true
	_ := css_style_computer_for(document)
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	mut invalidator := document.style_invalidator()
	scope.clear_pending_has_invalidations()
	invalidator.pending_invalidations.clear()
	clear_style_sheet_invalidation_test_flags(subgrid.as_node())

	scope.record_pending_has_invalidation_mutation_properties(subgrid.as_node(), [
		InvalidationProperty.class('unrelated'),
	])
	scope.invalidate_style_of_elements_affected_by_has()
	assert invalidator.pending_invalidations.len == 0
	assert !subgrid.needs_style_update()
}

fn test_user_agent_shadow_tree_mutations_use_document_style_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document, 'div:has(.flag) { color: blue }')
	mut document_node := unsafe { &dom.Node(document) }
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .closed }) or { panic(err) }
	mut mutable_shadow_root := unsafe { &dom.ShadowRoot(shadow_root) }
	mutable_shadow_root.set_uses_document_style_sheets(true)
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut wrapper := style_sheet_invalidation_test_element(document, 'div')
	shadow_node.append_child(wrapper.as_node()) or { panic(err) }
	_ := css_style_computer_for(document)
	mut document_scope := css_style_scope_for_document(document)
	document_scope.build_rule_cache_if_needed()
	document_scope.clear_pending_has_invalidations()
	clear_style_sheet_invalidation_test_flags(document_node, host.as_node(), shadow_node, wrapper.as_node())

	wrapper.set_attribute_value('class', 'flag')
	assert document_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
}

fn test_light_dom_insert_schedules_has_invalidation_in_host_shadow_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	mut sheet := parse_css_stylesheet_with_parser(':host(:has(.flag)) { color: red }', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	_ := css_style_computer_for(document)
	mut shadow_scope := css_style_scope_for_shadow_root(shadow_root)
	shadow_scope.build_rule_cache_if_needed()
	assert shadow_scope.may_have_has_selectors()
	shadow_scope.clear_pending_has_invalidations()

	mut flag := style_sheet_invalidation_test_element(document, 'span')
	flag.set_attribute_value('class', 'flag')
	mut host_node := host.as_node()
	host_node.append_child(flag.as_node()) or { panic(err) }
	assert shadow_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
}

fn test_light_dom_attribute_change_schedules_has_invalidation_in_host_shadow_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	mut sheet := parse_css_stylesheet_with_parser(':host(:has(.flag)) { color: red }', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	mut light_child := style_sheet_invalidation_test_element(document, 'span')
	mut host_node := host.as_node()
	host_node.append_child(light_child.as_node()) or { panic(err) }
	_ := css_style_computer_for(document)
	mut shadow_scope := css_style_scope_for_shadow_root(shadow_root)
	shadow_scope.build_rule_cache_if_needed()
	assert shadow_scope.may_have_has_selectors()
	shadow_scope.clear_pending_has_invalidations()

	light_child.set_attribute_value('class', 'flag')
	assert shadow_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
}

fn test_shadow_tree_mutations_schedule_has_invalidation_in_outer_document_scope() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document, 'x-host::part(container):has(.flag) { color: red }')
	mut document_node := unsafe { &dom.Node(document) }
	mut host := style_sheet_invalidation_test_element(document, 'x-host')
	document_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut container := style_sheet_invalidation_test_element(document, 'div')
	container.set_attribute_value('part', 'container')
	shadow_node.append_child(container.as_node()) or { panic(err) }
	mut existing_child := style_sheet_invalidation_test_element(document, 'span')
	mut container_node := container.as_node()
	container_node.append_child(existing_child.as_node()) or { panic(err) }
	_ := css_style_computer_for(document)
	mut document_scope := css_style_scope_for_document(document)
	document_scope.build_rule_cache_if_needed()
	assert document_scope.may_have_has_selectors()
	document_scope.clear_pending_has_invalidations()

	existing_child.set_attribute_value('class', 'flag')
	assert document_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
	document_scope.clear_pending_has_invalidations()

	mut inserted_child := style_sheet_invalidation_test_element(document, 'span')
	inserted_child.set_attribute_value('class', 'flag')
	container_node.append_child(inserted_child.as_node()) or { panic(err) }
	assert document_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
}

fn test_dir_and_lang_changes_schedule_has_invalidation_across_shadow_scopes() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document, 'div:has(:dir(rtl)) { color: red }')
	mut document_node := unsafe { &dom.Node(document) }
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	mut sheet := parse_css_stylesheet_with_parser(':host(:has(:lang(fr))) { color: blue }', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	mut light_child := style_sheet_invalidation_test_element(document, 'span')
	mut host_node := host.as_node()
	host_node.append_child(light_child.as_node()) or { panic(err) }
	_ := css_style_computer_for(document)
	mut document_scope := css_style_scope_for_document(document)
	mut shadow_scope := css_style_scope_for_shadow_root(shadow_root)
	document_scope.build_rule_cache_if_needed()
	shadow_scope.build_rule_cache_if_needed()
	document_scope.clear_pending_has_invalidations()
	shadow_scope.clear_pending_has_invalidations()

	light_child.set_attribute_value('dir', 'rtl')
	assert document_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
	assert shadow_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
	dir_features := document_scope.pending_has_invalidation_features[light_child.as_node().unique_id().value()] or {
		panic('missing directionality mutation features')
	}
	assert dir_features.pseudo_classes[.dir]
	assert !dir_features.is_conservative
	document_scope.clear_pending_has_invalidations()
	shadow_scope.clear_pending_has_invalidations()

	light_child.set_attribute_value('lang', 'fr')
	assert document_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
	assert shadow_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
	lang_features := document_scope.pending_has_invalidation_features[light_child.as_node().unique_id().value()] or {
		panic('missing language mutation features')
	}
	assert lang_features.pseudo_classes[.lang]
	assert !lang_features.is_conservative
}

fn test_dir_auto_text_change_schedules_has_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	add_document_author_style_sheet(document, 'section:has(:dir(rtl)) { color: red }')
	mut document_node := unsafe { &dom.Node(document) }
	mut subject := style_sheet_invalidation_test_element(document, 'section')
	mut auto_parent := style_sheet_invalidation_test_element(document, 'div')
	auto_parent.set_attribute_value('dir', 'auto')
	document_node.append_child(subject.as_node()) or { panic(err) }
	mut subject_node := subject.as_node()
	subject_node.append_child(auto_parent.as_node()) or { panic(err) }
	mut text := document.create_text_node('abc')
	mut auto_parent_node := auto_parent.as_node()
	auto_parent_node.append_child(text.as_node()) or { panic(err) }
	_ := css_style_computer_for(document)
	mut document_scope := css_style_scope_for_document(document)
	document_scope.build_rule_cache_if_needed()
	document_scope.clear_pending_has_invalidations()

	text.replace_data(0, text.length(), '\u05d0\u05d1\u05d2') or { panic(err) }
	assert auto_parent.needs_style_update()
	assert document_scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len > 0
	features := document_scope.pending_has_invalidation_features[auto_parent.as_node().unique_id().value()] or {
		panic('missing text directionality mutation features')
	}
	assert features.pseudo_classes[.dir]
	assert features.pseudo_classes[.empty]
	assert !features.is_conservative
}

fn test_insert_rule_uses_leading_anchor_for_trailing_universal_and_pseudo_element() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut anchor := style_sheet_invalidation_test_element(document, 'section')
	anchor.set_attribute_value('id', 'scope')
	anchor.set_attribute_value('class', 'anchor')
	mut child := style_sheet_invalidation_test_element(document, 'span')
	mut outside := style_sheet_invalidation_test_element(document, 'span')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(anchor.as_node()) or { panic(err) }
	root_node.append_child(outside.as_node()) or { panic(err) }
	mut anchor_node := anchor.as_node()
	anchor_node.append_child(child.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), anchor.as_node(), child.as_node(), outside.as_node())
	document.set_needs_full_style_update(false)

	assert sheet.insert_rule('#scope > * { color: red }', 0)! == 0
	assert child.needs_style_update()
	assert !outside.needs_style_update()
	assert !document.needs_full_style_update()

	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), anchor.as_node(), child.as_node(), outside.as_node())
	assert sheet.insert_rule('.anchor::before { content: "x" }', 1)! == 1
	assert anchor.needs_style_update()
	assert !child.needs_style_update()
	assert !outside.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_insert_rule_targets_matching_elements_inside_shadow_root() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'span')
	target.set_attribute_value('class', 'target')
	mut bystander := style_sheet_invalidation_test_element(document, 'span')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	shadow_node.append_child(target.as_node()) or { panic(err) }
	shadow_node.append_child(bystander.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), shadow_node, style.as_node(), target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	assert sheet.insert_rule('.target { color: green }', 0)! == 0
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	counters := document.style_invalidation_counters()
	assert counters.full_style_invalidations == 0
	assert counters.style_invalidations == 1
}

fn test_shadow_host_escape_selector_classification() {
	assert !selector_text_may_match_light_dom_under_shadow_host(':host')
	assert !selector_text_may_match_light_dom_under_shadow_host(':host(.active)')
	assert !selector_text_may_match_light_dom_under_shadow_host(':is(:host)')
	assert !selector_text_may_match_light_dom_under_shadow_host(':where(:host)')
	assert selector_text_may_match_light_dom_under_shadow_host('::slotted(.item)')
	assert selector_text_may_match_light_dom_under_shadow_host(':host > .item')
	assert selector_text_may_match_light_dom_under_shadow_host(':host + .item')
	assert selector_text_may_match_light_dom_under_shadow_host(':host ~ .item')
	assert selector_text_may_match_light_dom_under_shadow_host(':is(:host) > *')
	assert selector_text_may_match_light_dom_under_shadow_host(':where(:host) .item')
	assert selector_text_may_match_light_dom_under_shadow_host(':is(.foo, :host) + .item')
	assert !selector_text_may_match_light_dom_under_shadow_host('.item')
	assert !selector_text_may_match_light_dom_under_shadow_host('not[')
}

fn test_shadow_host_outside_escape_selector_classification() {
	for selector in [':host', ':host(.active)', ':host > *', ':host *', '::slotted(.item)',
		':is(:host)', ':where(:host)', ':is(:host) > *', ':where(:host) *', ':is(:host > .item)',
		':where(:host .item)', ':host:has(+ .item)', ':has(:host) + .item', ':not(:host) + .item',
		':nth-child(1 of :host) + .item'] {
		assert !selector_text_may_match_light_dom_outside_shadow_host(selector)
	}
	for selector in [':host + .item', ':host ~ .item', ':host + :has(*)', ':is(:host) + .item',
		':where(:host) ~ .item', ':is(:host) + :has(*)', ':is(.foo, :host) + .item',
		':where(.foo, :host(.active)) + .item', ':is(:where(:host)) + .item', ':is(:host + .item)',
		':where(:host ~ .item)', ':is(:host + .item) > .child', ':is(.foo, :where(:host + .item))'] {
		assert selector_text_may_match_light_dom_outside_shadow_host(selector)
	}
}

fn test_insert_keyframes_rule_targets_only_animation_name_users() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'div')
	mut pseudo_target := style_sheet_invalidation_test_element(document, 'div')
	mut bystander := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(pseudo_target.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }
	set_style_sheet_invalidation_test_animation_name(mut target, none, 'other, fade')
	set_style_sheet_invalidation_test_animation_name(mut pseudo_target, dom.PseudoElement.before, 'fade')
	set_style_sheet_invalidation_test_animation_name(mut bystander, none, 'other')

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), target.as_node(), pseudo_target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	assert sheet.insert_rule('@keyframes fade { from { opacity: 0 } to { opacity: 1 } }', 0)! == 0
	assert target.needs_style_update()
	assert pseudo_target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	counters := document.style_invalidation_counters()
	assert counters.full_style_invalidations == 0
	assert counters.style_invalidations == 2
}

fn test_document_keyframes_insertion_walks_existing_shadow_trees() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut target := style_sheet_invalidation_test_element(document, 'span')
	mut bystander := style_sheet_invalidation_test_element(document, 'span')
	shadow_node.append_child(target.as_node()) or { panic(err) }
	shadow_node.append_child(bystander.as_node()) or { panic(err) }
	set_style_sheet_invalidation_test_animation_name(mut target, none, 'fade')
	set_style_sheet_invalidation_test_animation_name(mut bystander, none, 'other')

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), host.as_node(), shadow_node, target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)

	assert sheet.insert_rule('@keyframes fade { from { opacity: 0 } }', 0)! == 0
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_shadow_keyframes_insertion_reaches_host_without_document_bystanders() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	mut bystander := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	set_style_sheet_invalidation_test_animation_name(mut host, none, 'fade')

	mut sheet := parse_css_stylesheet_with_parser(':host { animation-name: fade }', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	effects := determine_shadow_root_style_sheet_effects(shadow_root)
	assert effects.may_match_shadow_host
	assert !effects.may_match_light_dom_under_shadow_host
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), bystander.as_node(), shadow_node, style.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	assert sheet.insert_rule('@keyframes fade { from { opacity: 0.25 } }', 1)! == 1
	assert host.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	counters := document.style_invalidation_counters()
	assert counters.full_style_invalidations == 0
	assert counters.style_invalidations == 1
}

fn test_shadow_root_style_sheet_effects_include_hosts_light_dom_and_slots() {
	document := dom.Document.create(dom.url_about_blank())
	mut host := style_sheet_invalidation_test_element(document, 'div')
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut slot_wrapper := style_sheet_invalidation_test_element(document, 'div')
	slot_wrapper.set_attribute_value('class', 'slot-wrapper')
	mut slot := style_sheet_invalidation_test_element(document, 'slot')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	shadow_node.append_child(slot_wrapper.as_node()) or { panic(err) }
	mut wrapper_node := slot_wrapper.as_node()
	wrapper_node.append_child(slot.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser(':host > .item {} .slot-wrapper {}', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	effects := determine_shadow_root_style_sheet_effects(shadow_root)
	assert effects.may_match_shadow_host
	assert effects.may_match_light_dom_under_shadow_host
	assert !effects.may_match_light_dom_outside_shadow_host
	assert effects.may_affect_assigned_nodes_via_slots
}

fn test_host_attribute_change_invalidates_host_dependent_shadow_subtree() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'span')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	shadow_node.append_child(target.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser(':host(.active) span { color: red }', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	_ := css_style_computer_for(document)
	clear_style_sheet_invalidation_test_flags(document_node, host.as_node(), shadow_node, style.as_node(), target.as_node())

	host.set_attribute_value('class', 'active')
	assert shadow_node.entire_subtree_needs_style_update()
	assert shadow_node.needs_style_update()
}

fn test_shadow_local_replace_sync_does_not_invalidate_light_dom() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	mut light_bystander := style_sheet_invalidation_test_element(document, 'span')
	light_bystander.set_attribute_value('class', 'foo')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(light_bystander.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut shadow_target := style_sheet_invalidation_test_element(document, 'div')
	shadow_target.set_attribute_value('class', 'foo')
	shadow_node.append_child(shadow_target.as_node()) or { panic(err) }

	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	mut adopted := create_adopted_style_sheets_list(shadow_node)
	adopted.append(sheet) or { panic(err) }
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), light_bystander.as_node(), shadow_node, shadow_target.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	sheet.replace_sync('.foo { color: green }') or { panic(err) }
	assert shadow_node.entire_subtree_needs_style_update()
	assert !host.as_node().entire_subtree_needs_style_update()
	assert !light_bystander.needs_style_update()
	assert !document.needs_full_style_update()
	assert document.style_invalidation_counters().style_invalidations == 0
}

fn test_shadow_style_replacement_uses_pre_mutation_host_reach() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	mut slotted := style_sheet_invalidation_test_element(document, 'span')
	slotted.set_attribute_value('class', 'item')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(slotted.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut slot := style_sheet_invalidation_test_element(document, 'slot')
	shadow_node.append_child(slot.as_node()) or { panic(err) }

	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	sheet.replace_sync('::slotted(.item) { color: blue }') or { panic(err) }
	mut adopted := create_adopted_style_sheets_list(shadow_node)
	adopted.append(sheet) or { panic(err) }
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), slotted.as_node(), shadow_node, slot.as_node())
	document.set_needs_full_style_update(false)

	sheet.replace_sync('') or { panic(err) }
	assert host.as_node().entire_subtree_needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_shadow_rule_deletion_uses_pre_mutation_host_reach() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }

	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	sheet.replace_sync(':host { color: blue }') or { panic(err) }
	mut adopted := create_adopted_style_sheets_list(shadow_node)
	adopted.append(sheet) or { panic(err) }
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), shadow_node)
	document.set_needs_full_style_update(false)

	sheet.delete_rule(0) or { panic(err) }
	assert host.as_node().entire_subtree_needs_style_update()
	assert shadow_node.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_shadow_sheet_disabled_toggle_preserves_host_reach_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	mut slotted := style_sheet_invalidation_test_element(document, 'span')
	slotted.set_attribute_value('class', 'item')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(slotted.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut slot := style_sheet_invalidation_test_element(document, 'slot')
	shadow_node.append_child(slot.as_node()) or { panic(err) }

	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	sheet.replace_sync('::slotted(.item) { color: blue }') or { panic(err) }
	mut adopted := create_adopted_style_sheets_list(shadow_node)
	adopted.append(sheet) or { panic(err) }
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), slotted.as_node(), shadow_node, slot.as_node())
	document.set_needs_full_style_update(false)

	sheet.set_disabled(true)
	assert host.as_node().entire_subtree_needs_style_update()
	assert !document.needs_full_style_update()

	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), slotted.as_node(), shadow_node, slot.as_node())
	document.set_needs_full_style_update(false)
	sheet.set_disabled(false)
	assert host.as_node().entire_subtree_needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_shadow_media_list_mutation_uses_pre_mutation_host_reach() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }

	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	sheet.replace_sync(':host { color: blue }') or { panic(err) }
	mut adopted := create_adopted_style_sheets_list(shadow_node)
	adopted.append(sheet) or { panic(err) }
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), shadow_node)
	document.set_needs_full_style_update(false)

	mut media := unsafe { &MediaList(sheet.base.media) }
	media.set_media_text('not all')
	assert host.as_node().entire_subtree_needs_style_update()
	assert !document.needs_full_style_update()
	assert sheet.did_match or { true } == false
}

fn conditional_sheet_invalidation_fixture() (&dom.Document, &CSSStyleSheet, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	document.set_viewport_rect(dom.Rect{width: 800, height: 600})
	mut root := style_sheet_invalidation_test_element(document, 'html')
	style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'div')
	target.set_attribute_value('class', 'target')
	bystander := style_sheet_invalidation_test_element(document, 'aside')
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }
	mut sheet := parse_css_stylesheet_with_parser('.target {color:blue}', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	_ = css_style_computer_for(document)
	document.update_style()
	assert target.el_computed_properties() != none
	assert !document.needs_full_style_update()
	return document, sheet, target, bystander
}

fn conditional_sheet_invalidation_property(element &dom.Element, id PropertyID) string {
	computed := computed_properties_for_element(element) or { panic('missing style') }
	return (computed.property(id, .no) or { panic('missing property') }).css_text
}

fn test_inserted_style_only_conditionals_preserve_unrelated_styles_and_match_a_full_cascade() {
	for text in ['@media (min-width: 1px) {.target {color:red}}',
		'@supports (display:block) {.target {color:red}}',
		'@media (min-width: 1px) {@supports (display:block) {.target {color:red}}}',
		'@media (min-width: 10000px) {.target {color:red}}',
		'@supports (unknown-property:unknown-value) {.target {color:red}}',
		'@media (min-width: 1px) {.target {color:red; &::before {content:"new"}}}'] {
		mut document, mut sheet, target, bystander := conditional_sheet_invalidation_fixture()
		defer { document.finalize() }
		previous := bystander.el_computed_properties() or { panic('missing bystander style') }
		assert sheet.insert_rule(text, 1)! == 1
		assert document.needs_full_style_update() == disable_conditional_sheet_invalidation, text
		if !disable_conditional_sheet_invalidation {
			assert target.needs_style_update() == (disable_inactive_conditional_sheet_skip || (!text.contains('10000px') && !text.contains('unknown-property'))), text
			assert !bystander.needs_style_update(), text
		}
		document.update_style()
		assert (voidptr(bystander.el_computed_properties() or { panic('missing style') }) == voidptr(previous)) == !disable_conditional_sheet_invalidation
		actual := conditional_sheet_invalidation_property(target, .color)
		expected_red := !text.contains('10000px') && !text.contains('unknown-property')
		assert actual == if expected_red { 'rgb(255, 0, 0)' } else { 'rgb(0, 0, 255)' }, text
		document.set_needs_full_style_update(true)
		document.update_style()
		assert conditional_sheet_invalidation_property(target, .color) == actual, text
	}
}

fn test_inserted_conditional_groups_keep_global_rule_and_universal_fallbacks() {
	for text in ['@media all {@font-face {font-family:UnusedConditional;src:local(AbsentConditional)}}',
		'@media all {@layer conditional-layer {.target {color:red}}}',
		'@supports (display:block) {@property --conditional {syntax:"<color>";inherits:true;initial-value:red}}',
		'@media all {* {color:red}}', '@media all {:has(.flag) {color:red}}'] {
		mut document, mut sheet, _, _ := conditional_sheet_invalidation_fixture()
		defer { document.finalize() }
		assert sheet.insert_rule(text, 1)! == 1
		assert document.needs_full_style_update(), text
	}
}

fn test_inserted_conditional_group_preserves_preexisting_media_match_changes() {
	mut document, mut sheet, target, _ := conditional_sheet_invalidation_fixture()
	defer { document.finalize() }
	assert sheet.insert_rule('@media (min-width: 900px) {.target {color:green}}', 1)! == 1
	document.update_style()
	assert conditional_sheet_invalidation_property(target, .color) == 'rgb(0, 0, 255)'
	document.set_viewport_rect(dom.Rect{width: 1000, height: 600})
	assert sheet.insert_rule('@media all {.absent {color:red}}', 2)! == 2
	document.update_style()
	assert conditional_sheet_invalidation_property(target, .color) == 'rgb(0, 128, 0)'
}


fn test_inactive_conditional_rule_insertion_waits_for_its_media_to_match() {
	for text in ['@media (min-width: 900px) {.target, * {color:red}}',
		'@supports (display:block) {@media (min-width: 900px) {.target, * {color:red}}}',
		'@media (min-width: 900px) {@supports (display:block) {.target, * {color:red}}}'] {
		mut document, mut sheet, target, bystander := conditional_sheet_invalidation_fixture()
		defer { document.finalize() }
		previous := target.el_computed_properties() or { panic('missing style') }
		assert sheet.insert_rule(text, 1)! == 1
		assert document.needs_full_style_update() == (disable_conditional_sheet_invalidation || disable_inactive_conditional_sheet_skip), text
		document.update_style()
		assert conditional_sheet_invalidation_property(target, .color) == 'rgb(0, 0, 255)', text
		if !disable_conditional_sheet_invalidation && !disable_inactive_conditional_sheet_skip {
			assert voidptr(target.el_computed_properties() or { panic('missing style') }) == voidptr(previous), text
		}
		document.set_viewport_rect(dom.Rect{width: 1000, height: 600})
		document.evaluate_media_rules()
		assert document.needs_full_style_update(), text
		document.update_style()
		assert conditional_sheet_invalidation_property(target, .color) == 'rgb(255, 0, 0)', text
		assert conditional_sheet_invalidation_property(bystander, .color) == 'rgb(255, 0, 0)', text
		document.set_viewport_rect(dom.Rect{width: 800, height: 600})
		document.evaluate_media_rules()
		document.update_style()
		assert conditional_sheet_invalidation_property(target, .color) == 'rgb(0, 0, 255)', text
	}
}
