module main

import browserjs
import html

fn test_document_open_write_close_replace_the_document() {
	$if !darwin && !linux { return }
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
