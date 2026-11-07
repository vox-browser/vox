module main

import browserjs
import dom

fn test_compact_native_tree_version_uses_exact_numbers_and_falls_back_above_safe_range() {
	for engine in [browserjs.Engine.javascriptcore, .libjs] {
		mut runtime := browserjs.Runtime.create_with_engine(engine)
		mut document := dom.Document.create(dom.url_about_blank())
		defer { runtime.close(); document.finalize() }
		install_compact_dom_tree_version_binding(document, mut runtime)!
		for version in [u64(0), 1, 9007199254740991] {
			document.dom_tree_version = version
			assert runtime.evaluate('typeof __ladybirdDOMTreeVersion()')! == 'number'
			assert runtime.evaluate('__ladybirdDOMTreeVersion() === ${version}')! == 'true'
		}
		for version in [u64(9007199254740992), 9007199254740993, 18446744073709551615] {
			document.dom_tree_version = version
			assert runtime.evaluate('__ladybirdDOMTreeVersion() === -1')! == 'true'
		}
	}
}
