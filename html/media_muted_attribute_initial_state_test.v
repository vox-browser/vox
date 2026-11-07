module html

import dom

// https://html.spec.whatwg.org/multipage/media.html#dom-media-muted
// A media element created with a muted content attribute starts muted. Parsed
// owners are materialized after the parser set their attributes; later
// content-attribute changes only reflect defaultMuted.
fn test_parsed_media_with_muted_attribute_start_muted() {
	mut document := parse_document('<!doctype html><video id="muted" muted autoplay></video><audio id="audio" muted=""></audio><video id="plain"></video>')
	defer { document.finalize() }
	muted := html_media_element_for_dom_element(document.get_element_by_id('muted') or { panic('muted') }) or { panic('muted model') }
	assert muted.muted() && muted.effective_media_volume() == 0
	audio := html_media_element_for_dom_element(document.get_element_by_id('audio') or { panic('audio') }) or { panic('audio model') }
	assert audio.muted()
	plain := html_media_element_for_dom_element(document.get_element_by_id('plain') or { panic('plain') }) or { panic('plain model') }
	assert !plain.muted()
}

fn test_muted_attribute_added_after_materialization_does_not_mute() {
	mut document := parse_document('<!doctype html><body></body>')
	defer { document.finalize() }
	mut element := dom.create_element(document, 'video', 'http://www.w3.org/1999/xhtml', none, none, false) or { panic(err) }
	media := html_media_element_for_dom_element(element) or { panic('video model') }
	element.set_attribute_value('muted', '')
	assert !media.muted() && element.has_attribute('muted')
}
