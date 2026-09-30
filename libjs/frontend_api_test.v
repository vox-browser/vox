module libjs

fn test_frontend_api_retains_functions_and_utf16_source_positions_for_dumping() {
	source := parse_source('function f(α) { return α; }\nconst 𐐀 = f(1);', .script)
	assert !source.has_errors(), '${source.diagnostics}'
	assert !source.is_strict_mode
	assert !source.has_top_level_await
	ast_text := source.dump_ast()!
	assert ast_text.contains('FunctionDeclaration')
	assert ast_text.contains('Identifier "α"')
	assert ast_text.contains('Identifier "𐐀"')
}

fn test_frontend_api_reports_both_parser_and_scope_early_errors() {
	for text in ['const value = ;', 'let value; let value;'] {
		source := parse_source(text, .script)
		assert source.has_errors(), text
		assert source.diagnostics[0].line == 1
		assert source.diagnostics[0].column > 0
		source.dump_ast() or {
			assert err.msg().contains('syntax errors')
			continue
		}
		assert false, 'erroneous programs must not be dumped'
	}
}

fn test_frontend_api_selects_the_strict_module_grammar() {
	module_source := parse_source('export const value = await Promise.resolve(1);', .module)
	assert !module_source.has_errors(), '${module_source.diagnostics}'
	assert module_source.is_strict_mode
	assert module_source.has_top_level_await
	assert module_source.dump_ast()!.contains('Program (module)')
	assert parse_source('export const value = 1;', .script).has_errors()
	assert parse_source('"use strict"; const value = 1;', .script).is_strict_mode
}
