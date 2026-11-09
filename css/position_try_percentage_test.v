module css

fn test_position_try_flip_resolves_calculated_anchor_percentages() {
 context := PositionTryTacticContext{mapping:[0,3,2,1]!,container_starts:[3,0]!,self_starts:[3,0]!,inline_horizontal:true}
 value := parse_css_value_logic(.left, 'anchor(calc(10% + 20%))') or { panic('anchor') }
 moved := context.move_value(value, 3)
 assert moved.serialize(.normal) == 'anchor(70%)'
}

fn test_percentage_calculations_resolve_without_an_unrelated_length_basis() {
 for source, expected in {'calc(10% + 20%)':30.0,'calc(10% - 10%)':0.0} {
  value := parse_css_value_logic(.left,source) or { panic(source) }
  assert value is CalculatedStyleValue
  assert value.resolve_percentage(CalculationResolutionContext{})?.value() == expected
 }
 value := parse_css_value_logic(.left,'calc(10% + 20px)') or { panic('mixed') }
 assert value is CalculatedStyleValue
 assert value.resolve_percentage(CalculationResolutionContext{}) == none
}
