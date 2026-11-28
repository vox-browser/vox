// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs

fn offsets_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-element-offsets.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_element_offsets_read_native_border_geometry_and_empty_detached_layout() {
	document := html.parse_document('<body><div id="box"></div></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	box := document.get_element_by_id('box')?
	mut node := box.as_node()
	node.set_layout_node(&dom.LayoutNode{ dom_node_: node, has_geometry_: true, border_box_: dom.Rect{ x: 2, y: 3, width: 10.4, height: 20.6 } })
	assert offsets_binding_eval(mut vm, 'var box=document.getElementById("box"),empty=document.createElement("div");box.offsetWidth===10&&box.offsetHeight===21&&empty.offsetWidth===0&&empty.offsetHeight===0&&empty.offsetParent===null&&empty.clientWidth===0&&empty.clientHeight===0')!.as_bool()
	assert offsets_binding_eval(mut vm, 'var count=0;for(var name of ["offsetParent","offsetWidth","offsetTop"])try{Object.getOwnPropertyDescriptor(HTMLElement.prototype,name).get.call({})}catch(e){if(e instanceof TypeError)count++}for(var name of ["clientWidth","scrollHeight"])try{Object.getOwnPropertyDescriptor(Element.prototype,name).get.call({})}catch(e){if(e instanceof TypeError)count++}count===5')!.as_bool()
}
