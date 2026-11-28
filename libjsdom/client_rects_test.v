// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs

fn client_rect_binding_fixture() !(&Host, &libjs.VM) {
	mut document := html.parse_document('<body><div id="box"></div></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn client_rect_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-client-rect.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_native_mutable_rect_inheritance_factory_order_and_readonly_getter_brand() {
	mut host, mut vm := client_rect_binding_fixture()!
	defer { host.close() }
	assert client_rect_binding_eval(mut vm, 'class R extends DOMRect{}var r=new R(10,20,-4,-8);r.x=12;r.height=3;var j=r.toJSON();r instanceof R&&r instanceof DOMRect&&r instanceof DOMRectReadOnly&&r.left===8&&r.right===12&&r.top===20&&r.bottom===23&&j.x===12&&Object.getPrototypeOf(DOMRect)===DOMRectReadOnly&&Object.prototype.toString.call(r)==="[object DOMRect]"')!.as_bool()
	assert client_rect_binding_eval(mut vm, 'var order="",r=DOMRect.fromRect({get height(){order+="h";return 2},get width(){order+="w";return 3},get x(){order+="x";return 4},get y(){order+="y";return 5}});order==="hwxy"&&r instanceof DOMRect&&r.right===7&&r.bottom===7')!.as_bool()
	assert client_rect_binding_eval(mut vm, 'var count=0;for(var run of [()=>DOMRect(),()=>DOMRect.fromRect(1),()=>Object.getOwnPropertyDescriptor(DOMRect.prototype,"x").get.call(new DOMRectReadOnly()),()=>Object.getOwnPropertyDescriptor(DOMRect.prototype,"width").set.call({},1)])try{run()}catch(e){if(e instanceof TypeError)count++}count===4')!.as_bool()
}

fn test_client_geometry_returns_independent_native_rect_snapshots_and_indexed_lists() {
	mut host, mut vm := client_rect_binding_fixture()!
	defer { host.close() }
	box := host.document.get_element_by_id('box')?
	mut node := box.as_node()
	mut layout := &dom.LayoutNode{ dom_node_: node, has_geometry_: true, border_box_: dom.Rect{ x: 12, y: 23, width: 40, height: 50 } }
	node.set_layout_node(layout)
	assert client_rect_binding_eval(mut vm, 'var box=document.getElementById("box"),a=box.getBoundingClientRect(),list=box.getClientRects();a instanceof DOMRect&&a.x===12&&a.y===23&&a.width===40&&a.height===50&&list instanceof DOMRectList&&list.length===1&&list[0]===list.item(0)&&list[0]!==a&&list.item(1)===null&&list[1]===undefined&&Array.from(list)[0]===list[0]')!.as_bool()
	layout.border_box_.width = 70
	assert client_rect_binding_eval(mut vm, 'list[0].x=900;a.width=1;list[0].left===900&&box.getBoundingClientRect().x===12&&box.getBoundingClientRect().width===70&&box.getClientRects()[0].x===12&&list[0].width===40')!.as_bool()
	assert client_rect_binding_eval(mut vm, 'var e=document.createElement("div"),r=e.getBoundingClientRect();r.width===0&&r.height===0&&e.getClientRects().length===0&&Object.keys(list).join()==="0"')!.as_bool()
}
