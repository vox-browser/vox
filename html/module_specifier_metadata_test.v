module html

import dom
import platform

fn test_module_resolution_metadata_preserves_url_normalization_and_legacy_result() {
	base := dom.URL{value: 'https://example.test/app/page.js'}
	import_map := ImportMap{}
	inputs := ['./dep.js', '../src/./dep.js', '/root.js', 'HTTPS://EXAMPLE.TEST:443/a/../dep.js', 'data:text/javascript,42']
	expected := ['https://example.test/app/dep.js', 'https://example.test/src/dep.js', 'https://example.test/root.js', 'https://example.test/dep.js', 'data:text/javascript,42']
	for index, input in inputs {
		result := resolve_module_specifier_with_metadata(&import_map, base, input)!
		assert result.url.serialize() == expected[index]
		assert result.normalized_specifier == expected[index]
		assert (result.url_like or { panic('missing URL-like input') }).serialize() == expected[index]
		assert resolve_module_specifier(&import_map, base, input)!.serialize() == expected[index]
	}
}

fn test_module_resolution_metadata_describes_input_before_import_map_remapping() {
	base := dom.URL{value: 'https://example.test/app/page.js'}
	import_map := parse_import_map_string('{"imports":{"dep":"data:text/javascript,42","./source.js":"data:text/javascript,43","data:text/javascript,44":"./target.js"}}', base)!
	bare := resolve_module_specifier_with_metadata(&import_map, base, 'dep')!
	assert bare.url.serialize() == 'data:text/javascript,42'
	assert bare.normalized_specifier == 'dep' && bare.url_like == none
	special := resolve_module_specifier_with_metadata(&import_map, base, './source.js')!
	assert special.url.serialize() == 'data:text/javascript,43'
	assert special.normalized_specifier == 'https://example.test/app/source.js'
	assert (special.url_like or { panic('missing original URL') }).scheme() == 'https'
	opaque := resolve_module_specifier_with_metadata(&import_map, base, 'data:text/javascript,44')!
	assert opaque.url.serialize() == 'https://example.test/app/target.js'
	assert opaque.normalized_specifier == 'data:text/javascript,44'
	assert (opaque.url_like or { panic('missing original URL') }).scheme() == 'data'
}

fn test_module_resolution_metadata_keeps_scope_and_prefix_precedence() {
	base := dom.URL{value: 'https://example.test/app/deep/page.js'}
	import_map := parse_import_map_string('{"imports":{"dep":"/global.js","pkg/":"https://cdn.test/pkg/"},"scopes":{"/app/":{"dep":"/outer.js"},"/app/deep/":{"dep":"/inner.js"}}}', base)!
	result := resolve_module_specifier_with_metadata(&import_map, base, 'dep')!
	assert result.url.serialize() == 'https://example.test/inner.js'
	assert result.normalized_specifier == 'dep' && result.url_like == none
	prefix := resolve_module_specifier_with_metadata(&import_map, base, 'pkg/util.js')!
	assert prefix.url.serialize() == 'https://cdn.test/pkg/util.js'
	assert prefix.normalized_specifier == 'pkg/util.js' && prefix.url_like == none
}

fn test_module_resolution_metadata_preserves_errors() {
	base := dom.URL{value: 'https://example.test/'}
	import_map := parse_import_map_string('{"imports":{"blocked":null,"pkg/":"https://cdn.test/pkg/"}}', base)!
	inputs := ['missing', 'blocked', 'pkg/../escape.js']
	expected := ["Failed to resolve non relative module specifier 'missing' from an import map.", "Import resolution of 'blocked' was blocked by a null entry.", "Could not resolve 'pkg/../escape.js' as it backtracks above its prefix specifierKey."]
	for index, input in inputs {
		if _ := resolve_module_specifier_with_metadata(&import_map, base, input) {
			assert false, input
		} else { assert err.msg() == expected[index] }
		if _ := resolve_module_specifier(&import_map, base, input) {
			assert false, input
		} else { assert err.msg() == expected[index] }
	}
}

fn test_module_resolution_metadata_observes_import_map_mutation() {
	base := dom.URL{value: 'https://example.test/'}
	mut import_map := parse_import_map_string('{"imports":{"dep":"/first.js"}}', base)!
	first := resolve_module_specifier_with_metadata(&import_map, base, 'dep')!
	import_map.imports.set('dep', dom.URL{value: 'https://example.test/second.js'})
	second := resolve_module_specifier_with_metadata(&import_map, base, 'dep')!
	assert first.url.serialize() == 'https://example.test/first.js'
	assert second.url.serialize() == 'https://example.test/second.js'
	assert first.normalized_specifier == 'dep' && second.normalized_specifier == 'dep'
}

fn test_module_resolution_metadata_owns_normalized_text_after_input_owner_retires() {
	base := dom.URL{value: 'https://example.test/app/page.js'}
	import_map := parse_import_map_string('{"imports":{"dependency":"/dep.js"}}', base)!
	for input in ['dependency', './temporary.js', 'https://elsewhere.test/temporary.js'] {
		scratch := platform.begin_thread_scratch('module normalization input')
		temporary := input.clone()
		scratch.leave()
		result := resolve_module_specifier_with_metadata(&import_map, base, temporary)!
		scratch.finish()
		gc_collect()
		assert result.normalized_specifier == if input == 'dependency' { input } else if input.starts_with('./') { 'https://example.test/app/temporary.js' } else { input }
		assert result.url.serialize() == if input == 'dependency' { 'https://example.test/dep.js' } else { result.normalized_specifier }
	}
}
