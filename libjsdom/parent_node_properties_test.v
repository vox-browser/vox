// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn parent_properties_fixture() !(&Host, &libjs.VM) {
	address := dom.URL{value:'https://parent-properties.test/'}
	document := html.parse_navigation_document('<body><div id="root">text<!-- comment --><span id="first"></span><b id="last"></b></div></body>',address,address.origin(),none)!
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm,vm.realm(),document,Hooks{})!
	return host,vm
}

fn parent_properties_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source,vm.realm(),'parent-node-properties.js',unsafe { nil })!
	return vm.run_with_limits(mut script,libjs.ExecutionLimits{max_instructions:100000}) or { return error(exception_message(err)) }
}

fn test_parent_properties_are_live_same_object_collections_of_only_element_children() {
	mut host, mut vm := parent_properties_fixture()!
	defer { host.close() }
	assert parent_properties_eval(mut vm, 'var root=document.getElementById("root"),list=root.children,first=root.firstElementChild,last=root.lastElementChild;var initial=list===root.children&&list instanceof HTMLCollection&&list.length===2&&root.childElementCount===2&&list[0]===first&&list.first===first&&list[1]===last;root.removeChild(first);initial&&list.length===1&&root.childElementCount===1&&root.firstElementChild===last&&root.lastElementChild===last&&document.children.length===1&&document.firstElementChild===document.documentElement')!.as_bool()
}

fn test_fragment_and_cloned_template_content_expose_parent_properties() {
	mut host, mut vm := parent_properties_fixture()!
	defer { host.close() }
	assert parent_properties_eval(mut vm, 'var template=document.createElement("template");template.innerHTML="<div><span>clipboard</span></div>";var clone=template.content.cloneNode(true),outer=clone.children[0],inner=outer.children[0],held=clone.children;clone.append(document.createComment("ignored"));var sibling=document.createElement("b");clone.append(sibling);clone instanceof DocumentFragment&&outer instanceof HTMLElement&&inner.textContent==="clipboard"&&clone.firstElementChild===outer&&clone.lastElementChild===sibling&&clone.childElementCount===2&&held===clone.children&&held.length===2&&template.content.childElementCount===1')!.as_bool()
	assert parent_properties_eval(mut vm, 'var empty=document.createDocumentFragment(),failed=false;try{Object.getOwnPropertyDescriptor(DocumentFragment.prototype,"children").get.call(document.createTextNode("text"))}catch(e){failed=e instanceof TypeError}failed&&empty.children.length===0&&empty.childElementCount===0&&empty.firstElementChild===null&&empty.lastElementChild===null')!.as_bool()
}

fn test_cached_parent_properties_follow_current_native_tree_without_compiler() {
	directory := os.join_path(os.temp_dir(),'vox-parent-properties-'+rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := parent_properties_fixture()!
		vm.enable_native_code_cache(directory,if visit==0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert parent_properties_eval(mut vm, 'var root=document.getElementById("root"),children=root.children;root.append(document.createElement("em"));children===root.children&&children.length===3&&root.lastElementChild===children[2]&&root.childElementCount===3')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit==1 { assert stats.cache_hits>0&&stats.cache_misses==0&&stats.compiler_invocations==0&&activity.entries>0 }
		vm.close_native_code()!
		host.close()
	}
}
