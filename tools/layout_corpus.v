module main

import html
import layout
import dom
import encoding
import os
import browserjs

struct CorpusOptions {
	upstream_root string
	case_path     string
	start_path    string
	end_path      string
	run_all       bool
}

fn default_upstream_root() string {
	if configured := os.getenv_opt('LADYBIRD_SOURCE_ROOT') {
		return configured
	}
	repository_root := os.dir(os.dir(@FILE))
	return os.real_path(os.join_path(repository_root, '..', '3rd', 'ladybird'))
}

fn parse_options() !CorpusOptions {
	mut upstream_root := default_upstream_root()
	mut case_path := ''
	mut start_path := ''
	mut end_path := ''
	mut run_all := false
	mut index := 1
	for index < os.args.len {
		argument := os.args[index]
		match argument {
			'--upstream' {
				index++
				if index >= os.args.len {
					return error('--upstream requires a path')
				}
				upstream_root = os.args[index]
			}
			'--case' {
				index++
				if index >= os.args.len {
					return error('--case requires a path relative to Layout/input')
				}
				case_path = os.args[index]
			}
			'--all' {
				run_all = true
			}
			'--start' {
				index++
				if index >= os.args.len {
					return error('--start requires a path relative to Layout/input')
				}
				start_path = os.args[index]
			}
			'--end' {
				index++
				if index >= os.args.len {
					return error('--end requires a path relative to Layout/input')
				}
				end_path = os.args[index]
			}
			else {
				return error('unknown argument ${argument}')
			}
		}
		index++
	}
	if !run_all && case_path.len == 0 {
		return error('choose --case RELATIVE/PATH.html or --all')
	}
	return CorpusOptions{
		upstream_root: upstream_root
		case_path: case_path
		start_path: start_path
		end_path: end_path
		run_all: run_all
	}
}

fn corpus_directories(upstream_root string) !(string, string) {
	base := os.join_path(upstream_root, 'Tests', 'LibWeb', 'Layout')
	input_root := os.join_path(base, 'input')
	expected_root := os.join_path(base, 'expected')
	if !os.is_dir(input_root) || !os.is_dir(expected_root) {
		return error('Layout corpus not found below ${upstream_root}')
	}
	return input_root, expected_root
}

fn expected_path_for(input_root string, expected_root string, input_path string) string {
	relative := input_path.trim_string_left(input_root).trim_left(os.path_separator)
	local_override := os.join_path(os.dir(@FILE), 'layout_expected', relative.all_before_last('.') +
		'.txt')
	if os.is_file(local_override) {
		return local_override
	}
	return os.join_path(expected_root, relative.all_before_last('.') + '.txt')
}

fn first_difference(expected string, actual string) string {
	expected_lines := expected.split_into_lines()
	actual_lines := actual.split_into_lines()
	line_count := if expected_lines.len > actual_lines.len {
		expected_lines.len
	} else {
		actual_lines.len
	}
	for index in 0 .. line_count {
		expected_line := if index < expected_lines.len {
			expected_lines[index]
		} else {
			'<missing>'
		}
		actual_line := if index < actual_lines.len { actual_lines[index] } else { '<missing>' }
		if expected_line != actual_line {
			return 'line ${index + 1}\n  expected: ${expected_line}\n    actual: ${actual_line}'
		}
	}
	return ''
}

fn read_decoded_document_source(path string) !string {
	bytes := os.read_bytes(path)!
	label := html.run_html_encoding_sniffing_algorithm(bytes, none)
	decoder := encoding.TextDecoder.construct(label, encoding.TextDecoderOptions{})!
	return decoder.decode(bytes, encoding.TextDecodeOptions{})!
}

