module main

import browserjs
import dom
import html
import page

fn check_compact_paragraph_join(source string) ! {
	url := dom.URL{ value: 'https://native-test-input.test/' }
	mut owner := page.Page.create(1)!
	mut document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><textarea id="field"></textarea><input id="readonly" readonly value="unchanged"><div id="editor" contenteditable>start</div></body>')
	allocation.finish()
	owner.set_local_root_navigable(document.navigable() or { return error('missing navigable') })!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [], runtime, mut messages)
	mut app := BrowserApp{ document: document, page_model: owner, js_runtime: runtime, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.relayout(320, 284)
	assert messages == []string{}
	assert runtime.evaluate_host(source)! == 'passed'
}

fn test_paragraph_join_preserves_class_and_inline_white_space() {
	check_compact_paragraph_join(r'

const check=(actual,expected)=>{if(actual!==expected)throw new Error(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
const style=document.createElement("style");style.textContent=".preLine{white-space:pre-line}.preWrap{white-space:pre-wrap}.colored{color:rgb(255,0,0)}@media all{pre.authored{white-space:pre}}";document.head.append(style);
function join(markup){editor.innerHTML=markup;editor.focus();const left=editor.firstChild,right=editor.lastChild;const range=document.createRange();range.setStart(left.firstChild,left.firstChild.length);let text=right;while(text.nodeType!==Node.TEXT_NODE)text=text.firstChild;range.setEnd(text,0);getSelection().removeAllRanges();getSelection().addRange(range);internals.sendText(editor,"\ue017");return editor.innerHTML}

for(const right of [`style="white-space:pre-line"`,`class="preLine"`]){
check(join(`<div style="white-space:pre-wrap">abc</div><div `+right+`>def</div>`),`<div style="white-space:pre-wrap">abc<span style="white-space: pre-line;">def</span></div>`);
check(getSelection().isCollapsed,true);check(getSelection().anchorNode.closest?getSelection().anchorNode.closest(`#editor`):getSelection().anchorNode.parentElement.closest(`#editor`),editor);
}

"passed"
')!
}

fn test_paragraph_join_leaves_lines_after_preserved_newline_or_br() {
	check_compact_paragraph_join(r'

const check=(actual,expected)=>{if(actual!==expected)throw new Error(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
const style=document.createElement("style");style.textContent=".preLine{white-space:pre-line}.preWrap{white-space:pre-wrap}.colored{color:rgb(255,0,0)}@media all{pre.authored{white-space:pre}}";document.head.append(style);
function join(markup){editor.innerHTML=markup;editor.focus();const left=editor.firstChild,right=editor.lastChild;const range=document.createRange();range.setStart(left.firstChild,left.firstChild.length);let text=right;while(text.nodeType!==Node.TEXT_NODE)text=text.firstChild;range.setEnd(text,0);getSelection().removeAllRanges();getSelection().addRange(range);internals.sendText(editor,"\ue017");return editor.innerHTML}

for(const split of [`\n`,`<br>`]){
check(join(`<div style="white-space:pre-wrap">abc</div><div class="preLine">def`+split+`ghi</div>`),`<div style="white-space:pre-wrap">abc<span style="white-space: pre-line;">def</span></div><div class="preLine">ghi</div>`);
}

"passed"
')!
}

fn test_paragraph_join_splits_nested_formatting_at_utf16_line_boundaries() {
	check_compact_paragraph_join(r'

const check=(actual,expected)=>{if(actual!==expected)throw new Error(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
const style=document.createElement("style");style.textContent=".preLine{white-space:pre-line}.preWrap{white-space:pre-wrap}.colored{color:rgb(255,0,0)}@media all{pre.authored{white-space:pre}}";document.head.append(style);
function join(markup){editor.innerHTML=markup;editor.focus();const left=editor.firstChild,right=editor.lastChild;const range=document.createRange();range.setStart(left.firstChild,left.firstChild.length);let text=right;while(text.nodeType!==Node.TEXT_NODE)text=text.firstChild;range.setEnd(text,0);getSelection().removeAllRanges();getSelection().addRange(range);internals.sendText(editor,"\ue017");return editor.innerHTML}

for(const split of [`\n`,`<br>`]){
check(join(`<div style="white-space:pre-wrap">abc</div><div class="preLine"><b>😀def`+split+`ghi</b></div>`),`<div style="white-space:pre-wrap">abc<b style="white-space: pre-line;">😀def</b></div><div class="preLine"><b>ghi</b></div>`);
}

"passed"
')!
}

fn test_paragraph_join_unwraps_only_spans_that_add_no_other_formatting() {
	check_compact_paragraph_join(r'

const check=(actual,expected)=>{if(actual!==expected)throw new Error(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
const style=document.createElement("style");style.textContent=".preLine{white-space:pre-line}.preWrap{white-space:pre-wrap}.colored{color:rgb(255,0,0)}@media all{pre.authored{white-space:pre}}";document.head.append(style);
function join(markup){editor.innerHTML=markup;editor.focus();const left=editor.firstChild,right=editor.lastChild;const range=document.createRange();range.setStart(left.firstChild,left.firstChild.length);let text=right;while(text.nodeType!==Node.TEXT_NODE)text=text.firstChild;range.setEnd(text,0);getSelection().removeAllRanges();getSelection().addRange(range);internals.sendText(editor,"\ue017");return editor.innerHTML}

check(join(`<div style="white-space:pre-wrap">abc</div><div><span class="preLine">def</span></div>`),`<div style="white-space:pre-wrap">abc<span style="white-space: pre-line;">def</span></div>`);
check(join(`<div style="white-space:pre-wrap">abc</div><div><span class="preLine colored">def</span></div>`),`<div style="white-space:pre-wrap">abc<span class="preLine colored">def</span></div>`);
check(join(`<div style="white-space:pre-wrap">abc</div><div><span id="retained" class="preLine">def</span></div>`),`<div style="white-space:pre-wrap">abc<span id="retained" class="preLine">def</span></div>`);

"passed"
')!
}

fn test_paragraph_join_distinguishes_default_pre_from_author_white_space() {
	check_compact_paragraph_join(r'

const check=(actual,expected)=>{if(actual!==expected)throw new Error(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
const style=document.createElement("style");style.textContent=".preLine{white-space:pre-line}.preWrap{white-space:pre-wrap}.colored{color:rgb(255,0,0)}@media all{pre.authored{white-space:pre}}";document.head.append(style);
function join(markup){editor.innerHTML=markup;editor.focus();const left=editor.firstChild,right=editor.lastChild;const range=document.createRange();range.setStart(left.firstChild,left.firstChild.length);let text=right;while(text.nodeType!==Node.TEXT_NODE)text=text.firstChild;range.setEnd(text,0);getSelection().removeAllRanges();getSelection().addRange(range);internals.sendText(editor,"\ue017");return editor.innerHTML}

check(join(`<div style="white-space:normal">abc</div><pre>def</pre>`),`<div style="white-space:normal">abcdef</div>`);
check(join(`<div style="white-space:normal">abc</div><pre class="authored">def</pre>`),`<div style="white-space:normal">abc<span style="white-space: pre;">def</span></div>`);
check(join(`<pre>abc</pre><div class="preLine">def</div>`),`<pre>abcdef</pre>`);

"passed"
')!
}

fn test_paragraph_join_preserves_lines_in_ancestor_and_descendant_blocks() {
	check_compact_paragraph_join(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
const style=document.createElement("style");style.textContent=".preLine{white-space:pre-line}.preWrap{white-space:pre-wrap}.colored{color:rgb(255,0,0)}@media all{pre.authored{white-space:pre}}";document.head.append(style);
function join(markup){editor.innerHTML=markup;editor.focus();const left=editor.firstChild,right=editor.lastChild;const range=document.createRange();range.setStart(left.firstChild,left.firstChild.length);let text=right;while(text.nodeType!==Node.TEXT_NODE)text=text.firstChild;range.setEnd(text,0);getSelection().removeAllRanges();getSelection().addRange(range);internals.sendText(editor,"\ue017");return editor.innerHTML}


function removeBoundary(left, right){editor.focus();const range=document.createRange();range.setStart(left,left.length);range.setEnd(right,0);getSelection().removeAllRanges();getSelection().addRange(range);internals.sendText(editor,"\ue017")}
editor.innerHTML=`<div style="white-space:pre-wrap">abc<div class="preLine"><b>def\nghi</b></div></div>`;
removeBoundary(editor.firstChild.firstChild,editor.firstChild.lastChild.firstChild.firstChild);
check(editor.innerHTML,`<div style="white-space:pre-wrap">abc<b style="white-space: pre-line;">def</b><div class="preLine"><b>ghi</b></div></div>`);
editor.innerHTML=`<div class="preLine"><div style="white-space:pre-wrap">abc</div><b>def\nghi</b></div>`;
removeBoundary(editor.firstChild.firstChild.firstChild,editor.firstChild.lastChild.firstChild);
check(editor.innerHTML,`<div class="preLine"><div style="white-space:pre-wrap">abc<b style="white-space: pre-line;">def</b></div><b>ghi</b></div>`);

"passed"
')!
}
