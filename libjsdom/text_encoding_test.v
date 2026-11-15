// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand
import platform

fn text_encoding_fixture() !(&Host, &libjs.VM) {
	address := dom.URL{value: 'https://libjs-encoding.test/'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	return Host.create(vm, vm.realm(), document, Hooks{})!, vm
}

fn text_encoding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'text-encoding.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 200000}) or { return error(exception_message(err)) }
}

fn test_text_encoding_prototypes_descriptors_and_subclasses() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'class E extends TextEncoder{}class D extends TextDecoder{}var e=new E(),d=new D();e instanceof TextEncoder&&d instanceof TextDecoder&&e.encoding==="utf-8"&&d.encoding==="utf-8"&&!d.fatal&&!d.ignoreBOM&&Object.prototype.toString.call(e)==="[object TextEncoder]"&&Object.prototype.toString.call(d)==="[object TextDecoder]"&&Object.keys(e).length===0&&Object.keys(d).length===0&&TextEncoder.length===0&&TextDecoder.length===0&&e.encode.length===0&&e.encodeInto.length===2&&d.decode.length===0&&Object.getOwnPropertyDescriptor(TextEncoder.prototype,"encode").enumerable&&!Object.getOwnPropertyDescriptor(TextDecoder,"prototype").writable&&Object.getOwnPropertyDescriptor(TextDecoder.prototype,"fatal").get.length===0')!.as_bool()
}

fn test_text_encoder_utf16_replacement_optional_input_and_real_typed_storage() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var e=new TextEncoder(),a=e.encode("Aé😀\\ud800Z\\udc00");a instanceof Uint8Array&&a.buffer instanceof ArrayBuffer&&a.join()==="65,195,169,240,159,152,128,239,191,189,90,239,191,189"&&e.encode().length===0&&e.encode(undefined).length===0&&e.encode(null).join()==="110,117,108,108"&&e.encode("a").buffer!==e.encode("a").buffer&&new TextDecoder().decode(a)==="Aé😀�Z�"')!.as_bool()
	assert text_encoding_eval(mut vm, 'var U=Uint8Array;globalThis.Uint8Array=function(){throw 1};var a=e.encode("kept"),good=a instanceof U&&a.join()==="107,101,112,116";globalThis.Uint8Array=U;good')!.as_bool()
}

fn test_text_encoder_into_offsets_complete_scalars_and_utf16_read_counts() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var e=new TextEncoder(),b=new Uint8Array(8).fill(9),view=b.subarray(2,7),r=e.encodeInto("A😀Z",view);r.read===3&&r.written===5&&b.join()==="9,9,65,240,159,152,128,9"&&Object.keys(r).join()==="read,written"&&Object.getOwnPropertyDescriptor(r,"read").writable&&Object.getOwnPropertyDescriptor(r,"read").enumerable')!.as_bool()
	assert text_encoding_eval(mut vm, 'var a=new Uint8Array(3).fill(7),r=e.encodeInto("😀",a),c=new Uint8Array(3),s=e.encodeInto("\\ud800",c);r.read===0&&r.written===0&&a.join()==="7,7,7"&&s.read===1&&s.written===3&&c.join()==="239,191,189"')!.as_bool()
}

fn test_text_encoding_receiver_brands_and_conversion_exceptions() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var reads=0,errors=0,e=new TextEncoder(),source={toString(){reads++;return "x"}};for(var f of [()=>TextEncoder(),()=>TextDecoder(),()=>e.encodeInto(),()=>e.encodeInto("x"),()=>e.encodeInto("x",new Uint8ClampedArray(2)),()=>e.encodeInto("x",new Proxy(new Uint8Array(2),{})),()=>TextEncoder.prototype.encode.call({},source),()=>TextEncoder.prototype.encode.call(new Proxy(e,{}),source),()=>Object.getOwnPropertyDescriptor(TextDecoder.prototype,"fatal").get.call({}),()=>TextDecoder.prototype.decode.call({},null)])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===10&&reads===0')!.as_bool()
	assert text_encoding_eval(mut vm, 'var marker={},same=false,log="";try{e.encodeInto({toString(){log+="s";throw marker}}, {})}catch(e){same=e===marker}same&&log==="s"&&(function(){try{e.encode(Symbol());return false}catch(e){return e instanceof TypeError}})()')!.as_bool()
}

