// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs

fn node_list_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-node-lists.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_query_selector_all_returns_native_static_lists_in_tree_order() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body><div id="a" class="item"></div><div id="b" class="item"></div></body>'), Hooks{})!
	defer { host.close() }
	assert node_list_eval(mut vm, 'var a=document.getElementById("a"),b=document.getElementById("b"),list=document.querySelectorAll(".item"),ids="";list.forEach(function(e,i,self){if(self!==list)throw 1;ids+=i+e.id});list instanceof NodeList&&!Array.isArray(list)&&list.length===2&&list[0]===a&&list.item(1)===b&&list.item(2)===null&&list[2]===undefined&&ids==="0a1b"&&Object.keys(list).join(",")==="0,1"&&Object.prototype.toString.call(list)==="[object NodeList]"')!.as_bool()
	assert node_list_eval(mut vm, 'document.body.removeChild(b);var empty=document.querySelectorAll(".missing");list.length===2&&list[1]===b&&document.querySelectorAll(".item").length===1&&empty instanceof NodeList&&empty.length===0&&empty.item(0)===null')!.as_bool()
}

fn test_child_nodes_is_native_live_same_object_and_iterates_current_contents() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert node_list_eval(mut vm, 'var body=document.body,list=body.childNodes,e=document.createElement("div");body.append("text",e);var iterator=list.values(),first=iterator.next(),second=iterator.next();list===body.childNodes&&list.length===2&&list[0].nodeType===3&&list[1]===e&&first.value===list[0]&&second.value===e&&iterator.next().done&&list[Symbol.iterator]===list.values&&list.entries().next().value[0]===0&&list.keys().next().value===0')!.as_bool()
	assert node_list_eval(mut vm, 'body.replaceChildren(e);list.length===1&&list[0]===e&&list[1]===undefined&&list.item(-1)===null&&Object.keys(list).join(",")==="0"')!.as_bool()
}

fn test_fragment_lists_validate_selectors_and_guard_native_receivers() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert node_list_eval(mut vm, 'var f=new DocumentFragment(),e=document.createElement("span");e.id="inside";f.append(e);var list=f.querySelectorAll("#inside"),syntax=false,n=0;try{f.querySelectorAll("[")}catch(e){syntax=e instanceof DOMException&&e.name==="SyntaxError"}for(var call of [()=>new NodeList(),()=>NodeList(),()=>NodeList.prototype.item.call({},0),()=>list.item(),()=>Element.prototype.querySelectorAll.call({},"span"),()=>f.querySelectorAll()])try{call()}catch(e){if(e instanceof TypeError)n++}list[0]===e&&syntax&&n===6')!.as_bool()
}
