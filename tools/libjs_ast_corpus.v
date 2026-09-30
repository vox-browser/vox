module main

import libjs
import os

fn main() {
	mut upstream := os.getenv('LADYBIRD_SOURCE_DIR')
	if upstream == '' {
		upstream = os.real_path(os.join_path(os.dir(os.dir(@FILE)), '..', '3rd', 'ladybird'))
	}
	mut selected := []string{}
	mut index := 1
	for index < os.args.len {
		argument := os.args[index]
		if argument == '--upstream' {
			index++
			if index >= os.args.len {
				eprintln('--upstream requires a Ladybird checkout path')
				exit(2)
			}
			upstream = os.args[index]
		} else if argument != '--all' {
			selected << argument
		}
		index++
	}
	base := os.join_path(upstream, 'Tests', 'LibJS', 'AST')
	input_root := os.join_path(base, 'input')
	mut names := os.ls(input_root) or {
		eprintln(err)
		exit(2)
	}
	names.sort()
	output := os.join_path(os.dir(os.dir(@FILE)), 'Build', 'libjs-ast')
	os.mkdir_all(output) or {
		eprintln(err)
		exit(2)
	}
	mut passed := 0
	mut failed := 0
	for name in names {
		if !name.ends_with('.js') && !name.ends_with('.mjs') {
			continue
		}
		stem := name.all_before_last('.')
		if selected.len > 0 && name !in selected && stem !in selected {
			continue
		}
		text := os.read_file(os.join_path(input_root, name)) or {
			eprintln(err)
			exit(2)
		}
		type_ := if name.ends_with('.mjs') { libjs.SourceType.module } else { libjs.SourceType.script }
		parsed := libjs.parse_source(text, type_)
		mut actual := ''
		if parsed.has_errors() {
			for diagnostic in parsed.diagnostics {
				actual += 'SyntaxError: ${diagnostic.message} (${diagnostic.line}:${diagnostic.column})\n'
			}
		} else {
			actual = parsed.dump_ast() or {
				eprintln(err)
				exit(2)
			}
		}
		expected := os.read_file(os.join_path(base, 'expected', '${stem}.txt')) or {
			eprintln(err)
			exit(2)
		}
		os.write_file(os.join_path(output, '${stem}.actual.txt'), actual) or {
			eprintln(err)
			exit(2)
		}
		if actual.trim_right('\r\n') == expected.trim_right('\r\n') {
			passed++
			println('PASS ${name}')
		} else {
			failed++
			println('FAIL ${name}')
		}
	}
	if passed + failed == 0 {
		eprintln('No AST fixtures matched the requested names')
		exit(2)
	}
	println('LibJS AST corpus: ${passed} passed, ${failed} failed, ${passed + failed} total')
	println('Actual AST output: ${output}')
	if failed != 0 {
		exit(1)
	}
}
