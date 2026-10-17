module main

import browserjs
import dom
import html

// 4chan's catalog shows its saved settings by assigning selectedIndex, and
// marks the current theme by walking the selector's children for its value.
fn test_compact_select_facades_read_and_set_the_live_selected_index() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><html><body><select id="teaser-ctrl" size="1"><option value="off">Off</option><option value="on">On</option></select><select id="styleSelector"><option>Yotsuba</option><option>Yotsuba B</option><option>Tomorrow</option></select><div id="plain"></div></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://boards.4chan.org/pol/catalog', [r'
		const teaser = document.getElementById("teaser-ctrl");
		const before = teaser.selectedIndex;
		teaser.selectedIndex = 1;
		const entries = [before, teaser.selectedIndex, teaser.options.length,
			teaser.options[teaser.selectedIndex].value, teaser.options === teaser.options];
		const style = document.getElementById("styleSelector");
		for (let index = 0, option; option = style.children[index]; ++index) {
			if (option.value === "Tomorrow") style.selectedIndex = index;
		}
		const plain = document.getElementById("plain");
		entries.push(style.selectedIndex, plain.selectedIndex === undefined, "options" in plain);
		globalThis.result = entries.join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == '0|1|2|on|true|2|true|false'
	assert messages == []
	teaser := document.get_element_by_id('teaser-ctrl') or { panic('missing teaser control') }
	assert html.html_select_element_selected_index(unsafe { &dom.HTMLSelectElement(teaser) }) == 1
	style := document.get_element_by_id('styleSelector') or { panic('missing style selector') }
	assert html.html_select_element_value(unsafe { &dom.HTMLSelectElement(style) }) == 'Tomorrow'
}
