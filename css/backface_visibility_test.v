module css

import dom

fn backface_visibility_serialization(text string) ?string {
	value := parse_css_value_logic(.backface_visibility, text) or { return none }
	return value.serialize(.normal)
}

fn test_backface_visibility_metadata_and_parsing() {
	assert number_of_longhand_properties == 364
	assert last_longhand_property_id() == .webkit_font_smoothing
	assert property_id_from_string('backface-visibility')? == .backface_visibility
	assert property_id_from_string('BACKFACE-VISIBILITY')? == .backface_visibility
	assert string_from_property_id(.backface_visibility) == 'backface-visibility'
	assert property_initial_value_string(.backface_visibility) == 'visible'
	assert !is_inherited_property(.backface_visibility)
	assert animation_type_from_longhand_property(.backface_visibility) == .discrete
	assert is_animatable_property(.backface_visibility)
	assert !property_affects_layout(.backface_visibility)
	assert property_affects_stacking_context(.backface_visibility)
	assert generated_shorthands_for_longhand(.backface_visibility) == [PropertyID.all]
	assert PropertyID.backface_visibility in generated_longhands_for_shorthand(.all)
	assert PropertyID.backface_visibility in generated_expanded_longhands_for_shorthand(.all)

	for valid in ['visible', 'hidden', 'HiDdEn'] {
		assert backface_visibility_serialization(valid)? == valid.to_lower()
	}
	for invalid in ['none', 'auto', 'visible hidden'] {
		assert backface_visibility_serialization(invalid) == none, invalid
	}
}

fn test_backface_visibility_computed_value() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element('div') or { panic(err) }
	computer := StyleComputer.new(document)

	initial := computer.compute_style(dom.AbstractElement.new(element, none))
	assert initial.backface_visibility() == .visible
	assert resolve_computed_values_for_document(initial, document).backface_visibility() == .visible

	element.set_attribute_value('style', 'backface-visibility: hidden')
	hidden := computer.compute_style(dom.AbstractElement.new(element, none))
	assert hidden.backface_visibility() == .hidden
	assert resolve_computed_values_for_document(hidden, document).backface_visibility() == .hidden
}

fn test_backface_visibility_invalidation() {
	visible := &dom.StyleValue{ css_text: 'visible' }
	hidden := &dom.StyleValue{ css_text: 'hidden' }
	to_hidden := compute_property_invalidation(.backface_visibility, visible, hidden)
	assert to_hidden.needs_stacking_context_tree_rebuild()
	assert to_hidden.accumulated_visual_contexts() == .rebuild
	to_visible := compute_property_invalidation(.backface_visibility, hidden, visible)
	assert to_visible.needs_stacking_context_tree_rebuild()
}

fn test_document_reports_running_css_animations_to_the_browser_host() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'animation-name: flip; animation-duration: 10s')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(element.as_node()) or { panic(err) }

	assert !document_has_running_css_animations(document)
	mut computer := css_style_computer_for(document)
	mut abstract_element := dom.AbstractElement.new(element, none)
	computer.recompute_style(mut abstract_element)
	assert document_has_running_css_animations(document)
}

fn math_abs(value f64) f64 {
	return if value < 0 { -value } else { value }
}

fn backface_visibility_test_matrix(text string) FloatMatrix4x4 {
	document := dom.Document.create(dom.url_about_blank())
	parsed := parse_css_value_logic(.transform, text) or { panic('unparsable transform: ${text}') }
	mut transformations := []TransformationStyleValue{}
	if parsed is TransformationStyleValue {
		transformations << parsed
	} else if parsed is StyleValueList {
		for item in parsed.values() {
			transformations << (item as TransformationStyleValue)
		}
	}
	return resolve_transformations_4x4_matrix(transformations, 100, 100,
		LengthResolutionContext.for_document(document)) or { panic('unresolvable transform: ${text}') }
}

fn test_backface_visibility_matrix_math() {
	front := backface_visibility_test_matrix('rotateY(0deg)')
	back := backface_visibility_test_matrix('rotateY(180deg)')
	assert !is_back_face_visible(front)
	assert is_back_face_visible(back)
	inverse := back.inverse() or { panic('rotation should be invertible') }
	identity := inverse.multiply(back)
	assert math_abs(identity.m11 - 1) < 0.0000001
	assert math_abs(identity.m22 - 1) < 0.0000001
	assert math_abs(identity.m33 - 1) < 0.0000001
	assert math_abs(identity.m44 - 1) < 0.0000001
}

fn test_transform_function_names_are_ascii_case_insensitive() {
	assert transform_function_from_string('rotatex')? == .rotate_x
	assert transform_function_from_string('ROTATEY')? == .rotate_y
	assert transform_function_from_string('scalez')? == .scale_z

	back := backface_visibility_test_matrix('rotatex(180deg) scalez(2)')
	assert is_back_face_visible(back)
}
