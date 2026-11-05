module css

import dom

struct PropertyValueSourceObservation {
mut:
	ids   []PropertyID
	value &dom.StyleValue = unsafe { nil }
}

fn property_source_test_value(property_id PropertyID, text string) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, property_id) or { panic(text) }
}

fn property_source_test_layer_count(value &dom.StyleValue) int {
	typed := typed_style_value_logic_from_dom(value) or { panic('missing typed list') }
	if typed is StyleValueList {
		return typed.size()
	}
	panic('missing coordinated list')
}

fn test_custom_property_lookup_remains_lazy_and_survives_collection() {
	mut observed := &PropertyValueSourceObservation{
		value: property_source_test_value(.background_image, 'none, none, none')
	}
	handle := voidptr(observed)
	lookup := fn [handle] (id PropertyID) &dom.StyleValue {
		mut state := unsafe { &PropertyValueSourceObservation(handle) }
		state.ids << id
		gc_collect()
		return state.value
	}
	opacity := StyleComputer.compute_value_of_property(.opacity,
		property_source_test_value(.opacity, '0.5'), lookup, ComputationContext{}, 1)
	assert observed.ids.len == 0
	assert computed_interpolation_number_from_dom_style_value(opacity)? == 0.5
	attachment := StyleComputer.compute_value_of_property(.background_attachment,
		property_source_test_value(.background_attachment, 'fixed'), lookup, ComputationContext{}, 1)
	assert observed.ids == [PropertyID.background_image]
	assert property_source_test_layer_count(attachment) == 3
	observed.value = property_source_test_value(.math_depth, '2')
	font_size := StyleComputer.compute_value_of_property(.font_size,
		property_source_test_value(.font_size, 'math'), lookup, ComputationContext{}, 1)
	assert observed.ids == [PropertyID.background_image, .math_depth]
	assert computed_interpolation_length_from_dom_style_value(font_size)?.absolute_length_to_px().raw_value() == 516
}

fn test_cascade_property_source_reads_current_background_and_math_depth() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element('div')!
	element.set_attribute_value('style', 'background-image:none,none,none;background-attachment:fixed;font-size:math;math-depth:2')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	attachment := computed.property(.background_attachment, .no)?
	assert property_source_test_layer_count(attachment) == 3
	assert computed.math_depth() == 2
	assert computed.font_size().raw_value() == 516
	assert !computed.is_property_inherited(.background_attachment)
	assert !computed.is_property_inherited(.font_size)
}

fn test_recomputation_property_source_observes_replaced_values_and_keeps_flags() {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element('div')!
	subject := dom.AbstractElement.new(element, none)
	mut computed := computed_properties_with_initial_values()
	for count in [2, 3] {
		images := if count == 2 { 'none, none' } else { 'none, none, none' }
		computed.set_property(.background_image, property_source_test_value(.background_image, images), .no, .no)
		computed.set_property(.background_attachment, property_source_test_value(.background_attachment, 'scroll'), .yes, .yes)
		computed.set_property(.math_depth, property_source_test_value(.math_depth, '2'), .no, .no)
		computed.set_property(.font_size, property_source_test_value(.font_size, 'math'), .no, .no)
		gc_collect()
		StyleComputer.new(document).compute_property_values(mut computed, subject)
		attachment := computed.property(.background_attachment, .no)?
		assert property_source_test_layer_count(attachment) == count
		assert computed.font_size().raw_value() == 516
		assert computed.is_property_inherited(.background_attachment)
		assert computed.is_property_important(.background_attachment)
	}
}

fn test_keyframe_lookup_keeps_specified_overlay_and_computed_fallback() {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element('div')!
	subject := dom.AbstractElement.new(element, none)
	mut base := computed_properties_with_initial_values()
	base.set_property(.math_depth, property_source_test_value(.math_depth, '2'), .no, .no)
	with_images := ResolvedKeyFrame{
		properties: {
			PropertyID.background_image: property_source_test_value(.background_image, 'none,none,none')
			.background_attachment: property_source_test_value(.background_attachment, 'fixed')
			.font_size: property_source_test_value(.font_size, 'math')
		}
	}
	values := StyleComputer.new(document).compute_keyframe_values(subject, with_images, base)
	assert property_source_test_layer_count(values[.background_attachment] or { panic('missing attachment') }) == 3
	assert computed_interpolation_length_from_dom_style_value(values[.font_size] or { panic('missing size') })?.absolute_length_to_px().raw_value() == 516
	base.set_property(.background_image, property_source_test_value(.background_image, 'none,none'), .no, .no)
	without_images := ResolvedKeyFrame{
		properties: {PropertyID.background_attachment: property_source_test_value(.background_attachment, 'scroll')}
	}
	fallback := StyleComputer.new(document).compute_keyframe_values(subject, without_images, base)
	assert property_source_test_layer_count(fallback[.background_attachment] or { panic('missing fallback') }) == 2
}
