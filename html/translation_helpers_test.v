module html

import dom
import math
import x.json2

fn test_audio_play_state_and_binding_navigation_type_helpers() {
	assert invert_mute_state(.muted) == .unmuted
	assert invert_mute_state(.unmuted) == .muted
	assert idl_enum_to_string(.push) == 'push'
	assert idl_enum_to_string(.replace) == 'replace'
	assert idl_enum_to_string(.reload) == 'reload'
	assert idl_enum_to_string(.traverse) == 'traverse'
}

fn test_normalize_non_finite_scroll_values() {
	assert normalize_non_finite_values(12.5) == 12.5
	assert normalize_non_finite_values(math.inf(1)) == 0
	assert normalize_non_finite_values(math.inf(-1)) == 0
	assert normalize_non_finite_values(math.nan()) == 0
	assert normalize_optional_non_finite_values(none) == 0
	assert normalize_optional_non_finite_values(7.0) == 7.0
}

fn test_canvas_rendering_context_static_helpers() {
	state := DrawingState{ letter_spacing_px: 2.5 }
	assert resolved_letter_spacing(state) == 2.5
	assert to_gfx_cap(.round) == .round
	assert to_gfx_join(.bevel) == .bevel
	assert parse_fill_rule('evenodd') == 'evenodd'
	assert parse_fill_rule('nonzero') == 'nonzero'
	assert parse_fill_rule('invalid') == 'nonzero'
	image := ImageBitmap.create()
	assert !image_is_not_origin_clean(CanvasImageSource(ImageBitmapCanvasSource{ value: image }))
}

fn test_custom_element_webidl_conversion_helpers() {
	callback := &dom.CallbackType{}
	assert convert_value_to_callback_function(dom.js_object(voidptr(callback)))! == callback
	if _ := convert_value_to_callback_function(dom.js_string('not callable')) {
		assert false
	}
	values := convert_value_to_sequence_of_strings([
		dom.js_string('value'),
		dom.js_number(3),
		dom.js_bool(true),
		dom.js_null(),
	])!
	assert values == ['value', '3.0', 'true', 'null']
}

fn test_input_and_parser_static_helpers() {
	assert is_integral_multiple(0.3, 0.1)
	assert !is_integral_multiple(0.35, 0.1)
	assert is_applicable_for_maxlength_attribute(.text)
	assert !is_applicable_for_maxlength_attribute(.number)
	assert is_allowed_to_have_placeholder(.number)
	assert !is_allowed_to_have_placeholder(.checkbox)
	assert inner_text_style_when_visible().contains('overflow:auto')
	assert inner_text_style_when_hidden() == 'width:0;display:inline;'
	assert stepper_button_style_when_visible().contains('cursor:default')
	assert stepper_button_style_when_hidden() == 'display:none;'
	assert placeholder_style_when_visible().contains('overflow:hidden')
	assert placeholder_style_when_hidden() == 'display:none;'

	assert ascii_alphabetic_to_index(`A`) == 0
	assert ascii_alphabetic_to_index(`Z`) == 25
	assert ascii_alphabetic_to_index(`a`) == 26
	assert ascii_alphabetic_to_index(`z`) == 51
	assert is_whitespace_or_slash(`\t`)
	assert is_whitespace_or_slash(`/`)
	assert is_whitespace_or_end_chevron(`>`)
	assert !is_whitespace_or_end_chevron(`x`)
	assert parse_current_dimension_value(5, '%tail').percentage
	assert parse_dimension_value(' 12.5%junk')? == LegacyDimension{ value: 12.5, percentage: true }
	assert parse_nonzero_dimension_value('0') == none
	assert parse_nonzero_dimension_value('2px')?.value == 2
	assert parse_legacy_color_value('#123')? == dom.Color{ r: 17, g: 34, b: 51, a: 255 }
	assert parse_border('12') == 12
	assert parse_border('-1') == 0
}

