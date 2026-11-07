module main

import browserjs
import html

// 4chan's catalog walks the theme selector's children, styles the element
// after its global message and reads document.forms.
fn test_compact_elements_navigate_their_live_document_relatives() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><html><body><div id="message"><p id="first">A</p><p id="second">B</p><span id="last"></span></div><div id="after"></div><div id="empty"></div><form id="reply" name="post"></form></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://boards.4chan.org/pol/catalog', [r'
		const message = document.getElementById("message");
		const first = document.getElementById("first");
		const last = document.getElementById("last");
		const entries = [first.nextElementSibling.id, last.previousElementSibling.id,
			message.firstElementChild.id, message.lastElementChild.id, last.nextElementSibling === null,
			first.previousElementSibling === null, message.nextElementSibling.id, message.childElementCount];
		const ids = [];
		for (let index = 0, child; child = message.children[index]; ++index) ids.push(child.id);
		entries.push(ids.join(","), message.children === message.children, message.hasChildNodes(),
			document.getElementById("empty").hasChildNodes(), document.forms.length, document.forms[0].id,
			document.forms.post.id, document.forms === document.forms);
		const created = document.createElement("span");
		entries.push(created.nextElementSibling === null, created.firstElementChild === null,
			created.children.length, created.hasChildNodes());
		created.innerHTML = "<b>bold</b>";
		entries.push(created.hasChildNodes());
		const appended = document.createElement("i");
		message.appendChild(appended);
		entries.push(message.children.length, message.lastElementChild === appended);
		globalThis.result = entries.join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'second|second|first|last|true|true|after|3|first,second,last|true|true|false|1|reply|reply|true|true|true|0|false|true|4|true'
	assert messages == []
}
