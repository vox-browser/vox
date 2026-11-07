module main

import adblock
import browserjs
import css
import dom
import page
import platform

fn test_adblock_cached_survey_observes_attribute_tree_and_document_changes() {
	mut document := parse_browser_navigation_document('<!doctype html><body><div id="one" class="first repeated first"></div><div id="host"></div><svg><g id="icon" class="svg-class"></g></svg></body>', dom.url_about_blank(), none)
	mut other := parse_browser_navigation_document('<!doctype html><body id="other"></body>', dom.url_about_blank(), none)
	mut cache := BrowserAdblockTokenCache{}
	defer { cache.release(); document.finalize(); other.finalize() }
	assert cache.survey(document) == selector_adblock_token_survey(document)
	before := cache.tokens.data
	assert cache.survey(document) == selector_adblock_token_survey(document)
	if !disable_adblock_token_reuse { assert cache.tokens.data == before }
	mut one := document.get_element_by_id('one')?
	one.set_attribute_value('id', 'renamed')
	one.set_attribute_value('class', 'changed\tsecond')
	assert cache.survey(document) == selector_adblock_token_survey(document)
	mut classes := one.class_list()
	classes.add(['added'])!
	assert '.added' in cache.survey(document)
	mut attributes := one.attributes()
	attributes.set_attribute(&dom.Attr_{name_: 'class', local_name_: 'class', value_: 'via-attribute'})!
	assert '.via-attribute' in cache.survey(document)
	assert '.added' !in cache.tokens
	mut icon := document.get_element_by_id('icon')?
	icon.set_attribute_value('class', 'new-svg')
	assert cache.survey(document) == selector_adblock_token_survey(document)
	mut node := one.as_node()
	node.remove(false)
	assert '#renamed' !in cache.survey(document)
	_ = document.body()?.as_node().append_child(node)!
	assert '#renamed' in cache.survey(document)
	other.adopt_node(node)
	_ = other.body()?.as_node().append_child(node)!
	assert '#renamed' !in cache.survey(document)
	assert '#renamed' in cache.survey(other)
	assert cache.survey(other) == selector_adblock_token_survey(other)
	assert cache.survey(document) == selector_adblock_token_survey(document)
	// Shadow-only classes never become cosmetic survey inputs.
	mut host := document.get_element_by_id('host')?
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	mut child := document.create_element('span')!
	child.set_attribute_value('class', 'shadow-only')
	_ = shadow.as_node().append_child(child.as_node())!
	assert '.shadow-only' !in cache.survey(document)
}

fn test_adblock_cached_tokens_survive_caller_storage_and_bound_replacement_storage() {
	mut document := parse_browser_navigation_document('<!doctype html><div id="item" class="original"></div>', dom.url_about_blank(), none)
	mut cache := BrowserAdblockTokenCache{}
	defer { cache.release(); document.finalize() }
	mut caller := platform.new_arena('adblock survey caller')
	entry := caller.enter()
	assert '.original' in cache.survey(document)
	caller.leave(entry)
	caller.release()
	assert '.original' in cache.survey(document)
	mut item := document.get_element_by_id('item')?
	mut first_usage := i64(0)
	for index in 0 .. 64 {
		item.set_attribute_value('class', 'replacement${index:02}')
		assert cache.survey(document) == selector_adblock_token_survey(document)
		$if prealloc {
			assert cache.storage.contains(cache.tokens.data)
			for token in cache.tokens { assert cache.storage.contains(token.str) }
			if index == 0 { first_usage = cache.storage.usage().used }
			assert cache.storage.usage().used <= first_usage + 256
		}
	}
	cache.release()
	assert !cache.valid && cache.tokens.len == 0 && cache.storage == unsafe { nil }
	assert '.replacement63' in cache.survey(document)
}

fn test_cached_adblock_survey_preserves_filter_toggle_and_live_styles() {
	mut document := parse_browser_navigation_document('<!doctype html><div id="target" class="ad_banner">Advertisement</div><p id="story">Story</p>', dom.URL{value: 'https://www.theverge.com/'}, none)
	mut cache := BrowserAdblockTokenCache{}
	defer { cache.release(); document.finalize(); adblock.set_enabled(true) }
	css.set_document_user_style_sheet(document, '#story{color:green!important}')
	install_browser_adblock_styles_with_tokens(document, '', mut cache)!
	target := document.get_element_by_id('target')?
	assert cached_adblock_test_property(document, target, .display) == 'none'
	adblock.set_enabled(false)
	install_browser_adblock_styles_with_tokens(document, '', mut cache)!
	assert cached_adblock_test_property(document, target, .display) == 'block'
	adblock.set_enabled(true)
	install_browser_adblock_styles_with_tokens(document, '', mut cache)!
	assert cached_adblock_test_property(document, target, .display) == 'none'
	story := document.get_element_by_id('story')?
	assert cached_adblock_test_property(document, story, .color) == 'rgb(0, 128, 0)'
}

fn test_cached_adblock_survey_observes_procedural_mutation_between_primed_and_final_styles() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><div id="target">Advertisement</div><p id="story">Story</p>', dom.URL{value: 'https://www.theverge.com/'}, none)
	mut runtime := browserjs.Runtime.create()
	mut app := &BrowserApp{document: document, js_runtime: runtime}
	defer { app.adblock_tokens.release(); runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	assert messages.len == 0
	assert '.ad_banner' !in app.adblock_tokens.survey(document)
	runtime.evaluate_host('globalThis.__voxAdblockProceduralCSS=()=>"/* prime */";globalThis.__voxAdblockApplyProcedural=()=>{target.setAttribute("class","ad_banner");story.setAttribute("class","organic");return "/* final */"}')!
	app.refresh_browser_adblock()
	assert app.js_messages.len == 0
	assert '.ad_banner' in app.adblock_tokens.survey(document)
	assert '.organic' in app.adblock_tokens.tokens
	target := document.get_element_by_id('target')?
	assert cached_adblock_test_property(document, target, .display) == 'none'
}

fn cached_adblock_test_property(document &dom.Document, element &dom.Element, property css.PropertyID) string {
	style := css.StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	return (style.property(property, .no) or { panic('missing computed property') }).css_text
}

fn test_cached_adblock_tokens_follow_navigation_and_are_released_with_the_tab() {
	owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{url: 'https://token-cache.test/first', markup: '<!doctype html><body class="first-page">First</body>'}, false)
	assert '.first-page' in app.adblock_tokens.survey(app.document)
	app.install_loaded_page(LoadedPage{url: 'https://token-cache.test/second', markup: '<!doctype html><body class="second-page">Second</body>'}, false)
	assert '.second-page' in app.adblock_tokens.survey(app.document)
	assert '.first-page' !in app.adblock_tokens.tokens
	app.dispose_browser_tab()
	assert !app.adblock_tokens.valid
	assert app.adblock_tokens.document == unsafe { nil }
	assert app.adblock_tokens.storage == unsafe { nil }
	assert app.adblock_tokens.tokens.len == 0
}
