module css

import dom

fn environment_reuse_value(source string, important bool) dom.CSSCustomProperty_ {
	return dom.CSSCustomProperty_{
		value:     custom_property_bridge_value(parse_custom_property_value(source))
		important: important
	}
}

fn test_custom_environment_reuse_requires_equal_own_values_and_identical_parent() {
	parent := dom.CSSCustomPropertyData_.create({
		'--parent': environment_reuse_value('red', false)
	}, none)
	other_parent := dom.CSSCustomPropertyData_.create({
		'--parent': environment_reuse_value('red', false)
	}, none)
	shared_value := environment_reuse_value('var(--parent)', true)
	previous := &dom.CSSCustomPropertyData_{
		own_values:     {
			'--value': shared_value
		}
		parent:         parent
		ancestor_count: 1
	}
	equal := &dom.CSSCustomPropertyData_{
		own_values:     {
			'--value': dom.CSSCustomProperty_{
				...shared_value
				value: &dom.CSSStyleValue_{
					...shared_value.value
				}
			}
		}
		parent:         parent
		ancestor_count: 1
	}
	assert reuse_unchanged_custom_property_environment(previous, equal)? == previous
	assert reuse_unchanged_custom_property_environment(none, equal)? == equal
	assert reuse_unchanged_custom_property_environment(previous, none) == none
	for next in [
		&dom.CSSCustomPropertyData_{
			...equal
			parent: other_parent
		},
		&dom.CSSCustomPropertyData_{
			...equal
			ancestor_count: 2
		},
		&dom.CSSCustomPropertyData_{
			...equal
			own_values: {
				'--value': environment_reuse_value('blue', true)
			}
		},
		&dom.CSSCustomPropertyData_{
			...equal
			own_values: {
				'--value': environment_reuse_value('var(--parent)', false)
			}
		},
	] {
		assert reuse_unchanged_custom_property_environment(previous, next)? == next
	}
}

fn test_custom_environment_reuse_keeps_distinct_retained_values_and_relative_url_bases() {
	mut first_value := parse_custom_property_value('url(relative.png)')
	mut second_value := parse_custom_property_value('url(relative.png)')
	first_value.base_url = 'https://first.example/styles/'
	second_value.base_url = 'https://second.example/styles/'
	previous := dom.CSSCustomPropertyData_.create({
		'--image': dom.CSSCustomProperty_{ value: custom_property_bridge_value(first_value) }
	}, none)
	current := dom.CSSCustomPropertyData_.create({
		'--image': dom.CSSCustomProperty_{ value: custom_property_bridge_value(second_value) }
	}, none)
	assert custom_property_maps_equal(previous.own_values, current.own_values)
	assert reuse_unchanged_custom_property_environment(previous, current)? == current
	// Bind the custom property first: current V passes the address of the
	// option's payload, not the reference it holds, for `f(g()?)`.
	image := current.get('--image')?
	retained := dom_style_value_from_custom_property_bridge(image)?
	assert retained.base_url? == 'https://second.example/styles/'
}

fn test_custom_environment_reuse_preserves_separate_animation_overlays() {
	base := dom.CSSCustomPropertyData_.create({
		'--value': environment_reuse_value('red', false)
	}, none)
	previous := dom.CSSCustomPropertyData_.create_animation_overlay({
		'--animated': environment_reuse_value('10px', false)
	}, base)
	current := dom.CSSCustomPropertyData_.create_animation_overlay({
		'--animated': environment_reuse_value('10px', false)
	}, base)
	assert reuse_unchanged_custom_property_environment(previous, current)? == current
	assert reuse_unchanged_custom_property_environment(previous, base)? == base
	assert reuse_unchanged_custom_property_environment(base, current)? == current
	assert current.is_animation_overlay()
	assert current.parent? == base
}

fn test_custom_environment_reuse_preserves_bridge_serialization_and_invalidity_metadata() {
	value := parse_custom_property_value('rgb(10 20 30)')
	bridge := custom_property_bridge_value(value)
	previous := dom.CSSCustomPropertyData_.create({
		'--value': dom.CSSCustomProperty_{ value: bridge }
	}, none)
	for replacement in [
		&dom.CSSStyleValue_{
			...bridge
			css_text: 'rgb(10, 20, 30)'
		},
		&dom.CSSStyleValue_{
			...bridge
			guaranteed_invalid: true
		},
	] {
		current := dom.CSSCustomPropertyData_.create({
			'--value': dom.CSSCustomProperty_{ value: replacement }
		}, none)
		assert custom_property_maps_equal(previous.own_values, current.own_values)
		assert reuse_unchanged_custom_property_environment(previous, current)? == current
	}
}

fn test_full_style_pass_reuses_unchanged_root_variables_and_updates_changed_inheritance() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(child.as_node())!
	add_document_author_style_sheet(document,
		'html{--tone:red;--a:1;--b:2;--c:3;--d:4;--e:5;--f:6;--g:7;--h:8;--i:9}span{color:var(--tone)}')
	css_style_computer_for(document)
	document.set_needs_full_style_update(true)
	document.update_style()
	root_abstract := dom.AbstractElement.new(root, none)
	child_abstract := dom.AbstractElement.new(child, none)
	initial := root_abstract.custom_property_data()?
	assert child_abstract.custom_property_data()? == initial
	assert computed_value_for(child, .color)? == 'rgb(255, 0, 0)'
	for _ in 0 .. 3 {
		gc_collect()
		document.set_needs_full_style_update(true)
		document.update_style()
		assert root_abstract.custom_property_data()? == initial
		assert child_abstract.custom_property_data()? == initial
	}
	root.set_attribute_value('style', '--tone:blue !important')
	document.update_style()
	changed := root_abstract.custom_property_data()?
	assert changed != initial
	assert child_abstract.custom_property_data()? == changed
	assert computed_value_for(child, .color)? == 'rgb(0, 0, 255)'
	assert changed.get_property('--tone')?.important
	document.set_needs_full_style_update(true)
	document.update_style()
	assert root_abstract.custom_property_data()? == changed
	assert child_abstract.custom_property_data()? == changed
	register_property_for_document(mut document, PropertyDefinition{
		name:          '--tone'
		syntax:        '<color>'
		inherits:      false
		initial_value: 'green'
	})!
	document.set_needs_full_style_update(true)
	document.update_style()
	assert computed_value_for(child, .color)? == 'rgb(0, 128, 0)'
	registered := root_abstract.custom_property_data()?
	document.set_needs_full_style_update(true)
	document.update_style()
	assert root_abstract.custom_property_data()? == registered
	assert computed_value_for(child, .color)? == 'rgb(0, 128, 0)'
}
