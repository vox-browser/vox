module main

import browserjs
import dom
import html
import page
import time

@[heap]
struct MediaSrcProbe {
mut:
	urls []string
}

fn media_src_document(address string, markup string) !&dom.Document {
	url := dom.URL{ value: address }
	return html.parse_navigation_document(markup, url, url.origin(), none)!
}

fn media_src_observe(mut media html.HTMLMediaElement, probe &MediaSrcProbe) {
	media.set_fetch_hook(fn [probe] (url dom.URL, offset u64) !html.MediaResourceResponse {
		assert offset == 0
		mut observed := unsafe { &MediaSrcProbe(probe) }
		observed.urls << url.serialize()
		return html.MediaResourceResponse{ mime_type: 'audio/webm', duration: 7, buffered_end: 7 }
	})
}

fn media_src_flush(document &dom.Document, runtime &browserjs.Runtime) ! {
	snapshot := runtime.evaluate_host('__ladybirdFinalize()')!
	mut messages := []string{}
	apply_javascript_runtime_state(document, snapshot, runtime, mut messages)
	assert messages == []
	_ = runtime.evaluate_host('__ladybirdClearLogs();0')!
}

fn test_media_src_dom_changes_and_equal_writes_load_each_actual_audio_and_video_owner_once() {
	mut document := media_src_document('https://media-src.example/first/page.html', '<!doctype html><audio id="ms-audio"></audio><video id="ms-video"></video>')!
	defer { document.finalize() }
	for id in ['ms-audio', 'ms-video'] {
		mut element := document.get_element_by_id(id)?
		mut media := html.html_media_element_for_dom_element(element)?
		probe := &MediaSrcProbe{}
		media_src_observe(mut media, probe)
		assert media.current_src() == '' && media.network_state() == .empty
		element.set_attribute_value('src', 'first.webm')
		attribute := element.get_attribute_node_ns(none, 'src')?
		assert probe.urls == ['https://media-src.example/first/first.webm']
		assert media.current_src() == probe.urls[0] && media.ready_state() == .have_enough_data
		element.set_attribute_value('src', 'first.webm')
		assert probe.urls.len == 2 && probe.urls[0] == probe.urls[1]
		element.set_attribute_value('src', '../second.webm')
		assert probe.urls.len == 3 && probe.urls[2] == 'https://media-src.example/second.webm'
		assert media.current_src() == probe.urls[2] && media.paused()
		assert voidptr(element.get_attribute_node_ns(none, 'src')?) == voidptr(attribute)
		assert media.event_count('loadstart') == 3
	}
}

fn test_media_src_removal_does_not_load_but_removes_stale_input_from_the_next_selection() {
	mut document := media_src_document('https://media-src.example/', '<!doctype html><audio id="ms-audio"></audio>')!
	defer { document.finalize() }
	mut element := document.get_element_by_id('ms-audio')?
	mut media := html.html_media_element_for_dom_element(element)?
	probe := &MediaSrcProbe{}
	media_src_observe(mut media, probe)
	element.set_attribute_value('src', 'playing.webm')
	current := media.current_src()
	state := media.ready_state()
	element.remove_attribute('src')
	element.remove_attribute('src')
	assert probe.urls.len == 1 && media.current_src() == current && media.ready_state() == state
	assert media.event_count('loadstart') == 1
	media.load()!
	assert probe.urls.len == 1 && media.current_src() == '' && media.network_state() == .empty
	assert media.ready_state() == .have_nothing
}

fn test_media_src_source_namespace_hook_uses_qualified_selection_and_retains_attr_identity() {
	mut document := media_src_document('https://media-src.example/', '<!doctype html><video id="ms-video"></video><svg><video id="ms-svg"></video></svg>')!
	defer { document.finalize() }
	mut element := document.get_element_by_id('ms-video')?
	// The first qualified attribute seeds an owner created after parsing.
	element.set_attribute_value_ns('src', 'foreign.webm', none, 'urn:media-src')
	element.set_attribute_value('src', 'plain.webm')
	foreign := element.get_attribute_node_ns('urn:media-src', 'src')?
	plain := element.get_attribute_node_ns(none, 'src')?
	mut media := html.html_media_element_for_dom_element(element)?
	probe := &MediaSrcProbe{}
	media_src_observe(mut media, probe)
	media.load()!
	assert probe.urls == ['https://media-src.example/foreign.webm']
	element.set_attribute_ns_for_bindings('urn:prefixed-src', 'q:src', 'ignored.webm')!
	assert probe.urls.len == 2 && probe.urls[1] == probe.urls[0]
	element.set_attribute_value('src', 'changed-plain.webm')
	assert probe.urls.len == 3 && probe.urls[2] == probe.urls[0]
	assert voidptr(element.get_attribute_node_ns('urn:media-src', 'src')?) == voidptr(foreign)
	assert voidptr(element.get_attribute_node_ns(none, 'src')?) == voidptr(plain)
	element.remove_attribute_ns('urn:media-src', 'src')
	element.remove_attribute_ns('urn:prefixed-src', 'src')
	assert probe.urls.len == 3 && media.current_src() == probe.urls[0]
	element.set_attribute_value('src', 'changed-plain.webm')
	assert probe.urls.len == 4 && media.current_src() == 'https://media-src.example/changed-plain.webm'
	mut svg := document.get_element_by_id('ms-svg')?
	svg.set_attribute_value('src', 'svg.webm')
	assert html.html_media_element_for_dom_element(svg) == none && probe.urls.len == 4
}

