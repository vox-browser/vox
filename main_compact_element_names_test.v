module main

import browserjs
import html

// Scripts branch on tagName and nodeName. 4chan's catalog skips its keyboard
// shortcuts when the key event's target nodeName is INPUT or TEXTAREA.
fn test_compact_elements_report_their_names_and_node_type() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><html><body><div id="box"><a id="link" href="#">x</a></div><svg id="drawing"><foreignObject id="island"></foreignObject></svg></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://boards.4chan.org/pol/catalog', [r'
		const box = document.getElementById("box"), link = document.getElementById("link");
		const drawing = document.getElementById("drawing"), island = document.getElementById("island");
		const created = document.createElement("span");
		const svgCreated = document.createElementNS("http://www.w3.org/2000/svg", "foreignObject");
		let illegal = false;
		try {
			Object.getOwnPropertyDescriptor(Element.prototype, "tagName").get.call({});
		} catch (error) {
			illegal = error instanceof TypeError;
		}
		globalThis.result = [box.tagName, link.tagName, drawing.tagName, island.tagName, created.tagName,
			svgCreated.tagName, box.nodeName, box.localName, created.localName, island.localName,
			box.nodeType, document.body.tagName, document.documentElement.nodeName, "tagName" in box,
			drawing.namespaceURI, box.prefix === null, document.nodeType, document.nodeName, illegal].join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'DIV|A|svg|foreignObject|SPAN|foreignObject|DIV|div|span|foreignObject|1|BODY|HTML|true|http://www.w3.org/2000/svg|true|9|#document|true'
	assert messages == []
}
