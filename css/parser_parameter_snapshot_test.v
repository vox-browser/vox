module css

import platform

fn test_parser_parameter_snapshots_keep_independent_contexts_and_namespaces() {
	mut parser := RuleSelectorParser{
		mode: .svg_presentation_attribute
		value_context: [ValueParsingContext(PropertyID.width)]
		rule_context: [.style]
		declared_namespaces: {'svg': true}
		is_ua_style_sheet: .yes
	}
	first := parser.parsing_params()
	parser.value_context[0] = PropertyID.height
	parser.rule_context[0] = .media
	parser.declared_namespaces['svg'] = false
	parser.declared_namespaces['new'] = true
	second := parser.parsing_params()
	assert first.mode == .svg_presentation_attribute && first.is_ua_style_sheet == .yes
	assert first.value_context[0] == ValueParsingContext(PropertyID.width)
	assert first.rule_context == [RuleContext.style]
	assert first.declared_namespaces['svg'] && 'new' !in first.declared_namespaces
	assert second.value_context[0] == ValueParsingContext(PropertyID.height)
	assert second.rule_context == [RuleContext.media]
	assert !second.declared_namespaces['svg'] && second.declared_namespaces['new']
}

fn test_empty_parser_parameter_snapshots_do_not_box_the_whole_parser() {
	parser := RuleSelectorParser{}
	parser.parsing_params()
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		params := parser.parsing_params()
		assert params.value_context.len == 0 && params.rule_context.len == 0
		assert params.declared_namespaces.len == 0
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < i64(sizeof(RuleSelectorParser)) * 1024
	}
}
