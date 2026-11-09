module css

// selector() checks support for every part, including parts a forgiving
// :is() or :where() list would discard during ordinary selector parsing.
fn supports_selector_components(context ParsingParams, values []ComponentValue, in_has bool, in_logical bool) bool {
 mut previous_colon := false
 for value in values {
  if value.is(.colon) {
   if previous_colon && in_logical { return false }
   previous_colon = true
   continue
  }
  if in_logical && previous_colon && value.is(.ident)
   && value.token().ident().to_lower() in ['before','after','first-line','first-letter'] { return false }
  if value.is_function() {
   name := value.function().name.to_lower()
   logical := previous_colon && name in ['is','where','not','has']
   nested_has := logical && name == 'has'
   if nested_has && in_has { return false }
   if logical {
    text := supports_component_values_to_string(value.function().value)
    mut parser := RuleSelectorParser.create(context,text,'utf-8')
    parsed := if nested_has { parser.parse_as_relative_selector(.standard) } else { parser.parse_as_selector(.standard) }
    if parsed == none { return false }
   }
   if !supports_selector_components(context,value.function().value,in_has || nested_has,in_logical || logical) { return false }
  } else if value.is_block() {
   if !supports_selector_components(context,value.block().value,in_has,in_logical) { return false }
  }
  previous_colon = false
 }
 return true
}

fn supports_single_selector(context ParsingParams, values []ComponentValue) bool {
 text := supports_component_values_to_string(values)
 mut parser := RuleSelectorParser.create(context,text,'utf-8')
 selectors := parser.parse_as_selector(.standard) or { return false }
 return selectors.selectors.len == 1
  && !supports_selector_contains_unknown_webkit_pseudo_element(text)
  && supports_selector_components(context,values,false,false)
}
