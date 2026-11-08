module main

import browserjs
import css
import dom
import html
import x.json2

fn test_named_elements_build_wrappers_on_first_read() {
	$if darwin {
		document :=
			html.parse_document('<!doctype html><div id="target">t</div><p id="other">o</p><span id="123">n</span><b id="setTimeout">s</b><i id="unread">u</i>')
		mut runtime := browserjs.Runtime.create()
		defer { runtime.close() }
		mut messages := []string{}
		_ = run_document_script_sources(document, 'about:blank', [
			browserjs.ScriptSource{
				code: '
				const before=Object.getOwnPropertyDescriptor(window,"target");
				if(typeof before.get!=="function"||!before.enumerable||!before.configurable)throw new Error("lazy accessor");
				if(target!==document.getElementById("target")||target.textContent!=="t")throw new Error("first read identity");
				const after=Object.getOwnPropertyDescriptor(window,"target");
				if(after.value!==target||!after.writable||!after.enumerable||!after.configurable)throw new Error("settled data property");
				window.other=5;
				if(other!==5||Object.getOwnPropertyDescriptor(window,"other").value!==5)throw new Error("assignment before read");
				if(window["123"]!==document.getElementById("123"))throw new Error("numeric id");
				const collision=Object.getOwnPropertyDescriptor(window,"setTimeout");
				if(!collision||"get" in collision)throw new Error("collision keeps eager assignment");
				if(!Object.keys(window).includes("unread"))throw new Error("enumerable before read");
				delete window.unread;
				if("unread" in window)throw new Error("configurable before read");
				console.log("named elements passed");
			'
			},
		], runtime, mut messages)
		assert messages == ['named elements passed']
	}
}

fn test_named_element_discovery_returns_versioned_identities_without_hydrating_states() {
	mut document := html.parse_document('<!doctype html><div id="first"></div><i id="same"></i><b id="same"></b>')
	mut binding := &CompactElementQueryBinding{document: document, runtime: unsafe { nil }}
	for index, element in css.query_selector_all(document.as_node(), '[id]') {
		key := '__named_${index}'
		binding.keys[voidptr(element)] = key
		binding.elements[key] = element
	}
	initial := json2.decode[map[string]json2.Any](binding.named_elements_query(''))!
	version := json_string_property(initial, 'version') or { panic('missing version') }
	elements := (initial['elements'] or { panic('missing identities') }).as_array()
	assert elements.len == 3
	for index, id in ['first', 'same', 'same'] {
		record := elements[index].as_map()
		assert record.len == 2
		assert (json_string_property(record, 'id') or { '' }) == id
		assert (json_string_property(record, 'bridgeKey') or { '' }) == '__named_${index}'
	}
	assert binding.materialized.len == 0
	cached := json2.decode[map[string]json2.Any](binding.named_elements_query(version))!
	assert (cached['elements'] or { panic('missing cache marker') }) is json2.Null
	mut first := document.get_element_by_id('first') or { panic('missing first') }
	first.set_attribute_value('id', 'renamed')
	updated := json2.decode[map[string]json2.Any](binding.named_elements_query(version))!
	assert (json_string_property(updated, 'version') or { '' }) != version
	updated_elements := (updated['elements'] or { panic('missing updated identities') }).as_array()
	assert (json_string_property(updated_elements[0].as_map(), 'id') or { '' }) == 'renamed'
	assert binding.materialized.len == 0
}

fn test_parser_stage_named_elements_are_lazy_and_preserve_author_values() {
	$if !darwin && !linux { return }
	address := dom.URL{value: 'https://parser-names.test/'}
	document := create_browser_navigation_document_input_with_source('UTF-8', address,
		none, none, none, 1_000_000, true, none)
	mut images := new_browser_image_request_loader(document, {})
	mut scripts := new_browser_script_request_loader(document, {})
	mut host := install_browser_parser_script_host(document, .javascriptcore, images, scripts,
		{}, none, none)
	defer {
		scripts.cancel()
		images.cancel()
		if host.runtime != unsafe { nil } { host.runtime.close() }
		mut owner := unsafe { &dom.Document(document) }
		owner.finalize()
	}
	parse_prepared_browser_navigation_document(PreparedBrowserNavigationDocument{
		document: document
		markup: r'<!doctype html><html><head><script>
globalThis.namedChecks=[typeof futureName==="undefined"];
window.reservedName="author";
</script></head><body><div id=futureName>first</div><span id=futureName>second</span><i id=reservedName>element</i><b id=assignedName>before</b><u id=deletedName>deleted</u><script>
const descriptor=Object.getOwnPropertyDescriptor(window,"futureName");
namedChecks.push(typeof descriptor.get==="function",futureName===document.getElementById("futureName"),futureName.textContent==="first",reservedName==="author");
globalThis.savedNamed=futureName;
assignedName=23;delete window.deletedName;futureName.remove();
document.write("<div id=writtenName>written</div>");
namedChecks.push(writtenName===document.getElementById("writtenName"));
</script><p id=tailName>tail</p><script>
namedChecks.push(futureName===savedNamed,futureName.textContent==="first",document.getElementById("futureName").textContent==="second",assignedName===23,!("deletedName" in window),tailName===document.getElementById("tailName"));
</script><p id=afterLastName>last</p></body></html>'
	})
	assert host.initialized
	assert host.runtime.evaluate_host('namedChecks.length===12&&namedChecks.every(Boolean)')! == 'true'
	assert host.runtime.evaluate_host('typeof Object.getOwnPropertyDescriptor(window,"afterLastName").get==="function"')! == 'true'
	mut loop := html.main_thread_event_loop()
	for _ in 0 .. 64 {
		if !loop.task_queue().has_runnable_tasks() { break }
		loop.process()
	}
	assert !loop.task_queue().has_runnable_tasks()
	mut messages := []string{}
	host.flush(mut messages)
	assert messages == []string{}
}
