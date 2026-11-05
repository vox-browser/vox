module css

import dom
import platform

fn reference_keyframe_property_ids(keyframe ResolvedKeyFrame) []PropertyID {
	mut ids := map[PropertyID]bool{}
	for property, _ in keyframe.properties { ids[property] = true }
	for property, _ in keyframe.use_initial_properties { ids[property] = true }
	return ids.keys()
}

fn test_keyframe_property_vector_preserves_union_order_and_presence() {
	properties := computed_interpolation_longhand_property_ids()
	value := &dom.StyleValue{ css_text: 'unused' }
	assert keyframe_property_ids(ResolvedKeyFrame{}) == []PropertyID{}
	for seed in 0 .. 128 {
		mut keyframe := ResolvedKeyFrame{}
		for step in 0 .. properties.len {
			property := properties[(step * 173 + seed * 31) % properties.len]
			if step % 3 != 0 { keyframe.properties[property] = value }
			if step % 5 != 0 { keyframe.use_initial_properties[property] = step % 2 == 0 }
		}
		keyframe.properties[.margin] = value
		keyframe.use_initial_properties[.margin] = false
		keyframe.use_initial_properties[.all] = false
		assert keyframe_property_ids(keyframe) == reference_keyframe_property_ids(keyframe)
	}
}

fn test_keyframe_property_vector_reads_current_maps_and_returns_independent_storage() {
	value := &dom.StyleValue{ css_text: 'unused' }
	mut keyframe := ResolvedKeyFrame{ properties: {
		PropertyID.width: value
	}, use_initial_properties: {
		PropertyID.height: false
	} }
	mut first := keyframe_property_ids(keyframe)
	assert first == [PropertyID.width, .height]
	first[0] = .opacity
	keyframe.properties.delete(.width)
	keyframe.properties[.color] = value
	keyframe.use_initial_properties[.color] = true
	keyframe.use_initial_properties[.opacity] = false
	assert keyframe_property_ids(keyframe) == reference_keyframe_property_ids(keyframe)
	assert first == [PropertyID.opacity, .height]
}

fn test_keyframe_property_vector_keeps_resolved_values_and_logical_alias_collisions() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	mut element := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	mut root := document.as_node()
	root.append_child(element.as_node()) or { panic(err) }
	for writing_mode in ['horizontal-tb', 'vertical-rl'] {
		element.set_attribute_value('style', 'writing-mode:${writing_mode};direction:rtl;width:18px;height:24px;font-size:14px;--union-width:37px')
		computed := up_to_date_computed_properties_for_element(element)
		computer := css_style_computer_for(document)
		mut keyframe := ResolvedKeyFrame{}
		for property, spelling in {
			PropertyID.width: 'var(--union-width)'
			.inline_size:     'calc(5px + 7px)'
			.block_size:      '31px'
			.font_size:       '2em'
			.color:           'inherit'
		} {
			typed := parse_css_value_logic(property, spelling) or { panic('missing keyframe value') }
			keyframe.properties[property] = dom_style_value_from_value_logic(typed)
		}
		for property in [PropertyID.width, .height, .margin_inline_start, .color] {
			keyframe.use_initial_properties[property] = false
		}
		abstract := dom.AbstractElement.new(element, none)
		expected := computer.compute_keyframe_values_with_id_map(abstract, keyframe, computed)
		actual := computer.compute_keyframe_values(abstract, keyframe, computed)
		assert actual.keys() == expected.keys()
		for property, value in expected {
			assert actual[property].css_text == value.css_text
		}
	}
}

fn test_keyframe_property_union_scratch_storage_does_not_escape_the_lookup() {
	$if prealloc {
		mut arena := platform.new_arena('keyframe vector producer')
		mut keyframe := ResolvedKeyFrame{ use_initial_properties: {
			PropertyID.width: true
			.height:          false
		} }
		entry := arena.enter()
		ids := keyframe_property_ids(keyframe)
		assert arena.contains(ids.data)
		arena.leave(entry)
		// The union never mutates or stores its temporary vector in either
		// input map. Retiring it cannot affect later fresh property selection.
		keyframe.use_initial_properties = {
			PropertyID.opacity: false
		}
		arena.release()
		assert keyframe_property_ids(keyframe) == [PropertyID.opacity]
	}
}
