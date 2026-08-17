module html

import dom

fn ignore_parse_result_warning(_ string) {}

fn test_import_map_parse_result_catches_parse_errors() {
	result := ImportMapParseResult.create('[]', dom.URL{'https://example.test/app/'})
	assert result.import_map() == none
	assert result.error_to_rethrow() != none
	mut existing := ImportMap{}
	if _ := result.register_import_map(mut existing, [], ignore_parse_result_warning) {
		assert false
	}
}

fn test_import_map_parse_result_registers_parsed_map() {
	result :=
		ImportMapParseResult.create('{"imports":{"pkg":"./pkg.js"}}', dom.URL{'https://example.test/app/'})
	assert result.error_to_rethrow() == none
	assert result.import_map() != none
	mut existing := ImportMap{}
	result.register_import_map(mut existing, [], ignore_parse_result_warning)!
	assert existing.imports.entries.len == 1
	assert existing.imports.entries[0].specifier == 'pkg'
	assert existing.imports.entries[0].url?.serialize() == 'https://example.test/app/pkg.js'
}
