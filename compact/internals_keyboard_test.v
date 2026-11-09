module main

import browserjs
import dom
import html
import page

fn check_compact_native_send_text(source string) ! {
	url := dom.URL{value: 'https://native-test-input.test/'}
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
	mut app := BrowserApp{document:document, page_model:owner, js_runtime:runtime, layout_tree_only:true, viewport_width:320, viewport_height:200}
	app.relayout(320,284)
	assert messages == []string{}
	assert runtime.evaluate_host(source)! == 'passed'
}

fn test_internals_send_text_uses_trusted_keyboard_events_and_cancellable_native_editing() {
	check_compact_native_send_text(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(JSON.stringify(actual)+" != "+JSON.stringify(expected))};
const events=[];let genuine=true;
for(const name of ["keydown","beforeinput","input","keyup"])field.addEventListener(name,event=>{events.push([name,event.key||event.inputType,event.data]);genuine=genuine&&event.isTrusted&&event.target===field&&(name.startsWith("key")?event instanceof KeyboardEvent:event instanceof InputEvent)});
check(internals.sendText(field,"a😀"),undefined);check(field.value,"a😀");check(field.selectionStart,3);check(document.activeElement,field);
check(events.map(event=>event[0]).join(","),"keydown,beforeinput,input,keyup,keydown,beforeinput,input,keyup");check(genuine,true);check(events[0][1],"a");check(events[3][1],"a");
field.addEventListener("keydown",event=>{if(event.key==="x")event.preventDefault()});
internals.sendText(field,"xy");check(field.value,"a😀y");
field.addEventListener("beforeinput",event=>{if(event.data==="z")event.preventDefault()});internals.sendText(field,"z");check(field.value,"a😀y");
internals.sendText(field,"\ue003");check(field.value,"a😀");internals.sendText(field,"\ue012\ue017");check(field.value,"a");
field.value="abc";internals.sendText(field,"\ue011");check(field.selectionStart,0);internals.sendText(field,"\ue010");check(field.selectionStart,3);
internals.sendText(field,"\ue012",4);check(field.selectionStart,2);check(field.selectionEnd,3);internals.sendText(field,"B");check(field.value,"abB");
internals.sendText(field,"\ue006");check(field.value,"abB\n");
const cancelEdit=event=>event.preventDefault();field.addEventListener("beforeinput",cancelEdit);
internals.sendText(field,"\ue003\ue006X");check(field.value,"abB\n");field.removeEventListener("beforeinput",cancelEdit);
internals.sendText(readonly,"ignored");check(readonly.value,"unchanged");
"passed"
')!
}

fn test_internals_send_text_edits_contenteditable_and_validates_arguments_before_conversion() {
	check_compact_native_send_text(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected))};
check(internals.sendText.name,"sendText");check(internals.sendText.length,2);check(Object.hasOwn(internals.sendText,"prototype"),false);
let conversions=0;const text={toString(){conversions++;return "😀!"}},bad={toString(){throw new Error("converted wrong receiver")}};
for(const target of [{},document,document.createElementNS("http://www.w3.org/2000/svg","svg")]){let rejected=false;try{internals.sendText(target,bad)}catch(error){rejected=error instanceof TypeError}check(rejected,true)}
for(const operation of [()=>internals.sendText(field),()=>internals.sendText(field,Symbol()),()=>internals.sendText(field,"x",1n)]){let rejected=false;try{operation()}catch(error){rejected=error instanceof TypeError}check(rejected,true)}
editor.focus();const selection=getSelection(),range=document.createRange();range.selectNodeContents(editor);range.collapse(false);selection.removeAllRanges();selection.addRange(range);
internals.sendText(editor,"\ue011");check(selection.focusOffset,0);internals.sendText(editor,"\ue010");check(selection.focusOffset,5);
internals.sendText(editor,text);check(conversions,1);check(editor.textContent,"start😀!");check(document.activeElement,editor);
let before=0;editor.addEventListener("beforeinput",event=>{before++;check(event.isTrusted,true);check(event.inputType,"insertText");check(event.getTargetRanges().length,1);event.preventDefault()});internals.sendText(editor,"cancel");check(before,6);check(editor.textContent,"start😀!");
"passed"
')!
}

fn test_internals_send_text_refreshes_attributes_of_retained_inline_elements() {
	check_compact_native_send_text(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected))};
editor.innerHTML="<div style=\"white-space:pre-wrap\">abc</div><div style=\"white-space:pre-line\"><b>def\nghi</b></div>";
const left=editor.firstChild,right=editor.lastChild,retained=right.firstChild,attributes=retained.attributes;
const range=document.createRange();range.setStart(left.firstChild,3);range.setEnd(retained.firstChild,0);getSelection().removeAllRanges();getSelection().addRange(range);editor.focus();
let inputs=0;editor.addEventListener("input",()=>{inputs++;editor.setAttribute("data-author","kept")});
internals.sendText(editor,"\ue017");
check(retained.parentNode,left);check(retained.attributes,attributes);check(retained.getAttribute("style"),"white-space: pre-line;");
check(attributes.getNamedItem("style").value,"white-space: pre-line;");check(retained.getAttributeNode("style"),attributes.getNamedItem("style"));
check(inputs,1);check(editor.getAttribute("data-author"),"kept");check(right.textContent,"ghi");
"passed"
')!
}
