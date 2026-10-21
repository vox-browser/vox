module css

import dom
import math
import os

fn computed_length_owner_value(length Length) &dom.StyleValue {
	box := &TypedStyleValueBox{value: StyleValue(LengthStyleValue.create(length))}
	return &dom.StyleValue{css_text: 'stale serialization', css_value_handle: unsafe { voidptr(box) }}
}

fn test_computed_length_owner_preserves_all_units_and_scalar_bits() {
	mut style := ComputedProperties.new()
	for unit in [LengthUnit.px, .pt, .in_, .cm, .mm, .q, .pc, .em, .rem, .ex, .ch,
		.cap, .ic, .lh, .rlh, .vw, .vh, .cqw, .cqh, .cqi] {
		for number in [-19.25, -0.0, 0.0, 1.0 / 128, 1e100,
			math.f64_from_bits(u64(0x7ff8000000004321)), math.inf(1), math.inf(-1)] {
			value := computed_length_owner_value(Length.new(number, unit))
			style.set_property(.letter_spacing, value, .no, .no)
			actual := style.length(.letter_spacing)
			assert actual.unit() == unit
			assert math.f64_bits(actual.raw_value()) == math.f64_bits(number)
			oracle := Length.from_style_value(value, none)
			assert actual.unit() == oracle.unit()
			assert math.f64_bits(actual.raw_value()) == math.f64_bits(oracle.raw_value())
		}
	}
}

fn test_computed_length_owner_keeps_missing_serialized_and_other_typed_fallbacks() {
	mut style := ComputedProperties.new()
	probe := os.getenv('VOX_COMPUTED_LENGTH_PERCENTAGE_PANIC')
	if probe != '' {
		value := if probe == 'retained' {
			dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(Percentage.new(25))))
		} else {
			&dom.StyleValue{css_text: '25%'}
		}
		style.set_property(.width, value, .no, .no)
		_ = style.length(.width)
		panic('percentage without a basis unexpectedly returned')
	}
	for mode in ['retained', 'serialized'] {
		child := os.execute('VOX_COMPUTED_LENGTH_PERCENTAGE_PANIC=${mode} ${os.quoted_path(os.executable())}')
		assert child.exit_code == 1
		assert child.output.contains('VERIFY_NOT_REACHED')
		assert !child.output.contains('percentage without a basis unexpectedly returned')
	}
	assert style.length(.width) == Length.make_px(0)
	for text, expected in {'12px': 12.0, '-2.5px': -2.5,
		'calc(2px + 3px)': 5.0, 'auto': 0.0, 'normal': 0.0, '12px trailing': 0.0} {
		value := &dom.StyleValue{css_text: text}
		style.set_property(.width, value, .no, .no)
		assert style.length(.width) == Length.make_px(expected)
		assert style.length(.width) == Length.from_style_value(value, none)
	}
	for typed in [StyleValue(KeywordStyleValue.create(.normal)), StyleValue(NumberStyleValue.create(9))] {
		mut value := dom_style_value_from_value_logic(typed)
		value.css_text = '99px'
		style.set_property(.width, value, .no, .no)
		assert style.length(.width) == Length.make_px(0)
		assert style.length(.width) == Length.from_style_value(value, none)
	}
	calculated := parse_css_value(ParsingParams{}, 'calc(2px + 3px)', .width) or { panic(err) }
	style.set_property(.width, calculated, .no, .no)
	assert style.length(.width) == Length.make_px(5)
}

fn test_computed_length_owner_keeps_animation_precedence_and_live_handle_reads() {
	mut style := ComputedProperties.new()
	mut base := computed_length_owner_value(Length.new(1.25, .em))
	animated := computed_length_owner_value(Length.make_px(27.5))
	style.set_property(.width, base, .no, .yes)
	style.set_animated_property(.width, animated, .no, .no)
	assert style.length(.width) == Length.new(1.25, .em)
	style.set_animated_property(.width, animated, .yes, .no)
	assert style.length(.width) == Length.make_px(27.5)
	style.remove_animated_property(.width)
	snapshot := style.length(.width)
	base.css_value_handle = animated.css_value_handle
	gc_collect()
	assert style.length(.width) == Length.make_px(27.5)
	base.css_value_handle = unsafe { nil }
	base.css_text = '7px'
	assert style.length(.width) == Length.make_px(7)
	assert snapshot == Length.new(1.25, .em)
}
