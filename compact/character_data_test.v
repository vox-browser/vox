module main

import browserjs
import html

fn test_compact_native_text_and_comment_constructors_share_the_parser_interfaces() {
	mut document := html.parse_document('<!doctype html><div id="box">parsed<!--comment--></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
class Derived extends Text{};const text=new Derived("created"),comment=new Comment(null);
if(!(text instanceof Text)||!(text instanceof CharacterData)||!(text instanceof Node)||!(text instanceof Derived)||text.data!=="created"||text.ownerDocument!==document)throw new Error("native text construction");
if(!(box.firstChild instanceof Text)||!(box.lastChild instanceof Comment)||!(comment instanceof CharacterData)||comment.data!=="null"||new Text().length!==0||Object.prototype.toString.call(text)!=="[object Text]")throw new Error("parser node prototypes");
box.appendChild(text);if(box.lastChild!==text||text.parentNode!==box)throw new Error("native text identity");
'], runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_native_text_split_and_character_data_methods_use_utf16_offsets() {
	mut document := html.parse_document('<!doctype html><div id="box"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const text=new Text("a😀b");box.appendChild(text);const second=text.splitText(3);
if(text.data!=="a😀"||second.data!=="b"||box.childNodes.length!==2||text.wholeText!=="a😀b"||second.wholeText!=="a😀b"||text.length!==3)throw new Error("native text split");
if(text.substringData(1,2)!=="😀")throw new Error("native substring");
second.appendData("cd");second.insertData(1,"x");second.deleteData(2,1);second.replaceData(0,2,"end");if(second.data!=="endd")throw new Error("native character mutations "+second.data);
second.remove();if(second.parentNode!==null||box.childNodes.length!==1||text.wholeText!=="a😀")throw new Error("native character remove");
'], runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_character_data_receiver_conversion_and_range_errors() {
	mut document := html.parse_document('<!doctype html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const text=new Text("abc");let errors=0;
for(const call of [()=>Text(),()=>new Text(Symbol()),()=>new CharacterData(),()=>Text.prototype.splitText.call({},{valueOf(){throw new Error("must brand first")}}),()=>text.splitText(),()=>text.splitText(1n),()=>CharacterData.prototype.appendData.call({},"x")])try{call()}catch(error){if(error instanceof TypeError)errors++}
if(errors!==7)throw new Error("character data brands "+errors);
let ranges=0;for(const call of [()=>text.splitText(4),()=>text.substringData(-1,1),()=>text.insertData(10,"x")])try{call()}catch(error){if(error instanceof DOMException&&error.name==="IndexSizeError")ranges++}if(ranges!==3)throw new Error("character data ranges");
const marker={};let original=false;try{text.appendData({toString(){throw marker}})}catch(error){original=error===marker}if(!original)throw new Error("original text exception");
'], runtime, mut messages)
	assert messages == []string{}
}
