// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom

fn test_element_scroll_offsets_read_the_native_document_viewport() {
	mut host, mut vm, mut document := document_state_fixture()!
	defer { host.close() }
	document.set_quirks_mode(.no)
	document.set_viewport_rect(dom.Rect{12, 34, 800, 600})
	assert document_state_eval(mut vm, r'
		var root = document.documentElement;
		root.scrollLeft === 12 && root.scrollTop === 34 &&
			document.getElementById("field").scrollTop === 0
	')!.as_bool()
}

fn test_element_scroll_methods_convert_options_and_return_native_promises() {
	mut host, mut vm, _ := document_state_fixture()!
	defer { host.close() }
	assert document_state_eval(mut vm, r'
		var element = document.createElement("div"), order = "";
		var promise = element.scrollTo({
			get behavior() { order += "b"; return "instant"; },
			get left() { order += "l"; return {valueOf() { order += "x"; return 0; }}; },
			get top() { order += "t"; return {valueOf() { order += "y"; return 0; }}; }
		});
		element.scrollTop = {valueOf() { order += "s"; return Infinity; }};
		order === "blxtys" && element.scrollTop === 0 && promise instanceof Promise &&
			element.scroll(null) instanceof Promise && element.scrollBy(NaN, Infinity) instanceof Promise &&
			element.scrollTo.length === 0
	')!.as_bool()
	document_state_eval(mut vm, r'
		var failures = 0, sentinel = {};
		element.scrollTo({get behavior() { throw sentinel; }}).catch(e => {if (e === sentinel) failures++;});
		element.scrollBy({behavior: "invalid"}).catch(e => {if (e instanceof TypeError) failures++;});
		Element.prototype.scroll.call({}).catch(e => {if (e instanceof TypeError) failures++;});
	')!
	vm.run_queued_promise_jobs()
	assert document_state_eval(mut vm, 'failures === 3')!.as_bool()
}
