module css

fn test_image_set_parses_candidates_descriptors_and_type_filters() {
	parsed := parse_css_image_value_logic('image-set("one.png", url("unsupported.png") 1.5x type("image/unknown"), url("two.png") 2x type("image/webp"))') or {
		panic('failed to parse image-set()')
	}
	assert parsed is ImageSetStyleValue
	image_set := parsed as ImageSetStyleValue
	assert image_set.options_.len == 3
	assert image_set.options_[0].resolution.serialize(.normal) == '1x'
	assert image_set.options_[1].type_? == 'image/unknown'
	assert image_set.options_[2].type_? == 'image/webp'
	assert image_set.select_image_index(1.25)? == 2
	assert image_set.select_image_index(3)? == 2
	assert image_set.serialize(.normal).starts_with('image-set(')
}

fn test_webkit_image_set_serializes_to_canonical_function() {
	parsed := parse_css_image_value_logic('-webkit-image-set(url("one.png") 1x)') or {
		panic('failed to parse -webkit-image-set()')
	}
	assert parsed is ImageSetStyleValue
	assert parsed.serialize(.normal).starts_with('image-set(')
}

fn test_image_set_rejects_invalid_or_nested_candidates() {
	assert parse_css_image_value_logic('image-set()') == none
	assert parse_css_image_value_logic('image-set(image-set(url("nested.png") 1x) 2x)') == none
	assert parse_css_image_value_logic('image-set(url("one.png") 1x 2x)') == none
	assert parse_css_image_value_logic('image-set(url("one.png") type(image/png))') == none
}

fn test_image_set_rejects_attr_tainted_candidate_tokens() {
	mut values := parse_component_values_for_value_logic('image-set(url("tainted.png") 1x)')
	mut function := values[0].function()
	function.value[0].set_attr_tainted()
	values[0] = ComponentValue.from_function(function)
	mut parser := Parser{}
	mut tokens := ComponentValueStream.new(values)
	assert parser.parse_image_value(mut tokens) == none
}
