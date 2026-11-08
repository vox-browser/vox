module main

import browserjs
import html

fn check_mathml_interfaces(markup string, code string) {
	mut document := html.parse_document(markup)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://mathml-interfaces.test/', [code], runtime, mut messages)
	assert messages == [], messages.join('\n')
}

fn test_mathml_interface_classifies_parsed_created_prefixed_and_cloned_elements() {
	check_mathml_interfaces('<!doctype html><math id="root"><mi id="letter">x</mi></math>', r'
const ns="http://www.w3.org/1998/Math/MathML";
function check(value,message){if(!value)throw Error(message);}
check(Object.getPrototypeOf(MathMLElement)===Element&&Object.getPrototypeOf(MathMLElement.prototype)===Element.prototype,"interface chain");
for(const node of [root,letter,root.cloneNode(true),document.createElementNS(ns,"mrow"),document.createElementNS(ns,"m:mi"),document.createElementNS(ns,"future-tag")]){
 check(node instanceof MathMLElement&&node instanceof Element&&node instanceof Node&&!(node instanceof HTMLElement)&&!(node instanceof SVGElement),"instance chain");
 check(Object.prototype.toString.call(node)==="[object MathMLElement]","interface tag");
 check(node.constructor===MathMLElement,"constructor identity");
}
for(const node of [document.createElement("math"),document.createElementNS("urn:other","math"),document.createElementNS("http://www.w3.org/2000/svg","math")])check(!(node instanceof MathMLElement),"namespace boundary");
for(const make of [()=>MathMLElement(),()=>new MathMLElement()]){let illegal=false;try{make()}catch(error){illegal=error instanceof TypeError;}check(illegal,"illegal constructor");}
check(Object.getOwnPropertyDescriptor(MathMLElement,"prototype").writable===false,"fixed prototype");
')
}

fn test_mathml_and_svg_global_handlers_compile_replace_clone_and_dispatch_natively() {
	check_mathml_interfaces('<!doctype html><math id="root" onclick="globalThis.mathRuns=(globalThis.mathRuns||0)+1;"></math><svg id="vector"/>', r'
function check(value,message){if(!value)throw Error(message);}
const pairs=[["onclick","click"],["onfocus","focus"],["onkeydown","keydown"],["oncopy","copy"],["onload","load"],["onerror","error"],["onwheel","wheel"],["onscrollend","scrollend"],["onwebkitanimationend","webkitAnimationEnd"]];
for(const [namespace,Constructor] of [["http://www.w3.org/1998/Math/MathML",MathMLElement],["http://www.w3.org/2000/svg",SVGElement]]){
 for(const [attribute,type] of pairs){
  const descriptor=Object.getOwnPropertyDescriptor(Constructor.prototype,attribute),node=document.createElementNS(namespace,"input");
  check(descriptor&&descriptor.enumerable&&descriptor.configurable&&!(attribute in Element.prototype),attribute+" placement");
  check(node[attribute]===null,attribute+" default");
  node.setAttribute(attribute,"globalThis.mathEventRuns=(globalThis.mathEventRuns||0)+1;");
  check(typeof node[attribute]==="function",attribute+" compilation");
  const copy=node.cloneNode(true);copy[attribute]();
  let target=null,listened=0;node.addEventListener(type,()=>listened++);node[attribute]=function(event){target=event.currentTarget;return false;};
  check(node.dispatchEvent(new Event(type,{cancelable:true}))===false&&target===node&&listened===1,attribute+" dispatch");
  node[attribute]=42;check(node[attribute]===null,attribute+" noncallable");
  node.setAttribute(attribute,"globalThis.mathEventRuns++;");check(typeof node[attribute]==="function",attribute+" mutation");
  node.removeAttribute(attribute);check(node[attribute]===null,attribute+" removal");
 }
}
check(typeof root.onclick==="function","parsed content attribute");root.dispatchEvent(new Event("click"));check(mathRuns===1,"parsed dispatch once");
')
}

fn test_mathml_handler_receivers_namespaces_and_scope_remain_separate() {
	check_mathml_interfaces('<!doctype html><math id="root"></math><div id="html"></div>', r'
function check(value,message){if(!value)throw Error(message);}
const descriptor=Object.getOwnPropertyDescriptor(MathMLElement.prototype,"onclick");
for(const receiver of [{},null,html,MathMLElement.prototype,new Proxy(root,{})]){
 let illegal=false;try{descriptor.get.call(receiver)}catch(error){illegal=error instanceof TypeError;}check(illegal,"getter brand");
}
root.setAttributeNS("urn:other","x:onclick","throw Error(1)");check(root.onclick===null,"namespaced content attribute");
root.setAttribute("ONCLICK","throw Error(2)");check(root.onclick===null,"case-sensitive attribute");
const node=document.createElementNS("http://www.w3.org/1998/Math/MathML","button");node.marker="element";globalThis.marker="global";
node.setAttribute("onclick","globalThis.mathScope=marker");node.onclick();check(mathScope==="element","handler element scope");
')
}

fn test_mathml_common_reflections_preserve_integer_rules_and_dataset_identity() {
	check_mathml_interfaces('<!doctype html><math id="root" data-part="formula"></math>', r'
function check(value,message){if(!value)throw Error(message);}
const ns="http://www.w3.org/1998/Math/MathML";
for(const name of ["math","mi","mrow","input","a"]){
 const node=document.createElementNS(ns,name),fallback=name==="a"?0:-1;
 check(node.tabIndex===fallback,"default "+name);
 for(const value of ["","invalid","9999999999","-9999999999","18446744073709551616"]){node.setAttribute("tabindex",value);check(node.tabIndex===fallback,"invalid "+value);}
 for(const [value,expected] of [["3",3],["1.5",1],["4abc",4],["-2 ",-2],["+2147483647",2147483647],["-2147483648",-2147483648]]){node.setAttribute("tabindex",value);check(node.tabIndex===expected,"integer "+value);}
 node.removeAttribute("tabindex");check(node.tabIndex===fallback,"reset");node.tabIndex=4294967295;check(node.getAttribute("tabindex")==="-1","IDL long");
 let illegal=false;try{node.tabIndex=1n}catch(error){illegal=error instanceof TypeError;}check(illegal,"BigInt conversion");
 check(node.autofocus===false,"autofocus default");node.autofocus=true;check(node.hasAttribute("autofocus"),"autofocus set");node.autofocus=false;check(!node.hasAttribute("autofocus"),"autofocus remove");
}
const data=root.dataset;check(data===root.dataset&&data instanceof DOMStringMap&&data.part==="formula","dataset identity");data.variableName="x";check(root.getAttribute("data-variable-name")==="x","dataset reflection");
const unknown=document.createElementNS("urn:other","math");check(unknown.tabIndex===undefined&&unknown.dataset===undefined,"unrelated namespace");
')
}
