// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs

fn storage_document(url string, previous ?&dom.Document) !&dom.Document {
	address := dom.URL{value: url}
	return html.parse_navigation_document('<!doctype html><body>Storage</body>', address,
		address.origin(), previous)
}

fn evaluate_storage(document &dom.Document, source string) !bool {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	mut script := libjs.Script.parse(source, vm.realm(), 'session-storage.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or {
		return error(exception_message(err))
	}
	return value.as_bool()
}

fn test_session_storage_interface_is_live_and_branded() {
	document := storage_document('https://session-storage.test/', none)!
	assert evaluate_storage(document, r'
		const storage = window.sessionStorage;
		let missing = storage.getItem("missing") === null && storage.key(0) === null;
		const same = storage === sessionStorage && storage instanceof Storage &&
			Object.prototype.toString.call(storage) === "[object Storage]";
		storage.setItem("soft-nav:marker", "react");
		storage[4] = false;
		storage.setItem("clear", "shadowed");
		storage.setItem("\ud800", "\udcff");
		const live = storage["soft-nav:marker"] === "react" && storage.getItem(4) === "false" &&
			storage.key(0) === "soft-nav:marker" && storage.key(1) === "4" && storage.length === 4 &&
			typeof storage.clear === "function" && storage.getItem("clear") === "shadowed" &&
			storage.getItem("\ud800") === "\udcff";
		const names = Object.keys(storage).sort().join(",") === "4,soft-nav:marker,\ud800";
		delete storage[4];
		storage.removeItem("soft-nav:marker");
		const deleted = storage.length === 2 && storage[4] === undefined &&
			storage.getItem("soft-nav:marker") === null;
		storage.clear();
		let errors = 0;
		for (const call of [
			() => new Storage(),
			() => storage.setItem("key"),
			() => storage.getItem(Symbol()),
			() => Storage.prototype.clear.call({}),
			() => Object.getOwnPropertyDescriptor(globalThis, "sessionStorage").get.call({})
		]) {
			try { call(); } catch (error) { if (error instanceof TypeError) errors++; }
		}
		same && missing && live && names && deleted && storage.length === 0 && errors === 5;
	')!
}

fn test_session_storage_spans_same_origin_documents_and_isolates_other_contexts() {
	first := storage_document('https://storage-scope.test/first', none)!
	assert evaluate_storage(first, 'sessionStorage.setItem("key", "first"); true')!

	next := storage_document('https://storage-scope.test/next', first)!
	assert evaluate_storage(next, 'sessionStorage.getItem("key") === "first"')!

	foreign := storage_document('https://other-storage-scope.test/', next)!
	assert evaluate_storage(foreign, 'sessionStorage.getItem("key") === null')!

	other_tab := storage_document('https://storage-scope.test/first', none)!
	assert evaluate_storage(other_tab, 'sessionStorage.getItem("key") === null')!

	returned := storage_document('https://storage-scope.test/again', foreign)!
	assert evaluate_storage(returned, 'sessionStorage.getItem("key") === "first"')!

	opaque := storage_document('about:blank', none)!
	assert evaluate_storage(opaque, 'let denied=false;try{sessionStorage}catch(error){denied=error instanceof DOMException&&error.name==="SecurityError"}denied')!
}
