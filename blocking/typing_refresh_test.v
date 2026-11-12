module main

import adblock
import css
import dom
import html
import os

fn test_chatgpt_cosmetic_tokens_reuse_text_and_non_token_mutations() {
	mut document := html.parse_document('<!doctype html><div id="editor" class="composer">one</div><div id="host"></div>')
	document.url = dom.URL{value: 'https://chatgpt.com/'}
	mut cache := BrowserAdblockTokenCache{}
	defer { cache.release(); document.finalize() }
	assert cache.survey(document) == selector_adblock_token_survey(document)
	first := cache.tokens.data
	mut editor := document.get_element_by_id('editor')?
	editor.set_attribute_value('data-state', 'typing')
	editor.as_node().set_text_content('two')!
	mut host := document.get_element_by_id('host')?
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	mut child := document.create_element('span')!
	child.set_attribute_value('class', 'internal-editor')
	shadow.as_node().append_child(child.as_node())!
	assert cache.survey(document) == selector_adblock_token_survey(document)
	if !disable_chatgpt_cosmetic_token_reuse && !disable_adblock_token_reuse {
		assert cache.tokens.data == first
	}
	editor.set_attribute_value('class', 'changed')
	assert '.changed' in cache.survey(document)
	assert '.composer' !in cache.tokens
	assert '.internal-editor' !in cache.tokens
	child.as_node().remove(false)
	document.body()?.as_node().append_child(child.as_node())!
	assert '.internal-editor' in cache.survey(document)
	child.as_node().remove(false)
	assert '.internal-editor' !in cache.survey(document)
}

fn test_cached_cosmetic_css_tracks_tokens_url_enablement_and_lifetime() {
	mut document := html.parse_document('<!doctype html><div id="target" class="ad_banner"></div>')
	document.url = dom.URL{value: 'https://www.theverge.com/'}
	mut cache := BrowserAdblockTokenCache{}
	previous := adblock.is_enabled()
	defer { cache.release(); document.finalize(); adblock.set_enabled(previous) }
	adblock.set_enabled(true)
	assert cache.document_css(document)! == adblock.document_css(document.url.serialize(), selector_adblock_token_survey(document))!
	first := cache.css_source.str
	assert cache.document_css(document)! == cache.css_source
	if !disable_adblock_token_reuse && os.getenv('VOX_DISABLE_DOCUMENT_FILTER_MEMO') != '1' {
		assert cache.css_source.str == first
	}
	mut target := document.get_element_by_id('target')?
	target.set_attribute_value('class', 'organic')
	assert cache.document_css(document)! == adblock.document_css(document.url.serialize(), selector_adblock_token_survey(document))!
	document.url = dom.URL{value: 'https://example.test/'}
	assert cache.document_css(document)! == adblock.document_css(document.url.serialize(), selector_adblock_token_survey(document))!
	adblock.set_enabled(false)
	assert cache.document_css(document)! == ''
	adblock.set_enabled(true)
	assert cache.document_css(document)! == adblock.document_css(document.url.serialize(), selector_adblock_token_survey(document))!
	cache.release()
	assert cache.css_storage == unsafe { nil }
	assert !cache.css_valid
	assert cache.document_css(document)! == adblock.document_css(document.url.serialize(), selector_adblock_token_survey(document))!
}

fn test_cookie_survey_reuses_negative_results_but_observes_late_banners() {
	mut document := html.parse_document('<!doctype html><div id="editor">one</div>')
	mut cache := BrowserCookieSurveyCache{}
	defer { document.finalize() }
	assert cache.apply(document) == 0
	assert !cache.text_sensitive
	before := cache.tree
	mut editor := document.get_element_by_id('editor')?
	editor.as_node().set_text_content('two')!
	assert document.dom_tree_version() > before
	assert cache.apply(document) == 0
	if !disable_cookie_survey_reuse { assert cache.tree == before }
	editor.set_attribute_value('class', 'cookie-banner')
	editor.as_node().set_text_content('We use cookies.')!
	assert cache.apply(document) == 0
	assert cache.text_sensitive
	mut button := document.create_element('button')!
	button.as_node().set_text_content('Accept')!
	editor.as_node().append_child(button.as_node())!
	assert cache.apply(document) == 1
	assert editor.has_attribute('data-vox-cookie-blocked')
	css.inline_style(editor).set_property('display', 'block')
	assert cache.apply(document) == 1
	assert css.inline_style(editor).get_property_priority('display') == 'important'
	assert cache.apply(document) == 0
}

fn test_cookie_survey_observes_text_edits_document_changes_and_policy_toggle() {
	previous := os.getenv_opt('VOX_BLOCK_COOKIE_BANNERS')
	defer {
		if value := previous { os.setenv('VOX_BLOCK_COOKIE_BANNERS', value, true) }
		else { os.unsetenv('VOX_BLOCK_COOKIE_BANNERS') }
	}
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '1', true)
	mut document := html.parse_document('<!doctype html><div role="dialog"><span id="message">Welcome</span><button>Accept</button></div>')
	mut other := html.parse_document('<!doctype html><div id="onetrust-banner-sdk"></div>')
	defer { document.finalize(); other.finalize() }
	mut cache := BrowserCookieSurveyCache{}
	assert cache.apply(document) == 0
	assert cache.text_sensitive
	mut message := document.get_element_by_id('message')?
	mut text := unsafe { &dom.Text(message.as_node().children[0]) }
	text.CharacterData.append_data(' cookies')!
	assert cache.apply(document) == 1
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '0', true)
	assert cache.apply(other) == 0
	assert !cache.valid
	os.setenv('VOX_BLOCK_COOKIE_BANNERS', '1', true)
	assert cache.apply(other) == 1
}
