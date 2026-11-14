module main

import browserjs
import dom
import html
import page
import time

fn test_enter_on_a_late_parser_control_keeps_its_element_wrapper_and_navigation() {
	$if !darwin && !linux {
		return
	}
	owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><body><div id="mount"></div>',
		dom.URL{ value: 'https://search.example/' }, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://search.example/', [r'
globalThis.searchTarget=null;globalThis.searchChecks=[];
document.addEventListener("keydown",function(event){
 const target=event.target;searchTarget=target;
 searchChecks.push(target instanceof HTMLTextAreaElement,
  target===document.getElementById("query"),target.closest("form").id==="search",
  event.key==="Enter",event.keyCode===13,event.isTrusted);
 event.preventDefault();location.assign("/search?q="+encodeURIComponent(target.value));
});
'], runtime, mut messages)
	// A head script has already started the realm when the parser adds the
	// form. No selector has materialized either of these native elements yet.
	mut form := document.create_element('form')!
	form.set_attribute_value('id', 'search')
	mut query := document.create_element('textarea')!
	query.set_attribute_value('id', 'query')
	query.set_attribute_value('name', 'q')
	form.append_child(query)
	mut mount := document.get_element_by_id('mount')?
	mount.append_child(form)
	mut model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(query) })
	model.set_value('utc time')
	event := dom.KeyboardEvent.create_from_platform_event('keydown', .return_, 0, 0, false)
	assert !dom.event_target_dispatch_event(unsafe { &dom.EventTarget(query) }, unsafe { &dom.Event(event) })
	assert runtime.evaluate_host('searchChecks.length===6&&searchChecks.every(Boolean)')! == 'true'
	assert runtime.evaluate_host('searchTarget===document.querySelector("[name=q]")&&searchTarget.value==="utc time"')! == 'true'
	commit := commit_compact_dom_task(document, runtime, mut messages)!
	assert commit.navigation? == '/search?q=utc%20time'
	assert messages == []string{}
}
