module main

import adblock
import css
import dom

fn test_unchanged_cosmetic_rules_do_not_replace_the_user_sheet_after_token_changes() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><div id="advert" data-concert="leaderboard">Advertisement</div><article id="news">News</article>',
		dom.URL{value: 'https://www.theverge.com/'}, none)
	defer { document.finalize() }
	css.set_document_user_style_sheet(document, '#news { color: green !important; }')
	install_browser_adblock_styles(document, '')!
	scope := css.style_scope_for_dom_node(unsafe { &dom.Node(document) })
	source := scope.user_style_source or { panic('missing cosmetic sheet') }
	document.update_style()
	document.set_needs_full_style_update(false)
	mut news := document.get_element_by_id('news') or { panic('missing article') }
	news.set_attribute_value('class', 'vox-irrelevant-cosmetic-token')
	document.update_style()
	document.set_needs_full_style_update(false)
	install_browser_adblock_styles(document, '')!
	assert (scope.user_style_source or { panic('lost cosmetic sheet') }) == source
	assert !document.needs_full_style_update()
	advert := document.get_element_by_id('advert') or { panic('missing advert') }
	computed := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(advert, none))
	assert (computed.property(.display, .no) or { panic("missing computed property") }).css_text == 'none'
	assert source.contains('#news { color: green !important; }')
}

fn test_cosmetic_sheet_changes_follow_procedural_rules_and_enable_state() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><article id="news">News</article>',
		dom.URL{value: 'https://www.theverge.com/'}, none)
	defer { document.finalize() }
	install_browser_adblock_styles(document, '#news{display:none!important}')!
	scope := css.style_scope_for_dom_node(unsafe { &dom.Node(document) })
	source := scope.user_style_source or { panic('missing procedural sheet') }
	assert source.contains('#news{display:none!important}')
	install_browser_adblock_styles(document, '#news{visibility:hidden!important}')!
	changed := scope.user_style_source or { panic('missing changed sheet') }
	assert changed != source
	assert changed.contains('#news{visibility:hidden!important}')
	assert !changed.contains('#news{display:none!important}')
	adblock.set_enabled(false)
	defer { adblock.set_enabled(true) }
	install_browser_adblock_styles(document, '')!
	assert !(scope.user_style_source or { '' }).contains('vox-adblock-start')
	adblock.set_enabled(true)
	install_browser_adblock_styles(document, '')!
	assert (scope.user_style_source or { '' }).contains('vox-adblock-start')
}
