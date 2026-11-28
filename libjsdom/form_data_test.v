// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import os
import platform
import rand

fn test_native_form_data_order_duplicates_get_set_and_delete() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=new FormData;f.append("a",1);f.append("b",2);f.append("a",3);var initial=f.getAll("a").join();f.set("a",4);var keys=[...f.keys()].join();f.delete("b");initial==="1,3"&&keys==="a,b"&&f.get("a")==="4"&&f.get("missing")===null&&f.getAll("missing").length===0&&!f.has("b")&&[...f].length===1&&f instanceof FormData&&FormData.length===0&&f.append.length===2&&f.get.length===1&&f.forEach.length===1&&Object.prototype.toString.call(f)==="[object FormData]"&&f[Symbol.iterator]===f.entries')!.as_bool()
}

fn test_native_form_data_usv_conversions_and_required_blob_overload_order() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=new FormData,order="",bad=0;f.append({toString(){order+="n";return "\\ud800"}},{toString(){order+="v";return "\\udc00"}});try{f.append({toString(){order+="x";return "x"}},"text",undefined)}catch(e){if(e instanceof TypeError)bad++}var marker={},same=false;try{f.set("x",{toString(){throw marker}})}catch(e){same=e===marker}order==="nv"&&bad===1&&same&&f.get("�")==="�"&&!f.has("x")')!.as_bool()
}

fn test_native_form_data_blob_and_file_entries_preserve_native_identity() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=new FormData,b=new Blob(["abc"],{type:"TEXT/PLAIN"}),file=new File(["def"],"original.txt",{lastModified:23});f.append("blob",b);f.append("file",file);f.append("named",file,"other.txt");var a=f.get("blob"),c=f.get("named");a instanceof File&&a instanceof Blob&&a.name==="blob"&&a.type==="text/plain"&&a.size===3&&a===f.get("blob")&&f.get("file")===file&&[...f.values()][1]===file&&c!==file&&c.name==="other.txt"&&c.lastModified===23&&c.size===3')!.as_bool()
}

fn test_native_form_data_iterators_are_live_and_remain_done_after_completion() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=new FormData;f.append("a",1);f.append("b",2);var i=f.entries(),a=i.next();f.delete("b");f.append("c",3);var b=i.next(),end=i.next();f.append("d",4);a.value.join()==="a,1"&&b.value.join()==="c,3"&&end.done&&i.next().done&&i[Symbol.iterator]()===i&&Object.prototype.toString.call(i)==="[object FormData Iterator]"')!.as_bool()
}

fn test_native_form_data_for_each_observes_mutation_this_and_original_receiver() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=new FormData,receiver={},seen=[];f.append("a",1);f.append("b",2);var result=f.forEach(function(value,key,object){if(this!==receiver||object!==f)throw 1;seen.push(key+value);if(key==="a"){f.delete("b");f.append("c",3)}return false},receiver);seen.join()==="a1,c3"&&result===undefined')!.as_bool()
}

fn test_native_form_data_brands_argument_errors_and_history_rejection() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=new FormData,bad=0;for(var run of [()=>FormData(),()=>new FormData(null),()=>new FormData({}),()=>new FormData(undefined,{}),()=>FormData.prototype.get.call({},"a"),()=>f.get(),()=>f.append("x"),()=>f.set("x"),()=>f.forEach(1),()=>FormData.prototype.get.call(new Proxy(f,{}),"x")])try{run()}catch(e){if(e instanceof TypeError)bad++}var clone=0;for(var x of [f,f.entries()])try{history.replaceState(x,"")}catch(e){if(e.name==="DataCloneError")clone++}bad===10&&clone===2')!.as_bool()
}

fn test_native_form_data_constructor_reads_native_controls_and_submitter() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><input name=a value=one><input name=a value=two><input disabled name=bad value=x><input type=checkbox name=yes checked><input type=checkbox name=no><button id=submit name=button value=go>Go</button></form>";var form=document.getElementById("f"),button=document.getElementById("submit"),f=new FormData(form,button);f.getAll("a").join()==="one,two"&&!f.has("bad")&&!f.has("no")&&f.get("yes")==="on"&&f.get("button")==="go"&&new FormData(form).get("button")===null')!.as_bool()
}

