module main

import adblock
import browserjs
import css
import dom

fn test_procedural_css_getter_reads_primed_styles_without_evaluating_selectors() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><div id="paid">Sponsored</div><p id="organic">News</p>', dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	filters := adblock.DocumentFilters{procedural: [
		r'{"raw":"#paid:has-text(Sponsored)","selector":"#paid","tasks":[["has-text","Sponsored"]]}',
		r'{"raw":"#organic:style(color: red)","selector":"#organic","action":["style","color:red!important;"]}',
	]}
	runtime.evaluate_host(adblock.procedural_script(filters))!
	runtime.evaluate_host('globalThis.__primeQueries=0;const originalPrimeQuery=document.querySelectorAll.bind(document);document.querySelectorAll=(...args)=>{__primeQueries++;return originalPrimeQuery(...args)};0')!
	primed := runtime.evaluate_host('__voxAdblockProceduralCSS()')!
	assert primed.contains('display:none!important;')
	assert primed.contains('color:red!important;')
	assert runtime.evaluate_host('__primeQueries')! == '0'
	assert runtime.evaluate_host('paid.getAttribute("data-vox-adblock-1")===null&&paid.getAttribute("data-vox-adblock-2")===null')! == 'true'
	assert document.get_element_by_id('paid') != none
	assert runtime.evaluate_host('__voxAdblockProceduralCSS()')! == primed
	assert runtime.evaluate_host('__primeQueries')! == '0'
	assert messages == []string{}
}

fn test_procedural_computed_style_queries_see_primed_css_without_replacing_it_afterward() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><div id="paid">Sponsored</div><p id="organic">News</p>', dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	css.set_document_user_style_sheet(document, '#organic{color:green!important}')
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	filters := adblock.DocumentFilters{procedural: [
		r'{"raw":"#paid:has-text(Sponsored)","selector":"#paid","tasks":[["has-text","Sponsored"]]}',
		r'{"raw":"#paid:matches-css(display:none):remove()","selector":"#paid","tasks":[["matches-css",{"name":"display","value":"^none$"}]],"action":["remove",""]}',
	]}
	runtime.evaluate_host(adblock.procedural_script(filters))!
	primed := runtime.evaluate_host('__voxAdblockProceduralCSS()')!
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages == []string{}
	assert document.get_element_by_id('paid') == none
	assert document.get_element_by_id('organic') != none
	scope := css.style_scope_for_dom_node(unsafe { &dom.Node(document) })
	source := scope.user_style_source or { panic('missing procedural stylesheet') }
	assert source.starts_with('#organic{color:green!important}')
	assert source.ends_with(primed)
	// The query flushes the preinstalled sheet. An identical final CSS payload
	// must retain that sheet instead of requesting another whole cascade.
	assert !document.needs_full_style_update()
	refresh_browser_adblock(document, runtime, mut messages)
	assert (scope.user_style_source or { '' }) == source
	assert !document.needs_full_style_update()
}

fn test_procedural_callback_without_css_getter_keeps_the_installed_sheet_during_queries() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><div id="paid">Sponsored</div><p id="organic">News</p>', dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	install_browser_adblock_styles(document, '#paid{display:none!important}')!
	runtime.evaluate_host('delete globalThis.__voxAdblockProceduralCSS;globalThis.__voxAdblockApplyProcedural=()=>{globalThis.__primeDisplay=getComputedStyle(paid).display;return "#paid{display:none!important}"};0')!
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('__primeDisplay')! == 'none'
	assert !document.needs_full_style_update()
}

fn test_procedural_style_actions_and_later_css_additions_reach_the_user_origin() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><style>#paid{color:blue!important}</style><div id="paid">Sponsored</div><p id="organic">News</p>', dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	filters := adblock.DocumentFilters{procedural: [
		r'{"raw":"#paid:style(color: red)","selector":"#paid","action":["style","color:red!important;"]}',
	]}
	runtime.evaluate_host(adblock.procedural_script(filters))!
	refresh_browser_adblock(document, runtime, mut messages)
	paid := document.get_element_by_id('paid') or { panic('style action removed paid node') }
	style := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(paid, none))
	assert (style.property(.color, .no) or { panic("missing computed property") }).css_text == 'rgb(255, 0, 0)'
	assert document.get_element_by_id('organic') != none
	// A nonstandard adapter can emit extra CSS while committing. The final
	// install still handles it rather than assuming the primed payload is final.
	runtime.evaluate_host('globalThis.__voxAdblockProceduralCSS=()=>"#paid{color:red!important}";globalThis.__voxAdblockApplyProcedural=()=>"#paid{color:red!important}#organic{color:green!important}";0')!
	refresh_browser_adblock(document, runtime, mut messages)
	organic := document.get_element_by_id('organic') or { panic('missing organic node') }
	organic_style := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(organic, none))
	assert (organic_style.property(.color, .no) or { panic("missing computed property") }).css_text == 'rgb(0, 128, 0)'
	assert messages == []string{}
}

fn test_replacing_the_published_procedural_css_getter_does_not_change_apply_results() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><div id="paid">Sponsored</div>', dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	filters := adblock.DocumentFilters{procedural: [
		r'{"raw":"#paid:has-text(Sponsored)","selector":"#paid","tasks":[["has-text","Sponsored"]]}',
	]}
	runtime.evaluate_host(adblock.procedural_script(filters))!
	primed := runtime.evaluate_host('__voxAdblockProceduralCSS()')!
	runtime.evaluate_host('globalThis.__voxAdblockProceduralCSS=()=>{throw new Error("replaced page getter")};0')!
	assert runtime.evaluate_host('__voxAdblockApplyProcedural()')! == primed
	assert runtime.evaluate_host('paid.getAttribute("data-vox-adblock-1")')! == ''
	assert runtime.evaluate_host('paid.getAttribute("data-vox-adblock-2")')! == ''
	assert messages == []string{}
}
