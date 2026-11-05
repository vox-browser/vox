module main

import browserjs
import html

fn test_compact_class_collection_supports_wikipedia_lookup_and_html_collection_access() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><div id="outside" class="overlay-banner-toggle"></div><section id="scope"><button id="toggle" name="banner" class="overlay-banner-toggle">Languages</button><button id="second" name="toggle" class="overlay-banner-toggle">Close</button><button id="length" class="overlay-banner-toggle">Other</button></section>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
const toggles=document.getElementsByClassName("overlay-banner-toggle");
if(Array.isArray(toggles)||toggles.length!==4||toggles.push!==undefined)throw new Error("collection shape");
if(toggles[0]!==outside||toggles[1]!==toggle||toggles.item(2)!==second||toggles.item(99)!==null||toggles[99]!==undefined)throw new Error("indexed access");
if(toggles.namedItem("banner")!==toggle||toggles.namedItem("toggle")!==toggle||toggles.namedItem("missing")!==null||toggles.namedItem("")!==null)throw new Error("named item");
if(toggles.banner!==toggle||toggles.toggle!==toggle||toggles.missing!==undefined||toggles.length!==4||toggles.namedItem("length")!==document.getElementById("length"))throw new Error("named properties");
if(Array.from(toggles).map(element=>element.id).join(",")!=="outside,toggle,second,length")throw new Error("collection iteration");
let registrations=0;
Array.prototype.forEach.call(toggles,function(element){element.addEventListener("click",function(){});registrations++;});
if(registrations!==4)throw new Error("Wikipedia listener registration");
const descendants=scope.getElementsByClassName("overlay-banner-toggle");
if(descendants.length!==3||descendants[0]!==toggle||descendants.item(1)!==second||document.getElementsByClassName("overlay-banner-toggle")[1]!==toggle)throw new Error("stable element facade");
console.log("Wikipedia class lookup passed");
',
	], runtime, mut messages)
	assert messages == ['Wikipedia class lookup passed']
}

fn test_compact_class_collection_matches_literal_tokens_and_ascii_whitespace_in_standards_mode() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><section id="scope"><div id="multiple" class="alpha beta"></div><div id="literal" class="dot.name bracket[x] colon:y"></div><div id="nonbreaking" class="alpha beta"></div><div id="mixedcase" class="MixedCase"></div><div id="conversion" class="null undefined 42"></div></section>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
for(const root of [document,scope]){
 const all=root.getElementsByClassName(" \talpha\n\rbeta\f alpha ");
 if(all.length!==1||all[0]!==multiple)throw new Error("all ASCII-whitespace-separated tokens");
 if(root.getElementsByClassName("alpha absent").length!==0)throw new Error("all tokens required");
 for(const value of [""," \t\n\r\f "])if(root.getElementsByClassName(value).length!==0)throw new Error("empty token list");
 for(const value of ["dot.name","bracket[x]","colon:y","dot.name bracket[x]"])if(root.getElementsByClassName(value)[0]!==literal)throw new Error("literal punctuation");
 if(root.getElementsByClassName("alpha\u00a0beta")[0]!==nonbreaking||root.getElementsByClassName("alpha").length!==1)throw new Error("non-ASCII whitespace remains literal");
 if(root.getElementsByClassName("MixedCase")[0]!==mixedcase||root.getElementsByClassName("mixedcase").length!==0)throw new Error("standards case sensitivity");
 if(root.getElementsByClassName(null)[0]!==conversion||root.getElementsByClassName(undefined)[0]!==conversion||root.getElementsByClassName(42)[0]!==conversion)throw new Error("DOMString primitive conversion");
}
console.log("class tokens passed");
',
	], runtime, mut messages)
	assert messages == ['class tokens passed']
}

fn test_compact_class_collection_matches_ascii_case_insensitively_in_quirks_mode() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<section id="scope"><div id="mixedcase" class="MiXeD ToKeN"></div><div id="nonascii" class="Ä"></div></section>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
for(const root of [document,scope]){
 const matches=root.getElementsByClassName("mixed TOKEN mixed");
 if(matches.length!==1||matches[0]!==mixedcase)throw new Error("quirks ASCII case folding");
 if(root.getElementsByClassName("ä").length!==0||root.getElementsByClassName("Ä")[0]!==nonascii)throw new Error("quirks does not fold non-ASCII");
}
console.log("quirks class lookup passed");
',
	], runtime, mut messages)
	assert messages == ['quirks class lookup passed']
}

