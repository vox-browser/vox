module css

import dom
import platform

fn test_custom_property_keyword_probe_preserves_tokens_on_success_and_failure() {
	for source in [' /*leading*/inherit ', ' inherit extra ', 'f(inherit)', ' var(--x) '] {
		values := parse_component_values_for_value_logic(source)
		before := parser_component_values_to_string(values)
		parsed := parse_custom_property_components(values, source)
		value := typed_style_value_logic_from_dom(parsed)?
		if source == ' /*leading*/inherit ' {
			assert value.to_keyword() == .inherit
		} else {
			assert value is UnresolvedStyleValue
			assert parsed.css_text == source
		}
		assert parser_component_values_to_string(values) == before
	}
}

fn test_custom_property_probe_retains_only_the_returned_value_records() {
	source := 'var(--theme, red)'
	values := parse_component_values_for_value_logic(source)
	mut results := []&dom.StyleValue{cap:128}
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 { results << parse_custom_property_components(values, source) }
	$if prealloc {
		// The stream and keyword probe need no Parser record or parsing context.
		per_value := sizeof(dom.StyleValue) + sizeof(TypedStyleValueBox) + sizeof(UnresolvedStyleValue) + 96
		assert platform.thread_arena_usage().used - before < 128 * per_value
	}
	for result in results {
		assert result.css_text == source
		value := typed_style_value_logic_from_dom(result)?
		assert value is UnresolvedStyleValue
		assert value.tokens.data == values.data
	}
}
