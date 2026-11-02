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

fn test_compact_bounding_rects_are_mutable_dom_rect_snapshots_with_json_serialization() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#box{position:absolute;left:12px;top:14px;width:40px;height:20px}#hidden{display:none}</style><div id="box"></div><div id="hidden"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	layout.install_document_layout_hook(document)
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const rect=box.getBoundingClientRect();
if(!(rect instanceof DOMRect)||!(rect instanceof DOMRectReadOnly))throw new Error("bounding rectangle type");
if(JSON.stringify(rect.toJSON())!==JSON.stringify({x:12,y:14,width:40,height:20,top:14,right:52,bottom:34,left:12}))throw new Error("bounding rectangle serialization");
rect.x=100;rect.width=-20;if(rect.left!==80||rect.right!==100||box.getBoundingClientRect().x!==12)throw new Error("mutable independent snapshot");
box.style.width="70px";if(rect.width!==-20||box.getBoundingClientRect().width!==70)throw new Error("live geometry and retained snapshot");
for(const element of [hidden,document.createElement("div")]){const empty=element.getBoundingClientRect();if(!(empty instanceof DOMRect)||Object.values(empty.toJSON()).some(value=>value!==0))throw new Error("empty bounding rectangle");}
'], runtime, mut messages)
	assert messages == []string{}
}

fn test_compact_bounding_rect_uses_the_intrinsic_constructor_after_author_replacement() {
	mut document := html.parse_document('<!doctype html><svg id="drawing" width="30" height="20"></svg><div id="box"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	layout.install_document_layout_hook(document)
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const RealRect=DOMRect;globalThis.DOMRect=function(){throw new Error("author rectangle constructor")};
if(!(drawing.getBoundingClientRect() instanceof RealRect)||!(box.getBoundingClientRect() instanceof RealRect))throw new Error("intrinsic bounding rectangle constructor");
let brands=0;for(const receiver of [{},Object.create(box),null])try{box.getBoundingClientRect.call(receiver)}catch(error){if(error instanceof TypeError)brands++}
if(brands!==3)throw new Error("bounding rectangle receiver checks");
'], runtime, mut messages)
	assert messages == []string{}
}
