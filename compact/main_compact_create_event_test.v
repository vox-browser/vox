module main

import browserjs
import html

// 4chan's catalog fires its own events through document.createEvent("Event"),
// initEvent() and an expando detail.
fn test_document_create_event_returns_events_of_the_named_interface() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><html><body><div id="board"></div></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://boards.4chan.org/pol/catalog', [r'
		let received = null;
		document.addEventListener("4chanThreadsLoaded", function (event) { received = event.detail.count; });
		const event = document.createEvent("Event");
		event.initEvent("4chanThreadsLoaded", false, false);
		event.detail = { count: 202 };
		document.dispatchEvent(event);
		const custom = document.createEvent("CustomEvent");
		custom.initCustomEvent("custom", false, false, 7);
		let unsupported = "";
		try {
			document.createEvent("NoSuchEvent");
		} catch (error) {
			unsupported = error.name;
		}
		let receiver = false;
		try {
			document.createEvent.call({}, "Event");
		} catch (error) {
			receiver = error instanceof TypeError;
		}
		globalThis.result = [received, event instanceof Event, event.type, document.createEvent("HTMLEvents") instanceof Event,
			custom instanceof CustomEvent, custom.detail, unsupported, receiver].join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == '202|true|4chanThreadsLoaded|true|true|7|NotSupportedError|true'
	assert messages == []
}
