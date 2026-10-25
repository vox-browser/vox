module main

import browserjs
import html

fn test_compact_element_prototype_preserves_specialized_native_facades_and_receiver_brand() {
	$if !darwin {
		return
	}
	mut document :=
		html.parse_document('<!doctype html><div id="ordinary"></div><img id="picture"><video id="movie"></video><svg id="vector"></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
for(const element of [ordinary,picture,movie,vector,document.createElement("span"),document.createElementNS("http://www.w3.org/2000/svg","rect")]) {
 if(!(element instanceof Element)||!(element instanceof EventTarget))throw new Error("element inheritance");
 if(Element.prototype.matches.call(element,"*")!==true)throw new Error("native match");
}
if(Object.getPrototypeOf(ordinary)!==HTMLElement.prototype||Object.getPrototypeOf(picture)!==HTMLImageElement.prototype||Object.getPrototypeOf(movie)!==HTMLVideoElement.prototype)throw new Error("specialized facade");
if(![ordinary,picture,movie].every(element=>element instanceof HTMLElement))throw new Error("HTML ancestry");
for(const Constructor of [HTMLImageElement,HTMLMediaElement,HTMLTrackElement])if(Object.getPrototypeOf(Constructor)!==HTMLElement)throw new Error("HTML constructor ancestry");
if(document.createDocumentFragment() instanceof Element)throw new Error("fragment is an element");
for(const construct of [()=>Element(),()=>new Element()]){let failed=false;try{construct()}catch(error){failed=error instanceof TypeError}if(!failed)throw new Error("illegal constructor");}
let traps=0;
const proxy=new Proxy(ordinary,{get(){traps++;throw new Error("get trap")},getPrototypeOf(){traps++;throw new Error("prototype trap")}});
for(const receiver of [null,undefined,1,{},Object.create(ordinary),Object.create(Element.prototype),proxy]) {
 let failed=false;try{Element.prototype.matches.call(receiver,"*")}catch(error){failed=error instanceof TypeError}if(!failed)throw new Error("receiver brand");
}
if(traps!==0)throw new Error("invalid receiver ran a proxy trap");
for(const name of ["matches","closest","querySelector","querySelectorAll"]){const d=Object.getOwnPropertyDescriptor(Element.prototype,name);if(!d.writable||!d.enumerable||!d.configurable||d.value.length!==1||d.value.name!==name)throw new Error("method descriptor");}
if(Element.prototype.webkitMatchesSelector!==Element.prototype.matches)throw new Error("legacy alias");
console.log("prototype passed");
',
	], runtime, mut messages)
	assert messages == ['prototype passed']
	ordinary := document.get_element_by_id('ordinary')?
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('ordinary')!)!) == voidptr(ordinary)
}

fn test_compact_element_selectors_use_native_css_and_live_dom_mutations() {
	$if !darwin {
		return
	}
	mut document :=
		html.parse_document('<!doctype html><section id="ancestor" class="region"><div id="parent"><span id="leaf" class="choice" data-kind="yes">first</span><span class="choice">second</span></div></section>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
if(!leaf.matches("section.region > div > span.choice[data-kind=yes]:first-child"))throw new Error("complex selector");
if(leaf.closest(".region")!==ancestor||leaf.closest("span")!==leaf||leaf.closest("article")!==null)throw new Error("closest identity");
if(parent.querySelector(".choice")!==leaf||parent.querySelector("#parent")!==null||document.querySelector(".region .choice")!==leaf)throw new Error("descendant selector");
const list=document.querySelectorAll("section span.choice");if(list.length!==2||list[0]!==leaf)throw new Error("query order");
console.log("before mutation query");
leaf.classList.remove("choice");if(leaf.matches(".choice")||document.querySelectorAll(".choice").length!==1||list.length!==2)throw new Error("live class and static list");
const child=document.createElement("em");child.id="created";child.className="choice";
if(!child.matches("em.choice")||child.closest(".region")!==null)throw new Error("disconnected created element");
parent.appendChild(child);
if(child.closest(".region")!==ancestor||parent.querySelector("em.choice")!==child)throw new Error("inserted element identity");
child.remove();if(document.querySelector("em.choice")!==null||child.closest(".region")!==null||!child.matches(".choice"))throw new Error("removed element identity");
for(const selector of ["[",":not("]){for(const name of ["matches","closest","querySelector","querySelectorAll"]){let failed=false;try{leaf[name](selector)}catch(error){failed=error.name==="SyntaxError"&&error instanceof DOMException}if(!failed)throw new Error("invalid selector "+name);}}
console.log("selectors passed");
',
	], runtime, mut messages)
	assert messages == ['before mutation query', 'selectors passed']
	assert document.get_element_by_id('created') == none
	assert document.get_element_by_id('leaf')?.get_attribute_value('class') == ''
}

fn test_compact_queries_import_inner_html_children_with_live_native_identity_and_content() {
	$if !darwin {
		return
	}
	mut document :=
		html.parse_document('<!doctype html><strong id="collision">first</strong><div id="parent"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
const firstCollision=document.getElementById("collision");
parent.innerHTML="<strong id=imported data-state=ready>new <i>child</i></strong><b id=collision>second</b><i id=id#with.punctuation>exact ID</i>";
globalThis.imported=parent.querySelector("strong[data-state=ready]");
if(!(imported instanceof Element)||document.querySelector("#imported")!==imported||imported.closest("#parent")!==parent)throw new Error("imported identity");
if(imported.textContent!=="new child"||imported.innerHTML!=="new <i>child</i>")throw new Error("imported content");
imported.setAttribute("data-state","updated");if(parent.querySelector("[data-state=updated]")!==imported)throw new Error("imported live attribute");
const secondCollision=parent.querySelector("b");if(document.getElementById("collision")!==firstCollision)throw new Error("duplicate ID tree order");
if(document.getElementById("id#with.punctuation")!==parent.querySelector("i[id]"))throw new Error("literal ID lookup");
firstCollision.remove();if(document.getElementById("collision")!==secondCollision)throw new Error("duplicate ID after removal");
console.log("import passed");
',
	], runtime, mut messages)
	assert messages == ['import passed']
	imported := document.get_element_by_id('imported')?
	assert imported.get_attribute_value('data-state') == 'updated'
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('imported')!)!) == voidptr(imported)
}
