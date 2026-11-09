module css

fn (mut parser Parser) parse_light_dark_image_function(component ComponentValue, allow_image_set bool) ?StyleValue {
 arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(component.function().value)
 if arguments.len != 2 { return none }
 mut branches := []StyleValue{}
 for argument in arguments {
  mut tokens := ComponentValueStream.new(argument)
  mut branch := ?StyleValue(none)
  if value := parser.parse_all_as_single_keyword_value(mut tokens,.none_) { branch = value }
  else {
   image := parser.parse_image_value_allowing_image_set(mut tokens,allow_image_set) or { return none }
   branch = style_value_from_css_image_source_for_value_logic(image)
  }
  tokens.consume_whitespace()
  if tokens.has_more_tokens() { return none }
  branches << branch or { return none }
 }
 return StyleValue(LightDarkStyleValue{...LightDarkStyleValue.create(branches[0],branches[1]),image_:true})
}
