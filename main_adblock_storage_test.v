module main

import browserjs
import dom
import html

fn test_page_storage_bindings_use_native_origin_and_traversable_owners() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><body>Storage</body>', dom.URL{value: 'https://storage.adblock.test/'}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	install_browser_page_storage(document, runtime)!
	install_browser_page_storage(document, runtime)!
	assert runtime.evaluate_host('localStorage.clear();sessionStorage.clear();localStorage.setItem("native","persisted");sessionStorage.setItem("session","private");localStorage.native')! == 'persisted'
	window_pointer := document.get_window() or { panic('Missing native window') }
	mut window := unsafe { &html.WindowModel(window_pointer) }
	assert window.local_storage()!.get_item('native')? == 'persisted'
	assert window.session_storage()!.get_item('session')? == 'private'
	assert runtime.evaluate_host('localStorage.named="value";Object.keys(localStorage).join(",")')! == 'native,named'
	assert runtime.evaluate_host('delete localStorage.named;localStorage.getItem("named")===null&&localStorage.length===1&&localStorage.key(0)==="native"')! == 'true'
	assert runtime.evaluate_host('localStorage.setItem("empty","");localStorage.getItem("empty")===""&&localStorage.empty===""&&("empty" in localStorage)&&localStorage.getItem("missing")===null&&localStorage.missing===undefined&&!("missing" in localStorage)&&Object.getOwnPropertyDescriptor(localStorage,"empty").value===""&&Object.getOwnPropertyDescriptor(localStorage,"missing")===undefined')! == 'true'
	assert runtime.evaluate_host('delete localStorage.empty;localStorage.getItem("empty")===null&&localStorage.empty===undefined&&Object.keys(localStorage).join(",")==="native"')! == 'true'
	mut next := parse_browser_navigation_document('<!doctype html><body>Next</body>', dom.URL{value: 'https://storage.adblock.test/next'}, none)
	mut next_runtime := browserjs.Runtime.create()
	defer { next_runtime.close(); next.finalize() }
	install_browser_page_storage(next, next_runtime)!
	assert next_runtime.evaluate_host('localStorage.getItem("native")')! == 'persisted'
	assert next_runtime.evaluate_host('sessionStorage.getItem("session")===null')! == 'true'
	mut other := parse_browser_navigation_document('<!doctype html><body>Other</body>', dom.URL{value: 'https://other-storage.adblock.test/'}, none)
	mut other_runtime := browserjs.Runtime.create()
	defer { other_runtime.close(); other.finalize() }
	install_browser_page_storage(other, other_runtime)!
	assert other_runtime.evaluate_host('localStorage.getItem("native")===null')! == 'true'
	runtime.evaluate_host('localStorage.clear();sessionStorage.clear()')!
}

fn test_page_storage_bindings_reject_opaque_document_origins() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document('<!doctype html><body>Opaque</body>', dom.url_about_blank(), none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	install_browser_page_storage(document, runtime)!
	assert runtime.evaluate_host('try{localStorage;"allowed"}catch(error){error.name}')! == 'SecurityError'
	assert runtime.evaluate_host('try{sessionStorage;"allowed"}catch(error){error.name}')! == 'SecurityError'
}
