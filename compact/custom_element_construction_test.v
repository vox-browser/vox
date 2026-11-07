module main

import browserjs
import dom
import html
import platform

fn custom_constructor_document() &dom.Document {
	address := dom.URL{value: 'https://custom-construction.test/'}
	return html.parse_navigation_document('<!doctype html><div id="container"></div>', address, address.origin(), none) or { panic(err) }
}

fn test_compact_custom_element_constructors_initialize_real_native_owners() {
	mut document := custom_constructor_document()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	assert messages == []string{}, messages.str()
	mut scratch := platform.begin_thread_scratch('custom constructor checks')
	assert runtime.evaluate_host(r'
 globalThis.calls=0;
 class Frame extends HTMLElement {
  constructor(){super();calls++;this.delegate={element:this};}
  method(){return this.delegate.element===this;}
 }
 customElements.define("turbo-frame",Frame);
 if(HTMLElement.prototype.constructor!==HTMLElement||HTMLButtonElement.prototype.constructor!==HTMLButtonElement)throw Error("HTML interface constructor identity");
 const first=document.createElement("turbo-frame"),direct=new Frame(),namespaced=document.createElementNS("http://www.w3.org/1999/xhtml","turbo-frame");
 if(calls!==3||first===direct||!first.method()||first.delegate.element!==first||!(first instanceof Frame)||!(first instanceof HTMLElement)||first.localName!=="turbo-frame"||first.ownerDocument!==document||first.parentNode!==null)throw Error("constructor initialization or identity");
 if(!(namespaced instanceof Frame)||namespaced.delegate.element!==namespaced)throw Error("namespace creation did not construct");
 const prefixed=document.createElementNS("http://www.w3.org/1999/xhtml","p:turbo-frame");
 if(!(prefixed instanceof Frame)||prefixed.prefix!=="p"||prefixed.tagName!=="P:TURBO-FRAME")throw Error("post-construction namespace prefix");
 first.id="constructed";container.appendChild(first);
 if(document.getElementById("constructed")!==first||document.querySelector("turbo-frame")!==first||container.firstChild!==first)throw Error("native owner identity");
 class Child extends Frame{};customElements.define("x-child",Child);
 globalThis.retainedCustom=new Child();
 if(!(retainedCustom instanceof Child)||!retainedCustom.method()||retainedCustom.localName!=="x-child")throw Error("inherited constructor");
 class Button extends HTMLButtonElement{constructor(){super();this.initialized=true}}
 customElements.define("x-button-constructor",Button,{extends:"button"});
 globalThis.nativeButton=new Button();if(!(nativeButton instanceof Button)||!(nativeButton instanceof HTMLButtonElement)||nativeButton.localName!=="button"||!nativeButton.initialized)throw Error("customized built-in constructor");
 let rejected=0;class Unregistered extends HTMLElement{};
 for(const action of [()=>new HTMLElement(),()=>HTMLElement(),()=>new HTMLButtonElement(),()=>new Unregistered()])try{action()}catch(error){if(error instanceof TypeError)rejected++}
 class Wrong extends HTMLButtonElement{};customElements.define("x-wrong-interface",Wrong);
 class WrongBuiltin extends HTMLElement{};customElements.define("x-wrong-builtin",WrongBuiltin,{extends:"button"});
 for(const action of [()=>new Wrong(),()=>new WrongBuiltin()])try{action()}catch(error){if(error instanceof TypeError)rejected++}
 if(rejected!==6)throw Error("constructor interface validation");
 class Nested extends HTMLElement{constructor(){super();if(!globalThis.inNested){globalThis.inNested=true;this.inner=document.createElement("x-nested");globalThis.inNested=false}}}
 customElements.define("x-nested",Nested);const nested=document.createElement("x-nested");
 if(!(nested instanceof Nested)||!(nested.inner instanceof Nested)||nested.inner===nested)throw Error("reentrant construction");
 globalThis.constructorPass=true;
 true;
 ')! == 'true'
	scratch.finish()
	gc_collect()
	assert messages == []string{}, messages.str()
	assert runtime.evaluate_host('constructorPass&&retainedCustom.method()&&retainedCustom.localName==="x-child"')! == 'true'
	first := document.get_element_by_id('constructed')?
	assert first.custom_element_state_ == .custom
	assert first.custom_element_definition()?.name() == 'turbo-frame'
	wrapper := runtime.evaluate_host_value('document.getElementById("constructed")')!
	defer { runtime.release_javascript_value(wrapper) }
	assert voidptr(runtime.native_event_target(wrapper)!) == voidptr(first)
	button := runtime.evaluate_host_value('nativeButton')!
	defer { runtime.release_javascript_value(button) }
	native := unsafe { &dom.Element(runtime.native_event_target(button)!) }
	assert native.custom_element_is_value()? == 'x-button-constructor'
}

fn test_compact_synchronous_custom_element_failures_report_and_return_failed_native_elements() {
	mut document := custom_constructor_document()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	assert messages == []string{}, messages.str()
	assert runtime.evaluate_host(r'
 globalThis.originalFailure={original:true};
 class Throws extends HTMLElement{constructor(){super();throw originalFailure}}
 class Attributes extends HTMLElement{constructor(){super();this.setAttribute("extra","")}}
 class Children extends HTMLElement{constructor(){super();this.appendChild(document.createElement("span"))}}
 class Parent extends HTMLElement{constructor(){super();container.appendChild(this)}}
 class Other extends HTMLElement{constructor(){super();return document.createElement("div")}}
 class NonElement extends HTMLElement{constructor(){return {}}}
 class OtherDocument extends HTMLElement{constructor(){super();return document.implementation.createHTMLDocument("").createElement("x-other-document")}}
 globalThis.failedConstructions=[];
 for(const [name,C] of [["x-throws",Throws],["x-attributes",Attributes],["x-children",Children],["x-parent",Parent],["x-other",Other],["x-non-element",NonElement],["x-other-document",OtherDocument]]){
  customElements.define(name,C);const element=document.createElement(name);failedConstructions.push(element);
  if(!(element instanceof HTMLElement)||element instanceof C||element.localName!==name||element.ownerDocument!==document||element.childNodes.length||element.parentNode!==null)throw Error("invalid failure fallback: "+name);
 }
 let original=false;try{new Throws()}catch(error){original=error===originalFailure}
 if(!original)throw Error("direct construction replaced original thrown value");
 let reads=0,throwPrototype=false;
 const ProxyConstructor=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype"){reads++;if(throwPrototype)throw originalFailure}return Reflect.get(target,key,receiver)}});
 customElements.define("x-prototype-error",ProxyConstructor);throwPrototype=true;
 let prototypeOriginal=false;try{Reflect.construct(HTMLElement,[],ProxyConstructor)}catch(error){prototypeOriginal=error===originalFailure}
 if(!prototypeOriginal||reads!==2)throw Error("new target prototype access");
 // Author replacement of these intrinsics must not alter native construction.
 const savedSet=Object.setPrototypeOf,savedConstruct=Reflect.construct,savedTypeError=globalThis.TypeError;
 class Stable extends HTMLElement{constructor(){super();this.initialized=true}}
 customElements.define("x-stable",Stable);
 try{Object.setPrototypeOf=Reflect.construct=globalThis.TypeError=function(){throw originalFailure};if(!document.createElement("x-stable").initialized)throw Error("captured constructor intrinsics")}
 finally{Object.setPrototypeOf=savedSet;Reflect.construct=savedConstruct;globalThis.TypeError=savedTypeError}
 true;
 ')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 7
	marker := runtime.evaluate_host_value('originalFailure')!
	defer { runtime.release_javascript_value(marker) }
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == marker
	for index in 0 .. 7 {
		wrapper := runtime.evaluate_host_value('failedConstructions[${index}]')!
		native := unsafe { &dom.Element(runtime.native_event_target(wrapper)!) }
		assert native.custom_element_state_ == .failed
		assert !native.has_attributes()
		assert native.custom_element_definition() == none
		runtime.release_javascript_value(wrapper)
	}
}

// Console output queued earlier in the task is not a replay failure. GitHub
// logs during module evaluation and then creates <turbo-frame> synchronously.
fn test_compact_custom_element_construction_keeps_pending_console_output() {
	mut document := custom_constructor_document()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
 console.log("before definition");
 class Frame extends HTMLElement{constructor(){super();console.log("constructing");this.delegate={element:this};}}
 customElements.define("turbo-frame",Frame);
 console.warn("before creation");
 const frame=document.createElement("turbo-frame");
 if(!(frame instanceof Frame)||frame.delegate.element!==frame)throw Error("constructor did not run");
 container.appendChild(frame);
 console.log("created",document.querySelector("turbo-frame")===frame);
 '], runtime, mut messages)
	assert messages == ['before definition', 'before creation', 'constructing', 'created true'], messages.str()
}
