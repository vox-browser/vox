// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs

fn html_interface_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'html-interfaces.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_specialized_html_wrapper_prototypes_match_native_tags_and_media_ancestry() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body><button id="b"></button><input id="i"><div id="d"></div><video id="v"></video><audio id="a"></audio><unknown id="u"></unknown><x-custom id="x"></x-custom><summary id="s"></summary></body>'), Hooks{})!
	defer { host.close() }
	assert html_interface_eval(mut vm, 'var b=document.getElementById("b"),i=document.getElementById("i"),d=document.getElementById("d"),v=document.getElementById("v"),a=document.getElementById("a"),u=document.getElementById("u");b instanceof HTMLButtonElement&&b instanceof HTMLElement&&b instanceof Element&&!(b instanceof HTMLInputElement)&&i instanceof HTMLInputElement&&d instanceof HTMLDivElement&&v instanceof HTMLVideoElement&&a instanceof HTMLAudioElement&&v instanceof HTMLMediaElement&&a instanceof HTMLMediaElement&&u instanceof HTMLUnknownElement&&Object.getPrototypeOf(HTMLVideoElement)===HTMLMediaElement&&Object.getPrototypeOf(HTMLMediaElement)===HTMLElement&&Object.getPrototypeOf(HTMLButtonElement)===HTMLElement&&Object.getPrototypeOf(b)===HTMLButtonElement.prototype&&b.constructor===HTMLButtonElement&&Object.prototype.toString.call(i)==="[object HTMLInputElement]"&&document.getElementById("x").constructor===HTMLElement&&document.getElementById("s").constructor===HTMLElement')!.as_bool()
	assert html_interface_eval(mut vm, 'document.createElement("td") instanceof HTMLTableCellElement&&document.createElement("h2") instanceof HTMLHeadingElement&&document.createElement("blockquote") instanceof HTMLQuoteElement&&document.createElement("template") instanceof HTMLTemplateElement&&!(new Document().createElement("button") instanceof HTMLButtonElement)')!.as_bool()
}

fn test_customized_builtin_html_constructor_upgrades_native_button_and_checks_interface() {
	mut document := html.parse_document('<body><button is="x-button" id="b"></button></body>')
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert html_interface_eval(mut vm, 'var existing=document.getElementById("b"),calls=0;class Button extends HTMLButtonElement{value=42;connectedCallback(){calls++}};customElements.define("x-button",Button,{extends:"button"});var fresh=new Button();existing===document.getElementById("b")&&existing instanceof Button&&existing instanceof HTMLButtonElement&&existing.value===42&&fresh instanceof Button&&fresh.tagName==="BUTTON"&&fresh.ownerDocument===document&&fresh.value===42&&calls===1')!.as_bool()
	native := document.get_element_by_id('b')?
	assert native.custom_element_state_ == .custom && native.custom_element_definition()?.local_name() == 'button'
	assert html_interface_eval(mut vm, 'class Wrong extends HTMLInputElement{};customElements.define("x-wrong",Wrong,{extends:"button"});var rejected=0;for(var action of [()=>new Wrong(),()=>new HTMLButtonElement(),()=>new HTMLMediaElement(),()=>HTMLInputElement(),()=>new HTMLUnknownElement()])try{action()}catch(e){if(e instanceof TypeError)rejected++}rejected===5')!.as_bool()
}
