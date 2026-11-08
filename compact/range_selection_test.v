module main

import browserjs
import html

fn test_compact_ranges_selection_and_exec_command_use_native_objects() {
	mut document := html.parse_document('<!doctype html><div id="root"><p id="a">hello world</p><p id="b">second</p></div><div id="editor" contenteditable>plain text</div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
const a=document.getElementById("a"),b=document.getElementById("b"),root=document.getElementById("root");
const range=document.createRange();
if(!(range instanceof Range)||!(range instanceof AbstractRange)||range.startContainer!==document||range.startOffset!==0||!range.collapsed)fail("initial range");
range.setStart(a.firstChild,6);range.setEnd(b.firstChild,3);
if(range.startContainer!==a.firstChild||range.endOffset!==3||range.collapsed||range.commonAncestorContainer!==root)fail("boundaries");
if(range.toString()!=="worldsec")fail("toString "+range.toString());
const copy=range.cloneRange();
if(copy===range||copy.compareBoundaryPoints(Range.START_TO_START,range)!==0)fail("cloneRange");
if(!range.isPointInRange(a.firstChild,8)||range.comparePoint(a.firstChild,1)!==-1||!range.intersectsNode(b))fail("point queries");
let threw=false;try{range.setStart(a.firstChild,99);}catch(error){threw=error.name==="IndexSizeError";}
if(!threw)fail("IndexSizeError");
const fragment=range.cloneContents();
if(!(fragment instanceof DocumentFragment)||fragment.textContent!=="worldsec")fail("cloneContents "+fragment.textContent);
range.deleteContents();
if(root.textContent!=="hello ond"||!range.collapsed)fail("deleteContents "+root.textContent);
const live=new Range();live.selectNodeContents(b);
b.insertBefore(document.createTextNode("!"),b.firstChild);
if(live.endOffset!==2)fail("live range offsets "+live.endOffset);
const selection=getSelection();
if(!(selection instanceof Selection)||getSelection()!==selection||document.getSelection()!==selection)fail("selection identity");
selection.removeAllRanges();
const target=document.createRange();target.selectNodeContents(a);selection.addRange(target);
if(selection.rangeCount!==1||selection.getRangeAt(0)!==target||selection.anchorNode!==a||selection.toString()!=="hello ")fail("addRange "+selection.toString());
selection.collapse(a.firstChild,2);
if(!selection.isCollapsed||selection.focusOffset!==2||selection.type!=="Caret")fail("collapse");
selection.extend(a.firstChild,5);
if(selection.toString()!=="llo"||selection.isCollapsed)fail("extend "+selection.toString());
const editor=document.getElementById("editor"),word=document.createRange();
word.setStart(editor.firstChild,0);word.setEnd(editor.firstChild,5);
selection.removeAllRanges();selection.addRange(word);
if(!document.queryCommandSupported("bold")||document.queryCommandState("bold"))fail("bold state before");
if(document.execCommand("bold",false,null)!==true)fail("execCommand result");
if(editor.innerHTML!=="<b>plain</b> text")fail("execCommand markup "+editor.innerHTML);
if(!document.queryCommandState("bold"))fail("bold state after");
console.log("ranges passed");
'], runtime, mut messages)
	assert messages == ['ranges passed']
}

fn test_compact_range_offsets_follow_an_identical_data_replacement() {
	mut document := html.parse_document('<!doctype html><p id="a">hello</p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const text=document.getElementById("a").firstChild,range=document.createRange();
range.setStart(text,1);range.setEnd(text,3);
const before=[range.startOffset,range.endOffset].join(",");
text.data=text.data;
console.log(before+" "+[range.startOffset,range.endOffset].join(","));
'], runtime, mut messages)
	assert messages == ['1,3 0,0']
}
