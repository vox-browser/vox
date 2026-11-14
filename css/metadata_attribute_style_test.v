module css

import dom
import os

fn metadata_style_fixture(source string) (&dom.Document, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut scope := document.create_element_ns(dom.namespace_html_uri, 'section') or { panic(err) }
	scope.set_attribute_value('class', 'scope')
	mut root_node := root.as_node()
	root_node.append_child(scope.as_node()) or { panic(err) }
	mut target := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
	target.set_attribute_value('class', 'target')
	mut scope_node := scope.as_node()
	scope_node.append_child(target.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '.target{color:blue}' + source)
	css_style_computer_for(document)
	document.update_style()
	return document, scope, target
}

fn metadata_style_color(target &dom.Element) string {
	style := computed_properties_for_element(target) or { panic('missing style') }
	return (style.property(.color, .no) or { panic('missing color') }).css_text
}

fn test_irrelevant_metadata_attributes_retain_computed_styles() {
	mut document, _, mut target := metadata_style_fixture('')
	defer { document.finalize() }
	for name in ['data-react-ready', 'aria-label', 'data-state', 'aria-busy'] {
		before := computed_properties_for_element(target) or { panic('missing initial style') }
		target.set_attribute_value(name, 'ready')
		document.update_style()
		after := computed_properties_for_element(target) or { panic('missing retained style') }
		if os.getenv('VOX_DISABLE_METADATA_ATTRIBUTE_STYLE_REUSE') == '' {
			assert voidptr(before) == voidptr(after), name
		}
		assert metadata_style_color(target) == 'rgb(0, 0, 255)'
		target.remove_attribute(name)
		document.update_style()
		assert metadata_style_color(target) == 'rgb(0, 0, 255)'
	}
}

fn test_metadata_selectors_keep_self_descendant_and_has_invalidation() {
	for rule in ['.target[data-state=on]{color:red}',
		'.scope[data-state=on] .target{color:red}',
		'.scope:has(> [aria-expanded=true]) .target{color:red}'] {
		mut document, mut scope, mut target := metadata_style_fixture(rule)
		defer { document.finalize() }
		mut owner := if rule.starts_with('.scope[data-') { scope } else { target }
		name := if rule.contains('aria-expanded') { 'aria-expanded' } else { 'data-state' }
		value := if name == 'aria-expanded' { 'true' } else { 'on' }
		assert metadata_style_color(target) == 'rgb(0, 0, 255)'
		owner.set_attribute_value(name, value)
		document.update_style()
		assert metadata_style_color(target) == 'rgb(255, 0, 0)', rule
		owner.set_attribute_value(name, 'off')
		document.update_style()
		assert metadata_style_color(target) == 'rgb(0, 0, 255)', rule
		owner.set_attribute_value(name, value)
		document.update_style()
		assert metadata_style_color(target) == 'rgb(255, 0, 0)', rule
		owner.remove_attribute(name)
		document.update_style()
		assert metadata_style_color(target) == 'rgb(0, 0, 255)', rule
	}
}

fn test_metadata_attr_function_values_remain_live_without_attribute_selectors() {
	mut document, _, mut target := metadata_style_fixture('.target{color:attr(data-color type(<color>), blue)}')
	defer { document.finalize() }
	assert metadata_style_color(target) == 'rgb(0, 0, 255)'
	target.set_attribute_value('data-color', 'red')
	document.update_style()
	assert metadata_style_color(target) == 'rgb(255, 0, 0)'
	target.set_attribute_value('data-color', 'green')
	document.update_style()
	assert metadata_style_color(target) == 'rgb(0, 128, 0)'
	target.remove_attribute('data-color')
	document.update_style()
	assert metadata_style_color(target) == 'rgb(0, 0, 255)'
}

fn test_identical_metadata_writes_preserve_matching_and_attr_styles() {
	mut document, _, mut target := metadata_style_fixture('.target[data-state=on]{color:attr(data-color type(<color>), red)}')
	defer { document.finalize() }
	target.set_attribute_value('data-state', 'on')
	target.set_attribute_value('data-color', 'green')
	document.update_style()
	mut queue := dom.MutationObserverDeliveryQueue.create(fn () {})
	mut observer := dom.MutationObserver.construct_impl(none)!
	observer.delivery_queue_ = queue
	mut options := dom.MutationObserverOptions{attributes: true, attribute_old_value: true}
	observer.observe(target.as_node(), mut options)!
	defer { observer.disconnect(); queue.retire() }
	for name in ['data-state', 'data-color'] {
		before := computed_properties_for_element(target) or { panic('missing initial style') }
		target.set_attribute_value(name, target.get_attribute_value(name))
		document.update_style()
		if os.getenv('VOX_DISABLE_METADATA_ATTRIBUTE_STYLE_REUSE') == '' {
			after := computed_properties_for_element(target) or { panic('missing retained style') }
			assert voidptr(before) == voidptr(after)
		}
		assert metadata_style_color(target) == 'rgb(0, 128, 0)'
		records := observer.take_records()
		assert records.len == 1
		assert (records[0].attribute_name or { '' }) == name
		assert (records[0].old_value or { '' }) == target.get_attribute_value(name)
	}
}

fn test_metadata_changes_keep_sibling_and_shadow_host_selectors_live() {
	mut document, mut scope, mut target := metadata_style_fixture('.trigger[aria-selected=true]+.target{color:red}')
	defer { document.finalize() }
	mut trigger := document.create_element_ns(dom.namespace_html_uri, 'div')!
	trigger.set_attribute_value('class', 'trigger')
	mut scope_node := scope.as_node()
	scope_node.insert_before(trigger.as_node(), target.as_node(), false)
	shadow := trigger.attach_shadow(dom.ShadowRootInit{mode: .open})!
	mut shadow_node := shadow.as_node()
	mut inner := document.create_element_ns(dom.namespace_html_uri, 'span')!
	shadow_node.append_child(inner.as_node())!
	add_shadow_root_author_style_sheet(shadow, 'span{color:blue}:host([data-state=on]) span{color:green}')
	document.update_style()
	assert metadata_style_color(target) == 'rgb(0, 0, 255)'
	assert metadata_style_color(inner) == 'rgb(0, 0, 255)'
	trigger.set_attribute_value('aria-selected', 'true')
	trigger.set_attribute_value('data-state', 'on')
	document.update_style()
	assert metadata_style_color(target) == 'rgb(255, 0, 0)'
	assert metadata_style_color(inner) == 'rgb(0, 128, 0)'
	trigger.remove_attribute('aria-selected')
	trigger.remove_attribute('data-state')
	document.update_style()
	assert metadata_style_color(target) == 'rgb(0, 0, 255)'
	assert metadata_style_color(inner) == 'rgb(0, 0, 255)'
}
