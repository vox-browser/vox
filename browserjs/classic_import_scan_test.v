module browserjs

fn test_classic_import_scan_rejects_only_ascii_identifier_substrings() {
	for source in ['', 'globalThis.answer=42', 'const important=1;',
		'function importer(){}', 'let myimport=0, import0=1, import_=2, import$=3;',
		'var imports={imported:1};"!important";', 'important;myimport();importer()'] {
		assert !classic_source_may_have_import_word(source), source
	}
	for source in ['import("./a.js")', 'import /* comment */ ("a")',
		'important; import("a"); importer()', 'import.meta.url',
		'f(...import("a"))', 'import\n("a")', '"import"', '/*import*/',
		'éimport("a")', 'importé', r'import\u0061', r'\u0069mport("a");import("b")',
		'import', 'import$;import("a")', 'importimport;import("a")'] {
		assert classic_source_may_have_import_word(source), source
	}
}
