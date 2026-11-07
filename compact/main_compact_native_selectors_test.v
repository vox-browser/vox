module main

import browserjs
import html

fn test_compact_selectors_are_actual_native_non_constructible_dom_methods() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><section id="scope"><p id="inside" class="comment">inside</p></section><p class="comment">outside</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
for(const owner of [document,Element.prototype]){
 for(const name of ["querySelector","querySelectorAll","matches","closest"]){
  if(owner===document&&(name==="matches"||name==="closest"))continue;
  const method=owner[name],descriptor=Object.getOwnPropertyDescriptor(owner,name);
  if(!/^[^{]+\{\s*\[native \w/.test(Function.prototype.toString.call(method)))throw new Error("selector fallback enabled for "+name);
  if(method.name!==name||method.length!==1||Object.getPrototypeOf(method)!==Function.prototype||Object.prototype.hasOwnProperty.call(method,"prototype"))throw new Error("native method surface "+name);
  if(!descriptor.writable||!descriptor.enumerable||!descriptor.configurable)throw new Error("descriptor "+name);
  let illegal=false;try{new method("p")}catch(error){illegal=error instanceof TypeError}if(!illegal)throw new Error("constructible selector");
 }
}
if(scope.querySelectorAll(":scope > .comment").length!==1||document.querySelectorAll(".comment").length!==2||scope.querySelector("#inside")!==inside||!inside.matches(".comment")||inside.closest("section")!==scope)throw new Error("native selector result or scope");
if(Element.prototype.webkitMatchesSelector!==Element.prototype.matches)throw new Error("matches alias identity");
console.log("native selectors passed");
'], runtime, mut messages)
	assert messages == ['native selectors passed']
}

fn test_native_selector_bindings_preserve_branding_conversion_and_exceptions() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><div id="target"><i id="child"></i></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
for(const name of ["querySelector","querySelectorAll","matches","closest"]){
 const method=Element.prototype[name];let conversions=0;
 const selector={toString(){conversions++;return "#child";}};
 let illegal=false;try{method.call({},selector)}catch(error){illegal=error instanceof TypeError}
 if(!illegal||conversions!==0)throw new Error("receiver conversion order "+name);
 method.call(target,selector);if(conversions!==1)throw new Error("repeated conversion "+name);
 const sentinel={name};let original=false;try{method.call(target,{toString(){throw sentinel}})}catch(error){original=error===sentinel}if(!original)throw new Error("changed exception identity "+name);
 let missing=false;try{method.call(target)}catch(error){missing=error instanceof TypeError}if(!missing)throw new Error("missing selector "+name);
 let symbol=false;try{method.call(target,Symbol())}catch(error){symbol=error instanceof TypeError}if(!symbol)throw new Error("symbol selector "+name);
}
let syntax=false;try{target.querySelectorAll("[")}catch(error){syntax=error.name==="SyntaxError"}if(!syntax)throw new Error("selector SyntaxError");
console.log("selector conversions passed");
'], runtime, mut messages)
	assert messages == ['selector conversions passed']
}

fn test_saved_native_selector_methods_replay_live_mutations_and_allow_author_overrides() {
	$if !darwin { return }
	mut document := html.parse_document('<!doctype html><div id="host"><i id="old"></i></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const native=Element.prototype.querySelectorAll;
const before=native.call(host,"i");host.innerHTML="<b id=new>updated</b>";
if(native.call(host,"i").length!==0||native.call(host,"b")[0]!==document.getElementById("new")||before.length!==1)throw new Error("live mutation or static query result");
Element.prototype.querySelectorAll=function(){return ["author"]};
if(host.querySelectorAll("b")[0]!=="author"||native.call(host,"b").length!==1)throw new Error("author override or saved native binding");
console.log("selector overrides passed");
'], runtime, mut messages)
	assert messages == ['selector overrides passed']
}
