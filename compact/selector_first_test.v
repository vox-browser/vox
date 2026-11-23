module main

import browserjs
import dom
import html
import platform

fn test_selector_first_retains_registered_keys_after_temporary_arguments_retire() {
	mut document := dom.Document.create(dom.URL{value: 'https://selector-first.test/'})
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><main id="host"><i></i></main>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer {
		runtime.close()
		owner.finish()
		document.finalize()
		document.release_native_storage()
	}
	mut binding := &CompactElementQueryBinding{document: document, runtime: runtime}
	target := document.get_element_by_id('host') or { panic('host') }
	key := '__element_0'.clone()
	binding.elements[key] = target
	binding.keys[voidptr(target)] = key
	work := platform.begin_thread_scratch('selector first borrowed key')
	borrowed := key.clone()
	work.leave()
	reply := binding.selector_first(borrowed, '.absent', false, false)!
	assert reply.handled && !reply.matched
	work.finish()
	retained := binding.keys[voidptr(target)] or { panic('registered key') }
	$if prealloc {
		// A later positive query publishes this key to the facade. It must not
		// point into the retired host argument buffer.
		assert document.native_storage().arena.contains(voidptr(retained.str))
	}
	churn := platform.begin_thread_scratch('selector first key overwrite')
	_ = 'x'.repeat(128 * 1024)
	churn.finish()
	assert binding.element_key(target) == '__element_0'
}

