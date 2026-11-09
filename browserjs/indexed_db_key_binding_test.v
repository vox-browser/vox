module browserjs

import dom
import html
import loader

fn key_binding_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-key-binding.test/' }
	document := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn test_indexed_db_key_conversion_rejects_nonkeys_with_data_error() {
	mut runtime, mut document := key_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const invalid=[undefined,null,true,NaN,{},Symbol(),1n,()=>{},new Number(1),new String("x"),new Date(NaN)];
 invalid.every(value=>{try{indexedDB.cmp(value,0);return false}catch(error){return error instanceof DOMException&&error.name==="DataError"}})&&
 indexedDB.cmp(-Infinity,Infinity)===-1&&indexedDB.cmp(-0,0)===0&&indexedDB.cmp("\ud800","\ue000")===-1;
 ')! == 'true'
}

fn test_indexed_db_key_conversion_reads_only_own_array_indices_and_keeps_shared_children() {
	mut runtime, mut document := key_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const child=[1],shared=[child,child],key=[1];let extraReads=0;
 Object.defineProperty(key,"ignored",{enumerable:true,get(){extraReads++;throw "named getter"}});
 const cycle=[];cycle.push(cycle);const sparse=Array(1),prototype=Object.create(Array.prototype);
 Object.defineProperty(prototype,"0",{get(){extraReads++;throw "inherited getter"}});Object.setPrototypeOf(sparse,prototype);
 const own=[];Object.defineProperty(own,"0",{value:7,enumerable:false});
 function invalid(value){try{indexedDB.cmp(value,0);return false}catch(error){return error.name==="DataError"}}
 indexedDB.cmp(shared,[[1],[1]])===0&&indexedDB.cmp(key,[1])===0&&indexedDB.cmp(own,[7])===0&&invalid(cycle)&&invalid(sparse)&&extraReads===0;
 ')! == 'true'
}

fn test_indexed_db_key_conversion_preserves_getter_exceptions_and_short_circuits_invalid_keys() {
	mut runtime, mut document := key_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const marker={},throwing=[];let reads=0;
 Object.defineProperty(throwing,"0",{get(){reads++;throw marker}});
 let original=false,short=false;try{indexedDB.cmp(throwing,0)}catch(error){original=error===marker}
 try{indexedDB.cmp({},throwing)}catch(error){short=error.name==="DataError"}
 const date=new Date(123);date.getTime=date.valueOf=()=>{throw "author method"};
 original&&short&&reads===1&&indexedDB.cmp(date,new Date(123))===0;
 ')! == 'true'
}

fn test_indexed_db_binary_keys_use_view_bytes_without_pinning_or_reading_author_properties() {
	mut runtime, mut document := key_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const buffer=new Uint8Array([9,1,2,8]).buffer,view=new Uint8Array(buffer,1,2),data=new DataView(buffer,1,2),expected=new Uint8Array([1,2]);
 for(const key of ["buffer","byteOffset","byteLength"])Object.defineProperty(view,key,{get(){throw "author metadata"}});
 const equal=indexedDB.cmp(view,expected)===0&&indexedDB.cmp(data,expected)===0&&indexedDB.cmp(buffer,new Uint8Array([9,1,2,8]))===0;
 const copy=buffer.transfer();let detached=false;try{indexedDB.cmp(buffer,expected)}catch(error){detached=error.name==="DataError"}
 equal&&detached&&copy.byteLength===4&&indexedDB.cmp(new ArrayBuffer(0),new Uint8Array(0))===0;
 ')! == 'true'
}
