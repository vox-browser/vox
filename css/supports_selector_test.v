module css

fn test_supports_selector_checks_forgiving_branches_and_rejects_lists() {
 for text in ['div','div + .c','::before',':is(.a,div)',':has(> .a)',':where(:has(.a),.b)'] {
  assert supports_single_selector(ParsingParams{},parse_component_values_for_value_logic(text)),text
 }
 for text in ['div,div',':is(:unknown,div)',':where(:is(.a,:unknown),.b)',':has(:is(:has(.a),.b))',':has(::before)',':is(::after)',':is()',':where()'] {
  assert !supports_single_selector(ParsingParams{},parse_component_values_for_value_logic(text)),text
 }
}
