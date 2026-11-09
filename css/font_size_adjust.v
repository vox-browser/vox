module css

fn (mut parser Parser) parse_font_size_adjust_value(mut tokens ComponentValueStream) ?StyleValue {
 if value := parser.parse_all_as_single_keyword_value(mut tokens,.none_) { return value }
 mut transaction := tokens.clone()
 transaction.consume_whitespace()
 mut metric := 'ex-height'
 if first := transaction.peek() {
  if first.is(.ident) && first.token().ident().to_lower() in ['ex-height','cap-height','ch-width','ic-width','ic-height'] {
   metric = first.token().ident().to_lower()
   transaction.consume()
   transaction.consume_whitespace()
  }
 }
 mut value := ?StyleValue(none)
 if first := transaction.peek() {
  if first.is(.ident) && first.token().ident().to_lower() == 'from-font' {
   transaction.consume()
   value = StyleValue(CustomIdentStyleValue.create('from-font'))
  }
 }
 if value == none { value = parser.parse_number_value(mut transaction) or { return none } }
 transaction.consume_whitespace()
 if transaction.has_more_tokens() { return none }
 number := value or { return none }
 if number is NumberStyleValue && number.number() < 0 { return none }
 tokens = transaction
 return if metric == 'ex-height' { number } else { StyleValue(StyleValueList.create([StyleValue(CustomIdentStyleValue.create(metric)),number],.space,.no)) }
}

fn composite_font_size_adjust_metric(underlying StyleValue, animated StyleValue, operation CompositeOperation) ?StyleValue {
 if underlying is StyleValueList && animated is StyleValueList {
  if underlying.size() != 2 || animated.size() != 2 || underlying.value_at(0,false) != animated.value_at(0,false) { return none }
  value := composite_style_value(.font_size_adjust,underlying.value_at(1,false),animated.value_at(1,false),operation) or { return none }
  return StyleValue(StyleValueList.create([underlying.value_at(0,false),value],.space,.no))
 }
 return none
}
