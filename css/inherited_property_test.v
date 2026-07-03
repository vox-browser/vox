module css

// Translation of Tests/LibWeb/TestCSSInheritedProperty.cpp.
//
// The C++ test calls the general `CSS::is_inherited_property(PropertyID)`, which accepts
// ANY property (returning false for shorthands). The V port instead exposes a
// longhand-scoped `computed_interpolation_is_inherited_property()` that asserts its argument
// is a translated longhand. The C++ test's negative cases use the shorthands Margin/Padding/
// Border/All, which would trip that assertion here, so this translation substitutes
// non-inherited *longhands* (opacity/display/width/height) to preserve the test's intent.
//
// NOTE: type-checks with `v -check test css/`, but cannot be executed yet due to the
// pre-existing, module-wide V C-codegen bug (unrelated to this test).

fn test_is_inherited_property() {
	// Inherited properties.
	assert computed_interpolation_is_inherited_property(PropertyID.color)
	assert computed_interpolation_is_inherited_property(PropertyID.font_size)
	assert computed_interpolation_is_inherited_property(PropertyID.visibility)

	// Non-inherited longhands (substituted for the C++ test's shorthand negatives, which
	// the port's longhand-scoped helper does not accept).
	assert !computed_interpolation_is_inherited_property(PropertyID.opacity)
	assert !computed_interpolation_is_inherited_property(PropertyID.display)
	assert !computed_interpolation_is_inherited_property(PropertyID.width)
	assert !computed_interpolation_is_inherited_property(PropertyID.height)
}
