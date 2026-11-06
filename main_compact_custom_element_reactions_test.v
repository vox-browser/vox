module main

import browserjs
import dom
import html

fn custom_reaction_document() &dom.Document {
	address := dom.URL{value: 'https://custom-reactions.test/'}
	return html.parse_navigation_document('<!doctype html><x-reacting id="parsed" data-x="1" data-y="2">text</x-reacting><x-throws id="bad"></x-throws><div id="container"></div>',
		address, address.origin(), none) or { panic(err) }
}

fn test_compact_custom_element_definitions_upgrade_parsed_elements_and_deliver_callbacks() {
	mut document := custom_reaction_document()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), []string{}, runtime, mut messages)
	assert messages == []string{}, messages.str()
	assert runtime.evaluate_host(r'
 globalThis.log=[];
 globalThis.parsedBefore=document.getElementById("parsed");
 class Reacting extends HTMLElement {
  static get observedAttributes(){return ["data-x"]}
  constructor(){super();log.push("ctor:"+(this.getAttribute("id")||"new"));this.initialized=true;}
  connectedCallback(){log.push("connected:"+this.id)}
  disconnectedCallback(){log.push("disconnected:"+this.id)}
  attributeChangedCallback(name,oldValue,value,namespace){log.push(["attr",name,oldValue,value,namespace].join(":"))}
  method(){return this.initialized===true}
 }
 globalThis.Reacting=Reacting;
 customElements.define("x-reacting",Reacting);
 const parsed=document.getElementById("parsed");
 if(parsed!==parsedBefore||!(parsed instanceof Reacting)||!parsed.method()||parsed.constructor!==Reacting)throw Error("parsed element was not upgraded in place: "+log.join());
 if(log.join()!=="ctor:parsed,attr:data-x::1:,connected:parsed")throw Error("upgrade reactions: "+log.join());
 log.length=0;
 const created=document.createElement("x-reacting");created.id="made";container.appendChild(created);
 if(document.querySelector("#made")!==created||log.join()!=="ctor:new,connected:made")throw Error("insertion reactions: "+log.join());
 log.length=0;parsed.setAttribute("data-x","2");document.querySelector("#parsed");
 parsed.setAttribute("data-y","3");document.querySelector("#parsed");
 parsed.removeAttribute("data-x");document.querySelector("#parsed");
 if(log.join()!=="attr:data-x:1:2:,attr:data-x:2::")throw Error("attribute reactions: "+log.join());
 log.length=0;created.remove();document.querySelector("#parsed");
 if(log.join()!=="disconnected:made")throw Error("removal reactions: "+log.join());
 log.length=0;globalThis.upgradeFailure={failure:true};
 class Throws extends HTMLElement{constructor(){super();throw upgradeFailure}connectedCallback(){log.push("unexpected")}}
 customElements.define("x-throws",Throws);
 const bad=document.getElementById("bad");
 // super() already set Throws.prototype; a failed upgrade does not revert it.
 if(!(bad instanceof Throws)||log.length)throw Error("failed upgrade delivered callbacks: "+log.join());
 log.length=0;
 const late=document.createElement("x-reacting");late.id="late";container.appendChild(late);
 true;
 ')! == 'true'
	assert messages == []string{}, messages.str()
	parsed := document.get_element_by_id('parsed')?
	assert parsed.custom_element_state_ == .custom
	assert parsed.custom_element_definition()?.name() == 'x-reacting'
	bad := document.get_element_by_id('bad')?
	// The spec leaves a failed upgrade "precustomized", which is not defined.
	assert bad.custom_element_state_ == .precustomized
	assert !bad.is_defined()
	assert bad.custom_element_definition() == none
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	marker := runtime.evaluate_host_value('upgradeFailure')!
	defer { runtime.release_javascript_value(marker) }
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == marker
	// Writes still pending at the end of a task reach the tree through the task
	// replay, which delivers the reactions they queue.
	state := runtime.evaluate_host('__ladybirdFinalize()')!
	apply_javascript_runtime_state(document, state, runtime, mut messages)
	assert messages == []string{}, messages.str()
	assert runtime.evaluate_host('log.join()')! == 'ctor:new,connected:late'
	assert !document.has_pending_custom_element_reactions()
}
