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
	reply := binding.selector_first(borrowed, '.absent')!
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
