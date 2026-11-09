module main

import browserjs
import html

// Counted loops over a live class collection read its length and members
// repeatedly; the collection reuses its last reply until the tree or an
// attribute changes, including edits still pending in the script.
fn test_class_collection_stays_live_across_cached_reads() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><html><body><p class="t" id="one"></p><p class="t" id="two"></p><p id="three"></p></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', [r'
		const list = document.getElementsByClassName("t"), seen = [];
		const ids = () => { const out = []; for (let i = 0; i < list.length; i++) out.push(list[i].id); return out.join(","); };
		seen.push(ids(), ids());
		document.getElementById("three").className = "t";
		seen.push(ids());
		document.getElementById("one").setAttribute("class", "u");
		seen.push(ids());
		const added = document.createElement("p"); added.id = "four"; added.className = "t";
		document.body.appendChild(added);
		seen.push(ids());
		document.body.removeChild(document.getElementById("two"));
		seen.push(ids(), String(list.length), String(list[5]));
		globalThis.result = seen.join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'one,two|one,two|one,two,three|two,three|two,three,four|three,four|2|undefined'
	assert messages == []
}
