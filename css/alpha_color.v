module css

// CSS Color 5 alpha(from <color> / <alpha-value>) preserves the origin's
// color space while replacing just its alpha component.
fn (mut parser Parser) parse_alpha_color_function(component ComponentValue) ?StyleValue {
 if !component.is_function_named('alpha') { return none }
 mut tokens := ComponentValueStream.new(component.function().value)
 tokens.consume_whitespace()
 from := tokens.consume() or { return none }
 if !from.is(.ident) || !equals_ignoring_ascii_case(from.token().ident(),'from') { return none }
 saved := parser.relative_color_channels
 defer { parser.relative_color_channels = saved }
 parser.relative_color_channels = []string{}
 origin := parser.parse_color_value(mut tokens) or { return none }
 parser.relative_color_channels = ['alpha']
 alpha := parser.parse_solidus_and_alpha_value(mut tokens) or { return none }
 tokens.consume_whitespace()
 if tokens.has_more_tokens() { return none }
 return StyleValue(ColorFunctionStyleValue{
  ...ColorFunctionStyleValue.create('srgb',StyleValue(NumberStyleValue.create(0)),StyleValue(NumberStyleValue.create(0)),StyleValue(NumberStyleValue.create(0)),alpha)
  relative_origin_:[origin]
  relative_alpha_:true
  alpha_function_:true
 })
}

fn alpha_color_parts(value ColorFunctionStyleValue, origin StyleValue) RelativeColorParts {
 origin_type := concrete_color_type(origin) or { ConcreteColorType.rgb }
 target := if origin_type in [.hsl,.hwb] { ConcreteColorType.rgb } else { origin_type }
 components := relative_color_channel_names(target).map(StyleValue(CustomIdentStyleValue.create(it)))
 return RelativeColorParts{target:target,origin:origin,components:components,alpha:value.alpha_.value,alpha_specified:true}
}
