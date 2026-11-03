module main

import browserjs
import dom
import html
import platform

fn async_replay_storage_trial(temporary bool) ?i64 {
	mut document := html.parse_document('<!doctype html><main id="target">before</main>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	target := document.get_element_by_id('target')?
	runtime.add_canvas_element_provider_with_lookup(fn [target] () map[string]&dom.Element {
		return {'target':target}
	}, fn [target] (key string) ?&dom.Element {
		return if key == 'target' { ?&dom.Element(target) } else { none }
	})
	encoded := '{"elements":{"target":{"bridgeKey":"target","attributesDirty":true,"attributes":{"id":"target","data-label":"λ😀"},"textContentDirty":true,"textContent":"after 雪😀"}},"logs":["retained λ😀"],"navigate":"/next?λ😀","unused":[' + '{"padding":[1,2,3,4],"other":{"more":17}},'.repeat(255) + '{"last":true}]}'
	storage := document.native_storage()
	before := if storage != unsafe { nil } { storage.arena.usage().used } else { i64(0) }
	mut messages := []string{}
	navigation := if temporary {
		apply_javascript_runtime_state(document, encoded, runtime, mut messages)?
	} else {
		state := javascript_replay_state(encoded, mut messages)?
		apply_decoded_javascript_state(document, state, {'target':target}, mut messages)?
	}
	growth := if storage != unsafe { nil } { storage.arena.usage().used - before } else { i64(0) }
	churn := platform.begin_thread_scratch('async replay overwrite')
	_ = []u8{len: 128 * 1024, init: u8(0xa5)}
	churn.finish()
	assert target.get_attribute_value('data-label') == 'λ😀'
	assert target.as_node().text_content()? == 'after 雪😀'
	assert messages == ['retained λ😀']
	assert navigation == '/next?λ😀'
	return growth
}

fn test_async_replay_retires_json_containers_and_preserves_native_strings() {
	control := async_replay_storage_trial(false)?
	candidate := async_replay_storage_trial(true)?
	$if prealloc {
		assert candidate * 4 < control, '${candidate} candidate versus ${control} control bytes'
		println('Async replay: candidate=${candidate} control=${control} bytes')
	}
}

fn test_async_replay_owns_strings_when_the_caller_has_a_frame_workspace() {
	mut document := html.parse_document('<!doctype html><main id="target">before</main>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	target := document.get_element_by_id('target')?
	runtime.add_canvas_element_provider_with_lookup(fn [target] () map[string]&dom.Element {
		return {'target':target}
	}, fn [target] (_ string) ?&dom.Element { return target })
	mut messages := []string{}
	work := platform.begin_thread_scratch('async replay caller frame')
	encoded := '{"elements":{"target":{"bridgeKey":"target","attributesDirty":true,"attributes":{"id":"target","data-label":"owned λ😀"},"textContentDirty":true,"textContent":"owned 雪😀"}},"logs":["owned message λ😀"],"navigate":"/owned?λ😀"}'.clone()
	navigation := apply_javascript_runtime_state(document, encoded, runtime, mut messages)?
	work.finish()
	assert target.get_attribute_value('data-label') == 'owned λ😀'
	assert target.as_node().text_content()? == 'owned 雪😀'
	assert messages == ['owned message λ😀']
	assert navigation == '/owned?λ😀'
	$if prealloc {
		assert document.native_storage().arena.contains(messages[0].str)
		assert document.native_storage().arena.contains(navigation.str)
	}
}