fn test_text_decoder_constructor_option_getter_order_and_encoding_labels() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var log="",d=new TextDecoder({toString(){log+="l";return " ASCII "}},{get fatal(){log+="f";return true},get ignoreBOM(){log+="b";return 1}});log==="lfb"&&d.encoding==="windows-1252"&&d.fatal&&d.ignoreBOM&&d.decode(new Uint8Array([128]))==="€"&&new TextDecoder("utf-16").encoding==="utf-16le"')!.as_bool()
	assert text_encoding_eval(mut vm, 'var errors=0;for(var f of [()=>new TextDecoder("replacement"),()=>new TextDecoder("unknown"),()=>new TextDecoder(null)])try{f()}catch(e){if(e instanceof RangeError)errors++}errors===3&&(function(){try{new TextDecoder("utf-8",1);return false}catch(e){return e instanceof TypeError}})()')!.as_bool()
	assert text_encoding_eval(mut vm, 'var marker={},same=false,log="",N=new Proxy(function(){},{get(t,k,r){if(k==="prototype"){log+="p";return TextDecoder.prototype}return Reflect.get(t,k,r)}});try{Reflect.construct(TextDecoder,[{toString(){log+="l";return "invalid"}},{get fatal(){log+="f";return false},get ignoreBOM(){log+="b";return false}}],N)}catch(e){same=e instanceof RangeError}same&&log==="lfbp"')!.as_bool()
}

fn test_text_decoder_views_raw_bytes_options_side_effects_and_detachment() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var d=new TextDecoder(),b=new Uint8Array([88,65,66,89]),v=new DataView(b.buffer,1,2);d.decode(v)==="AB"&&d.decode(b.subarray(1,3))==="AB"&&d.decode(b.buffer)==="XABY"&&d.decode(new Uint16Array(new Uint8Array([65,66]).buffer))==="AB"&&d.decode(b.subarray(1,3),{get stream(){b[1]=67;return false}})==="CB"')!.as_bool()
	assert text_encoding_eval(mut vm, 'var b=new Uint8Array([65]),d=new TextDecoder(),a=d.decode(b,{get stream(){b.buffer.transfer();return false}});a===""&&d.decode(b)===""&&d.decode()===""&&(function(){var reads=0;try{d.decode(null,{get stream(){reads++;return false}});return false}catch(e){return e instanceof TypeError&&reads===0}})()')!.as_bool()
}

fn test_text_decoder_streaming_bom_fatal_errors_and_reset() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var d=new TextDecoder(),a=d.decode(new Uint8Array([239]),{stream:true}),b=d.decode(new Uint8Array([187,191,240,159]),{stream:true}),c=d.decode(new Uint8Array([152,128]));a===""&&b===""&&c==="😀"&&d.decode(new Uint8Array([239,187,191,65]))==="A"&&new TextDecoder("utf-8",{ignoreBOM:true}).decode(new Uint8Array([239,187,191,65]))==="\\ufeffA"')!.as_bool()
	assert text_encoding_eval(mut vm, 'var d=new TextDecoder("utf-8",{fatal:true}),bad=false;try{d.decode(new Uint8Array([255]))}catch(e){bad=e instanceof TypeError}bad&&d.decode(new Uint8Array([65]))==="A"&&new TextDecoder().decode(new Uint8Array([255]))==="�"&&(d.decode(new Uint8Array([240]),{stream:true})===""&&function(){try{d.decode();return false}catch(e){return e instanceof TypeError}}())&&d.decode(new Uint8Array([66]))==="B"')!.as_bool()
}

