module main

import adblock
import css
import dom

fn static_adblock_memory_request() adblock.Request {
	return adblock.Request{
		url: 'https://securepubads.g.doubleclick.net/tag/js/gpt.js'
		source_url: 'https://www.theverge.com/'
		request_type: 'script'
	}
}

fn static_adblock_memory_document(scripting_enabled bool) &dom.Document {
	mut document := parse_browser_navigation_document_with_scripting(
		'<!doctype html><div id="kept" data-concert="leaderboard">retained document</div>',
		dom.URL{value: 'https://www.theverge.com/'}, none, none, none, 0, scripting_enabled)
	document.update_readiness(.complete)
	return document
}

fn test_idle_static_document_releases_filter_vm_without_losing_rules_or_later_filtering() {
	previous_enabled := adblock.is_enabled()
	adblock.set_enabled(true)
	defer {
		adblock.release_unused_engine()
		adblock.set_enabled(previous_enabled)
	}
	mut document := static_adblock_memory_document(false)
	defer { document.finalize() }
	install_browser_adblock_styles(document, '')!
	scope := css.style_scope_for_dom_node(document.as_node())
	installed_style := scope.user_style_source or { '' }
	assert installed_style != ''
	assert installed_style.contains('div[data-concert]')
	before := adblock.check(static_adblock_memory_request())
	assert before.error == ''
	assert before.blocked
	mut app := BrowserApp{document: document}
	app.memory_maintenance.document_changed(1_000_000_000)
	app.release_unused_memory_if_idle(3_000_000_000)
	$if gcboehm ? {
		assert !adblock.release_unused_engine()
	} $else {
		// The explicit no-GC diagnostic mode retains its existing idle policy.
		assert adblock.release_unused_engine()
	}
	assert scope.user_style_source or { '' } == installed_style
	assert document.get_element_by_id('kept')?.text_content() or { '' } == 'retained document'
	after := adblock.check(static_adblock_memory_request())
	assert after == before
	assert adblock.release_unused_engine()
}

fn test_idle_script_enabled_document_keeps_the_filter_engine_available() {
	previous_enabled := adblock.is_enabled()
	adblock.set_enabled(true)
	defer {
		adblock.release_unused_engine()
		adblock.set_enabled(previous_enabled)
	}
	mut document := static_adblock_memory_document(true)
	defer { document.finalize() }
	assert adblock.check(static_adblock_memory_request()).blocked
	mut app := BrowserApp{document: document}
	app.memory_maintenance.document_changed(1_000_000_000)
	app.release_unused_memory_if_idle(3_000_000_000)
	assert adblock.release_unused_engine()
}

fn test_pending_static_document_work_keeps_the_filter_engine_available() {
	previous_enabled := adblock.is_enabled()
	adblock.set_enabled(true)
	defer {
		adblock.release_unused_engine()
		adblock.set_enabled(previous_enabled)
	}
	mut document := static_adblock_memory_document(false)
	defer { document.finalize() }
	for pending in 0 .. 4 {
		assert adblock.check(static_adblock_memory_request()).blocked
		mut app := BrowserApp{document: document}
		app.memory_maintenance.document_changed(1_000_000_000)
		if pending == 0 {
			app.background_resource_pending['https://www.wikipedia.org/pending.png'] = true
		} else if pending == 1 {
			app.navigation_work_depth = 1
		} else if pending == 2 {
			app.frame_preparation_depth = 1
		} else {
			document.update_readiness(.loading)
		}
		app.release_unused_memory_if_idle(3_000_000_000)
		assert adblock.release_unused_engine()
		document.update_readiness(.complete)
	}
}
