module main

import adblock
import browserjs
import css
import dom
import json2
import os

struct PikabuSlotProbeExpected {
	blocked          int
	visible          int
	controls_visible int
}

struct PikabuSlotProbe {
	url        string
	candidates []string
	controls   []string
	expected   PikabuSlotProbeExpected
}

fn pikabu_native_slot_is_blocked(document &dom.Document, id string) !bool {
	element := document.get_element_by_id(id) or { return true }
	// Outside the ordinary document style traversal, populate the same ancestor
	// bloom filter that traversal maintains before matching contextual rules.
	mut computer := css.StyleComputer.new(document)
	style := computer.compute_style_with_seeded_ancestors(dom.AbstractElement.new(element, none))
	return style.property(.display, .no)!.css_text == 'none'
}

fn test_pikabu_ru_filters_block_five_ad_slots_and_preserve_organic_content() {
	$if !darwin { return }
	fixture := os.read_file(os.join_path(@VMODROOT, 'tools', 'adblock', 'fixtures',
		'pikabu-slots.html'))!
	probe := json2.decode[PikabuSlotProbe](os.read_file(os.join_path(@VMODROOT, 'tools', 'adblock',
		'fixtures', 'pikabu-slots-probe.json'))!)!
	address := dom.URL{
		value: probe.url
	}
	mut document := parse_browser_navigation_document(fixture, address, none)
	ad_ids := probe.candidates
	control_ids := probe.controls
	for id in ad_ids {
		assert document.get_element_by_id(id) != none, 'missing initial ad slot ${id}'
		assert !pikabu_native_slot_is_blocked(document, id)!, 'fixture started with hidden ad slot ${id}'
	}
	for id in control_ids {
		assert document.get_element_by_id(id) != none, 'missing initial organic content ${id}'
		assert !pikabu_native_slot_is_blocked(document, id)!, 'fixture started with hidden organic content ${id}'
	}
	selected := adblock.document_filters(address.serialize(), browser_adblock_tokens(document))!
	assert selected.filters.any(it.contains('json-prune, isVideoAutoplayMode'))
	assert selected.filters.any(it.contains('abort-on-property-read, Ya'))
	assert selected.procedural.len > 0
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	// The ordinary page startup installs the selected upstream scriptlets and
	// procedural engine against native DOM/Window bindings before page scripts.
	run_document_javascript(document, address.serialize(), []string{}, runtime, mut messages)
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages == [], '${messages}'
	mut blocked_count := 0
	mut slot_results := []string{}
	for id in ad_ids {
		blocked := pikabu_native_slot_is_blocked(document, id)!
		slot_results << '${id}:${blocked}'
		if blocked { blocked_count++ }
	}

	assert blocked_count == probe.expected.blocked, '${slot_results}'
	assert ad_ids.len - blocked_count == probe.expected.visible
	mut organic_visible := 0
	for id in control_ids {
		assert document.get_element_by_id(id) != none, 'organic content was removed: ${id}'
		assert !pikabu_native_slot_is_blocked(document, id)!, 'organic content was hidden: ${id}'
		organic_visible++
	}
	assert organic_visible == probe.expected.controls_visible
	assert runtime.evaluate_host('(()=>{const value=JSON.parse(JSON.stringify({isVideoAutoplayMode:true,title:"Keep"}));return !Object.prototype.hasOwnProperty.call(value,"isVideoAutoplayMode")&&value.title==="Keep"})()')! == 'true'
	assert runtime.evaluate_host('(()=>{try{globalThis.Ya;return false}catch(error){return error instanceof ReferenceError}})()')! == 'true'
}

fn test_adblock_procedural_runtime_failures_are_reported() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><body>Content</body>',
		dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host('globalThis.__voxAdblockApplyProcedural=()=>{throw new Error("adblock procedural fixture failure")}')!
	mut messages := []string{}
	refresh_browser_adblock(document, runtime, mut messages)
	assert messages.len == 1
	assert messages[0].starts_with('Adblock procedural filters:')
	assert messages[0].contains('adblock procedural fixture failure')
}
