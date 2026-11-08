module main

import browserjs
import html

fn test_writing_suggestions_reflects_and_inherits_html_ancestor_state() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><body><div id="parent" writingsuggestions="false"><span id="child"></span><svg><foreignObject><p id="nested"></p></foreignObject></svg></div></body>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/', [r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const owner=document.getElementById("parent"),child=document.getElementById("child"),nested=document.getElementById("nested");
check(child.writingSuggestions,"false");
check(nested.writingSuggestions,"false");
for(const tag of ["input","textarea","div","span","test-custom-element"]){
 const element=document.createElement(tag);
 check(element.writingSuggestions,"true");
 owner.appendChild(element);
 check(element.writingSuggestions,"false");
 for(const value of ["", "true", "TrUe", "invalid", null, undefined, false, "FaLsE"]){
  element.writingSuggestions=value;
  check(element.getAttribute("writingsuggestions"),String(value));
  check(element.writingSuggestions,String(value).toLowerCase()==="false"?"false":"true");
 }
 let rejected=false;
 try{element.writingSuggestions=Symbol();}catch(error){rejected=error instanceof TypeError;}
 check(rejected,true);
 check(element.getAttribute("writingsuggestions"),"FaLsE");
 element.removeAttribute("writingsuggestions");
 check(element.writingSuggestions,"false");
 element.remove();
 check(element.writingSuggestions,"true");
}
owner.writingSuggestions="true";
check(child.writingSuggestions,"true");
owner.writingSuggestions="FALSE";
check(child.writingSuggestions,"false");
child.writingSuggestions="";
check(child.writingSuggestions,"true");
const parsed=new DOMParser().parseFromString("<html writingsuggestions=false><body><input><textarea></textarea></body></html>","text/html");
check(parsed.querySelector("input").writingSuggestions,"false");
check(parsed.querySelector("textarea").writingSuggestions,"false");
console.log("writing suggestions passed");
'], runtime, mut messages)
	assert messages == ['writing suggestions passed'], messages.str()
}
