module main

import browserjs
import html

fn test_compact_text_controls_expose_selection_apis() {
	mut document := html.parse_document('<!doctype html><input id="text" value="hello world"><input id="number" type="number" value="5"><textarea id="area">abcdef</textarea>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
const text=document.getElementById("text"),number=document.getElementById("number"),area=document.getElementById("area");
text.setSelectionRange(2,5,"backward");
if(text.selectionStart!==2||text.selectionEnd!==5||text.selectionDirection!=="backward")fail("setSelectionRange "+text.selectionStart+" "+text.selectionEnd+" "+text.selectionDirection);
text.setSelectionRange(3,100);
if(text.selectionEnd!==11)fail("clamped end "+text.selectionEnd);
text.selectionStart=1;text.selectionEnd=4;
if(text.selectionStart!==1||text.selectionEnd!==4)fail("start/end setters");
text.setRangeText("XY",0,5,"select");
if(text.value!=="XY world"||text.selectionStart!==0||text.selectionEnd!==2)fail("setRangeText "+text.value+" "+text.selectionStart+" "+text.selectionEnd);
if(number.selectionStart!==null||number.selectionDirection!==null)fail("number type does not apply");
let threw=false;try{number.setSelectionRange(0,1);}catch(error){threw=error.name==="InvalidStateError";}
if(!threw)fail("number setSelectionRange");
threw=false;try{text.setRangeText("x",3,1);}catch(error){threw=error.name==="IndexSizeError";}
if(!threw)fail("IndexSizeError");
area.setSelectionRange(1,3);
if(area.selectionStart!==1||area.selectionEnd!==3)fail("textarea selection");
area.setRangeText("Z");
if(area.value!=="aZdef")fail("textarea setRangeText "+area.value);
console.log("selection passed");
'], runtime, mut messages)
	assert messages == ['selection passed']
}
