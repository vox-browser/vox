// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import geometry
import html
import libjs
import os
import rand

fn rect_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-read-only-rect.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_native_read_only_rect_coordinates_subclasses_metadata_and_default_serializer() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert rect_eval(mut vm, 'class R extends DOMRectReadOnly{answer=42}var r=new R(10,20,-4,-8),j=r.toJSON();r instanceof R&&r instanceof DOMRectReadOnly&&r.answer===42&&r.x===10&&r.y===20&&r.width===-4&&r.height===-8&&r.left===6&&r.right===10&&r.top===12&&r.bottom===20&&Object.prototype.toString.call(r)==="[object DOMRectReadOnly]"&&Object.keys(j).join(",")==="x,y,width,height,top,right,bottom,left"&&Object.values(j).join(",")==="10,20,-4,-8,12,10,20,6"&&Object.getPrototypeOf(j)===Object.prototype&&DOMRectReadOnly.length===0')!.as_bool()
	assert rect_eval(mut vm, 'var z=new DOMRectReadOnly(undefined,null);z.x===0&&z.y===0&&z.width===0&&z.height===0&&DOMRectReadOnly.fromRect().right===0')!.as_bool()
	assert rect_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(DOMRectReadOnly.prototype,"x");d.enumerable&&d.configurable&&d.set===undefined&&typeof d.get==="function"')!.as_bool()
}

fn test_native_read_only_rect_conversion_order_defaults_and_original_exceptions() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert rect_eval(mut vm, 'var order="",reason={},o={get height(){order+="height";return 2},get width(){order+="width";return 2},get x(){order+="x";return 2},get y(){order+="y";return 2}};var r=DOMRectReadOnly.fromRect(o);order==="heightwidthxy"&&r.x===2&&r.height===2')!.as_bool()
	assert rect_eval(mut vm, 'order="";var a={valueOf(){order+="a";return 1}},b={valueOf(){order+="b";throw reason}},caught=false;try{new DOMRectReadOnly(a,b,a,a)}catch(e){caught=e===reason}caught&&order==="ab"')!.as_bool()
	assert rect_eval(mut vm, 'var o={get height(){throw reason}};caught=false;try{DOMRectReadOnly.fromRect(o)}catch(e){caught=e===reason}caught&&DOMRectReadOnly.fromRect(null).x===0')!.as_bool()
}

fn test_native_read_only_rect_brands_nonfinite_values_readonly_and_factory_copy() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert rect_eval(mut vm, 'var n=0,r=new DOMRectReadOnly(1,2,3,4);for(var run of [()=>DOMRectReadOnly(),()=>DOMRectReadOnly.fromRect(1),()=>new DOMRectReadOnly(Symbol()),()=>DOMRectReadOnly.prototype.toJSON.call({}),()=>Object.getOwnPropertyDescriptor(DOMRectReadOnly.prototype,"x").get.call({})])try{run()}catch(e){if(e instanceof TypeError)n++}r.x=99;var copy=DOMRectReadOnly.fromRect(r);n===5&&r.x===1&&copy!==r&&copy.x===1&&copy.width===3')!.as_bool()
	assert rect_eval(mut vm, 'var r=new DOMRectReadOnly(NaN,Infinity,NaN,1);isNaN(r.left)&&isNaN(r.right)&&r.y===Infinity&&r.bottom===Infinity&&r.toJSON().width!==r.toJSON().width')!.as_bool()
}

fn test_read_only_rect_wrappers_keep_actual_native_geometry_identity() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	native := geometry.DOMRectReadOnly.construct(1, 2, 3, 4)
	first := host.wrap_read_only_rect(native, host.read_only_rect_prototype)
	second := host.wrap_read_only_rect(native, host.read_only_rect_prototype)
	assert voidptr(first.as_object()) == voidptr(second.as_object())
	assert voidptr(host.read_only_rects[voidptr(first.as_object())]) == voidptr(native)
}

fn test_cached_read_only_rect_construction_executes_in_a_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-native-rect-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert rect_eval(mut vm, 'function right(x){return new DOMRectReadOnly(x,0,2,1).right}right(40)')!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
