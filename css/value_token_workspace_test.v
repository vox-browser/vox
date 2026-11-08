module css

import dom
import platform

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_component_text_ownership_survives_the_original_token_payloads() {
	scratch := platform.begin_thread_scratch('test decoded component text')
	mut components := parse_component_values_for_value_logic(r'n\61 me fn(f\61 mily)')
	scratch.leave()
	own_value_component_text(mut components)
	// Headers, vectors and decoded strings belong to the retained owner.
	identifier := components[0].token().value
	function := components[2].function()
	name := function.name
	argument := function.value[0].token().value
	original := function.value[0].token().original_source_text_
	scratch.finish()
	$if gcboehm ? { C.GC_gcollect() }
	assert identifier == 'name'
	assert name == 'fn'
	assert argument == 'family'
	assert original == r'f\61 mily'
}

fn test_property_values_own_decoded_strings_and_typed_geometry_after_token_retirement() {
	properties := [PropertyID.content, .font_family, .animation_name, .background_image,
		.grid_template_columns, .width, .left, .transform, .color, .border_radius]
	sources := [r'"esc\61 ped"', r'"f\61 mily", serif', r'n\61 me',
		r'image-set(url("esc\61 ped.png") 1x, url(other.png) 2x)',
		r'[st\61 rt] minmax(10px, 1fr) [end]', 'calc(13px + 2%)',
		'calc(anchor(left, 7px) + 3px)', 'translate(3px, 4px) rotate(10deg)',
		'rgb(12 34 56 / 50%)', '10px 20px / 30px']
	for i, property in properties {
		mut reference := Parser.from_css_text(sources[i])
		expected := (reference.parse_css_value(property) or { panic('reference parse failed: ${sources[i]}') }).serialize(.normal)
		value := parse_css_value_logic(property, sources[i]) or { panic('workspace parse failed: ${sources[i]}') }
		$if gcboehm ? { C.GC_gcollect() }
		assert value.serialize(.normal) == expected
	}
}

fn test_unresolved_property_values_own_nested_components_and_original_token_text() {
	source := r'var(--esc\61 ped, calc(7px + env(safe-area-inset-left, 2px)))'
	mut parser := Parser.from_css_text(source)
	reference := parser.parse_css_value(.width) or { panic('reference unresolved parse failed') }
	expected := reference.serialize(.normal)
	value := parse_css_value_logic(.width, source) or { panic('workspace unresolved parse failed') }
	assert value is UnresolvedStyleValue
	$if gcboehm ? { C.GC_gcollect() }
	assert value.serialize(.normal) == expected
	assert value.includes_var_function() && value.includes_env_function()
	assert value.tokens[0].original_source_text() == source
	function := value.tokens[0].function()
	assert function.value[0].token().value == '--escaped'
}

fn test_svg_and_document_property_parses_keep_their_context_after_token_retirement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	value := parse_svg_presentation_attribute_value(document, .stroke_width, '12') or { panic('missing SVG width') }
	assert value.serialize(.normal) == '12'
	parsed := parse_css_value(ParsingParams{document: document}, r'"f\61 mily", serif', .font_family) or { panic('missing document font') }
	assert parsed.css_text.contains('family')
}

fn test_property_parse_retires_large_token_input_instead_of_retaining_its_vectors() {
	source := '/* ignored during property parsing */'.repeat(4096) + '17px'
	before := platform.thread_arena_usage().used
	for _ in 0 .. 4 {
		value := parse_css_value_logic(.width, source) or { panic('missing width') }
		assert value.serialize(.normal) == '17px'
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 32768 }
}

fn test_cached_property_values_survive_token_retirement_and_cache_reset() {
	begin_selector_parse_cache()
	value := parse_css_value_logic(.font_family, r'"f\61 mily", serif') or { panic('missing cached font') }
	again := parse_css_value_logic(.font_family, r'"f\61 mily", serif') or { panic('missing reused font') }
	assert css_parsed_value_cache[ int(PropertyID.font_family) ].len == 1
	end_selector_parse_cache()
	assert !css_parsed_value_cache_enabled && css_parsed_value_cache.len == 0
	$if gcboehm ? { C.GC_gcollect() }
	assert value.serialize(.normal) == again.serialize(.normal)
	assert value.serialize(.normal).contains('family')
}

fn assert_value_export_does_not_share_payloads(original ComponentValue, owned ComponentValue) {
	assert original.original_source_text() == owned.original_source_text()
	if original.is_token() {
		assert owned.is_token()
		assert component_export_payload_address(original) != component_export_payload_address(owned)
		assert original.token() == owned.token()
	} else if original.is_function() {
		assert owned.is_function()
		assert component_export_payload_address(original) != component_export_payload_address(owned)
		one := original.function()
		two := owned.function()
		assert one.name == two.name && one.value.len == two.value.len
		if one.value.len > 0 { assert voidptr(one.value.data) != voidptr(two.value.data) }
		for index, child in one.value { assert_value_export_does_not_share_payloads(child, two.value[index]) }
	} else if original.is_block() {
		assert owned.is_block()
		assert component_export_payload_address(original) != component_export_payload_address(owned)
		one := original.block()
		two := owned.block()
		assert one.value.len == two.value.len
		if one.value.len > 0 { assert voidptr(one.value.data) != voidptr(two.value.data) }
		for index, child in one.value { assert_value_export_does_not_share_payloads(child, two.value[index]) }
	}
}

fn test_component_export_preserves_shared_syntax_headers_and_vectors() {
	original := ParserTokenStream.from_source(r'n\61 me fn(f\61 mily ["word"])', 'utf-8').values
	name_pointer := original[0].token().value.str
	argument_pointer := original[2].function().value[0].token().value.str
	mut owned := unsafe { original }
	own_value_component_text(mut owned)
	assert voidptr(original.data) != voidptr(owned.data)
	assert voidptr(original[0].token().value.str) == voidptr(name_pointer)
	assert voidptr(original[2].function().value[0].token().value.str) == voidptr(argument_pointer)
	for index, component in original { assert_value_export_does_not_share_payloads(component, owned[index]) }
}

fn component_export_payload_address(component ComponentValue) voidptr {
	match component.value {
		&Token { return voidptr(component.value) }
		&Function { return voidptr(component.value) }
		&SimpleBlock { return voidptr(component.value) }
		else { return unsafe { nil } }
	}
}
