module main

import browserjs
import dom

@[heap]
struct AdblockReplayProviderProbe {
mut:
	snapshots int
	lookups   int
}

fn test_adblock_refresh_replays_changed_elements_without_copying_all_providers() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><div id="advert">Advertisement</div><article id="story">Keep</article>',
		dom.URL{value: 'https://example.test/'}, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	mut probe := &AdblockReplayProviderProbe{}
	runtime.add_canvas_element_provider_with_lookup(fn [mut probe] () map[string]&dom.Element {
		probe.snapshots++
		return map[string]&dom.Element{}
	}, fn [mut probe] (_ string) ?&dom.Element {
		probe.lookups++
		return none
	})
	runtime.evaluate_host('globalThis.__voxAdblockApplyProcedural=()=>{advert.setAttribute("data-filtered","yes");advert.remove();story.setAttribute("data-organic","keep");return "/* procedural fixture */"}')!
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages == []string{}
	assert document.get_element_by_id('advert') == none
	story := document.get_element_by_id('story') or { panic('organic story was removed') }
	assert story.get_attribute_value('data-organic') == 'keep'
	assert story.as_node().text_content() or { '' } == 'Keep'
	assert probe.lookups > 0
	assert probe.snapshots == 0
	// A subsequent commit with no DOM effects also needs no provider snapshot.
	runtime.evaluate_host('globalThis.__voxAdblockApplyProcedural=()=>"/* procedural fixture */"')!
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages == []string{}
	assert probe.snapshots == 0
}
