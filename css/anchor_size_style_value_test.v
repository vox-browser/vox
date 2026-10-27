module css

fn test_anchor_size_without_fallback_preserves_optional_components() {
	value := AnchorSizeStyleValue.create(none, none, none)
	assert value.anchor_name() == none
	assert value.anchor_size() == none
	assert value.fallback_value() == none
	assert value.serialize(.normal) == 'anchor-size()'
	assert value.properties_equal(AnchorSizeStyleValue.create(none, none, none))
}

fn test_anchor_size_fallback_keeps_value_equality_and_serialization() {
	fallback := StyleValue(PercentageStyleValue.create(Percentage.new(12)))
	value := AnchorSizeStyleValue.create('--card', .width, fallback)
	assert value.anchor_name()? == '--card'
	assert value.anchor_size()? == .width
	assert value.fallback_value()?.equals(fallback)
	assert value.serialize(.normal) == 'anchor-size(--card width, 12%)'
	assert AnchorSizeStyleValue.create(none, none, fallback).serialize(.normal) == 'anchor-size(12%)'
	assert value.properties_equal(AnchorSizeStyleValue.create('--card', .width,
		StyleValue(PercentageStyleValue.create(Percentage.new(12)))))
	assert !value.properties_equal(AnchorSizeStyleValue.create('--card', .width,
		StyleValue(PercentageStyleValue.create(Percentage.new(13)))))
	assert !value.properties_equal(AnchorSizeStyleValue.create('--card', .width, none))
	assert !value.properties_equal(AnchorSizeStyleValue.create('--other', .width, fallback))
	assert !value.properties_equal(AnchorSizeStyleValue.create('--card', .height, fallback))
}

fn test_anchor_size_can_own_nested_fallback_values() {
	inner := AnchorSizeStyleValue.create('--inner', .height,
		StyleValue(PercentageStyleValue.create(Percentage.new(8))))
	value := AnchorSizeStyleValue.create('--outer', .width, StyleValue(inner))
	assert value.fallback_value()? is AnchorSizeStyleValue
	assert value.serialize(.normal) == 'anchor-size(--outer width, anchor-size(--inner height, 8%))'
	same_inner := AnchorSizeStyleValue.create('--inner', .height,
		StyleValue(PercentageStyleValue.create(Percentage.new(8))))
	assert value.properties_equal(AnchorSizeStyleValue.create('--outer', .width, StyleValue(same_inner)))
}