fn test_media_src_parsing_stays_lazy_and_adoption_and_live_base_follow_the_current_document() {
	mut document := media_src_document('https://media-src.example/old/page.html', '<!doctype html><audio id="ms-live"></audio><video id="ms-lazy" src="parsed.webm"></video>')!
	mut destination := media_src_document('https://adopted-media-src.example/new/page.html', '<!doctype html><base id="ms-base" href="/base/"><body></body>')!
	defer { document.finalize(); destination.finalize() }
	mut element := document.get_element_by_id('ms-live')?
	mut media := html.html_media_element_for_dom_element(element)?
	probe := &MediaSrcProbe{}
	media_src_observe(mut media, probe)
	mut lazy := document.get_element_by_id('ms-lazy')?
	assert unsafe { &dom.HTMLVideoElement(lazy) }.media_element_model_ == unsafe { nil }
	lazy.set_attribute_value('src', 'still-lazy.webm')
	assert unsafe { &dom.HTMLVideoElement(lazy) }.media_element_model_ == unsafe { nil }
	assert probe.urls.len == 0
	element.set_attribute_value('src', 'old.webm')
	assert probe.urls == ['https://media-src.example/old/old.webm']
	destination.adopt_node(element.as_node())
	element.set_attribute_value('src', 'new.webm')
	assert probe.urls.len == 2 && probe.urls[1] == 'https://adopted-media-src.example/base/new.webm'
	mut base := destination.get_element_by_id('ms-base')?
	base.set_attribute_value('href', '/changed/')
	element.set_attribute_value('src', 'new.webm')
	assert probe.urls.len == 3 && probe.urls[2] == 'https://adopted-media-src.example/changed/new.webm'
	assert voidptr(html.html_media_element_for_dom_element(element)?) == voidptr(media)
}

fn test_compact_media_src_explicit_equal_mutations_load_once_and_dirty_flushes_do_not_repeat() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><video id="ms-parsed"></video>', dom.URL{ value: 'https://media-src.example/' },
		none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.msPlayers=[document.getElementById("ms-parsed")];const a=document.createElement("audio");a.id="ms-created";document.body.appendChild(a);msPlayers.push(a);for(const p of msPlayers)void p.paused;0'], runtime, mut messages)
	assert messages == []
	for index, id in ['ms-parsed', 'ms-created'] {
		mut element := document.get_element_by_id(id)?
		mut media := html.html_media_element_for_dom_element(element)?
		probe := &MediaSrcProbe{}
		media_src_observe(mut media, probe)
		assert runtime.evaluate_host('msPlayers[${index}].setAttribute("src","one.webm");msPlayers[${index}].currentSrc==="https://media-src.example/one.webm"')! == 'true'
		assert probe.urls.len == 1
		attribute := element.get_attribute_node_ns(none, 'src')?
		media_src_flush(document, runtime)!
		media_src_flush(document, runtime)!
		assert probe.urls.len == 1
		assert runtime.evaluate_host('msPlayers[${index}].setAttribute("src","one.webm");msPlayers[${index}].setAttribute("data-dirty","same source");msPlayers[${index}].currentSrc==="https://media-src.example/one.webm"')! == 'true'
		assert probe.urls.len == 2
		assert runtime.evaluate_host('msPlayers[${index}].src="two.webm";msPlayers[${index}].currentSrc==="https://media-src.example/two.webm"')! == 'true'
		assert probe.urls.len == 3 && voidptr(element.get_attribute_node_ns(none, 'src')?) == voidptr(attribute)
		assert runtime.evaluate_host('msPlayers[${index}].removeAttribute("src");msPlayers[${index}].currentSrc==="https://media-src.example/two.webm"')! == 'true'
		media_src_flush(document, runtime)!
		assert probe.urls.len == 3 && !element.has_attribute('src')
		media.load()!
		assert media.network_state() == .empty && probe.urls.len == 3
	}
}

fn test_compact_media_src_foreign_qualified_mutations_reach_the_same_dom_hook_once() {
	$if !darwin { return }
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><video id="ms-video"></video>', dom.URL{ value: 'https://media-src.example/' },
		none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut element := document.get_element_by_id('ms-video')?
	element.set_attribute_value_ns('src', 'first.webm', none, 'urn:media-src')
	element.set_attribute_value('src', 'plain.webm')
	foreign := element.get_attribute_node_ns('urn:media-src', 'src')?
	plain := element.get_attribute_node_ns(none, 'src')?
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'globalThis.msOwner=document.getElementById("ms-video");void msOwner.paused;0'], runtime, mut messages)
	assert messages == []
	mut media := html.html_media_element_for_dom_element(element)?
	probe := &MediaSrcProbe{}
	media_src_observe(mut media, probe)
	assert runtime.evaluate_host('msOwner.setAttribute("src","changed.webm");msOwner.currentSrc==="https://media-src.example/changed.webm"')! == 'true'
	assert probe.urls.len == 1 && element.get_attribute_ns(none, 'src')? == 'plain.webm'
	assert voidptr(element.get_attribute_node_ns('urn:media-src', 'src')?) == voidptr(foreign)
	media_src_flush(document, runtime)!
	assert probe.urls.len == 1
	assert runtime.evaluate_host('msOwner.removeAttribute("src");msOwner.currentSrc==="https://media-src.example/changed.webm"&&msOwner.getAttribute("src")==="plain.webm"')! == 'true'
	assert probe.urls.len == 1 && foreign.owner_element() == none
	assert runtime.evaluate_host('msOwner.setAttribute("src","plain.webm");msOwner.currentSrc==="https://media-src.example/plain.webm"')! == 'true'
	media_src_flush(document, runtime)!
	media_src_flush(document, runtime)!
	assert probe.urls.len == 2 && voidptr(element.get_attribute_node_ns(none, 'src')?) == voidptr(plain)
}
