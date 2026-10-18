module html

import dom
import page

fn audio_paint_document(owner &page.Page, address string) !&dom.Document {
	url := dom.URL{value: address}
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	parse_html_from_a_string(document, '<!doctype html><body><audio id="player" preload="none"></audio></body>')
	return document
}

fn test_audio_paint_uses_the_live_attribute_independently_of_controller_lifetime() {
	owner := page.Page.create(1)!
	mut document := audio_paint_document(owner, 'https://audio-paint.example/')!
	mut element := document.get_element_by_id('player') or { panic('Missing audio') }
	mut media := html_media_element_for_dom_element(element) or { panic('Missing media') }
	defer { media.finalize(); document.finalize() }
	audio := HTMLAudioElementModel.create(media)
	assert element.as_node().is_scripting_enabled() && !media.has_controls()
	// An owned element queries its actual policy, including when a caller's
	// compatibility hint is stale.
	assert !audio.should_paint(false) && !audio.should_paint(true)
	media.create_controls()
	assert media.has_controls() && !element.has_attribute('controls')
	assert !audio.should_paint(false)
	media.destroy_controls()
	element.set_attribute_value('controls', 'false')
	assert media.has_controls() && audio.should_paint(false)
	media.destroy_controls()
	assert !media.has_controls() && audio.should_paint(false)
	element.remove_attribute('controls')
	assert !audio.should_paint(false)
	// Source uses has_attribute's qualified-name lookup, independently of
	// the local-name check which creates a controller at attribute changes.
	element.set_attribute_value_ns('controls', 'prefixed', 'p', 'urn:audio-paint')
	assert media.has_controls() && !element.has_attribute('controls')
	assert !audio.should_paint(false)
	element.remove_attribute_ns('urn:audio-paint', 'controls')
	element.set_attribute_value_ns('controls', 'unprefixed', none, 'urn:audio-paint')
	assert element.has_attribute('controls') && !element.has_attribute_ns(none, 'controls')
	assert audio.should_paint(false)
	element.remove_attribute_ns('urn:audio-paint', 'controls')
	assert !audio.should_paint(false)
}

fn test_audio_paint_queries_the_current_document_and_page_scripting_policy() {
	mut old_page := page.Page.create(1)!
	mut new_page := page.Page.create(1)!
	mut first := audio_paint_document(old_page, 'https://audio-paint-old.example/')!
	mut second := audio_paint_document(new_page, 'https://audio-paint-new.example/')!
	mut element := first.get_element_by_id('player') or { panic('Missing old audio') }
	mut media := html_media_element_for_dom_element(element) or { panic('Missing media') }
	defer { media.finalize(); first.finalize(); second.finalize() }
	audio := HTMLAudioElementModel.create(media)
	assert !audio.should_paint(true)
	old_page.set_is_scripting_enabled(false)
	assert element.as_node().is_scripting_disabled() && audio.should_paint(false)
	old_page.set_is_scripting_enabled(true)
	assert !audio.should_paint(true)
	first.set_scripting_enabled_by_embedder(false)
	assert audio.should_paint(false)
	second.adopt_node(element.as_node())
	assert media.document()? == second && element.as_node().is_scripting_enabled()
	assert !audio.should_paint(true)
	new_page.set_is_scripting_enabled(false)
	assert audio.should_paint(false)
	new_page.set_is_scripting_enabled(true)
	second.set_scripting_enabled_by_embedder(false)
	assert audio.should_paint(false)
	second.set_scripting_enabled_by_embedder(true)
	assert !audio.should_paint(true) && !element.has_attribute('controls')
	mut inactive := dom.Document.create(dom.URL{value: 'https://audio-paint-no-context.example/'})
	defer { inactive.finalize() }
	mut detached := inactive.create_element_ns(dom.namespace_html_uri, 'audio')!
	mut detached_media := html_media_element_for_dom_element(detached)?
	defer { detached_media.finalize() }
	assert detached.as_node().is_scripting_disabled()
	assert HTMLAudioElementModel.create(detached_media).should_paint(false)
}

fn test_ownerless_audio_paint_preserves_the_explicit_compatibility_inputs() {
	mut media := HTMLMediaElement.create(none, dom.URL{value: 'https://ownerless-audio-paint.example/'})
	defer { media.finalize() }
	audio := HTMLAudioElementModel.create(media)
	assert !audio.should_paint(false) && audio.should_paint(true)
	media.create_controls()
	assert audio.should_paint(false) && audio.should_paint(true)
	media.destroy_controls()
	assert !audio.should_paint(false) && audio.should_paint(true)
}
