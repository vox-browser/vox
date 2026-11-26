// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn tree_walker_binding_fixture() !(&Host, &libjs.VM) {
	document := html.parse_document('<body><main id="root"><section id="skip"><button id="one">one</button></section><section id="reject"><button id="hidden">hidden</button></section><button id="two">two</button></main></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn tree_walker_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-tree-walker.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_tree_walker_uses_native_skip_reject_masks_and_bidirectional_current_node() {
	mut host, mut vm := tree_walker_binding_fixture()!
	defer { host.close() }
	assert tree_walker_binding_eval(mut vm, 'var root=document.getElementById("root"),one=document.getElementById("one"),two=document.getElementById("two"),filter={acceptNode(node){if(this!==filter)throw Error("receiver");return node.id==="reject"?NodeFilter.FILTER_REJECT:node.tagName==="BUTTON"?NodeFilter.FILTER_ACCEPT:NodeFilter.FILTER_SKIP}},walker=document.createTreeWalker(root,NodeFilter.SHOW_ELEMENT,filter);walker instanceof TreeWalker&&walker.root===root&&walker.currentNode===root&&walker.filter===filter&&walker.whatToShow===1&&walker.firstChild()===one&&walker.nextSibling()===two&&walker.previousNode()===one&&walker.nextNode()===two&&walker.nextNode()===null&&walker.currentNode===two')!.as_bool()
	assert tree_walker_binding_eval(mut vm, 'walker.currentNode=root;var last=walker.lastChild()===two&&walker.previousSibling()===one&&walker.parentNode()===null;var texts=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);last&&texts.filter===null&&texts.nextNode().data==="one"&&texts.nextNode().data==="hidden"&&texts.nextNode().data==="two"&&texts.nextNode()===null')!.as_bool()
}

fn test_tree_walker_preserves_original_filter_errors_reentrancy_and_callback_receivers() {
	mut host, mut vm := tree_walker_binding_fixture()!
	defer { host.close() }
	assert tree_walker_binding_eval(mut vm, 'var root=document.getElementById("root"),marker={},calls=0,fail=true,w=document.createTreeWalker(root,1,function(node){"use strict";if(this!==undefined)throw Error("receiver");calls++;if(fail)throw marker;return 1}),same=false;try{w.nextNode()}catch(error){same=error===marker}var original=w.currentNode===root;fail=false;same&&original&&calls===1&&w.nextNode()===root.firstChild&&calls===2')!.as_bool()
	assert tree_walker_binding_eval(mut vm, 'var caught=false,w=document.createTreeWalker(root,1,{acceptNode(node){try{w.nextNode()}catch(error){caught=error instanceof DOMException&&error.name==="InvalidStateError"}return 1}});w.nextNode()===root.firstChild&&caught')!.as_bool()
	assert tree_walker_binding_eval(mut vm, 'var original={},w=document.createTreeWalker(root,1,{get acceptNode(){throw original}}),same=false;try{w.firstChild()}catch(error){same=error===original}var failures=0;for(var run of [()=>new TreeWalker(),()=>document.createTreeWalker(),()=>document.createTreeWalker(root,1,true),()=>TreeWalker.prototype.nextNode.call({}),()=>{w.currentNode=null}])try{run()}catch(error){if(error instanceof TypeError)failures++}same&&failures===5&&NodeFilter.SHOW_ALL===4294967295&&NodeFilter.SHOW_NOTATION===2048&&typeof NodeFilter==="object"&&!("prototype"in NodeFilter)')!.as_bool()
}

fn test_native_cached_tree_traversal_uses_the_current_documents_node_wrappers() {
	directory := os.join_path(os.temp_dir(), 'vox-tree-walker-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := tree_walker_binding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		vm.diagnose_native_code(true)!
		assert tree_walker_binding_eval(mut vm, 'var root=document.getElementById("root"),w=document.createTreeWalker(root,NodeFilter.SHOW_ELEMENT,{acceptNode(node){return node.tagName==="BUTTON"?NodeFilter.FILTER_ACCEPT:NodeFilter.FILTER_SKIP}});w.nextNode()===document.getElementById("one")&&w.nextNode()===document.getElementById("hidden")&&w.nextNode()===document.getElementById("two")&&w.nextNode()===null')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert stats.cache_hits > 0 && stats.cache_misses == 0 && stats.compiler_invocations == 0 && activity.entries > 0
		}
		vm.close_native_code()!
		host.close()
	}
}
