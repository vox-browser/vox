module css

fn relative_color_value(text string) ?StyleValue {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parser.parse_color_value(mut tokens) or { return none }
	tokens.consume_whitespace()
	if tokens.has_more_tokens() {
		return none
	}
	return value
}

fn relative_specified(text string) string {
	value := relative_color_value(text) or { return 'invalid' }
	return value.serialize(.normal)
}

fn relative_computed(text string) string {
	value := relative_color_value(text) or { return 'invalid' }
	return value.absolutized(ComputationContext{}).serialize(.normal)
}

fn test_relative_color_specified_values_keep_their_origin_and_channels() {
	assert relative_specified('rgba(from rebeccapurple r g b)') == 'rgb(from rebeccapurple r g b)'
	assert relative_specified('rgb(from rgb(20%, 40%, 60%, 80%) r g b / alpha)') == 'rgb(from rgba(51, 102, 153, 0.8) r g b / alpha)'
	assert relative_specified('rgb(from rebeccapurple r g b / .25)') == 'rgb(from rebeccapurple r g b / 0.25)'
	assert relative_specified('rgb(from rebeccapurple b alpha r / g)') == 'rgb(from rebeccapurple b alpha r / g)'
	assert relative_specified('rgb(from rgb(from rebeccapurple r g b) r g b)') == 'rgb(from rgb(from rebeccapurple r g b) r g b)'
	assert relative_specified('rgb(from rebeccapurple r calc(g * 2) 10)') == 'rgb(from rebeccapurple r calc(2 * g) 10)'
	assert relative_specified('rgb(from rebeccapurple none none none / none)') == 'rgb(from rebeccapurple none none none / none)'
	assert relative_specified('hsla(from rebeccapurple 25deg s l / alpha)') == 'hsl(from rebeccapurple 25deg s l / alpha)'
	assert relative_specified('hwb(from rebeccapurple h w b)') == 'hwb(from rebeccapurple h w b)'
	assert relative_specified('lch(from lch(0.7 45 30) l c h / alpha)') == 'lch(from lch(0.7 45 30) l c h / alpha)'
	assert relative_specified('color(from color(srgb 0.7 0.5 0.3) srgb r g b)') == 'color(from color(srgb 0.7 0.5 0.3) srgb r g b)'
	assert relative_specified('color(from color(xyz-d65 0.7 0.5 0.3) xyz-d65 x y z)') == 'color(from color(xyz-d65 0.7 0.5 0.3) xyz-d65 x y z)'
}

fn test_relative_color_rejects_foreign_channels_and_legacy_syntax() {
	assert relative_specified('rgb(from rebeccapurple h g b)') == 'invalid'
	assert relative_specified('rgb(from rebeccapurple r, g, b)') == 'invalid'
	assert relative_specified('rgb(from r g b)') == 'invalid'
	assert relative_specified('hsl(from rebeccapurple h s l / alpha alpha)') == 'invalid'
	assert relative_specified('color(from rebeccapurple r g b)') == 'invalid'
	// Channel keywords are not values outside a relative color.
	assert relative_specified('rgb(r g b)') == 'invalid'
}

fn test_relative_color_computed_values_resolve_in_the_target_space() {
	assert relative_computed('rgb(from rebeccapurple r g b)') == 'color(srgb 0.4 0.2 0.6)'
	assert relative_computed('rgb(from rgb(20%, 40%, 60%, 80%) r g b / alpha)') == 'color(srgb 0.2 0.4 0.6 / 0.8)'
	assert relative_computed('rgb(from rebeccapurple 0 g b / 0)') == 'color(srgb 0 0.2 0.6 / 0)'
	assert relative_computed('rgb(from rebeccapurple r g none / alpha)') == 'color(srgb 0.4 0.2 none)'
	assert relative_computed('rgb(from rgb(none none none) r g b)') == 'color(srgb none none none)'
	assert relative_computed('rgb(from rebeccapurple calc(r) calc(g) calc(b))') == 'color(srgb 0.4 0.2 0.6)'
	assert relative_computed('hsl(from rebeccapurple h s l)') == 'color(srgb 0.4 0.2 0.6)'
	assert relative_computed('hsl(from rebeccapurple h s none)') == 'hsl(270 50 none)'
	assert relative_computed('hsl(from hsl(120deg 20% 50% / .5) none s l / alpha)') == 'hsl(none 20 50 / 0.5)'
	assert relative_computed('lab(from lab(25 20 50 / 40%) l a b / alpha)') == 'lab(25 20 50 / 0.4)'
	assert relative_computed('lab(from lab(200 300 400 / 500%) l a b / alpha)') == 'lab(100 300 400)'
	assert relative_computed('lch(from lch(-200 -300 -400 / -500%) l c h / alpha)') == 'lch(0 0 320 / 0)'
	assert relative_computed('color(from color(srgb 0.7 0.5 0.3) srgb b g r)') == 'color(srgb 0.3 0.5 0.7)'
}
