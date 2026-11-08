module css

import dom
import os
import processmetrics
import time

// Workload probe only: compiled with -prod, no regression assertions.
fn test_github20_parser_instruction_workload() {
	paths := os.read_lines('Build/github-20-instr/stylesheets.txt') or { panic(err) }
	mut document := dom.Document.create(dom.URL{value:'https://github.com/vlang/v'})
	document.set_document_type(.html)
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	mut seen := map[string]bool{}
	mut rules := 0
	mut total := u64(0)
	if os.getenv('ZZ_PROFILE_SLEEP') != '' { time.sleep(4 * time.second) }
	repeats := if os.getenv('ZZ_PARSER_REPEATS') != '' { os.getenv('ZZ_PARSER_REPEATS').int() } else { 1 }
	for _ in 0 .. repeats {
	seen = map[string]bool{}
	for path in paths {
		if seen[path] && os.getenv('ZZ_INCLUDE_DUPLICATE_SHEETS') == '' { continue }
		seen[path] = true
		text := os.read_file(path) or { panic(err) }
		start := processmetrics.instruction_snapshot()
		sheet := parse_css_stylesheet_in_workspace(ParsingParams{document:document}, text,
			'https://github.githubassets.com/style.css', none, text.len >= 16_384)
		count := processmetrics.instruction_snapshot().since(start) or { u64(0) }
		total += count
		rules += sheet.css_rules().length()
	}
	}
	eprintln('PARSER instructions=${total} rules=${rules} sheets=${seen.len}')
	allocations.finish()
	document.finalize()
}
