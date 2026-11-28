module main

import browserjs
import dom
import html
import platform
import x.json2

@[heap]
struct CompactReplayLookupFixture {
mut:
	elements       map[string]&dom.Element
	snapshot_calls int
	lookup_calls   int
}

fn install_counted_compact_replay_provider(mut runtime browserjs.Runtime,
	mut fixture CompactReplayLookupFixture) {
	runtime.add_canvas_element_provider_with_lookup(fn [mut fixture] () map[string]&dom.Element {
		fixture.snapshot_calls++
		return fixture.elements.clone()
	}, fn [mut fixture] (key string) ?&dom.Element {
		fixture.lookup_calls++
		return fixture.elements[key] or { return none }
	})
}

fn test_compact_replay_element_tables_retire_after_the_batch() {
	$if prealloc {
		mut document := html.parse_document('<!doctype html><div id="target"></div>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		mut runtime := browserjs.Runtime.create()
		defer {
			runtime.close()
			owner.finish()
			document.finalize()
			document.release_native_storage()
		}
		target := document.get_element_by_id('target') or { panic('missing target') }
		mut fixture := &CompactReplayLookupFixture{}
		mut operations := []json2.Any{}
		for index in 0 .. 512 {
			key := 'target-${index}'
			fixture.elements[key] = target
			operations << json2.Any({'target': json2.Any(key)})
		}
		install_counted_compact_replay_provider(mut runtime, mut fixture)
		state := {'operations': json2.Any(operations)}
		storage := document.native_storage()
		before := storage.arena.usage().used
		elements, mut replay_elements, workspace := compact_replay_element_tables(document, state, runtime)
		growth := storage.arena.usage().used - before
		assert growth == 0, 'Replay lookup retained ${growth} document bytes'
		assert elements.len == 512 && replay_elements.len == 512
		assert voidptr(elements['target-511'] or { panic('missing resolved element') }) == voidptr(target)
		replay_elements['created'] = target
		assert 'created' !in elements
		workspace.finish()

		churn := platform.begin_thread_scratch('compact replay lookup test overwrite')
		_ = []u8{len: 128 * 1024, init: u8(0xa5)}
		churn.finish()
		assert fixture.lookup_calls == 512
		assert voidptr(fixture.elements['target-511'] or { panic('missing provider element') }) == voidptr(target)
	}
}

fn test_compact_query_flush_and_finalization_use_keyed_provider_lookups() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><div id="target">before</div>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	mut fixture := &CompactReplayLookupFixture{}
	install_counted_compact_replay_provider(mut runtime, mut fixture)
	runtime.evaluate_host('target.className="changed";if(document.querySelector(".changed")!==target)throw new Error("class replay");target.textContent="after";document.getElementById("target");target.style.color="red";0')!
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document, state, runtime, mut messages)
	assert messages == []string{}
	assert fixture.lookup_calls > 0
	assert fixture.snapshot_calls == 0
	target := document.get_element_by_id('target') or { panic('missing target') }
	assert target.get_attribute_value('class') == 'changed'
	assert target.get_attribute_value('style').trim_right(';') == 'color: red'
	assert target.as_node().text_content() or { '' } == 'after'
}

fn test_compact_replay_resolves_moved_reference_and_selection_end_keys() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><div id="parent"><b id="reference">R</b><i id="child">Child</i></div><p id="end">End</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	parent := document.get_element_by_id('parent') or { panic('missing parent') }
	reference := document.get_element_by_id('reference') or { panic('missing reference') }
	child := document.get_element_by_id('child') or { panic('missing child') }
	end := document.get_element_by_id('end') or { panic('missing end') }
	mut fixture := &CompactReplayLookupFixture{
		elements: {
			'parent-key':    parent
			'child-key':     child
			'reference-key': reference
			'end-key':       end
		}
	}
	install_counted_compact_replay_provider(mut runtime, mut fixture)
	apply_javascript_runtime_state(document, r'{"elements":{},"operations":[{"op":"moveBefore","target":"parent-key","child":"child-key","reference":"reference-key"},{"op":"removeAllRanges"},{"op":"setSelectionRange","target":"child-key","firstChild":true,"startOffset":1,"endTarget":"end-key","endFirstChild":true,"endOffset":2}]}', runtime, mut messages)
	assert messages == []string{}
	assert voidptr(parent.as_node().first_child() or { panic('missing moved child') }) == voidptr(child.as_node())
	selection := document.get_selection() or { panic('missing selection') }
	range := selection.range() or { panic('missing range') }
	assert voidptr(range.start_container()) == voidptr(child.as_node().first_child() or { panic('missing start text') })
	assert voidptr(range.end_container()) == voidptr(end.as_node().first_child() or { panic('missing end text') })
	assert range.start_offset() == 1
	assert range.end_offset() == 2
	assert fixture.snapshot_calls == 0
}

fn test_compact_replay_keeps_live_meta_attribute_and_tree_replacements_current() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><meta id="schemeMeta" name="color-scheme" content="light"><p>text</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	runtime.evaluate_host('schemeMeta.content="only dark";document.querySelector("meta");0')!
	assert document.supported_color_schemes() or { [] } == ['dark']
	assert document.supported_color_schemes_are_only()
	runtime.evaluate_host(r'document.head.innerHTML=`<meta name="color-scheme" content="only light">`;document.querySelector("meta");0')!
	assert document.supported_color_schemes() or { [] } == ['light']
	assert document.supported_color_schemes_are_only()
	assert messages == []string{}
}
