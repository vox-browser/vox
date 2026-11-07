module main

import browserjs
import dom
import html
import page

fn native_document_window_event_fixture(markup string) !(&page.Page, &dom.Document, &browserjs.Runtime) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{value: 'https://document-window-events.example/'}, none, none, unsafe { &dom.Page(owner) }, 123456700000)
	return owner, document, browserjs.Runtime.create()
}

fn test_native_window_and_document_readiness_use_actual_event_records_and_source_target_override() {
	$if !darwin {
		return
	}
	_, mut document, mut runtime := native_document_window_event_fixture('<!doctype html><div id="result">initial</div>')!
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
 globalThis.readyEntries=[];
 document.addEventListener("DOMContentLoaded",function(event){readyEntries.push(event instanceof Event&&event.target===document&&event.currentTarget===document&&this===document&&event.bubbles&&event.isTrusted);result.textContent="document ready";});
 window.addEventListener("DOMContentLoaded",function(event){readyEntries.push(event.target===document&&event.currentTarget===window&&this===window&&event.eventPhase===Event.BUBBLING_PHASE);});
 window.addEventListener("load",function(event){readyEntries.push(event.target===document&&event.currentTarget===window&&this===window&&!event.bubbles&&event.isTrusted);});
 window.onload=function(event){readyEntries.push(this===window&&event.target===document&&event.currentTarget===window);result.textContent+=" window ready";};
'], runtime, mut messages)
	assert runtime.evaluate_host('readyEntries.length===4&&readyEntries.every(Boolean)')! == 'true'
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'document ready window ready'
	assert messages == []
}

fn test_native_window_source_body_raw_load_handler_reaches_actual_public_accessor() {
	$if !darwin {
		return
	}
	_, mut document, mut runtime := native_document_window_event_fixture('<!doctype html><body onload="result.textContent=typeof onload+\':\'+(this===window)+\':\'+(event.target===document)"><div id="result">initial</div>')!
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), ['globalThis.handlerBeforeLoad=window.onload;'], runtime, mut messages)
	assert runtime.evaluate_host('typeof handlerBeforeLoad==="function"&&handlerBeforeLoad===window.onload&&window.onload.name==="onload"')! == 'true'
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'function:true:true'
	assert messages == []
}

fn test_native_window_and_document_methods_use_source_listener_flags_and_same_event_identity() {
	$if !darwin {
		return
	}
	_, mut document, mut runtime := native_document_window_event_fixture('<!doctype html><div id="result">initial</div>')!
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
 globalThis.eventValues=[];const event=new Event("custom",{bubbles:true,cancelable:true});
 function removed(){eventValues.push("removed");}document.addEventListener("custom",removed);document.removeEventListener("custom",removed);
 document.addEventListener("custom",function(value){eventValues.push(value===event&&this===document&&value.currentTarget===document);value.preventDefault();},{once:true});
 window.addEventListener("custom",function(value){eventValues.push(value===event&&this===window&&value.target===document&&value.currentTarget===window);},{once:true});
 globalThis.eventCancelled=document.dispatchEvent(event)===false;
 document.dispatchEvent(new Event("custom",{bubbles:true}));
 globalThis.windowTargetCorrect=false;window.addEventListener("own",function(value){windowTargetCorrect=value.target===document&&value.currentTarget===window&&this===window});window.dispatchEvent(new Event("own"));
'], runtime, mut messages)
	assert runtime.evaluate_host('eventCancelled&&eventValues.length===2&&eventValues.every(Boolean)&&windowTargetCorrect')! == 'true'
	assert messages == []
}

fn test_native_window_listener_gate_rechecks_actual_owner_between_individual_callbacks() {
	$if !darwin {
		return
	}
	mut owner, mut document, mut runtime := native_document_window_event_fixture('<!doctype html><div id="result">initial</div>')!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.define_host_function('__disableActualPage', fn [owner] (_ string) !string {
		mut actual_owner := unsafe { &page.Page(owner) }
		actual_owner.set_is_scripting_enabled(false)
		return ''
	})!
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
 globalThis.nativeGateEntries=[];
 document.addEventListener("DOMContentLoaded",()=>{nativeGateEntries.push("first");__disableActualPage("")});
 document.addEventListener("DOMContentLoaded",()=>nativeGateEntries.push("second"));
 window.addEventListener("DOMContentLoaded",()=>nativeGateEntries.push("window"));
 window.onload=()=>nativeGateEntries.push("load");
'], runtime, mut messages)
	assert runtime.evaluate_host('nativeGateEntries.join(",")')! == 'first'
	assert messages == []
}

fn test_native_window_listener_error_keeps_original_value_in_actual_owner_report() {
	$if !darwin {
		return
	}
	_, mut document, mut runtime := native_document_window_event_fixture('<!doctype html><div id="result">initial</div>')!
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), ['globalThis.nativeWindowFailure={original:true};window.onload=function(){result.textContent="before failure";throw nativeWindowFailure};'], runtime, mut messages)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('nativeWindowFailure')!
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'before failure'
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}
