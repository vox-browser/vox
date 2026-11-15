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