fn run_case(input_root string, expected_root string, relative_path string) !bool {
	input_path := os.join_path(input_root, relative_path)
	expected_path := expected_path_for(input_root, expected_root, input_path)
	if !os.is_file(input_path) {
		return error('input does not exist: ${input_path}')
	}
	if !os.is_file(expected_path) {
		return error('expected snapshot does not exist: ${expected_path}')
	}
	source := read_decoded_document_source(input_path)!
	expected := os.read_file(expected_path)!.trim_right('\n')
	// Like a navigation, create the document with its final URL before parsing, so
	// parser-time URL consumers (style sheets created as style elements are
	// popped, a parser-inserted <base>) observe it.
	document_url := dom.dom_url_parse('file://${input_path}', dom.url_about_blank(), 'UTF-8') or {
		return error('could not construct the input URL for ${relative_path}')
	}
	mut document := if relative_path.ends_with('.svg') {
		mut svg_document := dom.Document.create(document_url)
		svg_document.set_content_type('image/svg+xml')
		svg_document.set_document_type(.xml)
		html.parse_xml_document_source(svg_document, source)!
		svg_document
	} else {
		html.parse_document_with_url(source, document_url)
	}
	// LibWeb's layout runner loads each fixture as the active document of a top-level
	// traversable. Preserve that state here so APIs gated on "fully active" (notably
	// HTMLDialogElement.showModal()) run instead of throwing InvalidStateError.
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	// The corpus runs deferred fixture scripts after parsing has completed. Mark the
	// synthetic document loaded so mutation-driven features use their normal
	// post-load lifecycle (for example, live SVG <use> instance trees).
	document.completely_finish_loading()
	mut javascript_runtime := browserjs.Runtime.create()
	defer {
		javascript_runtime.close()
	}
	browserjs.run_inline_document_scripts(document, document_url.serialize(), javascript_runtime) or {
		return error('JavaScript execution failed for ${relative_path}: ${err.msg()}')
	}
	actual := layout.dump_document_layout_snapshot(document, 800, 600) or {
		return error('layout produced no tree for ${relative_path}')
	}
	if actual != expected {
		eprintln('FAIL ${relative_path}: ${first_difference(expected, actual)}')
		if os.getenv('LIBWEB_V_LAYOUT_DUMP_ACTUAL') == '1' {
			eprintln('\n${actual}')
		}
		return false
	}
	println('PASS ${relative_path}')
	return true
}

fn all_cases(input_root string) []string {
	mut paths := os.walk_ext(input_root, '.html')
	paths << os.walk_ext(input_root, '.svg')
	paths.sort()
	return paths.map(it.trim_string_left(input_root).trim_left(os.path_separator))
}

fn main() {
	options := parse_options() or {
		eprintln('${err}')
		eprintln('usage: v run tools/layout_corpus.v --case blank.html [--upstream PATH]')
		eprintln('       v run tools/layout_corpus.v --all [--upstream PATH]')
		exit(2)
	}
	// The upstream layout runner always installs its deterministic SerenitySans
	// face. Mirror that setup when callers have not supplied an override, so the
	// documented bare `--all` command does not depend on host font discovery.
	if os.getenv('LADYBIRD_LAYOUT_TEST_FONT') == '' {
		layout_test_font := os.join_path(options.upstream_root, 'Base', 'res', 'fonts', 'SerenitySans-Regular.ttf')
		if os.is_file(layout_test_font) {
			os.setenv('LADYBIRD_LAYOUT_TEST_FONT', layout_test_font, true)
		}
	}
	input_root, expected_root := corpus_directories(options.upstream_root) or {
		eprintln('${err}')
		exit(2)
	}
	if !options.run_all {
		passed := run_case(input_root, expected_root, options.case_path) or {
			eprintln('${err}')
			exit(2)
		}
		if !passed {
			exit(1)
		}
		return
	}
	mut passed := 0
	mut failed := 0
	mut failed_paths := []string{}
	for case_path in all_cases(input_root) {
		if options.start_path.len > 0 && case_path < options.start_path {
			continue
		}
		if options.end_path.len > 0 && case_path > options.end_path {
			break
		}
		if run_case(input_root, expected_root, case_path) or { false } {
			passed++
		} else {
			failed++
			failed_paths << case_path
		}
	}
	println('Layout corpus: ${passed} passed, ${failed} failed, ${passed + failed} total')
	if failed > 0 {
		println('Failed cases:')
		for failed_path in failed_paths {
			println('  ${failed_path}')
		}
		exit(1)
	}
}