fn test_native_form_data_constructor_delivers_live_formdata_event_mutations() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><input name=a value=one></form>";var form=document.getElementById("f"),eventData,calls=0;form.addEventListener("formdata",e=>{calls++;if(!(e instanceof FormDataEvent)||!e.isTrusted||e.target!==form)throw 1;eventData=e.formData;if(e.formData!==eventData)throw 2;eventData.set("a","changed");eventData.append("extra","yes")});var f=new FormData(form);calls===1&&f.get("a")==="changed"&&f.get("extra")==="yes"&&eventData.get("a")==="changed"')!.as_bool()
}

fn test_native_form_data_invalid_submitters_and_reentrant_construction_throw_native_errors() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><input id=text><button type=button id=notSubmit></button></form><form id=other><button id=wrong></button></form>";var f=document.getElementById("f"),type=0,notFound=false,recursive=false;for(var id of ["text","notSubmit"])try{new FormData(f,document.getElementById(id))}catch(e){if(e instanceof TypeError)type++}try{new FormData(f,document.getElementById("wrong"))}catch(e){notFound=e instanceof DOMException&&e.name==="NotFoundError"}f.addEventListener("formdata",()=>{try{new FormData(f)}catch(e){recursive=e instanceof DOMException&&e.name==="InvalidStateError"}});new FormData(f);type===2&&notFound&&recursive')!.as_bool()
}

fn test_native_form_data_event_constructor_preserves_data_and_event_inheritance() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=new FormData,e=new FormDataEvent("formdata",{formData:f,bubbles:true});f.append("a",1);var bad=0;for(var run of [()=>FormDataEvent("x",{formData:f}),()=>new FormDataEvent("x"),()=>new FormDataEvent("x",{}),()=>new FormDataEvent("x",{formData:{}}),()=>Object.getOwnPropertyDescriptor(FormDataEvent.prototype,"formData").get.call(new Event("x"))])try{run()}catch(e){if(e instanceof TypeError)bad++}bad===5&&e instanceof Event&&e instanceof FormDataEvent&&e.formData===f&&e.formData.get("a")==="1"&&e.bubbles&&!e.isTrusted&&Object.getPrototypeOf(FormDataEvent)===Event')!.as_bool()
}

fn test_native_form_data_constructor_converts_elements_before_prototype_and_constructs_after_it() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><input name=a value=before></form>";var form=document.getElementById("f"),order=[],target=new Proxy(function(){},{get(t,k){if(k==="prototype"){order.push("prototype");form.querySelector("input").setAttribute("value","after");return FormData.prototype}return Reflect.get(t,k)}});form.addEventListener("formdata",()=>order.push("event"));var f=Reflect.construct(FormData,[form],target),bad=false;try{Reflect.construct(FormData,[null],target)}catch(e){bad=e instanceof TypeError}bad&&order.join()==="prototype,event"&&f.get("a")==="after"')!.as_bool()
}

fn test_native_form_data_owners_survive_arena_reset_and_clear_at_host_close() {
	mut host, mut vm := text_encoding_fixture()!
	mut arena := platform.new_arena('FormData native records')
	entry := arena.enter()
	stream_eval(mut vm, 'var f=new FormData;f.append("file",new File(["kept"],"kept.txt"));var iterator=f.entries();var event=new FormDataEvent("x",{formData:f})')!
	arena.leave(entry)
	for _, native in host.form_data { assert !arena.contains(native) }
	for _, native in host.form_data_iterators { assert !arena.contains(native) }
	arena.reset(); arena.release()
	assert stream_eval(mut vm, 'event.formData===f&&iterator.next().value[1].name==="kept.txt"')!.as_bool()
	host.close()
	assert host.form_data.len == 0 && host.form_data_iterators.len == 0 && host.form_event_data.len == 0
}

fn test_cached_native_form_data_methods_revisit_with_disabled_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-native-form-data-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := text_encoding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert stream_eval(mut vm, 'function collect(data){var out="";data.forEach((value,key)=>out+=key+value);return out}var f=new FormData;f.append("a",1);f.append("b",2);collect(f)==="a1b2"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
