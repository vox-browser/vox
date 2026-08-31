module css

import dom

// Runtime smoke test of the ported CSS value parser. Validates that parsing +
// shorthand expansion + serialization work end to end now that the module
// compiles and runs natively. Guards against the first-token-drop regression
// (a failed CSS-wide-keyword probe used to swallow the value's first token).
fn parsed(text string, property PropertyID) ?string {
	value := parse_css_value(ParsingParams{}, text, property) or { return none }
	return value.css_text
}

fn test_longhands() {
	assert parsed('42px', PropertyID.width)? == '42px'
	assert parsed('red', PropertyID.color)? == 'red'
	assert parsed('block', PropertyID.display)? == 'block'
	assert parsed('0.5', PropertyID.opacity)? == '0.5'
}

fn test_box_shorthands_expand_all_four_edges() {
	// margin/padding are positional-value-list shorthands: they expand to four longhands
	// and serialize with the CSS 4->2->1 shortest-form collapse (upstream
	// serialize_a_positional_value_list).
	assert parsed('1px 2px', PropertyID.margin)? == '1px 2px'
	assert parsed('5px', PropertyID.margin)? == '5px'
	assert parsed('1px 2px 3px 4px', PropertyID.padding)? == '1px 2px 3px 4px'
	assert parsed('1px 2px 1px 2px', PropertyID.margin)? == '1px 2px'
}

fn test_shorthands_first_token_not_dropped() {
	// Single-token values must not be swallowed by the CSS-wide-keyword probe.
	// (overflow-x == overflow-y == auto serializes as a single `auto`.)
	assert parsed('auto', PropertyID.overflow)? == 'auto'
	assert parsed('none', PropertyID.grid_template)?.len > 0
	assert parsed('1px', PropertyID.border)?.len > 0
	assert parsed('solid', PropertyID.border)?.len > 0
}

fn test_multi_component_shorthands() {
	// `||` shorthands where keyword components are followed by more tokens: a
	// component parser must not reject trailing tokens (regression).
	assert parsed('1px solid red', PropertyID.border)?.len > 0
	assert parsed('2px dashed blue', PropertyID.border_top)? == '2px dashed blue'
	assert parsed('thick solid green', PropertyID.outline)?.len > 0
	assert parsed('square inside', PropertyID.list_style)?.len > 0
	assert parsed('underline dotted red', PropertyID.text_decoration)?.len > 0
}

fn test_color_functions() {
	// Low-level numeric parsers must not consume-on-failure: bare-number hue and
	// percentage channels must parse (regression).
	assert parsed('hsl(120, 50%, 50%)', PropertyID.color)?.len > 0
	assert parsed('hsl(120 50% 50%)', PropertyID.color)?.len > 0
	assert parsed('rgb(50%, 50%, 50%)', PropertyID.color)?.len > 0
	assert parsed('rgb(1, 2, 3)', PropertyID.color)?.len > 0
}

fn test_background_layers() {
	// Image + repeat + position + size in a single layer (regression: the image
	// and repeat component parsers used to reject/require trailing tokens).
	assert parsed('url(a.png) no-repeat center / cover', PropertyID.background)?.len > 0
	assert parsed('url(a.png) center', PropertyID.background)?.len > 0
	assert parsed('no-repeat center', PropertyID.background)?.len > 0
	assert parsed('url(m.png) alpha', PropertyID.mask)?.len > 0
}

fn test_coordinated_list_shorthands() {
	// animation/transition components include keyword easings (linear/ease/...);
	// the easing must bind to timing-function, not fall through to name.
	anim := parsed('spin 2s linear', PropertyID.animation)?
	assert anim.contains('linear') && anim.contains('spin')
	trans := parsed('color 1s ease-in 2s', PropertyID.transition)?
	assert trans.contains('ease-in')
}

fn test_css_wide_keyword() {
	assert parsed('inherit', PropertyID.width)? == 'inherit'
}

fn test_invalid_returns_none() {
	assert parsed('not-a-length', PropertyID.width) == none
	assert parsed('12px', PropertyID.color) == none
}

fn test_dom_style_value_retains_typed_css_value() {
	value := parse_css_value(ParsingParams{}, '42px', .width) or {
		panic('width did not parse')
	}
	assert value.css_value_handle != unsafe { nil }
	typed := typed_style_value_logic_from_dom(value) or {
		panic('typed value handle was not retained')
	}
	assert typed is LengthStyleValue
	assert typed.serialize(.normal) == '42px'

	// DOM callers may still construct a serialized-only value. Keep the
	// compatibility parser at that boundary while typed parser output takes the
	// allocation-free path above.
	serialized_only := &dom.StyleValue{
		css_text: '17px'
	}
	assert typed_style_value_logic_from_dom(serialized_only) == none
	fallback := style_value_logic_from_dom(.width, serialized_only) or {
		panic('serialized fallback did not parse')
	}
	assert fallback is LengthStyleValue
	assert fallback.serialize(.normal) == '17px'
}

fn test_initial_values_are_typed_and_cached() {
	first := computed_interpolation_property_initial_value(.width)
	second := computed_interpolation_property_initial_value(.width)
	assert voidptr(first) == voidptr(second)
	assert first.css_value_handle != unsafe { nil }
	assert typed_style_value_logic_from_dom(first) != none
}
