module main

import libjs
import os

// Inspect real module resources without executing them or dumping owner graphs.
// LIBJS_PROBE_DEPTH selects the bounded embedding limit; the API's default is 32.
fn main() {
	if os.args.len == 1 {
		eprintln('Usage: LIBJS_PROBE_DEPTH=256 libjs_frontend_probe FILE.js ...')
		exit(2)
	}
	depth := os.getenv('LIBJS_PROBE_DEPTH').u32()
	mut failures := 0
	for path in os.args[1..] {
		source := os.read_file(path) or { eprintln(err); exit(2) }
		parsed := libjs.parse_source_with_options(source, .module, libjs.ParseOptions{max_recursion_depth:depth})
		message := if parsed.diagnostics.len > 0 {
			first := parsed.diagnostics[0]
			'${first.line}:${first.column}: ${first.message}'
		} else { '' }
		println('${path}\t${source.len}\t${parsed.reached_recursion_limit}\t${parsed.diagnostics.len}\t${message}')
		if parsed.has_errors() { failures++ }
	}
	if failures > 0 { exit(1) }
}
