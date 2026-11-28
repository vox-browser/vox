// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

fn test_readonly_native_collection_indices_follow_webidl_descriptors_and_deletion() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var p=document.createElement("div"),a=document.createElement("span"),b=document.createElement("span");p.append(a,b);p.className="one two";document.body.appendChild(p);var ok=true;for(var list of [p.childNodes,p.children,p.classList]){var d=Object.getOwnPropertyDescriptor(list,"0");ok=ok&&d.configurable&&d.enumerable&&!d.writable&&!Reflect.deleteProperty(list,"0")&&Reflect.deleteProperty(list,"9")&&!Reflect.set(list,"0",null)&&!Reflect.defineProperty(list,"9",{value:null})}ok')!.as_bool()
}

fn test_legacy_indexed_collections_cannot_be_made_nonextensible_even_when_empty() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var p=document.createElement("div"),ok=true,caught=0;for(var list of [p.childNodes,p.children,p.classList]){ok=ok&&!Reflect.preventExtensions(list)&&Object.isExtensible(list);for(var change of [Object.preventExtensions,Object.seal,Object.freeze])try{change(list)}catch(e){if(e instanceof TypeError)caught++}}ok&&caught===9')!.as_bool()
}

fn test_legacy_collection_index_support_stays_live_while_static_node_lists_keep_members() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var p=document.createElement("div"),a=document.createElement("span"),b=document.createElement("span");p.append(a,b);var live=p.children,fixed=p.querySelectorAll("span");p.removeChild(b);live.length===1&&fixed.length===2&&Reflect.deleteProperty(live,"1")&&!Reflect.deleteProperty(fixed,"1")&&fixed[1]===b&&Object.getOwnPropertyDescriptor(live,"1")===undefined')!.as_bool()
}

fn test_legacy_collection_nonindex_names_and_symbols_keep_ordinary_property_behavior() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var list=document.createElement("div").children,ok=true;for(var key of ["01","-1","4294967295",Symbol("extra")]){ok=ok&&Reflect.defineProperty(list,key,{value:7,writable:true,configurable:true})&&list[key]===7&&Reflect.deleteProperty(list,key)}ok&&!Reflect.defineProperty(list,"0",{get(){return 1}})')!.as_bool()
}

fn test_proxy_invariants_use_configurable_legacy_collection_descriptors() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var p=document.createElement("div"),a=document.createElement("span");p.appendChild(a);var list=p.children,hidden=new Proxy(list,{ownKeys(){return []}}),removed=new Proxy(list,{deleteProperty(){return true}});Object.keys(hidden).length===0&&Reflect.deleteProperty(removed,"0")&&list[0]===a&&Reflect.ownKeys(list)[0]==="0"')!.as_bool()
}
