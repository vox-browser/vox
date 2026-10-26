module css

import dom
import math

fn borrowed_projection_test_style() (&dom.Document, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	document.set_font_rendering_policy(.chromium)
	mut root := document.create_element('html') or { panic(err) }
	root.set_attribute_value('style', 'font:16px Arial;width:0px;padding:0px;color:red;opacity:.5;border:thin solid;transform:translate(3px,4px)')
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	return document, up_to_date_computed_properties_for_element(root)
}

fn test_projection_keeps_borrowed_values_and_still_scales_replaced_and_nested_lengths() {
	mut document, mut source := borrowed_projection_test_style()
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	first := computed_style_in_layout_coordinates(source, document)
	for property in [PropertyID.width, .padding_left, .color, .opacity] {
		assert voidptr(first.property(property, .yes)?) == voidptr(source.property(property, .yes)?)
	}
	assert first.length_percentage_to_px(.border_top_width, 1600)? == 2
	assert first.property(.transform, .yes)?.css_text == 'translate(6px, 8px)'
	source.set_property_without_modifying_flags(.width,
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(8)))))
	second := computed_style_in_layout_coordinates(source, document)
	assert voidptr(second) != voidptr(first)
	assert first.length_percentage_to_px(.width, 1600)? == 0
	assert second.length_percentage_to_px(.width, 1600)? == 16
	assert source.length_percentage_to_px(.width, 800)? == 8
}

fn test_projection_preserves_untyped_dom_values_and_dimensionless_animation_values() {
	mut document, mut source := borrowed_projection_test_style()
	defer { document.finalize() }
	source.set_property_without_modifying_flags(.width, &dom.StyleValue{ css_text: 'calc(50% - 3px)' })
	source.set_property_without_modifying_flags(.border_top_width, &dom.StyleValue{ css_text: '5px' })
	source.set_property_without_modifying_flags(.outline_width,
		dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.thick))))
	source.set_property_without_modifying_flags(.padding_left, &dom.StyleValue{ css_text: '0px' })
	animated := dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(0.25)))
	source.set_animated_property(.opacity, animated, .no, .no)
	for scale in [0.5, 2.0, 3.0] {
		document.set_layout_coordinate_scale(scale)
		projected := computed_style_in_layout_coordinates(source, document)
		assert projected.length_percentage_to_px(.width, 800 * scale)? == 397 * scale
		assert projected.length_percentage_to_px(.border_top_width, 800 * scale)? == 5 * scale
		assert projected.length_percentage_to_px(.outline_width, 800 * scale)? == 5 * scale
		assert voidptr(projected.property(.padding_left, .yes)?) == voidptr(source.property(.padding_left, .yes)?)
		assert voidptr(projected.property(.opacity, .yes)?) == voidptr(animated)
	}
}

fn test_projection_borrows_invariant_compounds_and_rechecks_nested_mutations() {
	mut document, mut source := borrowed_projection_test_style()
	defer { document.finalize() }
	for scale in [0.5, 2.0, 3.0] {
		document.set_layout_coordinate_scale(scale)
		projected := computed_style_in_layout_coordinates(source, document)
		for property in [PropertyID.background_size, .border_top_left_radius, .text_indent,
			.transform_origin] {
			assert voidptr(projected.property(property, .yes)?) == voidptr(source.property(property, .yes)?)
		}
	}

	// A new length inside a formerly invariant list must invalidate the projection.
	size := StyleValue(BackgroundSizeStyleValue.create(
		StyleValue(LengthStyleValue.create(Length.make_px(4))),
		StyleValue(PercentageStyleValue.create(Percentage.new(25)))))
	changed := StyleValue(StyleValueList.create([size], .comma, .no))
	source.set_property_without_modifying_flags(.background_size, dom_style_value_from_value_logic(changed))
	document.set_layout_coordinate_scale(2)
	projected := computed_style_in_layout_coordinates(source, document)
	assert projected.property(.background_size, .yes)?.css_text == '8px 25%'
	assert source.property(.background_size, .yes)?.css_text == '4px 25%'

	// Untyped values take the same path, including preservation of percentages.
	source.set_property_without_modifying_flags(.background_size, &dom.StyleValue{ css_text: '0px 25%' })
	unchanged := computed_style_in_layout_coordinates(source, document)
	assert voidptr(unchanged.property(.background_size, .yes)?) == voidptr(source.property(.background_size, .yes)?)
}

fn test_projection_invariant_compounds_match_absolutization_and_keep_context_sensitive_leaves() {
	zero := StyleValue(LengthStyleValue.create(Length.make_px(0)))
	percentage := StyleValue(PercentageStyleValue.create(Percentage.new(50)))
	radius := StyleValue(BorderRadiusStyleValue.create(zero, percentage))
	values := [
		StyleValue(StyleValueList.create([zero, percentage,
			StyleValue(KeywordStyleValue.create(.currentcolor)),
			StyleValue(NumberStyleValue.create(1))], .space, .no)),
		StyleValue(BackgroundSizeStyleValue.create(StyleValue(KeywordStyleValue.create(.auto)), percentage)),
		StyleValue(BorderRadiusRectStyleValue.create(radius, radius, radius, radius)),
		StyleValue(PositionStyleValue.create_computed_center()),
		StyleValue(TextIndentStyleValue.create(zero, .yes, .yes)),
	]
	for scale in [0.5, 2.0, 3.0] {
		mut context := ComputationContext{}
		context.length_resolution_context.absolute_length_scale = scale
		for value in values {
			assert device_layout_value_is_projection_invariant(&value)
			assert value.absolutized(context).equals(value)
		}
	}

	// A list itself supplies no proof about its children. Colors, unresolved
	// edges, calculations and even number-only matrices still require dispatch.
	for text in ['4px', '0em', 'calc(50% - 3px)', 'Canvas'] {
		property := if text == 'Canvas' { PropertyID.color } else { PropertyID.width }
		value := parse_css_value_logic(property, text) or { panic('missing ${text}') }
		list := StyleValue(StyleValueList.create([value], .space, .no))
		assert !device_layout_value_is_projection_invariant(&list)
	}
	for value in [StyleValue(EdgeStyleValue.create(.right, none)),
		StyleValue(TransformationStyleValue.create(.transform, .matrix, [
			StyleValue(NumberStyleValue.create(1)), StyleValue(NumberStyleValue.create(0)),
			StyleValue(NumberStyleValue.create(0)), StyleValue(NumberStyleValue.create(1)),
			StyleValue(NumberStyleValue.create(3)), StyleValue(NumberStyleValue.create(4)),
		])), StyleValue(NumberStyleValue.create(math.nan()))] {
		list := StyleValue(StyleValueList.create([value], .space, .no))
		assert !device_layout_value_is_projection_invariant(&list)
	}
}
