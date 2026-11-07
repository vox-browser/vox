module main

import adblock
import browserjs
import css
import dom

fn test_upstream_procedural_budget_logging_continues_native_hide_and_remove_actions() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><body><div id="paid">Sponsored story</div><p id="remove">Tracking prompt</p><div id="news">News</div></body>', dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('typeof console.info')! == 'function'
	// Exercise uBO's real over-budget diagnostic without a slow or timed test.
	runtime.evaluate_host('globalThis.__infoOriginalDateNow=Date.now;globalThis.__infoClock=0;Date.now=()=>{__infoClock+=1000;return __infoClock;};')!
	filters := adblock.DocumentFilters{procedural: [
		r'{"raw":"div:has-text(Sponsored)","selector":"div","tasks":[["has-text","Sponsored"]]}',
		r'{"raw":"p:has-text(Tracking):remove()","selector":"p","tasks":[["has-text","Tracking"]],"action":["remove",""]}',
	]}
	runtime.evaluate_host(adblock.procedural_script(filters))!
	refresh_browser_adblock(document, runtime, mut messages)
	runtime.evaluate_host('Date.now=__infoOriginalDateNow;')!
	assert !messages.any(it.starts_with('Adblock procedural filters:'))
	assert messages.filter(it.contains('uBO: disabling')).len == 2, '${messages}'
	assert document.get_element_by_id('remove') == none
	paid := document.get_element_by_id('paid') or { panic('missing paid story') }
	computed := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(paid, none))
	assert computed.property(.display, .no)!.css_text == 'none'
	assert document.get_element_by_id('news') != none
}
