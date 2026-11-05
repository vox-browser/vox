module css

import platform

fn transformation_export_assert_equivalent(actual StyleValue, expected StyleValue) {
	assert actual.equals(expected)
	assert actual.serialize(.normal) == expected.serialize(.normal)
	assert actual.serialize(.resolved_value) == expected.serialize(.resolved_value)
	if actual is TransformationStyleValue && expected is TransformationStyleValue {
		assert actual.property_ == expected.property_
		assert actual.transform_function_ == expected.transform_function_
		for width in [64.0, 257.5] {
			box := TransformPaintableBox{reference_box: TransformReferenceBox{
				width: CSSPixels.nearest_value_for(width)
				height: CSSPixels.nearest_value_for(width / 2)
			}}
			a := actual.to_matrix(box) or { panic('actual matrix') }
			b := expected.to_matrix(box) or { panic('expected matrix') }
			assert a == b
		}
	} else if actual is StyleValueList && expected is StyleValueList {
		assert actual.values_.len == expected.values_.len
		for index, value in actual.values_ {
			transformation_export_assert_equivalent(value, expected.values_[index])
		}
	}
}

fn test_transformation_export_matches_every_transform_function_and_individual_property() {
	sources := ['matrix(1,0,0,1,13,7)',
		'matrix3d(1,0,0,0,0,1,0,0,0,0,1,0,13,7,2,1)', 'perspective(30px)',
		'translate(3px,20%)', 'translate3d(3px,20%,4px)', 'translateX(4%)',
		'translateY(7px)', 'translateZ(-2px)', 'scale(.5, 120%)', 'scale3d(1,2,3)',
		'scaleX(.25)', 'scaleY(2)', 'scaleZ(3)', 'rotate(1turn)', 'rotate3d(1,2,3,45deg)',
		'rotateX(30deg)', 'rotateY(.3rad)', 'rotateZ(-2grad)', 'skew(3deg,7deg)',
		'skewX(7deg)', 'skewY(-7deg)', 'translate(10%,20%) rotate(calc(1turn / 3))',
		'translateX(calc(100% - 3px)) scale(calc(.5 + .25))']
	for source in sources {
		mut parser := Parser.from_css_text(source)
		expected := parser.parse_css_value(.transform) or { panic(source) }
		actual := parse_css_value_logic(.transform, source) or { panic(source) }
		assert property_value_can_export(expected) == (!retain_transform_value_reparse
			&& (!source.contains('calc(') || !retain_calculated_value_reparse)), source
		transformation_export_assert_equivalent(actual, expected)
	}
	for property, texts in {
		PropertyID.rotate: ['45deg', 'x 30deg', '1 2 3 calc(1turn / 3)']
		.scale: ['.5', '50% 125%', '1 2 3', 'calc(.5 + .25)']
		.translate: ['3px', '20% 3px', 'calc(100% - 3px) 20% 4px']
	} {
		for source in texts {
			mut parser := Parser.from_css_text(source)
			expected := parser.parse_css_value(property) or { panic(source) }
			actual := parse_css_value_logic(property, source) or { panic(source) }
			assert property_value_can_export(expected) == (!retain_transform_value_reparse
				&& (!source.contains('calc(') || !retain_calculated_value_reparse)), source
			transformation_export_assert_equivalent(actual, expected)
		}
	}
}

fn transformation_export_fixture() TransformationStyleValue {
	return TransformationStyleValue.create(.transform, .translate3d, [
		StyleValue(LengthStyleValue.create(Length.new(1.25, .em))),
		StyleValue(PercentageStyleValue.create(Percentage.new(25))),
		StyleValue(calculated_export_fixture()),
	])
}

