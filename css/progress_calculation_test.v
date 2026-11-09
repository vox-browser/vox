module css

fn test_progress_calculation_keeps_relative_units_until_computation() {
 for source,expected in {'progress(60px,20px,100px)':0.5,'progress(0px,20px,100px)':-0.25,'progress(140px,20px,100px)':1.5} {
  mut parser := Parser.from_css_text(source)
  mut tokens := ComponentValueStream.new(parser.component_values)
  value := parser.parse_calculated_value_with_context(mut tokens,CalculationContext{},true) or { panic(source) }
  assert value is CalculatedStyleValue
  number := (value as CalculatedStyleValue).resolve_number(CalculationResolutionContext{}) or { panic('number') }
  assert number == expected
 }
 assert parse_css_value_logic(.opacity,'progress(1px,2deg,3px)') == none
}
