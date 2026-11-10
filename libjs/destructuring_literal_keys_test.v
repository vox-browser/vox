// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// Frontend regressions for Ladybird 85fbe3d0d067de1e36573e20dc4421dda83c50a0.
module libjs

fn test_destructuring_literal_keys_use_numeric_values_in_all_pattern_positions() {
	for literal, expected in {
		'0x10': '16'
		'0o10': '8'
		'0b10': '2'
		'1_0': '10'
		'1e3': '1000'
		'1.5': '1.5'
		'1e21': '1e+21'
		'1e-7': '1e-7'
		'0x10n': '16'
		'0o10n': '8'
		'0b10n': '2'
		'1_0n': '10'
		'0x1_0n': '16'
		'0xffffffffffffffffffffn': '1208925819614629174706175'
	} {
		for source in ['const { ${literal}: value } = object;',
			'let value; ({ ${literal}: value } = object);',
			'function f({ ${literal}: value }) { return value; }'] {
			parsed := parse_source(source, .script)
			assert !parsed.has_errors(), '${source}: ${parsed.diagnostics}'
			ast_text := parsed.dump_ast()!
			assert ast_text.contains('Identifier "${expected}"'), ast_text
		}
	}
}

fn test_destructuring_literal_keys_need_aliases_and_strings_keep_their_spelling() {
	for source in ['const { 1n } = object;', 'let value; ({ 1n } = object);',
		'function f({ 1n }) {}', 'const { 0x10 } = object;', 'const { "key" } = object;'] {
		assert parse_source(source, .script).has_errors(), source
	}
	parsed := parse_source('const { "0x10": first, "1_0": second, identifier } = object;', .script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	ast_text := parsed.dump_ast()!
	assert ast_text.contains('Identifier "0x10"'), ast_text
	assert ast_text.contains('Identifier "1_0"'), ast_text
	assert ast_text.contains('Identifier "identifier"'), ast_text
}
