// Copyright (c) 2022, the SerenityOS developers.
// SPDX-License-Identifier: BSD-2-Clause
// Generated FileListWrapper/Prototype and indexed PlatformObject.cpp methods.
@[has_globals]
module browserjs

import fileapi
import libjs
import webidl


__global file_list_bindings_ = map[voidptr]&FileListHost{}

pub fn (mut host FileListHost) install(mut runtime Runtime) ! {
	runtime.require_javascript_value_context()!
	runtime.bind_scripting_environment(host.settings)!
	owner := voidptr(&runtime)
	if previous := file_list_bindings_[owner] {
		if voidptr(previous) == voidptr(&host) { return }
		return error('FileList binding already belongs to another native owner')
	}
	files := file_bindings_[owner] or { return error('FileList binding requires its actual relevant-realm File host') }
	if files.closed || voidptr(files.settings) != voidptr(host.settings) {
		return error('FileList binding requires its owning relevant-realm File host')
	}
	host.runtime = &runtime
	host.files = files
	handle := voidptr(&host)
	operate := runtime.make_value_host_function(fn [handle] (_ voidptr, args []voidptr) !voidptr {
		mut host := unsafe { &FileListHost(handle) }
		return host.operate(args) or {
			return host.runtime.actual_javascript_exception(host.runtime.binding_exception_value(err))
		}
	})!
	installer := runtime.evaluate_host_value(file_list_native_factory)!
	defer { runtime.release_javascript_value(installer) }
	factory := runtime.call_javascript_function(installer, C.vox_jsc_JSValueMakeUndefined(runtime.context), [operate])!
	host.prototype = runtime.retain_javascript_value(runtime.binding_property(factory, 'prototype')!)!
	host.wrap_function = runtime.retain_javascript_value(runtime.binding_property(factory, 'wrap')!)!
	file_list_bindings_[owner] = &host
	runtime.add_close_handler(fn [handle, owner] () {
		mut host := unsafe { &FileListHost(handle) }
		host.close()
		file_list_bindings_.delete(owner)
	})
}

fn (host &FileListHost) argument(args []voidptr, index int) voidptr {
	if index < args.len { return args[index] }
	return C.vox_jsc_JSValueMakeUndefined(host.runtime.context)
}

fn (host &FileListHost) record(value voidptr) !&FileListHostRecord {
	if host.closed { return error('TypeError: FileList binding is closed') }
	record := host.by_wrapper[value] or { return error('TypeError: Not an object of type FileList') }
	if voidptr(record.host) != voidptr(host) {
		return error('TypeError: Not an object of type FileList')
	}
	return record
}

fn (mut host FileListHost) wrap(list &fileapi.FileList) !voidptr {
	if host.closed { return error('FileList binding is closed') }
	native := voidptr(list)
	if record := host.records[native] { return record.object }
	object := host.runtime.retain_javascript_value(host.runtime.call_javascript_function(host.wrap_function, C.vox_jsc_JSValueMakeUndefined(host.runtime.context), [])!)!
	record := &FileListHostRecord{ host: host, list: list, object: object }
	host.records[native] = record
	host.by_wrapper[object] = record
	return object
}

