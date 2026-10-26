module main

import browserjs
import html

fn test_compact_title_inserted_in_head_survives_queries_and_finalization() {
	mut document := html.parse_document('<!doctype html><body><p id="host">before</p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
document.head.insertAdjacentHTML("beforeend",`<meta name="maps-test" content="ready"><title>  Map of&nbsp;Saint Petersburg &amp; Yandex Maps\n </title><style>#host{color:green}</style>`);
const title=document.querySelector("title");
if(document.title!=="Map of\u00a0Saint Petersburg & Yandex Maps")throw new Error("inserted title");
host.textContent="after";
if(document.querySelector("meta").getAttribute("content")!=="ready"||title.textContent.indexOf("Yandex Maps")<0)throw new Error("query replay erased title");
title.textContent="Карты Санкт-Петербурга";
if(document.title!=="Карты Санкт-Петербурга")throw new Error("live title text");
globalThis.insertedTitlePassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('insertedTitlePassed')! == 'true'
	assert document.title() == 'Карты Санкт-Петербурга'
	assert document.get_element_by_id('host')?.as_node().text_content()? == 'after'
	// A legacy cached title must not overwrite a newer native mutation.
	snapshot := runtime.evaluate_host('JSON.stringify({...JSON.parse(__ladybirdFinalize()),title:document.title})')!
	document.set_title('native update')!
	apply_javascript_state(document, snapshot, runtime.canvas_elements_for_binding(), mut messages)
	assert document.title() == 'native update'
	assert runtime.evaluate_host('document.title')! == 'native update'
}

fn test_compact_title_setter_creates_native_title_and_notifies_document_state() {
	mut document := html.parse_document('<!doctype html><body><p id="host">before</p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', []string{}, runtime, mut messages)
	assert messages == []string{}
	runtime.take_document_state_dirty()
	runtime.evaluate_host(r'
if(Object.prototype.hasOwnProperty.call(document,"title"))throw new Error("shadowed Document accessor");
let conversions=0;
document.title={toString(){conversions++;return " \tCreated\n title\u00a0 ";}};
const title=document.head.querySelector("title");
if(conversions!==1||!title||title.textContent!==" \tCreated\n title\u00a0 "||document.title!=="Created title\u00a0")throw new Error("native title setter");
title.textContent="pending text";
document.head.innerHTML;
document.title="replaced";
if(document.head.querySelector("title")!==title||title.textContent!=="replaced"||document.head.innerHTML.indexOf("pending text")!==-1)throw new Error("title identity and content invalidation");
let rejected=false;try{document.title=Symbol();}catch(error){rejected=error instanceof TypeError;}
if(!rejected||document.title!=="replaced")throw new Error("title conversion error");
')!
	assert document.title() == 'replaced'
	assert runtime.has_pending_document_state()
}

fn test_compact_title_tracks_tree_order_and_character_data_without_snapshot_overwrites() {
	mut document := html.parse_document('<!doctype html><head><title id="first">first</title><title id="second">second</title></head><body><p id="host">before</p>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
first.firstChild.nodeValue="  edited\n first  ";
if(document.title!=="edited first")throw new Error("character data title");
first.remove();
if(document.title!=="second")throw new Error("first title removed");
second.innerHTML="third &amp; fourth";
if(document.title!=="third & fourth")throw new Error("title markup");
const detached=document.implementation.createHTMLDocument("detached");
detached.title="separate";
host.textContent="updated";
if(document.title!=="third & fourth"||detached.title!=="separate")throw new Error("document isolation");
globalThis.titleOrderPassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('titleOrderPassed')! == 'true'
	assert document.title() == 'third & fourth'
	assert document.get_element_by_id('host')?.as_node().text_content()? == 'updated'
}
