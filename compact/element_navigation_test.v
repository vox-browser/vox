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

// GitHub and other pages read document.scripts; images, links and embeds are
// the other live document collections.
fn test_compact_document_collections_track_live_elements() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><html><head><script id="s1"></script></head><body><img id="i1"><a id="l1" href="/x"></a><a id="anchor"></a><map><area id="l2" href="/y"></map><embed id="e1"></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://collections.test/', [r'
		const ids = collection => Array.from(collection, element => element.id).join(",");
		const before = [ids(document.scripts), ids(document.images), ids(document.links), ids(document.embeds),
			document.plugins.length, document.scripts === document.scripts, document.images.i1.id];
		const image = document.createElement("img"); image.id = "i2"; document.body.appendChild(image);
		globalThis.result = before.concat([ids(document.images), document.scripts.length]).join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 's1|i1|l1,l2|e1|1|true|i1|i1,i2|1', runtime.evaluate_host('result')!
	assert messages == []
}
