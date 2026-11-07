module main

import browserjs
import css
import dom
import html
import platform
import x.json2

fn serialization_test_binding(document &dom.Document, elements []&dom.Element) &CompactElementQueryBinding {
	mut binding := &CompactElementQueryBinding{ document: document, runtime: unsafe { nil } }
	for index, element in elements {
		key := '__element_${index}'
		binding.keys[voidptr(element)] = key
		binding.elements[key] = element
	}
	return binding
}

fn test_native_collection_serialization_retires_intermediate_json_graphs() {
	mut document := dom.Document.create(dom.URL{ value: 'https://serialization.test/' })
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><main>' +
		'<span class="comment timestamp" data-one="one" data-two="two" data-three="three">text</span>'.repeat(256) + '</main>')
	elements := css.query_selector_all(document.as_node(), 'span')
	mut control := serialization_test_binding(document, elements)
	mut candidate := serialization_test_binding(document, elements)
	mut storage := platform.new_arena('collection serialization control')
	entry := storage.enter()
	mut states := []json2.Any{}
	for element in elements { states << control.element_state(element) }
	expected := json2.encode(states)
	storage.leave(entry)
	before := platform.thread_arena_usage().used
	actual := candidate.encode_element_states(elements)
	growth := platform.thread_arena_usage().used - before
	assert actual == expected
	$if prealloc {
		// Compare with the actual previous collection implementation, including
		// its full JSON maps, rather than a budget based on the new algorithm.
		assert growth * 4 < storage.usage().used, '${growth} retained versus ${storage.usage().used} control bytes'
		println('Compact collection serialization: retained=${growth} control=${storage.usage().used} bytes')
	}
	storage.release()
	// A later response can use keys alone without losing order or identity.
	later := json2.decode[[]map[string]json2.Any](candidate.encode_element_states(elements))!
	assert later.len == 256
	for index, state in later {
		assert state.len == 1
		assert json_string_property(state, 'bridgeKey')? == '__element_${index}'
		assert voidptr(candidate.elements['__element_${index}']) == voidptr(elements[index])
	}
	owner.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_native_collection_serialization_preserves_models_and_lazy_wrappers() {
	mut document := dom.Document.create(dom.URL{ value: 'https://serialization.test/controls' })
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><input value="retained"><select><option selected>Label</option></select><video></video><svg><rect id="shape" width="7"/></svg><textarea>Text area</textarea>')
	elements := css.query_selector_all(document.as_node(), 'input,select,video,rect,textarea')
	mut binding := serialization_test_binding(document, elements)
	encoded := binding.encode_element_states(elements)
	states := json2.decode[[]map[string]json2.Any](encoded)!
	assert states.len == 5
	assert json_string_property(states[0], 'value')? == 'retained'
	assert json_string_property(states[1], 'value')? == 'Label'
	assert json_string_property(states[3], 'namespaceURI')? == 'http://www.w3.org/2000/svg'
	assert json_string_property(states[4], 'value')? == 'Text area'
	churn := platform.begin_thread_scratch('collection serialization overwrite')
	_ = []u8{len: 1024 * 1024, init: u8(0xa5)}
	churn.finish()
	input := unsafe { &dom.HTMLInputElement(elements[0]) }
	mut model := html.HTMLInputElementModel.create(input)
	assert model.value() == 'retained'
	model.set_value('changed')!
	assert model.value() == 'changed'
	video := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(elements[2]) })
	assert video.media.paused()
	mut area := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(elements[4]) })
	assert area.value() == 'Text area'
	area.set_value('changed area')
	assert area.value() == 'changed area'
	assert binding.encode_element_states(elements).contains('"bridgeKey"')
	owner.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_native_tag_collection_serialization_keeps_live_members_after_replay() {
	mut document := html.parse_document('<!doctype html><div id="host"><i>one</i><i>two</i></div>')
	document.enable_native_storage()
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://serialization.test/live', [r'
const items=host.getElementsByTagName("i"),first=items[0];
if(items.length!==2||items[1].textContent!=="two")throw new Error("initial collection");
host.insertAdjacentHTML("beforeend","<i>three</i>");
if(items.length!==3||items[0]!==first||items[2].textContent!=="three")throw new Error("live collection");
const all=host.querySelectorAll("i");
if(all.length!==3||all[0]!==first||all[2]!==items[2])throw new Error("selector identity");
first.className="selected";
const named=host.getElementsByClassName("selected");
if(named.length!==1||named[0]!==first)throw new Error("class collection identity");
'], runtime, mut messages)
	assert messages == []string{}
}

fn collection_reply_retention_trial(temporary bool) !(i64, i64) {
	mut document := dom.Document.create(dom.URL{value: 'https://serialization.test/replies'})
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><main>' +
		'<i data-label="λ😀">item</i>'.repeat(256) +
		'<input value="retained"><textarea>text area</textarea><svg><rect/></svg></main>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	elements := css.query_selector_all(document.as_node(), 'i,input,textarea,rect')
	mut binding := serialization_test_binding(document, elements)
	if temporary {
		runtime.define_temporary_host_function('query', fn [mut binding] (input string) !browserjs.HostFunctionReply {
			return binding.query_with_temporary_reply(input)
		})!
	} else {
		runtime.define_host_function('query', fn [mut binding] (input string) !string { return binding.query(input) })!
	}
	request := r'{"key":"","action":"querySelectorAll","selector":"i,input,textarea,rect"}'
	source := 'query(${json2.encode(request)})'
	runtime.evaluate('var firstReply=${source};')!
	reply_length := runtime.evaluate('${source}.length;')!.i64()
	storage := document.native_storage()
	before := if storage != unsafe { nil } { storage.arena.usage().used } else { i64(0) }
	for _ in 0 .. 24 { runtime.evaluate('${source};0;')! }
	growth := if storage != unsafe { nil } { storage.arena.usage().used - before } else { i64(0) }
	assert runtime.evaluate('JSON.parse(firstReply).length;')! == '259'
	assert runtime.evaluate('JSON.parse(firstReply)[256].value;')! == 'retained'
	assert runtime.evaluate('JSON.parse(firstReply)[257].value;')! == 'text area'
	assert runtime.evaluate('JSON.parse(firstReply)[258].namespaceURI;')! == 'http://www.w3.org/2000/svg'
	mut input := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(elements[256]) })
	input.set_value('after λ😀')!
	assert input.value() == 'after λ😀'
	return growth, reply_length
}

fn test_native_collection_reply_bytes_retire_after_the_javascript_copy() {
	control, control_length := collection_reply_retention_trial(false)!
	candidate, reply_length := collection_reply_retention_trial(true)!
	assert reply_length == control_length
	$if prealloc {
		assert candidate + 24 * reply_length < control, '${candidate} candidate versus ${control} control bytes'
		println('Collection reply loop: candidate=${candidate} control=${control} reply_length=${reply_length}')
	}
}
