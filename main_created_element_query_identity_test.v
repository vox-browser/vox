module main

import browserjs
import dom
import page
import time

fn created_query_identity_document() !&dom.Document {
	owner := page.Page.create(1)!
	return parse_browser_navigation_document_for_page_with_response_time('<!doctype html><div id="parent"></div>',
		dom.URL{value: 'https://created-query.example/'}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
}

fn test_native_queries_reuse_created_media_track_and_element_wrappers_after_dom_replay() {
	$if !darwin { return }
	mut document := created_query_identity_document()!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.createdQueryOwners=[];globalThis.createdQueryEvents=[];
const parent=document.getElementById("parent");
for(const [i,name] of ["audio","video","track","q:track","button"].entries()){
 const node=name.includes(":")?document.createElementNS("http://www.w3.org/1999/xhtml",name):document.createElement(name);
 node.id="created-query-"+i;
 node.addEventListener(i===4?"wheel":"identity",function(event){createdQueryEvents.push(this===node&&event.target===node&&event.currentTarget===node);});
 parent.appendChild(node);createdQueryOwners.push(node);
}
'], runtime, mut messages)
	assert messages == []
	for i in 0 .. 5 { assert document.get_element_by_id('created-query-${i}') != none }
	assert runtime.evaluate_host(r'createdQueryOwners.every((node,i)=>{
 const byId=document.getElementById(node.id),bySelector=document.querySelector("#"+node.id);
 const parent=document.getElementById("parent");
 if(byId!==node||bySelector!==node||parent.querySelector("#"+node.id)!==node||parent.querySelectorAll("[id]")[i]!==node||node.closest("[id]")!==node)throw new Error("created query identity "+i);
 if(i===2||i===3){if(!(byId instanceof HTMLTrackElement)||byId.track!==node.track)throw new Error("created track brand "+i);}
 byId.dispatchEvent(i===4?new WheelEvent("wheel"):new Event("identity"));return true;
})&&(()=>{if(createdQueryEvents.length!==5||!createdQueryEvents.every(Boolean))throw new Error("created event results "+JSON.stringify(createdQueryEvents));return true;})()')! == 'true'
	assert runtime.evaluate_host(r'createdQueryOwners.every(node=>document.getElementById(node.id)===node)')! == 'true'
}

fn test_native_queries_still_discover_unwrapped_dom_nodes_and_retain_their_event_target_identity() {
	$if !darwin { return }
	mut document := created_query_identity_document()!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), ['globalThis.nativeQueryParent=document.getElementById("parent");'], runtime, mut messages)
	assert messages == []
	mut parent := document.get_element_by_id('parent')?
	parent.set_inner_html('<track id="native-query-track"><button id="native-query-button"></button>')!
	assert runtime.evaluate_host(r'(()=>{
 const track=document.getElementById("native-query-track"),button=document.querySelector("#native-query-button");
 if(!(track instanceof HTMLTrackElement)||!(button instanceof Element))throw new Error("native query brands "+(track instanceof HTMLTrackElement)+","+(button instanceof Element));
 let calls=0;for(const node of [track,button])node.addEventListener(node===button?"wheel":"identity",function(event){if(this!==node||event.target!==node||event.currentTarget!==node)throw "native query identity";calls++;});
 for(const node of [track,button]){
  if(document.getElementById(node.id)!==node||nativeQueryParent.querySelector("#"+node.id)!==node)throw new Error("native query identity "+node.id);
  node.dispatchEvent(node===button?new WheelEvent("wheel"):new Event("identity"));
 }
 if(calls!==2)throw new Error("native event count "+calls);return true;
})()')! == 'true'
}
