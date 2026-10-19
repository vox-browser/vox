module main

import browserjs
import dom
import html

fn test_compact_native_query_preserves_created_host_identity_without_map_snapshots() {
	mut document := html.parse_document('<!doctype html><div id="parent"></div>')
	defer { document.finalize() }
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [], runtime, mut messages)
	runtime.evaluate_host(r'
const parent=document.getElementById("parent");
const image=new Image(); image.id="created-image"; image.width=17; parent.appendChild(image);
const canvas=document.createElement("canvas"); canvas.id="created-canvas";
canvas.getContext("2d").fillRect(0,0,1,1); parent.appendChild(canvas);
const video=document.createElement("video");video.id="created-video";void video.paused;parent.appendChild(video);
if(document.querySelector("#created-image")!==image)throw new Error("image identity");
if(document.querySelector("#created-canvas")!==canvas)throw new Error("canvas identity");
if(document.querySelector("#created-video")!==video)throw new Error("media identity");
parent.innerHTML="<span id=from-native>native</span>";
const native=document.getElementById("from-native");
if(native!==parent.firstElementChild)throw new Error("native identity");
native.textContent="updated";document.querySelector("#from-native");0')!
	assert messages == []string{}
	assert document.get_element_by_id('from-native')?.as_node().text_content()? == 'updated'
}
