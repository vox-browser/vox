module css

fn font_palette_mix_value(first StyleValue, second StyleValue, percentage f64, method ColorInterpolationMethodStyleValue) StyleValue {
 if first.equals(second) { return first }
 if percentage <= 0 { return first }
 if percentage >= 100 { return second }
 second_entry := if percentage == 50 { second } else { StyleValue(StyleValueList.create([second,StyleValue(PercentageStyleValue.create(Percentage.new(percentage)))],.space,.no)) }
 return StyleValue(FunctionStyleValue.create('palette-mix',StyleValue(StyleValueList.create([StyleValue(method),first,second_entry],.comma,.no))))
}

fn (mut parser Parser) parse_font_palette_value(mut tokens ComponentValueStream) ?StyleValue {
 mut transaction := tokens.clone()
 transaction.consume_whitespace()
 component := transaction.consume() or { return none }
 if component.is(.ident) {
  name := component.token().ident()
  if name.to_lower() in ['normal','light','dark'] {
   tokens = transaction
   return StyleValue(KeywordStyleValue.create(keyword_from_string(name)?))
  }
  if name.starts_with('--') && name.len > 2 {
   tokens = transaction
   return StyleValue(CustomIdentStyleValue.create(name))
  }
  return none
 }
 if !component.is_function_named('palette-mix') { return none }
 arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(component.function().value)
 if arguments.len != 3 { return none }
 mut method_tokens := ComponentValueStream.new(arguments[0])
 method := parser.parse_color_interpolation_method_value(mut method_tokens) or { return none }
 method_tokens.consume_whitespace()
 if method_tokens.has_more_tokens() { return none }
 mut palettes := []StyleValue{}
 mut weights := []?f64{}
 for argument in arguments[1..] {
  mut inner := ComponentValueStream.new(argument)
  palette := parser.parse_font_palette_value(mut inner) or { return none }
  inner.consume_whitespace()
  mut weight := ?f64(none)
  if inner.has_more_tokens() {
   value := parser.parse_percentage_value(mut inner) or { return none }
   percentage := if value is PercentageStyleValue { value.percentage().value() }
    else if value is CalculatedStyleValue { value.resolve_percentage(CalculationResolutionContext{})?.value() }
    else { return none }
   if percentage < 0 || percentage > 100 { return none }
   weight = percentage
  }
  inner.consume_whitespace()
  if inner.has_more_tokens() { return none }
  palettes << palette
  weights << weight
 }
 first_weight := weights[0] or { if second := weights[1] { 100-second } else { 50.0 } }
 second_weight := weights[1] or { 100-first_weight }
 if first_weight+second_weight == 0 { return none }
 tokens = transaction
 return font_palette_mix_value(palettes[0],palettes[1],second_weight*100/(first_weight+second_weight),method)
}