fn (mut host FileListHost) operate(args []voidptr) !voidptr {
	name := host.runtime.binding_dom_string(host.argument(args, 0))!
	if name == 'arrayIndex' {
		key := libjs.PropertyName.from_utf16(host.runtime.native_utf16_string(host.argument(args, 1))!)
		if !key.is_number() { return C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
		return C.vox_jsc_JSValueMakeNumber(host.runtime.context, f64(key.number))
	}
	list := host.record(host.argument(args, 1))!.list
	match name {
		'length' { return C.vox_jsc_JSValueMakeNumber(host.runtime.context, f64(u32(list.length()))) }
		'indexed' {
			index := u32(webidl.convert_to_int(host.runtime.webidl_value(host.argument(args, 2))!, 32, false, .no, .no)!)
			file := list.item(int(index)) or { return C.vox_jsc_JSValueMakeUndefined(host.runtime.context) }
			return host.files.wrap(file)
		}
		'item' {
			argc := webidl.value_to_number(host.runtime.webidl_value(host.argument(args, 2))!)!
			if argc < 1 { return error('TypeError: item() needs one argument') }
			index := u32(webidl.convert_to_int(host.runtime.webidl_value(host.argument(args, 3))!, 32, false, .no, .no)!)
			file := list.item(int(index)) or { return C.vox_jsc_JSValueMakeNull(host.runtime.context) }
			return host.files.wrap(file)
		}
		else { return error('TypeError: Unknown FileList operation') }
	}
}

pub fn (mut runtime Runtime) javascript_file_list(list &fileapi.FileList) !voidptr {
	mut host := file_list_bindings_[voidptr(&runtime)] or { return error('FileList binding is unavailable') }
	return host.wrap(list)
}

pub fn (runtime &Runtime) native_file_list(value voidptr) !&fileapi.FileList {
	host := file_list_bindings_[voidptr(runtime)] or { return error('FileList binding is unavailable') }
	return host.record(value)!.list
}

// Only the indexed legacy branches are present for FileList. Ordinary storage,
// prototype traversal and OrdinarySetWithOwnDescriptor remain engine-owned.
const file_list_native_factory = r'(function(operate){
 "use strict";
 const define=Object.defineProperty,create=Object.create,descriptor=Object.getOwnPropertyDescriptor,P=Proxy;
 const get=Reflect.get,set=Reflect.set,has=Reflect.has,getOwn=Reflect.getOwnPropertyDescriptor,defineOwn=Reflect.defineProperty,remove=Reflect.deleteProperty,ownKeys=Reflect.ownKeys;
 const prototype=create(Object.prototype);
 const lengthGetter=descriptor({get length(){return operate("length",this)}},"length").get;
 define(prototype,"length",{get:lengthGetter,enumerable:true,configurable:true});
 define(prototype,"item",{value:({item(index){return operate("item",this,arguments.length,index)}}).item,writable:true,enumerable:true,configurable:true});
 define(prototype,Symbol.iterator,{value:Array.prototype.values,writable:true,configurable:true});
 define(prototype,Symbol.toStringTag,{value:"FileList",configurable:true});
 function arrayIndex(key){return typeof key==="string"?operate("arrayIndex",key):undefined}
 function wrap(){
  const target=create(prototype);let wrapper;
  function indexed(key){const index=arrayIndex(key);if(index===undefined)return undefined;const value=operate("indexed",wrapper,index);if(value===undefined)return undefined;return {value,writable:false,enumerable:true,configurable:true}}
  wrapper=new P(target,{
   getOwnPropertyDescriptor(target,key){return indexed(key)||getOwn(target,key)},
   get(target,key,receiver){const property=indexed(key);return property?property.value:get(target,key,receiver)},
   has(target,key){return indexed(key)!==undefined||has(target,key)},
   set(target,key,value,receiver){if(indexed(key)!==undefined)return false;return set(target,key,value,receiver)},
   defineProperty(target,key,property){if(arrayIndex(key)!==undefined)return false;return defineOwn(target,key,property)},
   deleteProperty(target,key){if(arrayIndex(key)!==undefined)return indexed(key)===undefined;return remove(target,key)},
   preventExtensions(){return false},
   ownKeys(target){const keys=[];function append(key){define(keys,keys.length,{value:key,writable:true,enumerable:true,configurable:true})}for(let index=0;index<=4294967295;++index){if(operate("indexed",wrapper,index)===undefined)break;append(`${index}`)}const ordinary=ownKeys(target);for(const key of ordinary)if(typeof key==="string")append(key);for(const key of ordinary)if(typeof key==="symbol")append(key);return keys}
  });return wrapper;
 }
 return {prototype,wrap};
})'
