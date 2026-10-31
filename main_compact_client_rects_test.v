module main

import browserjs
import html
import layout

fn test_compact_client_rects_use_native_layout_and_snapshot_mutable_rectangles() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#box{position:absolute;left:12px;top:14px;width:40px;height:20px}#hidden{display:none}</style><div id="box"></div><div id="hidden"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	layout.install_document_layout_hook(document)
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const rects=box.getClientRects();
if(!(rects instanceof DOMRectList)||rects.length!==1||rects.item(0)!==rects[0]||!(rects[0] instanceof DOMRect)||!(rects[0] instanceof DOMRectReadOnly))throw new Error("native rect types");
if(rects[0].x!==12||rects[0].y!==14||rects[0].width!==40||rects[0].height!==20)throw new Error("native box geometry "+JSON.stringify(rects[0]));
if(rects.item(2)!==null||rects[2]!==undefined||Array.from(rects).length!==1||hidden.getClientRects().length!==0)throw new Error("rect list membership");
rects[0].x=900;if(rects[0].left!==900||box.getClientRects()[0].x!==12)throw new Error("independent mutable snapshot");
box.style.width="70px";if(rects[0].width!==40||box.getClientRects()[0].width!==70)throw new Error("live layout and saved snapshot");
'], runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_client_rects_detached_elements_and_native_receiver_checks() {
	mut document := html.parse_document('<!doctype html><div id="box" style="width:20px;height:10px"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const detached=document.createElement("div");if(detached.getClientRects().length!==0)throw new Error("detached geometry");
let branded=0;for(const call of [()=>Element.prototype.getClientRects.call({}),()=>DOMRectList.prototype.item.call({},0),()=>Object.getOwnPropertyDescriptor(DOMRectList.prototype,"length").get.call({})])try{call()}catch(error){if(error instanceof TypeError)branded++}if(branded!==3)throw new Error("rect brands");
const rects=box.getClientRects();const first=rects[0];try{rects[0]=new DOMRect()}catch(error){}if(rects[0]!==first)throw new Error("readonly list index");
const RealRect=DOMRect;globalThis.DOMRect=function(){throw new Error("author constructor")};if(!(box.getClientRects()[0] instanceof RealRect))throw new Error("intrinsic rectangle constructor");
'], runtime, mut messages)
	assert messages == []string{}
}
