module css

import dom

fn pending_plan_fixture_element(document &dom.Document, parent &dom.Node, tag string, class_name string) &dom.Element {
	mut element := document.create_element(tag) or { panic(err) }
	if class_name != '' {
		element.set_attribute_value('class', class_name)
	}
	mut parent_node := unsafe { &dom.Node(parent) }
	parent_node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn pending_plan_fixture_color(element &dom.Element) string {
	style := computed_properties_for_element(element) or { panic('missing retained style') }
	color := style.property(.color, .no) or { panic('missing color') }
	return color.css_text
}

fn test_pending_native_style_plans_survive_descendant_and_sibling_dispatch() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer {
			owner.finish()
			document.finalize()
			document.release_native_storage()
		}
		document.set_document_type(.html)
		document.set_browsing_context(&dom.BrowsingContext{})
		root := pending_plan_fixture_element(document, document.as_node(), 'html', '')
		body := pending_plan_fixture_element(document, root.as_node(), 'body', '')
		mut trigger := pending_plan_fixture_element(document, body.as_node(), 'section', '')
		descendant := pending_plan_fixture_element(document, trigger.as_node(), 'span', 'leaf')
		peer := pending_plan_fixture_element(document, body.as_node(), 'section', 'peer')
		sibling_descendant := pending_plan_fixture_element(document, peer.as_node(), 'span', 'leaf')
		add_document_author_style_sheet(document, '
			.leaf { color: blue }
			.armed .leaf, .armed + .peer .leaf { color: red }')
		css_style_computer_for(document)
		document.update_style()
		assert pending_plan_fixture_color(descendant) == 'rgb(0, 0, 255)'
		assert pending_plan_fixture_color(sibling_descendant) == 'rgb(0, 0, 255)'

		properties := [dom.InvalidationProperty{type_: .class, name: 'armed'}]
		owned_plan := document.style_computer().invalidation_plan_for_properties(properties,
			document.style_scope())
		assert owned_plan.descendant_rules.len > 0
		assert owned_plan.sibling_rules.len > 0
		mut scope := unsafe { &StyleScope(css_style_scope_for_document(document)) }
		scope.invalidate_rule_cache()

		for _ in 0 .. 3 {
			trigger.set_attribute_value('class', 'armed')
			pending := document.style_invalidator().pending_invalidations[trigger.as_node().unique_id()] or {
				panic('missing descendant invalidation')
			}
			assert pending.len > 0
			match_properties := pending[0].rule.match_set.properties
			assert match_properties.len > 0
			assert !document.native_storage().arena.contains(match_properties.data)
			assert !document.needs_full_style_update()
			document.update_style()
			assert pending_plan_fixture_color(descendant) == 'rgb(255, 0, 0)'
			assert pending_plan_fixture_color(sibling_descendant) == 'rgb(255, 0, 0)'
			assert !document.style_invalidator().has_pending_invalidations()

			trigger.remove_attribute('class')
			document.update_style()
			assert pending_plan_fixture_color(descendant) == 'rgb(0, 0, 255)'
			assert pending_plan_fixture_color(sibling_descendant) == 'rgb(0, 0, 255)'
		}
		assert owned_plan.descendant_rules[0].match_set.properties[0].name == 'leaf'
		assert owned_plan.sibling_rules[0].match_set.properties[0].name == 'peer'

		// Closing also retires the last batch if it never reached a style pass.
		trigger.set_attribute_value('class', 'armed')
		assert document.style_invalidator().has_pending_invalidations()
	}
}
