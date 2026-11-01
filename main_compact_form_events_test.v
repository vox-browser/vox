module main

import browserjs
import dom
import html
import page
import time

fn test_compact_form_event_listeners_receive_native_capture_cancellation_and_once() {
	mut document := html.parse_document('<!doctype html><form id="form"><input id="field"></form>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
globalThis.order=[];globalThis.valid=true;
for(const name of ["submit","reset","formdata","invalid","beforeinput"]){
 const target=name==="invalid"||name==="beforeinput"?field:form;
 document.addEventListener(name,event=>{order.push(name+":document");valid=valid&&event.isTrusted&&event.currentTarget===document&&event.target===target&&event.composedPath()[0]===target},true);
 target.addEventListener(name,function(event){order.push(name+":target");valid=valid&&this===target&&event.currentTarget===target&&event instanceof Event;event.preventDefault()},{once:true});
 function removed(){throw new Error("removed "+name)}
 target.addEventListener(name,removed);target.removeEventListener(name,removed);
 function removedDocument(){throw new Error("removed document "+name)}
 document.addEventListener(name,removedDocument,true);document.removeEventListener(name,removedDocument,true);
}
'], runtime, mut messages)
	for name in ['submit', 'reset', 'formdata', 'invalid', 'beforeinput'] {
		target := document.get_element_by_id(if name in ['invalid', 'beforeinput'] { 'field' } else { 'form' }) or { panic(name) }
		for attempt in 0 .. 2 {
			mut event := dom.Event.create(name, dom.EventInit{bubbles: name != 'invalid', cancelable: true})
			event.set_is_trusted(true)
			dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, event)
			assert event.default_prevented() == (attempt == 0)
		}
	}
	assert runtime.evaluate_host('valid&&order.join("|")===["submit","reset","formdata","invalid","beforeinput"].flatMap(name=>[name+":document",name+":target",name+":document"]).join("|")')! == 'true'
	assert messages == []string{}
}

fn test_form_listener_cancels_the_native_button_submission() {
 mut owner := page.Page.create(1)!
 mut document := parse_browser_navigation_document_for_page_with_response_time(
  '<!doctype html><form id="form"><button id="button"><span id="label">Send</span></button></form>',
  dom.URL{value: 'https://form-events.test/'}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
 owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close(); document.finalize() }
 mut messages := []string{}
 run_document_javascript(document, 'https://form-events.test/', [r'
 globalThis.submissions=0;globalThis.valid=false;
 form.addEventListener("submit",function(event){submissions++;valid=event.isTrusted&&event.target===form&&this===form;event.preventDefault()});
 '], runtime, mut messages)
 label := document.get_element_by_id('label') or { panic('label') }
 event := dom.MouseEvent.create('click', dom.MouseEventInit{bubbles: true, cancelable: true})
 dom.event_target_dispatch_event(unsafe { &dom.EventTarget(label) }, unsafe { &dom.Event(event) })
 assert runtime.evaluate_host('submissions===1&&valid')! == 'true'
 assert messages == []string{}
}
