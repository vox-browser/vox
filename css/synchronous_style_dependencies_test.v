module css

import dom

fn synchronous_style_test_value(property_id PropertyID, text string) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, property_id) or { panic(text) }
}

fn synchronous_style_test_layers(value &dom.StyleValue) int {
	typed := typed_style_value_logic_from_dom(value) or { panic('missing typed value') }
	if typed is StyleValueList { return typed.size() }
	panic('expected coordinated list')
}

fn test_ancestor_hash_updates_keep_name_folding_duplicates_and_attribute_hashes() {
	for quirks in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		if quirks { document.set_quirks_mode(.yes) }
		mut element := document.create_element_ns('http://www.w3.org/2000/svg', 'linearGradient')!
		element.set_attribute_value('id', 'PaReNt')
		element.set_attribute_value('class', 'Token token token Étage ÉTAGE')
		element.set_attribute_value('DATA-Mixed', 'value')
		mut expected := CountingBloomFilter.new()
		names := if quirks {
			['lineargradient', 'parent', 'token', 'token', 'token', 'Étage', 'Étage', 'id', 'class',
				'data-mixed']
		} else {
			['lineargradient', 'PaReNt', 'Token', 'token', 'token', 'Étage', 'ÉTAGE', 'id', 'class',
				'data-mixed']
		}
		for name in names {
			expected.increment(selector_string_hash(name))
		}
		mut computer := StyleComputer.new(document)
		backing := computer.ancestor_filter_.buckets.data
		computer.push_ancestor(element)
		assert computer.ancestor_filter_.buckets == expected.buckets
		assert computer.ancestor_filter_.buckets.data == backing
		computer.pop_ancestor(element)
		assert computer.ancestor_filter_.buckets.all(it == 0)
		assert computer.ancestor_filter_.buckets.data == backing
		assert element.get_attribute('class')? == 'Token token token Étage ÉTAGE'
	}
}

fn test_ancestor_hash_updates_balance_repeated_nested_visits_after_dom_mutations() {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element('div')!
	mut child := document.create_element('span')!
	child.set_attribute_value('class', 'shared shared')
	mut computer := StyleComputer.new(document)
	backing := computer.ancestor_filter_.buckets.data
	for index in 0 .. 128 {
		parent.set_attribute_value('id', 'parent-${index % 3}')
		parent.set_attribute_value('class', if index % 2 == 0 {
			'shared current current'
		} else {
			'shared changed'
		})
		if index % 2 == 0 {
			parent.set_attribute_value('data-current', '${index}')
		} else {
			parent.remove_attribute('data-current')
		}
		computer.push_ancestor(parent)
		expected := computer.ancestor_filter_.buckets.clone()
		computer.push_ancestor(child)
		computer.pop_ancestor(child)
		assert computer.ancestor_filter_.buckets == expected
		computer.pop_ancestor(parent)
		assert computer.ancestor_filter_.buckets.all(it == 0)
		assert computer.ancestor_filter_.buckets.data == backing
	}
}

fn test_borrowed_property_overlay_precedes_base_and_observes_synchronous_changes() {
	mut base := ComputedProperties.new()
	base_value := synchronous_style_test_value(.math_depth, '2')
	base.set_property(.math_depth, base_value, .yes, .yes)
	ordinary := ComputedPropertyValueSource{
		properties: base
	}
	assert ordinary.specified_values == unsafe { nil }
	mut overlay := {
		PropertyID.math_depth: synchronous_style_test_value(.math_depth, '0')
	}
	source := ComputedPropertyValueSource{
		properties:       base
		specified_values: &overlay
	}
	assert source.get(.math_depth).css_text == '0'
	assert ordinary.get(.math_depth).css_text == '2'
	overlay[.math_depth] = synchronous_style_test_value(.math_depth, '3')
	gc_collect()
	assert source.get(.math_depth).css_text == '3'
	overlay.delete(PropertyID.math_depth)
	gc_collect()
	assert voidptr(source.get(.math_depth)) == voidptr(base_value)
	assert source.get(.opacity).css_text == '1'
	assert overlay.len == 0
	assert base.is_property_inherited(.math_depth)
	assert base.is_property_important(.math_depth)
}

fn test_repeated_keyframe_computation_borrows_dependencies_without_mutating_inputs_or_old_results() {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element('div')!
	subject := dom.AbstractElement.new(element, none)
	mut base := computed_properties_with_initial_values()
	computer := StyleComputer.new(document)
	mut first_result := map[PropertyID]&dom.StyleValue{}
	for index in 0 .. 32 {
		base_depth := if index % 2 == 0 { '2' } else { '0' }
		overlay_depth := if index % 2 == 0 { '0' } else { '2' }
		base_images := synchronous_style_test_value(.background_image, 'none,none')
		base_math_depth := synchronous_style_test_value(.math_depth, base_depth)
		base.set_property(.background_image, base_images, .yes, .yes)
		base.set_property(.math_depth, base_math_depth, .no, .no)
		keyframe := ResolvedKeyFrame{
			properties:             {
				PropertyID.background_image: synchronous_style_test_value(.background_image,
					'none,none,none')
				.background_attachment:      synchronous_style_test_value(.background_attachment,
					'fixed')
				.font_size:                  synchronous_style_test_value(.font_size, 'math')
				.math_depth:                 synchronous_style_test_value(.math_depth,
					overlay_depth)
			}
			use_initial_properties: {
				PropertyID.background_position_x: true
			}
		}
		gc_collect()
		values := computer.compute_keyframe_values(subject, keyframe, base)
		assert synchronous_style_test_layers(values[.background_attachment] or {
			panic('missing attachment')
		}) == 3
		assert synchronous_style_test_layers(values[.background_position_x] or {
			panic('missing initial position')
		}) == 3
		font_size := computed_interpolation_length_from_dom_style_value(values[.font_size] or {
			panic('missing size')
		})?.absolute_length_to_px().raw_value()
		assert font_size == if index % 2 == 0 {
			1024
		} else {
			516
		}
		if index == 0 { first_result = values.clone() }
		assert keyframe.properties.len == 4
		specified_size := keyframe.properties[.font_size] or { panic('missing specified size') }
		specified_depth := keyframe.properties[.math_depth] or { panic('missing specified depth') }
		assert specified_size.css_text == 'math'
		assert specified_depth.css_text == overlay_depth
		assert keyframe.use_initial_properties.len == 1
		assert voidptr(base.property(.background_image, .no)?) == voidptr(base_images)
		assert voidptr(base.property(.math_depth, .no)?) == voidptr(base_math_depth)
		assert base.is_property_inherited(.background_image)
		assert base.is_property_important(.background_image)
		fallback := computer.compute_keyframe_values(subject, ResolvedKeyFrame{
			properties: {
				PropertyID.background_attachment: synchronous_style_test_value(.background_attachment,
					'scroll')
			}
		}, base)
		assert synchronous_style_test_layers(fallback[.background_attachment] or {
			panic('missing fallback')
		}) == 2
	}
	gc_collect()
	assert synchronous_style_test_layers(first_result[.background_attachment] or {
		panic('lost prior attachment')
	}) == 3
	assert computed_interpolation_length_from_dom_style_value(first_result[.font_size] or {
		panic('lost prior size')
	})?.absolute_length_to_px().raw_value() == 1024
}
