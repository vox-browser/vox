// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn dataset_fixture() !(&Host, &libjs.VM) {
	address := dom.URL{ value: 'https://dataset.test/' }
	document := html.parse_navigation_document('<html data-color-mode="auto"><body><div id="item" data-user-id="42"></div></body></html>', address, address.origin(), none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn dataset_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'dataset.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_dataset_is_same_object_and_reflects_live_native_attributes_both_ways() {
	mut host, mut vm := dataset_fixture()!
	defer { host.close() }
	assert dataset_eval(mut vm, 'var item=document.getElementById("item"),map=item.dataset;var initial=map===item.dataset&&map instanceof DOMStringMap&&map.userId==="42"&&document.documentElement.dataset.colorMode==="auto";item.setAttribute("data-user-id","43");map.themeName="night";map[0]=7;delete map.userId;initial&&map.userId===undefined&&!item.hasAttribute("data-user-id")&&item.getAttribute("data-theme-name")==="night"&&item.getAttribute("data-0")==="7"&&Object.keys(map).join(",")==="themeName,0"')!.as_bool()
	assert dataset_eval(mut vm, 'map.toString="shadow";map.__proto__="native";var s=Symbol("ordinary");map[s]=5;map.toString==="shadow"&&item.getAttribute("data-to-string")==="shadow"&&map.__proto__==="native"&&Object.getPrototypeOf(map)===DOMStringMap.prototype&&map[s]===5')!.as_bool()
}

fn test_dataset_descriptors_conversion_order_and_dom_errors_follow_named_setter_rules() {
	mut host, mut vm := dataset_fixture()!
	defer { host.close() }
	assert dataset_eval(mut vm, 'var map=document.getElementById("item").dataset,d=Object.getOwnPropertyDescriptor(map,"userId");Object.defineProperty(map,"extra",{value:12,writable:false,configurable:false});d.writable&&d.enumerable&&d.configurable&&map.extra==="12"&&Object.getOwnPropertyDescriptor(map,"extra").configurable&&!Reflect.defineProperty(map,"bad",{get(){return 1}})')!.as_bool()
	assert dataset_eval(mut vm, 'var order="",n=0,sentinel={};try{map["bad-name"]={toString(){order+="convert";return "x"}}}catch(e){if(e instanceof DOMException&&e.name==="SyntaxError")n++}try{map["bad name"]="x"}catch(e){if(e instanceof DOMException&&e.name==="InvalidCharacterError")n++}try{map["bad-name"]={toString(){throw sentinel}}}catch(e){if(e===sentinel)n++}order==="convert"&&n===3')!.as_bool()
	assert dataset_eval(mut vm, 'var bad=false;try{Object.getOwnPropertyDescriptor(HTMLElement.prototype,"dataset").get.call({})}catch(e){bad=e instanceof TypeError}bad')!.as_bool()
}

fn test_dataset_mutations_publish_native_observer_records() {
	mut host, mut vm := dataset_fixture()!
	defer { host.close() }
	assert dataset_eval(mut vm, 'var item=document.getElementById("item"),observer=new MutationObserver(()=>{});observer.observe(item,{attributes:true,attributeOldValue:true});item.dataset.userId="new";delete item.dataset.userId;var records=observer.takeRecords();records.length===2&&records[0].attributeName==="data-user-id"&&records[0].oldValue==="42"&&records[1].oldValue==="new"')!.as_bool()
}

fn test_compiled_dataset_revisit_uses_current_native_element_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-dataset-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := dataset_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		vm.diagnose_native_code(true)!
		assert dataset_eval(mut vm, 'var map=document.documentElement.dataset;map.colorMode="dark";document.documentElement.getAttribute("data-color-mode")==="dark"&&map===document.documentElement.dataset')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert stats.cache_hits > 0 && stats.cache_misses == 0 && stats.compiler_invocations == 0 && activity.entries > 0
		}
		vm.close_native_code()!
		host.close()
	}
}
