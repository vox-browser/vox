module main

import browserjs
import css
import dom
import html
import loader

fn media_query_binding_fixture() !(&browserjs.Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://media-query.example/' }
	mut document := html.parse_navigation_document('<!doctype html><body></body>', address, address.origin(), none)!
	document.set_viewport_rect(dom.Rect{ width: 1024, height: 768 })
	mut runtime := browserjs.Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_window_media_query_binding()!
	return runtime, document
}

fn test_window_match_media_uses_native_queries_and_branded_interfaces() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := media_query_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
globalThis.query=matchMedia("(min-width:800px) and (orientation:landscape)");
const descriptor=Object.getOwnPropertyDescriptor(globalThis,"matchMedia"),getter=Object.getOwnPropertyDescriptor(MediaQueryList.prototype,"matches").get;
let invalid=0;for(const callback of [()=>matchMedia(),()=>matchMedia(Symbol()),()=>matchMedia.call({},"all"),()=>getter.call({}),()=>getter.call(new Proxy(query,{})),()=>new MediaQueryList(),()=>MediaQueryList.prototype.addListener.call(new EventTarget(),null)]){try{callback()}catch(error){if(error instanceof TypeError)invalid++}}
const conversions=[];const converted=matchMedia({toString(){conversions.push("query");return "screen"}});
const checked=query instanceof MediaQueryList&&query instanceof EventTarget&&Object.prototype.toString.call(query)==="[object MediaQueryList]"&&query.matches&&query.media==="(min-width: 800px) and (orientation: landscape)"&&query!==matchMedia(query.media)&&converted.matches&&conversions.join(",")==="query";
checked&&invalid===7&&matchMedia.length===1&&matchMedia.name==="matchMedia"&&descriptor.enumerable&&descriptor.writable&&descriptor.configurable&&!matchMedia("(display-mode: standalone)").matches&&matchMedia("(display-mode: browser)").matches&&matchMedia("").matches&&!matchMedia("invalid (").matches;
')! == 'true'
	native := runtime.native_event_target(runtime.evaluate_host_value('query')!)!
	assert document.media_query_lists.any(voidptr(it.target) == voidptr(native))
	assert voidptr(unsafe { &css.MediaQueryList(native) }.document_) == voidptr(document)
	runtime.evaluate_host('matchMedia=17')!
	runtime.install_window_media_query_binding()!
	assert runtime.evaluate_host('matchMedia===17')! == 'true'
}

fn test_media_queries_report_native_viewport_changes_to_modern_and_legacy_listeners() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := media_query_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
globalThis.query=matchMedia("(min-width: 800px)");globalThis.changes=[];
globalThis.legacy=function(event){changes.push("legacy:"+event.matches+":"+(this===query&&event.target===query&&event.currentTarget===query&&event instanceof MediaQueryListEvent&&event instanceof Event&&event.isTrusted&&event.media===query.media&&!event.bubbles&&!event.cancelable));};
query.addListener(legacy);query.addListener(legacy);query.addEventListener("change",legacy);
globalThis.handler=function(event){changes.push("handler:"+event.matches)};query.onchange=handler;
query.addEventListener("change",event=>changes.push("once:"+event.matches),{once:true});
query.addListener(null);query.removeListener(null);query.onchange===handler;
')! == 'true'
	document.evaluate_media_queries_and_report_changes()
	assert runtime.evaluate_host('changes.length')! == '0'
	document.set_viewport_rect(dom.Rect{ width: 640, height: 768 })
	document.evaluate_media_queries_and_report_changes()
	assert runtime.evaluate_host('!query.matches&&changes.join(",")==="legacy:false:true,handler:false,once:false"')! == 'true'
	runtime.evaluate_host('query.removeListener(legacy);query.onchange=null;query.addEventListener("change",legacy);changes.length=0')!
	document.set_viewport_rect(dom.Rect{ width: 1200, height: 768 })
	document.evaluate_media_queries_and_report_changes()
	assert runtime.evaluate_host('query.matches&&query.onchange===null&&changes.join(",")==="legacy:true:true"')! == 'true'
	// Removing via the modern API also removes a legacy registration.
	runtime.evaluate_host('query.removeEventListener("change",legacy);changes.length=0')!
	document.set_viewport_rect(dom.Rect{ width: 640, height: 768 })
	document.evaluate_media_queries_and_report_changes()
	assert runtime.evaluate_host('changes.length')! == '0'
}

fn test_media_query_list_events_preserve_native_payload_and_constructor_semantics() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := media_query_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
class Derived extends MediaQueryListEvent{};
const event=new Derived("change",{media:{toString(){return "screen"}},matches:1,bubbles:true,cancelable:true,composed:true}),empty=new MediaQueryListEvent("change");
const getter=Object.getOwnPropertyDescriptor(MediaQueryListEvent.prototype,"media").get;
let invalid=0;for(const callback of [()=>MediaQueryListEvent("change"),()=>new MediaQueryListEvent(),()=>new MediaQueryListEvent(Symbol()),()=>new MediaQueryListEvent("change",{media:Symbol()}),()=>new MediaQueryListEvent("change",1),()=>getter.call(new Event("change")),()=>getter.call(new Proxy(event,{}))]){try{callback()}catch(error){if(error instanceof TypeError)invalid++}}
globalThis.query=matchMedia("all");let seen=false;query.addListener(function(value){seen=value===event&&value.target===query&&this===query});query.dispatchEvent(event);
seen&&invalid===7&&event instanceof Derived&&event instanceof MediaQueryListEvent&&event instanceof Event&&event.media==="screen"&&event.matches&&event.bubbles&&event.cancelable&&event.composed&&!event.isTrusted&&Object.prototype.toString.call(event)==="[object MediaQueryListEvent]"&&empty.media===""&&!empty.matches&&getter.name==="get media"&&getter.length===0&&MediaQueryListEvent.length===1;
')! == 'true'
}

fn test_compact_page_exposes_match_media_before_deferred_application_startup() {
	$if !darwin && !linux {
		return
	}
	mut document := html.parse_document_with_url('<!doctype html><div id="result">pending</div><script defer src="app.js"></script><script>globalThis.appConfig={standalone:!!navigator.standalone||window.matchMedia("(display-mode: standalone)").matches};</script>', dom.URL{ value: 'https://media-query.example/maps/' })
	document.set_viewport_rect(dom.Rect{ width: 1024, height: 768 })
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	sources := script_sources(document, document.url.serialize(), {
		'https://media-query.example/maps/app.js': PreloadedResource{ body: 'Promise.resolve().then(()=>{if(appConfig.standalone)throw new Error("wrong display mode");const responsive=matchMedia("(min-width: 800px)");result.textContent=responsive.matches&&responsive instanceof MediaQueryList?"started":"wrong viewport";});' }
	}, mut messages)
	run_document_script_sources(document, document.url.serialize(), sources, runtime, mut messages)
	assert messages == []string{}
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'started'
}
