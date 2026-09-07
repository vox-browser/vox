module main

import browserjs
import dom
import encoding
import html
import layout
import os

// Prints the layout and paintable trees for each HTML file given on the command line, in
// the same shape as upstream's `Ladybird --headless=layout-tree` (layout tree, blank line,
// paintable tree). That makes the two directly diffable, so a generated corpus can be
// checked against the real browser without a checked-in expectation for every case.
//
// `tools/layout_corpus.v` compares against upstream's committed snapshots, which also carry
// a stacking-context section that no headless mode emits. This tool exists for the other
// direction: ad-hoc cases whose expectation is produced by running upstream right now.
//
//   $ v -enable-globals run tools/layout_dump.v case.html
//   $ v -enable-globals run tools/layout_dump.v --directory /tmp/cases
//
// With more than one input each dump is preceded by a `=== RELATIVE/PATH` marker line so a
// whole directory can be dumped by a single process; one Ladybird launch per case is the
// slow half of a differential run, but this side only pays for one.

const viewport_width = 800.0

const viewport_height = 600.0

struct DumpOptions {
	paths     []string
	delimited bool
	root      string
}

fn parse_options() !DumpOptions {
	mut paths := []string{}
	mut directory := ''
	mut index := 1
	for index < os.args.len {
		argument := os.args[index]
		match argument {
			'--directory' {
				index++
				if index >= os.args.len {
					return error('--directory requires a path')
				}
				directory = os.args[index]
			}
			else {
				if argument.starts_with('--') {
					return error('unknown argument ${argument}')
				}
				paths << argument
			}
		}
		index++
	}
	if directory.len > 0 {
		if !os.is_dir(directory) {
			return error('not a directory: ${directory}')
		}
		mut found := os.walk_ext(directory, '.html')
		found << os.walk_ext(directory, '.svg')
		found.sort()
		paths << found
	}
	if paths.len == 0 {
		return error('give at least one HTML path, or --directory PATH')
	}
	return DumpOptions{
		paths: paths
		delimited: paths.len > 1
		root: directory
	}
}

fn read_decoded_document_source(path string) !string {
	bytes := os.read_bytes(path)!
	label := html.run_html_encoding_sniffing_algorithm(bytes, none)
	decoder := encoding.TextDecoder.construct(label, encoding.TextDecoderOptions{})!
	return decoder.decode(bytes, encoding.TextDecodeOptions{})!
}

fn dump_case(path string) !string {
	source := read_decoded_document_source(path)!
	mut document := if path.ends_with('.svg') {
		mut svg_document := dom.Document.create(dom.url_about_blank())
		svg_document.set_content_type('image/svg+xml')
		svg_document.set_document_type(.xml)
		html.parse_xml_document_source(svg_document, source)!
		svg_document
	} else {
		html.parse_document(source)
	}
	document_url := dom.dom_url_parse('file://${path}', dom.url_about_blank(), 'UTF-8') or {
		return error('could not construct the input URL for ${path}')
	}
	document.set_url(document_url)
	// Match the corpus runner: each fixture is the active document of a top-level
	// traversable, so APIs gated on "fully active" run instead of throwing.
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	// Fixture scripts run after parsing, like deferred scripts in a loaded document.
	document.completely_finish_loading()
	mut javascript_runtime := browserjs.Runtime.create()
	defer {
		javascript_runtime.close()
	}
	browserjs.run_inline_document_scripts(document, document_url.serialize(), javascript_runtime) or {
		return error('JavaScript execution failed for ${path}: ${err.msg()}')
	}
	result := layout.run_document_layout(document, viewport_width, viewport_height) or {
		return error('layout produced no tree for ${path}')
	}
	layout_tree := layout.dump_typed_layout_tree(result.root, result.state)
	paint_tree := layout.dump_typed_paint_tree(result.root, result.state)
	return '${layout_tree}\n\n${paint_tree}'
}

fn main() {
	options := parse_options() or {
		eprintln('${err}')
		eprintln('usage: v run tools/layout_dump.v CASE.html [CASE.html ...]')
		eprintln('       v run tools/layout_dump.v --directory PATH')
		exit(2)
	}
	mut failures := 0
	for path in options.paths {
		if options.delimited {
			relative := if options.root.len > 0 {
				path.trim_string_left(options.root).trim_left(os.path_separator)
			} else {
				path
			}
			println('=== ${relative}')
		}
		dumped := dump_case(path) or {
			eprintln('ERROR ${path}: ${err.msg()}')
			failures++
			continue
		}
		println(dumped)
	}
	if failures > 0 {
		exit(1)
	}
}
