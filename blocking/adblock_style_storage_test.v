module main

import css
import dom
import platform

fn test_unchanged_adblock_styles_retire_comparison_text_and_publish_owned_replacements() {
	mut document := parse_browser_navigation_document('<!doctype html><article id="news">News</article>',
		dom.URL{value: 'https://www.theverge.com/'}, none)
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer {
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	// A large user-sheet comment isolates source ownership from parser/layout
	// complexity. Repeated equal refreshes must not retain the whole source.
	padding := '/*' + 'x'.repeat(128 * 1024) + '*/\n'
	css.set_document_user_style_sheet(document, padding + '#news{color:green!important}')
	install_browser_adblock_styles(document, '')!
	scope := css.style_scope_for_dom_node(document.as_node())
	expected := scope.user_style_source or { panic('missing stylesheet') }
	storage := document.native_storage()
	before := if storage != unsafe { nil } { storage.arena.usage().used } else { i64(0) }
	for _ in 0 .. 32 { install_browser_adblock_styles(document, '')! }
	growth := if storage != unsafe { nil } { storage.arena.usage().used - before } else { i64(0) }
	$if prealloc {
		assert growth < padding.len * 8, '${growth} bytes retained across equal refreshes'
		println('Unchanged stylesheet comparison: retained=${growth} source_bytes=${expected.len} iterations=32')
	}
	assert (scope.user_style_source or { '' }) == expected
	install_browser_adblock_styles(document, '#news{visibility:hidden!important}')!
	changed := scope.user_style_source or { panic('missing replacement stylesheet') }
	churn := platform.begin_thread_scratch('stylesheet comparison overwrite')
	_ = []u8{len: 256 * 1024, init: u8(0xa5)}
	churn.finish()
	assert changed.starts_with(padding)
	assert changed.contains('#news{color:green!important}')
	assert changed.ends_with('#news{visibility:hidden!important}')
	$if prealloc { assert storage.arena.contains(changed.str) }
	// A second refresh reads the published replacement after the workspace died.
	install_browser_adblock_styles(document, '#news{visibility:hidden!important}')!
	assert (scope.user_style_source or { '' }) == changed
}
