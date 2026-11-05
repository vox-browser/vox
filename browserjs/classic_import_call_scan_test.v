module browserjs

fn test_classic_import_call_scan_keeps_every_possible_call_and_meta_boundary() {
	for source in ['import("./a.js")', 'import.meta.url', 'import.source("a")',
		'import /* one */ /* two */ ("a")', 'import // comment\r\n ("a")',
		'import \t\v\f\n\r ("a")', 'f(...import("a"))',
		'import /* comment with import */ ("a")',
		'"@import";import("a")', 'import\u00a0("a")', 'import\uFEFF("a")',
		'import // x\u2028("a")', 'import // x\u2029("a")',
		'import /* no end', 'import <!-- comment\n ("a")',
		'import\n --> comment\n ("a")', 'importé', 'éimport("a")',
		'"import("', 'class X { import(value) {} }', 'x.import("a")'] {
		assert classic_source_may_need_import_rewrite(source), source
	}
}

fn test_classic_import_call_scan_rejects_text_without_a_possible_import_call() {
	for source in ['', 'const important=1;', '"@import"', '"dynamic-import"',
		'new Error("Please add import \\\"reflect-metadata\\\" to your entry point")',
		'loader.import=async value=>loader(value)', 'import', '/*import*/',
		'"import";const importer=42;', 'import /* complete */',
		'import // ascii comment', r'import\u0061', '/import\\(/',
		'import x from "./static.js"', 'import "./static.js"'] {
		assert !classic_source_may_need_import_rewrite(source), source
	}
}
