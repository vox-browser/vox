module main

import adblock
import browserjs
import css
import dom

fn test_empty_procedural_css_retains_the_existing_user_sheet_and_style_epoch() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><article id="news">News</article>',
		dom.URL{value: 'https://www.bbc.com/'}, none)
	defer { document.finalize() }
	css.set_document_user_style_sheet(document, '#news{color:green!important}')
	install_browser_adblock_styles(document, '')!
	document.update_style()
	scope := css.style_scope_for_dom_node(document.as_node())
	source := scope.user_style_source or { panic('missing user sheet') }
	sheet := scope.user_style_sheet or { panic('missing parsed user sheet') }
	version := document.style_environment_version()
	install_browser_adblock_styles(document, '/* vox procedural filters */\n')!
	assert ((scope.user_style_source or { '' }) == source) == !retain_empty_procedural_styles
	assert (document.style_environment_version() == version) == !retain_empty_procedural_styles
	if !retain_empty_procedural_styles {
		assert voidptr(scope.user_style_sheet or { panic('lost user sheet') }) == voidptr(sheet)
	}
}

fn test_empty_procedural_css_still_commits_remove_actions_to_the_live_dom() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><div id="paid">Sponsored</div><article id="news">News</article>',
		dom.URL{value: 'https://example.test/'}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	install_browser_adblock_styles(document, '')!
	scope := css.style_scope_for_dom_node(document.as_node())
	source := scope.user_style_source or { panic('missing initial sheet') }
	filters := adblock.DocumentFilters{procedural: [
		r'{"raw":"#paid:remove()","selector":"#paid","action":["remove",""]}',
	]}
	runtime.evaluate_host(adblock.procedural_script(filters))!
	assert runtime.evaluate_host('__voxAdblockProceduralCSS()')! == '/* vox procedural filters */\n'
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages == []string{}
	assert document.get_element_by_id('paid') == none
	assert document.get_element_by_id('news') != none
	assert ((scope.user_style_source or { '' }) == source) == !retain_empty_procedural_styles
}

fn test_empty_procedural_payload_removes_previous_rules_and_preserves_real_new_rules() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><article id="news">News</article>',
		dom.URL{value: 'https://example.test/'}, none)
	defer { document.finalize() }
	install_browser_adblock_styles(document, '/* vox procedural filters */\n#news{display:none!important}')!
	scope := css.style_scope_for_dom_node(document.as_node())
	assert (scope.user_style_source or { '' }).contains('#news{display:none!important}')
	install_browser_adblock_styles(document, '/* vox procedural filters */\n')!
	document.update_style()
	news := document.get_element_by_id('news') or { panic('missing story') }
	style := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(news, none))
	assert (style.property(.display, .no) or { panic("missing computed property") }).css_text != 'none'
	install_browser_adblock_styles(document, '/* vox procedural filters */\n#news{color:red!important}')!
	updated := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(news, none))
	assert (updated.property(.color, .no) or { panic("missing computed property") }).css_text == 'rgb(255, 0, 0)'
}