fn test_transformation_export_detaches_arguments_and_calculations_from_retired_workspace() {
	mut owner := platform.new_retained_arena('transform export destination')
	mut entered := owner.enter()
	expected := transformation_export_fixture()
	work := platform.begin_thread_scratch('transform export source')
	mut source := transformation_export_fixture()
	assert transformation_property_value_can_export(source) == !retain_calculated_value_reparse
	work.leave()
	actual := export_transformation_property_value(source)
	assert actual.values_.data != source.values_.data
	source.values_[0] = StyleValue(LengthStyleValue.create(Length.make_px(999)))
	mut calculated := source.values_[2] as CalculatedStyleValue
	calculated.node.clear()
	calculated.calculation_context.accepted_type_ranges[.length] = AcceptedTypeRange{min: 999, max: 1000}
	source.values_.clear()
	work.finish()
	churn := platform.begin_thread_scratch('transform export overwrite')
	_ = []u8{len: 256 * 1024, init: u8(0xa5)}
	churn.finish()
	transformation_export_assert_equivalent(StyleValue(actual), StyleValue(expected))
	$if prealloc { assert owner.arena.contains(actual.values_.data) }
	owned_calculated := actual.values_[2] as CalculatedStyleValue
	assert owned_calculated.calculation_context == (expected.values_[2] as CalculatedStyleValue).calculation_context
	calculated_export_assert_owned(owned_calculated.node[0], owner)
	entered.finish()
	owner.release()
}

fn test_transformation_export_preserves_relative_units_until_later_absolutization() {
	for source in ['translate(2em, 20%)', 'translateX(calc(10vw + 3px))',
		'translate3d(1rem, 2vh, calc(2em + 3px))', 'rotate(calc(1turn / 3))'] {
		mut parser := Parser.from_css_text(source)
		expected := parser.parse_css_value(.transform) or { panic(source) }
		actual := parse_css_value_logic(.transform, source) or { panic(source) }
		for scale in [1.0, 2.0] {
			context := ComputationContext{length_resolution_context: LengthResolutionContext{
				...LengthResolutionContext.default()
				absolute_length_scale: scale
				viewport_rect: CSSPixelRect.new(0, 0, 1024 * scale, 768 * scale)
			}}
			a := actual.absolutized(context)
			b := expected.absolutized(context)
			transformation_export_assert_equivalent(a, b)
		}
	}
}

fn test_transformation_export_rejects_dependent_or_unsupported_arguments_before_publication() {
	for source in ['translateX(calc(2px * sibling-index()))',
		'translate(1px, calc(2px * sibling-count()))', 'perspective(none)'] {
		mut parser := Parser.from_css_text(source)
		expected := parser.parse_css_value(.transform) or { panic(source) }
		assert !property_value_can_export(expected)
		actual := parse_css_value_logic(.transform, source) or { panic('fallback') }
		assert actual.equals(expected)
		assert actual.serialize(.normal) == expected.serialize(.normal)
	}
	for source in ['translateX(var(--travel))', 'translateX(calc(2px +))',
		'translate(1px,2px,3px)', 'matrix(1,0,0,1,2)', 'scale3d(1,2)'] {
		mut parser := Parser.from_css_text(source)
		expected := parser.parse_css_value(.transform)
		actual := parse_css_value_logic(.transform, source)
		assert (actual == none) == (expected == none)
		if a := actual {
			b := expected or { panic('reference') }
			assert !property_value_can_export(b)
			assert a.serialize(.normal) == b.serialize(.normal)
		}
	}
}

fn test_transformation_export_inspection_is_bounded_and_allocation_free() {
	leaf := StyleValue(NumberStyleValue.create(1))
	valid := TransformationStyleValue.create(.transform, .matrix3d,
		[]StyleValue{len: 16, init: leaf})
	oversized := TransformationStyleValue.create(.transform, .matrix3d,
		[]StyleValue{len: 17, init: leaf})
	mut unsupported := TransformationStyleValue.create(.transform, .matrix3d,
		valid.values_.clone())
	unsupported.values_[15] = StyleValue(UnresolvedStyleValue{})
	nested := StyleValue(StyleValueList.create([StyleValue(unsupported)], .space, .no))
	start := platform.thread_arena_usage().used
	for _ in 0 .. 64 {
		assert transformation_property_value_can_export(valid)
		assert !transformation_property_value_can_export(TransformationStyleValue{})
		assert !transformation_property_value_can_export(oversized)
		assert !transformation_property_value_can_export(unsupported)
		assert !property_value_can_export(nested)
	}
	$if prealloc { assert platform.thread_arena_usage().used == start }
}
