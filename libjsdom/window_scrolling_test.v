// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom

fn test_window_scroll_offsets_read_the_owning_native_viewport_and_are_replaceable() {
	mut host, mut vm, mut document := document_state_fixture()!
	defer { host.close() }
	document.set_viewport_rect(dom.Rect{12, 34, 800, 600})
	assert document_state_eval(mut vm, 'scrollX===12&&pageXOffset===12&&scrollY===34&&pageYOffset===34')!.as_bool()
	document.set_viewport_rect(dom.Rect{5, 8, 800, 600})
	assert document_state_eval(mut vm, 'var getter=Object.getOwnPropertyDescriptor(window,"scrollY").get,n=0;try{getter.call({})}catch(e){if(e instanceof TypeError)n++}scrollY="replaced";scrollY==="replaced"&&getter.call(window)===8&&pageYOffset===8&&n===1')!.as_bool()
}

fn test_window_scroll_converts_dictionary_in_webidl_order_and_observes_native_promise() {
	mut host, mut vm, _ := document_state_fixture()!
	defer { host.close() }
	assert document_state_eval(mut vm, 'var order="",p=window.scrollTo({get behavior(){order+="b";return "instant"},get left(){order+="l";return {valueOf(){order+="x";return 0}}},get top(){order+="t";return {valueOf(){order+="y";return 0}}}});order==="blxty"&&p instanceof Promise&&scrollTo.length===0&&scrollBy.length===0&&window.scroll(null) instanceof Promise')!.as_bool()
	assert document_state_eval(mut vm, 'var order="",p=scroll({valueOf(){order+="x";return NaN}},{valueOf(){order+="y";return Infinity}});order==="xy"&&p instanceof Promise&&scrollX===0&&scrollY===0')!.as_bool()
}

fn test_window_scroll_conversion_errors_reject_promises_with_original_values() {
	mut host, mut vm, _ := document_state_fixture()!
	defer { host.close() }
	document_state_eval(mut vm, 'var n=0,sentinel={};scrollTo({get behavior(){throw sentinel}}).catch(e=>{if(e===sentinel)n++});scrollBy({behavior:"invalid"}).catch(e=>{if(e instanceof TypeError)n++});scrollTo.call({}).catch(e=>{if(e instanceof TypeError)n++})')!
	vm.run_queued_promise_jobs()
	assert document_state_eval(mut vm, 'n===3')!.as_bool()
}
