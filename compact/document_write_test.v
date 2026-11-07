module main

import browserjs
import dom
import html

fn test_document_open_write_close_replace_the_document() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><p id="old">old</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'const old=document.getElementById("old");const same=document.open()===document;console.log(document.documentElement===null,old.isConnected);document.write("<title>t</title><p id=new>new");document.write("er</p>");document.writeln("<b>x</b>");document.close();console.log(document.body.innerHTML,document.title,document.getElementById("old")===null,document.compatMode);console.log(same,typeof Document.prototype.write,document.write.length)',
	], runtime, mut messages)
	assert messages == ['true false', '<p id="new">newer</p><b>x</b>\n t true BackCompat',
		'true function 0']
	paragraph := document.get_element_by_id('new') or { panic('missing written paragraph') }
	assert paragraph.as_node().text_content() or { '' } == 'newer'
}

fn test_parser_inserted_script_writes_after_itself() {
	$if !darwin { return }
	document :=
		html.parse_document('<!doctype html><body><script id="writer"></script><p id="after">after</p></body>')
	script := document.get_element_by_id('writer') or { panic('missing script') }
	// The browser runs parser-inserted scripts once parsing has finished,
	// before the document completes loading.
	mut owner := unsafe { &dom.Document(document) }
	owner.update_readiness(.interactive)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_script_sources(document, 'about:blank', [
		browserjs.ScriptSource{
			code:    'document.open();document.write("<div id=w>PA");console.log(document.getElementById("w").textContent);document.write("SS</div>");console.log(document.body.textContent,document.getElementById("w").nextElementSibling.id)'
			url:     'about:blank'
			element: script
		},
	], runtime, mut messages)
	assert messages == ['PA', 'PASSafter after']
	written := document.get_element_by_id('w') or { panic('missing written element') }
	previous := written.as_node().previous_sibling() or { panic('missing script sibling') }
	assert voidptr(previous) == voidptr(script.as_node())
	after := document.get_element_by_id('after') or { panic('missing after') }
	body := after.as_node().parent() or { panic('missing body') }
	assert body.children.len == 3
}