fn test_compact_held_class_collection_tracks_mutations_tree_order_and_detached_roots() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><section id="scope" class="tracked"><div id="first" class="tracked"><b id="nested" class="tracked"></b></div><div id="second"></div><div id="replacement"></div></section><div id="outside" class="tracked"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
const all=document.getElementsByClassName("tracked"),inside=scope.getElementsByClassName("tracked");
const ids=collection=>Array.from(collection).map(element=>element.id).join(",");
if(ids(all)!=="scope,first,nested,outside"||ids(inside)!=="first,nested")throw new Error("tree order and root exclusion");
first.className="";
if(ids(inside)!=="nested"||inside.first!==undefined)throw new Error("live className removal");
second.classList.add("tracked");
if(ids(inside)!=="nested,second"||inside.second!==second)throw new Error("live classList addition");
second.classList.remove("tracked");
if(ids(inside)!=="nested")throw new Error("live classList removal");
const created=document.createElement("em");created.id="created";created.className="tracked";
if(ids(all)!=="scope,nested,outside")throw new Error("detached created node excluded");
scope.appendChild(created);
if(ids(inside)!=="nested,created"||inside.namedItem("created")!==created||document.getElementsByClassName("tracked").namedItem("created")!==created)throw new Error("append and created identity");
scope.moveBefore(created,first);
if(ids(inside)!=="created,nested"||inside[0]!==created)throw new Error("live move order");
created.remove();
if(ids(inside)!=="nested"||inside.created!==undefined)throw new Error("live removal");
replacement.innerHTML="<i id=imported class=tracked>new</i><i id=importedSecond class=tracked>next</i>";
const imported=document.getElementById("imported");
if(ids(inside)!=="nested,imported,importedSecond"||inside.namedItem("imported")!==imported)throw new Error("live innerHTML import");
replacement.innerHTML="<strong id=last class=tracked>last</strong>";
if(ids(inside)!=="nested,last"||inside.imported!==undefined||document.getElementById("imported")!==null)throw new Error("live innerHTML replacement");
scope.remove();
if(ids(all)!=="outside"||ids(inside)!=="nested,last"||inside[0]!==nested)throw new Error("detached root descendants remain live");
console.log("live class collections passed");
',
	], runtime, mut messages)
	assert messages == ['live class collections passed']
	assert document.get_element_by_id('imported') == none
	assert document.get_element_by_id('scope') == none
}

fn test_compact_class_collection_requires_arguments_and_brands_element_receiver_before_conversion() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><div id="scope"><span id="child" class="wanted"></span></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
const method=Element.prototype.getElementsByClassName;
const descriptor=Object.getOwnPropertyDescriptor(Element.prototype,"getElementsByClassName");
if(typeof method!=="function"||method.name!=="getElementsByClassName"||method.length!==1||!descriptor.writable||!descriptor.enumerable||!descriptor.configurable)throw new Error("Element method descriptor");
for(const root of [document,scope]){
 let missing=false;try{root.getElementsByClassName()}catch(error){missing=error instanceof TypeError}if(!missing)throw new Error("required classNames argument");
 for(const value of [Symbol("wanted"),{[Symbol.toPrimitive](){return Symbol("wanted")}}]){let failed=false;try{root.getElementsByClassName(value)}catch(error){failed=error instanceof TypeError}if(!failed)throw new Error("Symbol conversion");}
 let conversions=0;const value={toString(){conversions++;return "wanted"}};
 if(root.getElementsByClassName(value)[0]!==child||conversions!==1)throw new Error("single string conversion");
 const reason={};let preserved=false;try{root.getElementsByClassName({toString(){throw reason}})}catch(error){preserved=error===reason}if(!preserved)throw new Error("conversion exception identity");
}
let traps=0,conversions=0;
const value={toString(){conversions++;throw new Error("converted before receiver brand")}};
const proxy=new Proxy(scope,{get(){traps++;throw new Error("get trap")},getPrototypeOf(){traps++;throw new Error("prototype trap")}});
for(const receiver of [null,undefined,0,{},Object.create(scope),Object.create(Element.prototype),document,document.createDocumentFragment(),proxy]){
 let failed=false;try{method.call(receiver,value)}catch(error){failed=error instanceof TypeError}if(!failed)throw new Error("Element receiver brand");
}
if(traps!==0||conversions!==0)throw new Error("receiver brand precedes conversion without proxy traps");
if(method.call(scope,"wanted")[0]!==child)throw new Error("valid borrowed method");
console.log("class collection conversion passed");
',
	], runtime, mut messages)
	assert messages == ['class collection conversion passed']
}

fn test_compact_held_class_collection_observes_native_attribute_changes() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><section id="scope"><span id="first" class="tracked"></span><span id="second"></span></section>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
globalThis.heldDocumentClasses=document.getElementsByClassName("tracked");
globalThis.heldElementClasses=scope.getElementsByClassName("tracked");
if(heldDocumentClasses.length!==1||heldElementClasses[0]!==first)throw new Error("initial native collection");
console.log("native class collection ready");
',
	], runtime, mut messages)
	assert messages == ['native class collection ready']
	mut first := document.get_element_by_id('first')?
	mut second := document.get_element_by_id('second')?
	first.set_attribute_value('class', '')
	second.set_attribute_value('class', 'tracked')
	assert runtime.evaluate_host('heldDocumentClasses.length===1&&heldDocumentClasses[0]===second&&heldDocumentClasses.first===undefined&&heldElementClasses.item(0)===second&&heldElementClasses.namedItem("second")===second')! == 'true'
}

fn test_compact_class_collection_wraps_only_requested_elements_with_stable_identity() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><p class="rank">1.</p><p class="rank">2.</p><p class="rank" id="third">3.</p><p class="rank">4.</p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
const ranks=document.getElementsByClassName("rank");
const last=ranks[3],first=ranks.item(0);
if(last.textContent!=="4."||first.textContent!=="1."||ranks.length!==4)throw new Error("out-of-order access");
if(ranks[2]!==third||ranks.namedItem("third")!==third||ranks.third!==third)throw new Error("named and indexed identity");
const iterated=Array.from(ranks);
if(iterated.length!==4||iterated[0]!==first||iterated[3]!==last||iterated[2]!==third)throw new Error("iteration identity");
if(!(1 in ranks)||(4 in ranks)||Object.getOwnPropertyDescriptor(ranks,"3").value!==last)throw new Error("index descriptors");
first.remove();
if(ranks.length!==3||ranks[0]!==iterated[1]||ranks[2]!==last||ranks[3]!==undefined)throw new Error("live after removal");
console.log("lazy class collection passed");
',
	], runtime, mut messages)
	assert messages == ['lazy class collection passed']
}
