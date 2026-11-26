// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import httpcookie
import libjs
import url as liburl

@[heap]
struct DocumentCookieProbe {
mut:
	cookie string = 'theme=dark'
	requests int
	sets int
}

fn document_state_fixture() !(&Host, &libjs.VM, &dom.Document) {
	address := dom.URL{value:'https://document-state.test/start'}
	mut document := html.parse_navigation_document('<head><title>Initial</title></head><body><input id="field"></body>', address, address.origin(), none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm, document
}

fn document_state_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-document-state.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions:100000}) or { return error(exception_message(err)) }
}

fn test_document_state_reads_native_visibility_focus_title_and_owning_window() {
	mut host, mut vm, mut document := document_state_fixture()!
	defer { host.close() }
	assert document_state_eval(mut vm, 'document.title==="Initial"&&document.documentURI===document.URL&&document.contentType==="text/html"&&document.characterSet===document.charset&&document.charset===document.inputEncoding&&document.activeElement===document.body&&document.defaultView===window&&document.location===location')!.as_bool()
	document.set_initial_visibility_state(.hidden)
	assert document_state_eval(mut vm, 'document.hidden&&document.visibilityState==="hidden"')!.as_bool()
	field := document.get_element_by_id('field')?
	document.set_active_element(field)
	assert document_state_eval(mut vm, 'document.activeElement===document.getElementById("field")')!.as_bool()
	document_state_eval(mut vm, 'document.title="Updated"')!
	assert document.title() == 'Updated'
	assert document_state_eval(mut vm, 'document.head.querySelector("title").textContent==="Updated"')!.as_bool()
}

fn test_document_cookie_access_reaches_native_page_client_boundary() {
	mut host, mut vm, mut document := document_state_fixture()!
	defer { host.close() }
	probe := &DocumentCookieProbe{}
	document.set_cookie_client_hook(dom.DocumentCookieClientHook{
		target: voidptr(probe)
		request_cookie: fn (target voidptr, record &liburl.URL, source httpcookie.Source) httpcookie.VersionedCookie {
			assert source == .non_http
			mut state := unsafe { &DocumentCookieProbe(target) }; state.requests++
			return httpcookie.VersionedCookie{cookie:state.cookie}
		}
		set_cookie: fn (target voidptr, record &liburl.URL, parsed httpcookie.ParsedCookie, source httpcookie.Source) {
			assert source == .non_http
			mut state := unsafe { &DocumentCookieProbe(target) }; state.sets++; state.cookie = parsed.name + '=' + parsed.value
		}
	})
	assert document_state_eval(mut vm, 'document.cookie==="theme=dark"')!.as_bool()
	assert probe.requests == 1
	document_state_eval(mut vm, 'document.cookie="theme=light; Path=/"')!
	assert probe.sets == 1 && probe.cookie == 'theme=light'
	assert document_state_eval(mut vm, 'document.cookie==="theme=light"')!.as_bool()
}

fn test_document_state_brand_checks_and_detached_document_default_view() {
	mut host, mut vm, _ := document_state_fixture()!
	defer { host.close() }
	assert document_state_eval(mut vm, 'var foreign=new Document(),n=0;for(var name of ["title","cookie","visibilityState","activeElement","defaultView"])try{Object.getOwnPropertyDescriptor(Document.prototype,name).get.call({})}catch(e){if(e instanceof TypeError)n++}foreign.defaultView===null&&foreign.location===null&&foreign.cookie===""&&n===5')!.as_bool()
}

fn test_document_domain_reads_the_native_effective_origin() {
	mut host, mut vm, mut document := document_state_fixture()!
	defer { host.close() }
	assert document_state_eval(mut vm, 'document.domain==="document-state.test"&&new Document().domain===""')!.as_bool()
	document.set_origin(dom.URL{value:'https://other.example:8443/path'}.origin())
	assert document_state_eval(mut vm, 'document.domain==="other.example"')!.as_bool()
	document.set_origin(dom.URL{value:'data:text/plain,opaque'}.origin())
	assert document_state_eval(mut vm, 'document.domain===""')!.as_bool()
}

fn test_document_domain_setter_uses_native_security_checks() {
	mut host, mut vm, mut document := document_state_fixture()!
	defer { host.close() }
	assert document_state_eval(mut vm, 'var denied=false;try{document.domain="document-state.test"}catch(e){denied=e instanceof DOMException&&e.name==="SecurityError"}denied')!.as_bool()
	document.set_browsing_context(&dom.BrowsingContext{active_document_:document})
	assert document_state_eval(mut vm, 'document.domain="document-state.test";var denied=false;try{document.domain="unrelated.example"}catch(e){denied=e instanceof DOMException&&e.name==="SecurityError"}denied&&document.domain==="document-state.test"')!.as_bool()
	document.set_active_sandboxing_flag_set(dom.SandboxingFlagSet{sandboxed_document_domain:true})
	assert document_state_eval(mut vm, 'var denied=false;try{document.domain="document-state.test"}catch(e){denied=e.name==="SecurityError"}denied')!.as_bool()
}

fn test_document_domain_checks_receiver_before_converting_setter_argument() {
	mut host, mut vm, _ := document_state_fixture()!
	defer { host.close() }
	assert document_state_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(Document.prototype,"domain"),n=0,converted=0,arg={toString(){converted++;return "document-state.test"}};try{d.get.call({})}catch(e){if(e instanceof TypeError)n++}try{d.set.call({},arg)}catch(e){if(e instanceof TypeError)n++}var sentinel={};try{d.set.call(document,{toString(){throw sentinel}})}catch(e){if(e===sentinel)n++}n===3&&converted===0&&d.enumerable&&d.configurable')!.as_bool()
}
