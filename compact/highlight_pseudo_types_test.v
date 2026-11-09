module main

import browserjs
import html

fn test_computed_highlight_pseudo_types_and_invalid_pseudo_arguments() {
	mut document := html.parse_document('<!doctype html><style>#target::selection,#target::target-text,#target::spelling-error,#target::grammar-error,#target::highlight(foo){color:lime;background-color:green}#target::search-text{color:lime;background-color:blue}#target::search-text:not(:current){background-color:green}#target::search-text:current{background-color:red}</style><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://highlight.test/', [r'
const target=document.getElementById("target");
for(const pseudo of ["::selection","::target-text","::spelling-error","::grammar-error","::highlight(foo)","::search-text"]){
 const style=getComputedStyle(target,pseudo);
 if(style.backgroundColor!=="rgb(0, 128, 0)"||style.color!=="rgb(0, 255, 0)")throw new Error(pseudo+": "+style.backgroundColor+" "+style.color);
 for(const invalid of [pseudo+":",pseudo+")",pseudo+"(",pseudo+"(foo)",pseudo+"()",":"+pseudo,pseudo+"."]){
  const empty=getComputedStyle(target,invalid);if(empty.color!==""||empty.backgroundColor!=="")throw new Error("Invalid pseudo accepted: "+invalid);
 }
}
if(getComputedStyle(target,":before").color!==getComputedStyle(target,"::before").color)throw new Error("legacy before alias");
console.log("highlight pseudo types passed");
'], runtime, mut messages)
	assert messages == ['highlight pseudo types passed']
}