fn test_text_encoding_allow_shared_and_fixed_length_webidl_conversion() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var b=new SharedArrayBuffer(8),a=new Uint8Array(b,1,5),e=new TextEncoder(),r=e.encodeInto("A😀",a);r.read===3&&r.written===5&&new TextDecoder().decode(a)==="A😀"&&new Uint8Array(b)[0]===0')!.as_bool()
	assert text_encoding_eval(mut vm, 'var b=new ArrayBuffer(8,{maxByteLength:16}),a=new Uint8Array(b,2,4),e=new TextEncoder(),d=new TextDecoder(),errors=0,reads=0;for(var f of [()=>e.encodeInto("A",a),()=>d.decode(a,{get stream(){reads++;return false}}),()=>d.decode(b),()=>d.decode(new DataView(b))])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===4&&reads===0')!.as_bool()
}

fn test_text_encoding_wrappers_and_streaming_state_survive_arena_reset() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	before := host.closures.len
	mut arena := platform.new_arena('native text encoding records')
	entry := arena.enter()
	text_encoding_eval(mut vm, 'var encoder=new TextEncoder(),decoder=new TextDecoder(),bytes=encoder.encode("retained");decoder.decode(new Uint8Array([240,159]),{stream:true});for(var i=0;i<20;i++){new TextEncoder();new TextDecoder()}')!
	arena.leave(entry)
	encoder := vm.global_object().get(mut vm, libjs.PropertyName.from_str('encoder'))!.as_object()
	decoder := vm.global_object().get(mut vm, libjs.PropertyName.from_str('decoder'))!.as_object()
	native_encoder := host.text_encoders[voidptr(encoder)] or { panic('Missing native encoder') }
	native_decoder := host.text_decoders[voidptr(decoder)] or { panic('Missing native decoder') }
	assert !arena.contains(encoder) && !arena.contains(decoder) && !arena.contains(native_encoder) && !arena.contains(native_decoder)
	arena.reset(); arena.release()
	assert text_encoding_eval(mut vm, 'decoder.decode(new Uint8Array([152,128]))==="😀"&&decoder.decode(bytes)==="retained"&&encoder.encode("ok").join()==="111,107"')!.as_bool()
	assert host.closures.len == before
}

fn test_text_encoding_history_rejection_does_not_run_author_getters() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert text_encoding_eval(mut vm, 'var reads=0,errors=0;for(var a of [new TextEncoder(),new TextDecoder()]){Object.defineProperty(a,"visible",{enumerable:true,get(){reads++;throw 1}});try{history.replaceState(a,"")}catch(e){if(e.name==="DataCloneError")errors++}}errors===2&&reads===0')!.as_bool()
}

fn test_text_encoding_native_work_charges_execution_budget() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	text_encoding_eval(mut vm, 'var hugeText="x".repeat(1000000),hugeBytes=new Uint8Array(1000000),encoder=new TextEncoder(),decoder=new TextDecoder()')!
	for source in ['encoder.encode(hugeText)', 'encoder.encodeInto(hugeText,hugeBytes)', 'decoder.decode(hugeBytes)'] {
		mut script := libjs.Script.parse(source, vm.realm(), 'text-encoding-budget.js', unsafe { nil })!
		if _ := vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 200}) { assert false }
		else { assert exception_message(err).contains('instruction budget') }
	}
}

fn test_cached_text_encoding_revisits_without_compiler_and_host_close_clears_records() {
	directory := os.join_path(os.temp_dir(), 'vox-text-encoding-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := text_encoding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert text_encoding_eval(mut vm, 'function utf8Roundtrip(s){return new TextDecoder().decode(new TextEncoder().encode(s))}utf8Roundtrip("GitHub 😀")==="GitHub 😀"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
		assert host.text_encoders.len == 0 && host.text_decoders.len == 0
	}
}
