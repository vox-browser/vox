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

fn test_compact_select_value_tracks_native_selection_and_updates_live_options() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><select id="sort"><option value="alt">Bump order</option><option value="r">Reply count</option></select><select id="cleared"><option>First</option><option>Second</option></select>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://boards.4chan.org/pol/catalog', [
		'globalThis.control=document.getElementById("sort");globalThis.before=control.value;const cleared=document.getElementById("cleared");cleared.selectedIndex=-1;globalThis.clearedValue=cleared.value+":"+cleared.selectedIndex;',
	], runtime, mut messages)
	assert messages == [], messages.str()
	assert runtime.evaluate_host('before')! == 'alt'
	assert runtime.evaluate_host('clearedValue')! == ':-1'
	control := document.get_element_by_id('sort')?
	select_element := unsafe { &dom.HTMLSelectElement(control) }
	html.set_html_select_element_selected_index(select_element, 1)
	assert runtime.evaluate_host('control.value+":"+control.selectedIndex')! == 'r:1'
	assert runtime.evaluate_host('control.value="alt";control.value+":"+control.selectedIndex')! == 'alt:0'
	assert html.html_select_element_value(select_element) == 'alt'
	assert runtime.evaluate_host('control.value="missing";control.value+":"+control.selectedIndex')! == ':-1'
	assert html.html_select_element_selected_index(select_element) == -1
	assert messages == []
}

// jQuery's select val() setter assigns selected on every option; 2ch.su's
// catalog restores its saved sort order that way.
fn test_compact_option_selected_sets_the_native_selectedness() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><select id="filter"><option value="standart">Bumps</option><option value="timestamp">Time</option><option value="posts_count">Posts</option></select>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://2ch.su/news/catalog.html', [r'
		const filter = document.getElementById("filter"), options = filter.querySelectorAll("option");
		const entries = [options[0].selected, options[1].selected];
		for (const option of options) option.selected = option.value === "timestamp";
		entries.push(filter.value, filter.selectedIndex, options[0].selected, options[1].selected);
		const detached = document.createElement("option");
		entries.push(detached.selected);
		detached.selected = 1;
		entries.push(detached.selected);
		globalThis.result = entries.join("|");
	'], runtime, mut messages)
	assert messages == [], messages.str()
	result := runtime.evaluate_host('result')!
	assert result == 'true|false|timestamp|1|false|true|false|true', result
	filter := document.get_element_by_id('filter') or { panic('missing filter') }
	select_element := unsafe { &dom.HTMLSelectElement(filter) }
	assert html.html_select_element_value(select_element) == 'timestamp'
	html.set_html_select_element_selected_index(select_element, 2)
	assert runtime.evaluate_host('[...filter.querySelectorAll("option")].map(o=>o.selected).join()')! == 'false,false,true'
}

fn test_compact_option_and_select_members_follow_the_html_interfaces() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><html><body><form id="f"><select id="s"><option id="a"> First\n option </option><optgroup><option name="b" label="Bee">B</option></optgroup><option value="v" selected>C<script>x</script></option></select><fieldset id="fs"></fieldset></form><output id="out" form="f"></output><object id="obj" form="missing"></object></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/', [r'
		const select = document.getElementById("s"), options = select.options;
		const [a, b, c] = Array.from(options);
		const entries = [a.text, a.label, a.value, b.label, b.index, c.value, c.text, c.defaultSelected, c.index, a.form === document.getElementById("f")];
		entries.push(select.type, select.length, select.item(1) === b, select.namedItem("b") === b, options.selectedIndex, select.selectedOptions.length);
		const created = new Option("New", "n", true, false);
		entries.push(created instanceof HTMLOptionElement, created.text, created.value, created.defaultSelected, created.selected, created.index);
		select.add(created, 0);
		entries.push(select.length, select.options[0] === created, created.index);
		options.length = 5;
		entries.push(select.length, select.options[4].text === "");
		select.remove(4);
		options.selectedIndex = 1;
		entries.push(select.length, select.selectedIndex, a.selected);
		let threw = "none";
		try { select.add(document.createElement("option"), document.createElement("option")); } catch (error) { threw = error.name; }
		entries.push(threw);
		a.text = "Renamed";
		entries.push(a.textContent, a.label);
		const form = document.getElementById("f");
		entries.push(select.form === form, document.getElementById("fs").form === form, document.getElementById("out").form === form, String(document.getElementById("obj").form));
		globalThis.result = entries.join("|");
	'], runtime, mut messages)
	result := runtime.evaluate_host('typeof result==="string"?result:"missing"')!
	assert messages == [], messages.join('\n')
	assert result == 'First option|First option|First option|Bee|1|v|C|true|2|true|select-one|3|true|true|2|1|true|New|n|true|false|0|4|true|0|5|true|4|1|true|NotFoundError|Renamed|Renamed|true|true|true|null', result
}
