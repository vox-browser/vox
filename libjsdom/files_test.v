// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform

fn test_native_file_uses_blob_identity_and_file_metadata() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=new File(["abc"],"name.txt",{type:"TEXT/PLAIN",lastModified:17.9});f instanceof File&&f instanceof Blob&&f.name==="name.txt"&&f.type==="text/plain"&&f.size===3&&f.lastModified===17&&Object.getPrototypeOf(File)===Blob&&Object.getPrototypeOf(File.prototype)===Blob.prototype&&Object.prototype.toString.call(f)==="[object File]"&&File.length===2')!.as_bool()
	object := vm.global_object().get(mut vm, libjs.PropertyName.from_str('f'))!.as_object()
	native := host.files[voidptr(object)] or { panic('Missing native File') }
	assert voidptr(host.blobs[voidptr(object)]) == voidptr(native.as_blob())
	assert voidptr(host.wrap_file(native, none).as_object()) == voidptr(object)
}

fn test_native_file_inherited_reads_and_slice_use_actual_owned_bytes() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'var f=new File(["😀",new Uint8Array([65])],"x"),text="",slice=f.slice(4),tail="";f.text().then(x=>text=x);slice.text().then(x=>tail=x)')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'text==="😀A"&&tail==="A"&&slice instanceof Blob&&!(slice instanceof File)')!.as_bool()
}

fn test_native_file_conversion_order_and_late_buffer_copy() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var order=[],bytes=new Uint8Array([65]),target=new Proxy(function(){},{get(t,k){if(k==="prototype"){order.push("prototype");bytes[0]=66;return File.prototype}return Reflect.get(t,k)}});var f=Reflect.construct(File,[[bytes],{toString(){order.push("name");return "x"}},{get endings(){order.push("endings");return "transparent"},get lastModified(){order.push("lastModified");return {valueOf(){order.push("number");return 5}}},get type(){order.push("type");return ""}}],target);order.join()==="name,endings,lastModified,number,type,prototype"&&f.lastModified===5')!.as_bool()
	stream_eval(mut vm, 'var text="";f.text().then(x=>text=x)')!
	stream_tasks_drain(mut vm)
	assert stream_eval(mut vm, 'text==="B"')!.as_bool()
}

fn test_native_file_usv_name_defaults_errors_and_history_brand() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=new File([],"\\ud800"),bad=0;for(var run of [()=>File([],"x"),()=>new File(),()=>new File(undefined,"x"),()=>new File([],Symbol()),()=>new File([],"x",1),()=>new File([],"x",{endings:"bad"}),()=>Object.getOwnPropertyDescriptor(File.prototype,"name").get.call(new Blob())])try{run()}catch(e){if(e instanceof TypeError)bad++}var clone=false;try{history.replaceState(f,"")}catch(e){clone=e.name==="DataCloneError"}bad===7&&f.name==="�"&&f.lastModified>0&&clone')!.as_bool()
}

fn test_native_file_wrapper_survives_arena_reset_and_clears_roots_on_close() {
	mut host, mut vm := text_encoding_fixture()!
	mut arena := platform.new_arena('native File wrapper')
	entry := arena.enter()
	stream_eval(mut vm, 'var file=new File(["kept"],"kept.txt",{lastModified:11})')!
	arena.leave(entry)
	for _, native in host.files { assert !arena.contains(native) && !arena.contains(native.as_blob()) }
	arena.reset(); arena.release()
	assert stream_eval(mut vm, 'file.name==="kept.txt"&&file.size===4&&file.lastModified===11')!.as_bool()
	host.close()
	assert host.files.len == 0 && host.file_wrappers.len == 0
}
