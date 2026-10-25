module main

import browserjs
import dom
import html
import layout

fn test_document_hit_stack_deduplicates_non_adjacent_native_element_identities() {
	mut document := html.parse_document('<!doctype html><body></body>')
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{ width: 320, height: 240 })
	first := document.create_element('span')!
	second := document.create_element('span')!
	hits := [first, second, first, second]
	document.set_viewport_paintable(&dom.ViewportPaintable{
		target:                document
		hit_test_all_callback: fn [hits] (_ voidptr, _ f64, _ f64) []&dom.Element {
			return hits
		}
	})
	stack := document.elements_from_point(20, 20)
	assert stack.len == 3
	assert voidptr(stack[0]) == voidptr(first)
	assert voidptr(stack[1]) == voidptr(second)
	root := document.document_element() or { panic('missing root') }
	assert voidptr(stack[2]) == voidptr(root)
}

fn test_compact_document_hit_testing_tracks_paint_order_and_live_native_elements() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><style>
html,body{margin:0}#base{position:absolute;left:20px;top:20px;width:100px;height:100px;background:blue}
#top,#glass{position:absolute;left:40px;top:40px;width:50px;height:50px;background:red}
#top{z-index:2}#glass{z-index:3;pointer-events:none}
#editor{position:absolute;left:20px;top:180px;width:100px;height:24px}
</style><div id="base"></div><div id="top"></div><div id="glass"></div><input id="editor">')
	document.set_viewport_rect(dom.Rect{ width: 320, height: 240 })
	_ = layout.run_document_layout(document, 320, 240) or { panic('missing initial layout') }
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const nativeTop=document.getElementById("top"),nativeBase=document.getElementById("base");
if(document.elementFromPoint(60,60)!==nativeTop)throw new Error("paint order or identity");
const stack=document.elementsFromPoint(60,60);
if(!Array.isArray(stack)||stack[0]!==nativeTop||stack.indexOf(nativeBase)<1||stack.includes(glass)||stack[stack.length-1]!==document.documentElement||new Set(stack).size!==stack.length)throw new Error("hit stack");
if(document.elementFromPoint(30,190)!==editor)throw new Error("control shadow retarget");
const made=document.createElement("div");made.id="made";Object.assign(made.style,{position:"absolute",left:"50px",top:"50px",width:"20px",height:"20px",zIndex:"7",background:"green"});document.body.appendChild(made);
if(document.elementFromPoint(60,60)!==made||document.elementsFromPoint(60,60)[0]!==made)throw new Error("pending insertion");
made.style.pointerEvents="none";
if(document.elementFromPoint(60,60)!==nativeTop)throw new Error("pending pointer events");
nativeTop.style.transform="translateX(120px)";
if(document.elementFromPoint(180,60)!==nativeTop||document.elementFromPoint(60,60)!==nativeBase)throw new Error("pending transform");
for(const point of [[-1,20],[20,-1],[321,20],[20,241]]){
 if(document.elementFromPoint(...point)!==null||document.elementsFromPoint(...point).length!==0)throw new Error("viewport bounds");
}
console.log("hit testing passed");
'], runtime, mut messages)
	assert messages == ['hit testing passed']
	made := document.get_element_by_id('made') or { panic('missing native insertion') }
	wrapper := runtime.evaluate_host_value('document.getElementById("made")')!
	actual := runtime.native_event_target(wrapper)!
	assert voidptr(actual) == voidptr(made)
}

fn test_compact_document_hit_testing_uses_webidl_receiver_and_double_conversions() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><body></body>')
	document.set_viewport_rect(dom.Rect{ width: 320, height: 240 })
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
for(const name of ["elementFromPoint","elementsFromPoint"]){
 const descriptor=Object.getOwnPropertyDescriptor(document,name),method=descriptor.value;
 if(!descriptor.writable||!descriptor.enumerable||!descriptor.configurable||method.name!==name||method.length!==2)throw new Error("method descriptor");
 const expectTypeError=callback=>{let threw=false;try{callback()}catch(error){threw=error instanceof TypeError}if(!threw)throw new Error("expected TypeError");};
 let conversions=0,traps=0;
 const number={valueOf(){conversions++;return 0;}},proxy=new Proxy(document,{get(){traps++;throw new Error("proxy get")},getPrototypeOf(){traps++;throw new Error("proxy prototype")}});
 for(const receiver of [undefined,null,{},Object.create(document),proxy])expectTypeError(()=>method.call(receiver,number,number));
 if(conversions||traps)throw new Error("brand must precede conversion");
 expectTypeError(()=>method.call(document,number));
 if(conversions)throw new Error("arity must precede conversion");
 for(const bad of [NaN,Infinity,-Infinity,undefined,1n,Symbol()]){
  expectTypeError(()=>method.call(document,bad,0));expectTypeError(()=>method.call(document,0,bad));
 }
 expectTypeError(()=>new method(0,0));
 const order=[];
 const result=method.call(document,{valueOf(){order.push("x");return "0";}},{valueOf(){order.push("y");return null;}});
 if(order.join("")!=="xy")throw new Error("coordinate conversion order");
 if(name==="elementFromPoint"?result!==document.documentElement:result[result.length-1]!==document.documentElement)throw new Error("numeric conversion");
 conversions=0;expectTypeError(()=>method.call(document,NaN,number));
 if(conversions)throw new Error("nonfinite x must precede y");
 if(name==="elementsFromPoint"&&method.call(document,-1,0)===method.call(document,-1,0))throw new Error("sequence identity");
}
console.log("hit conversion passed");
'], runtime, mut messages)
	assert messages == ['hit conversion passed']
}
