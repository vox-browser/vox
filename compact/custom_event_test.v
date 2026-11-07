module main

import browserjs
import html

// 4chan's scripts signal their own document events with CustomEvent details.
fn test_custom_events_carry_their_detail_through_native_dispatch() {
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
		const seen = [];
		document.addEventListener("4chanMainInit", function (event) {
			seen.push(event.detail.board, event instanceof CustomEvent, event instanceof Event, event.target === document);
		});
		document.dispatchEvent(new CustomEvent("4chanMainInit", { detail: { board: "pol" } }));
		const plain = new CustomEvent("plain");
		const legacy = new CustomEvent("first");
		legacy.initCustomEvent("second", true, true, 5);
		let illegal = false;
		try {
			Object.getOwnPropertyDescriptor(CustomEvent.prototype, "detail").get.call(new Event("event"));
		} catch (error) {
			illegal = error instanceof TypeError;
		}
		let required = false;
		try {
			CustomEvent("missing new");
		} catch (error) {
			required = error instanceof TypeError;
		}
		globalThis.result = [seen.join(","), plain.detail === null, plain.bubbles, legacy.type,
			legacy.bubbles, legacy.cancelable, legacy.detail, Object.prototype.toString.call(plain),
			Object.getPrototypeOf(CustomEvent.prototype) === Event.prototype, illegal, required].join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'pol,true,true,true|true|false|second|true|true|5|[object CustomEvent]|true|true|true'
	assert messages == []
}