fn test_collection_canvas_and_import_map_boundary_helpers() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut input := document.create_element_ns(namespace_html, 'input')!
	input.set_attribute_value('type', 'radio')
	assert radio_button(input.as_node())? == unsafe { &dom.HTMLInputElement(input) }
	input.set_attribute_value('type', 'text')
	assert radio_button(input.as_node()) == none

	assert options_convert_or_default(none) == ImageEncodeOptions{}
	options := options_convert_or_default(ImageEncodeOptions{ type_: 'image/jpeg', quality: 0.75 })
	assert options.type_ == 'image/jpeg'
	assert options.quality? == 0.75
	object_value := json2.decode[json2.Any]('{"value":1}')!
	array_value := json2.decode[json2.Any]('[1]')!
	assert value_is_ordered_map(object_value)
	assert !value_is_ordered_map(array_value)
}

fn test_merge_with_the_next_text_node_boundary() {
	document := dom.Document.create_for_fragment_parsing()
	mut fragment := document.create_document_fragment()
	mut fragment_node := unsafe { &dom.Node(fragment) }
	mut first := document.create_text_node('first')
	second := document.create_text_node('second')
	fragment_node.append_child(first.as_node())!
	fragment_node.append_child(second.as_node())!
	merge_with_the_next_text_node(first)
	assert first.data() == 'firstsecond'
	assert fragment_node.child_count() == 1
	assert rendered_text_collection_steps(fragment_node).len == 0
}

fn test_determine_origin_and_creation_sandboxing_flags() {
	source := dom.Origin{ value: 'https://source.test' }
	assert determine_the_origin(none, SandboxingFlagSet{}, source).value == 'opaque'
	assert determine_the_origin(dom.URL{ value: 'about:srcdoc' }, SandboxingFlagSet{}, source) == source
	assert determine_the_origin(dom.URL{ value: 'about:blank' }, SandboxingFlagSet{}, source) == source
	assert determine_the_origin(dom.URL{ value: 'https://target.test/path' }, SandboxingFlagSet{}, source).value == 'https://target.test'
	sandboxed := SandboxingFlagSet{ bits: u32(SandboxingFlag.sandboxed_origin) }
	assert determine_the_origin(dom.URL{ value: 'https://target.test/' }, sandboxed, source).value == 'opaque'

	mut context := BrowsingContextModel.create(none, none, '')
	popup_flags := SandboxingFlagSet{ bits: u32(SandboxingFlag.sandboxed_scripts) }
	context.set_popup_sandboxing_flag_set(popup_flags)
	assert determine_the_creation_sandboxing_flags(context, none).contains(.sandboxed_scripts)

	mut document := dom.Document.create(dom.URL{ value: 'https://embedder.test/' })
	document.set_active_sandboxing_flag_set(dom.SandboxingFlagSet{ sandboxed_forms: true })
	iframe_element := document.create_element_ns(namespace_html, 'iframe')!
	iframe := unsafe { &dom.HTMLIFrameElement(iframe_element) }
	mut iframe_model := html_iframe_element_model_for_dom_element(iframe)
	iframe_model.set_sandbox('allow-same-origin allow-forms allow-scripts allow-popups allow-top-navigation allow-pointer-lock allow-popups-to-escape-sandbox allow-modals allow-orientation-lock allow-presentation allow-downloads allow-top-navigation-to-custom-protocols')
	creation_flags := determine_the_creation_sandboxing_flags(context, iframe_element)
	assert creation_flags.contains(.sandboxed_navigation)
	assert creation_flags.contains(.sandboxed_forms)
}

fn test_user_agent_browsing_context_group_set_exposes_registered_groups() {
	initial_count := user_agent_browsing_context_group_count()
	page := &dom.Page{}
	mut group := BrowsingContextGroup.create(page)
	assert user_agent_browsing_context_group_count() == initial_count + 1
	assert user_agent_browsing_context_group_set().any(voidptr(it) == voidptr(group))
	group.finalize()
	assert user_agent_browsing_context_group_count() == initial_count
}
