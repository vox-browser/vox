module main

import adblock
import browserjs
import css
import dom

fn test_theverge_cosmetics_hide_ad_containers_at_user_origin_and_update_live_tokens() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><style>#advert{display:block!important}</style><body><div id="advert" data-concert="leaderboard">Advertisement</div><article id="news">News</article><div id="late">Late ad</div></body>',
		dom.URL{value: 'https://www.theverge.com/'}, none)
	defer { document.finalize() }
	css.set_document_user_style_sheet(document, '#news { color: green !important; }')
	install_browser_adblock_styles(document, '')!
	advert := document.get_element_by_id('advert') or { panic('missing advert') }
	computed := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(advert, none))
	assert (computed.property(.display, .no) or { panic('missing value') }).css_text == 'none'
	news := document.get_element_by_id('news') or { panic('missing news') }
	news_style := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(news, none))
	assert (news_style.property(.color, .no) or { panic('missing value') }).css_text == 'rgb(0, 128, 0)'
	mut late := document.get_element_by_id('late') or { panic('missing late ad') }
	late.set_attribute_value('class', 'ad_banner')
	install_browser_adblock_styles(document, '')!
	late_style := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(late, none))
	assert (late_style.property(.display, .no) or { panic('missing value') }).css_text == 'none'
	adblock.set_enabled(false)
	defer { adblock.set_enabled(true) }
	install_browser_adblock_styles(document, '')!
	visible := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(advert, none))
	assert (visible.property(.display, .no) or { panic('missing value') }).css_text == 'block'
}

fn test_theverge_scriptlets_run_against_the_native_page_storage() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><body>News</body>',
		dom.URL{value: 'https://www.theverge.com/'}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	assert messages == []
	runtime.evaluate_host('localStorage.setItem("csg_uid","adblock-test");document.cookie="vmidv1=tracking; path=/"')!
	install_browser_adblock_scriptlets(document, runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('localStorage.getItem("csg_uid")===null')! == 'true'
}

fn test_upstream_procedural_filters_apply_and_remove_live_native_nodes() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><body><div id="paid">Sponsored story</div><p id="remove">Tracking prompt</p><div id="news">News</div></body>', dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	assert messages == []
	filters := adblock.DocumentFilters{procedural: [
		r'{"raw":"div:has-text(Sponsored)","selector":"div","tasks":[["has-text","Sponsored"]]}',
		r'{"raw":"p:has-text(Tracking):remove()","selector":"p","tasks":[["has-text","Tracking"]],"action":["remove",""]}',
	]}
	runtime.evaluate_host(adblock.procedural_script(filters))!
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('remove') == none
	paid := document.get_element_by_id('paid') or { panic('missing paid story') }
	computed := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(paid, none))
	assert (computed.property(.display, .no) or { panic('missing value') }).css_text == 'none'
	assert document.get_element_by_id('news') != none
}