fn test_compact_selector_first_keeps_live_results_errors_scopes_and_reactions() {
	mut document := html.parse_document('<!doctype html><main id="host"><i id="target"></i></main><div id="other"></div>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.queryHost=document.getElementById("host");globalThis.queryTarget=document.getElementById("target");
if(document.querySelector(".missing")!==null||queryHost.querySelector("main")!==null||queryTarget.querySelector("i")!==null)throw Error("absent selectors");
if(document.querySelector("#target")!==queryTarget||queryHost.querySelector(":scope > i")!==queryTarget)throw Error("positive identity and scope");
queryTarget.className="λ😀";
if(queryHost.querySelector(`[class="λ😀"]`)!==queryTarget||queryHost.querySelector(".missing")!==null)throw Error("pending attributes");
const child=document.createElement("b");child.className="new";
if(child.querySelector("b")!==null)throw Error("detached root exclusion");
queryHost.appendChild(child);
if(queryHost.querySelector("b.new")!==child||queryHost.querySelector("i + b")!==child)throw Error("pending insertion");
const fragment=document.createDocumentFragment();
if(fragment.querySelector("b")!==null)throw Error("empty fragment");
fragment.appendChild(child);
if(fragment.querySelector("b")!==child||queryHost.querySelector("b")!==null)throw Error("fragment move");
const foreign=document.implementation.createHTMLDocument("foreign");foreign.body.appendChild(queryTarget);
if(queryTarget.querySelector("em")!==null||foreign.querySelector("#target")!==queryTarget||queryHost.querySelector("i")!==null)throw Error("foreign owner");
for(const root of [document,queryHost,queryTarget,fragment])for(const selector of ["[",":unknown-pseudo"]){let failed=false;try{root.querySelector(selector)}catch(e){failed=e.name==="SyntaxError"}if(!failed)throw Error("selector errors");}
customElements.define("first-query-probe",class extends HTMLElement{
 static get observedAttributes(){return ["data-mode"]}
 attributeChangedCallback(name,old,value){this.innerHTML=value==="present"?"<em class=reacted></em>":"";}
});
globalThis.queryReactor=document.createElement("first-query-probe");queryReactor.id="reactor";document.body.appendChild(queryReactor);
queryReactor.setAttribute("data-mode","present");if(queryReactor.querySelector("em.reacted")===null)throw Error("pending custom reaction");
queryReactor.setAttribute("data-mode","absent");if(queryReactor.querySelector("em")!==null)throw Error("pending reaction removal");
'], runtime, mut messages)
	assert messages == []string{}
	mut reactor := document.get_element_by_id('reactor') or { panic('reactor') }
	reactor.set_attribute_value('data-mode', 'present')
	assert runtime.evaluate_host('queryReactor.querySelector("em.reacted")!==null')! == 'true'
	reactor.set_attribute_value('data-mode', 'absent')
	assert runtime.evaluate_host('queryReactor.querySelector("em")===null')! == 'true'
}

fn test_selector_first_transport_preserves_false_true_undefined_and_argument_storage() {
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	runtime.install_selector_first_query(fn (key string, selector string) !browserjs.SelectorMatchReply {
		if selector == '[' { return error('SyntaxError: invalid selector') }
		if key != 'é😀' { return browserjs.SelectorMatchReply{} }
		return browserjs.SelectorMatchReply{handled: true, matched: selector == '.present'}
	})!
	for _ in 0 .. 8 {
		work := platform.begin_thread_scratch('first selector caller')
		assert runtime.evaluate_host(r'__ladybirdSelectorFirst("é😀",".absent")===false&&__ladybirdSelectorFirst("é😀",".present")===true&&__ladybirdSelectorFirst("foreign","*")===undefined')! == 'true'
		work.finish()
	}
	assert runtime.evaluate_host(r'(()=>{const value={toString(){throw Error("coerced")}};return [value,Symbol(),null,1,new String("é😀")].every(v=>__ladybirdSelectorFirst(v,"*")===undefined&&__ladybirdSelectorFirst("é😀",v)===undefined)&&__ladybirdSelectorFirst()===undefined})()')! == 'true'
	assert runtime.evaluate_host(r'(()=>{try{__ladybirdSelectorFirst("é😀","[");return false}catch(e){return e.message.includes("SyntaxError")}})()')! == 'true'
}

// The facade answers querySelector for element names the document has never
// seen without a native query, below the document and roots it has seen
// connected at the current tree version. Other selectors, detached roots,
// shadow trees and every insertion of a new name still reach the native DOM.
fn test_compact_selector_first_reuses_unseen_names_until_the_document_sees_them() {
	mut document := html.parse_document('<!doctype html><main id="host"><section id="first"><p id="para">one</p></section><section><p>two</p></section><react-partial partial-name="present"></react-partial></main>')
	mut runtime := browserjs.Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const sections=Array.from(document.querySelectorAll("section"));
const selectors=["absent-tag","other-absent-tag",`react-partial[partial-name="absent"]`,"p.absent","#absent","[data-absent]"];
for(let round=0;round<3;round++)for(const root of [document,...sections])for(const selector of selectors)if(root.querySelector(selector)!==null)throw Error("absent "+selector);
if(sections[0].querySelector("p")===null||document.querySelector(`react-partial[partial-name="present"]`)===null)throw Error("present selectors");
// A facade insertion is pending until replayed; then the tree version changes.
const added=document.createElement("absent-tag");sections[1].appendChild(added);
if(sections[1].querySelector("absent-tag")!==added||document.querySelector("absent-tag")!==added)throw Error("inserted tag");
if(sections[0].querySelector("absent-tag")!==null)throw Error("other root after insertion");
// Attribute edits change no structure.
const partial=document.querySelector("react-partial");partial.setAttribute("partial-name","absent");
if(document.querySelector(`react-partial[partial-name="absent"]`)!==partial)throw Error("attribute match");
sections[0].firstChild.setAttribute("data-absent","");
if(sections[0].querySelector("[data-absent]")!==sections[0].firstChild)throw Error("attribute presence");
// Detached and shadow roots never use document facts.
for(const selector of ["detached-tag","shadow-tag"])if(document.querySelector(selector)!==null)throw Error("document "+selector);
const detached=document.createElement("div");detached.appendChild(document.createElement("detached-tag"));
if(detached.querySelector("detached-tag")===null)throw Error("detached root");
const shadow=document.getElementById("host").attachShadow({mode:"open"});shadow.innerHTML="<div><shadow-tag></shadow-tag></div>";
if(document.querySelector("shadow-tag")!==null)throw Error("shadow content in document");
if(shadow.querySelector("shadow-tag")===null||shadow.firstChild.querySelector("shadow-tag")===null)throw Error("shadow roots");
globalThis.absenceSections=sections;
'], runtime, mut messages)
	assert messages == []string{}
	// Native edits outside script change the versions the facade reads.
	assert runtime.evaluate_host('absenceSections[0].querySelector("native-tag")===null')! == 'true'
	mut first := document.get_element_by_id('first') or { panic('section') }
	native := document.create_element('native-tag')!
	first.as_node().append_child(native.as_node())!
	assert runtime.evaluate_host('absenceSections[0].querySelector("native-tag")!==null')! == 'true'
	assert runtime.evaluate_host('absenceSections[0].querySelector("p.absent")===null')! == 'true'
	mut paragraph := document.get_element_by_id('para') or { panic('paragraph') }
	paragraph.set_attribute_value('class', 'absent')
	assert runtime.evaluate_host('absenceSections[0].querySelector("p.absent")!==null')! == 'true'
}
