module main

import browserjs
import html
import dom

fn test_compact_history_updates_location_without_queuing_cross_document_navigation() {
	address := dom.URL{ value: 'https://history.example/start' }
	mut document := html.parse_navigation_document('<!doctype html><body></body>', address, address.origin(), none)!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, address.serialize(), [r'
const before=location.href;
history.replaceState({route:1},"","/maps/?z=15#map");
if(before!=="https://history.example/start"||location.href!=="https://history.example/maps/?z=15#map"||location.pathname!=="/maps/"||location.search!=="?z=15"||location.hash!=="#map")throw new Error("history location");
history.pushState({route:2},"","?z=16");
if(history.state.route!==2||history.length!==2||location.search!=="?z=16")throw new Error("history push");
console.log("history passed");
'], runtime, mut messages)
	assert messages == ['history passed']
	assert document.url.serialize() == 'https://history.example/maps/?z=16'
	state := runtime.evaluate_host('__ladybirdSnapshot()')!
	assert state.contains('"navigate":""')
}
