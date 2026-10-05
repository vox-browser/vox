module browserjs

import dom
import fileapi

fn source_file_list_owner_runtime() (&Runtime, &FileListHost, &dom.Document) {
	mut runtime := Runtime.create()
	document := dom.Document.create(dom.URL{value: 'https://source-file-list.example.test/'})
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blobs := BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	mut files := FileHost.create(document) or { panic(err) }
	files.install(mut runtime) or { panic(err) }
	files.install_constructor() or { panic(err) }
	mut lists := FileListHost.create(document) or { panic(err) }
	lists.install(mut runtime) or { panic(err) }
	return runtime, lists, document
}

fn test_source_file_list_live_owner_indices_metadata_and_original_array_iterator() {
	$if !darwin {
		return
	}
	mut runtime, host, mut document := source_file_list_owner_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	mut list := fileapi.FileList.create()
	first := fileapi.File.create([u8(65)], 'first.txt', 'text/plain', -3)
	list.add_file(first)
	actual := runtime.javascript_file_list(list)!
	assert actual == runtime.javascript_file_list(list)!
	assert voidptr(runtime.native_file_list(actual)!) == voidptr(list)
	runtime.define_value_host_function('__sourceFileList', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	runtime.evaluate_host('globalThis.sourceList=__sourceFileList();globalThis.sourceListPrototype=Object.getPrototypeOf(sourceList);globalThis.sourceListValues=Array.prototype.values;globalThis.sourceListFirst=sourceList[0];globalThis.sourceListIterator=sourceList[Symbol.iterator]();')!
	assert voidptr(runtime.native_file(runtime.evaluate_host_value('sourceListFirst')!)!) == voidptr(first)
	assert runtime.evaluate_host('sourceList.length===1&&sourceList.item(0)===sourceListFirst&&sourceList[1]===undefined&&sourceList.item(1)===null&&sourceListFirst instanceof File&&sourceListFirst.name==="first.txt"&&sourceListFirst.lastModified===-3&&Object.prototype.toString.call(sourceList)==="[object FileList]"&&Object.getPrototypeOf(sourceListPrototype)===Object.prototype&&Reflect.ownKeys(sourceList).join() === "0"')! == 'true'
	assert runtime.evaluate_host('{const d=Object.getOwnPropertyDescriptor(sourceList,"0");d.value===sourceListFirst&&!d.writable&&d.enumerable&&d.configurable}')! == 'true'
	assert runtime.evaluate_host('{const get=Object.getOwnPropertyDescriptor,length=get(sourceListPrototype,"length"),item=get(sourceListPrototype,"item"),iterator=get(sourceListPrototype,Symbol.iterator),tag=get(sourceListPrototype,Symbol.toStringTag);length.get.name==="get length"&&length.get.length===0&&!Object.hasOwn(length.get,"prototype")&&length.set===undefined&&length.enumerable&&length.configurable&&item.value.name==="item"&&item.value.length===1&&!Object.hasOwn(item.value,"prototype")&&item.writable&&item.enumerable&&item.configurable&&iterator.value===sourceListValues&&iterator.writable&&!iterator.enumerable&&iterator.configurable&&tag.value==="FileList"&&!tag.writable&&!tag.enumerable&&tag.configurable}')! == 'true'
	assert runtime.evaluate_host('sourceListIterator.next().value===sourceListFirst')! == 'true'
	second := fileapi.File.create([u8(66)], 'second.txt', '', 8)
	list.add_file(second)
	assert runtime.evaluate_host('sourceList.length===2&&sourceList[1]===sourceList.item(1)&&sourceListIterator.next().value===sourceList[1]&&sourceListIterator.next().done&&Reflect.ownKeys(sourceList).join()==="0,1"')! == 'true'
	assert voidptr(runtime.native_file(runtime.evaluate_host_value('sourceList[1]')!)!) == voidptr(second)
	runtime.evaluate_host('globalThis.sourceListOriginalKeys=Reflect.ownKeys;globalThis.sourceListOriginalGet=Object.getOwnPropertyDescriptor;globalThis.sourceListOriginalValues=Array.prototype.values;Reflect.ownKeys=function(){throw "author Reflect"};Object.getOwnPropertyDescriptor=function(){throw "author descriptor"};Array.prototype.values=function(){throw "author values"};globalThis.FileList=function ForgedFileList(){};')!
	assert runtime.evaluate_host('sourceListOriginalKeys(sourceList).join()==="0,1"&&sourceList[Symbol.iterator]===sourceListOriginalValues&&sourceListOriginalGet(sourceList,"1").value===sourceList[1]')! == 'true'
	assert host.constructor == unsafe { nil }
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_file_list_exact_legacy_set_define_delete_extensibility_and_ordinary_storage() {
	$if !darwin {
		return
	}
	mut runtime, _, mut document := source_file_list_owner_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	mut list := fileapi.FileList.create()
	list.add_file(fileapi.File.create([u8(1)], 'one', '', 0))
	actual := runtime.javascript_file_list(list)!
	runtime.define_value_host_function('__sourceFileList', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	runtime.evaluate_host('globalThis.sourceList=__sourceFileList();globalThis.sourceListFirst=sourceList[0];')!
	assert runtime.evaluate_host('!Reflect.set(sourceList,"0",null)&&!Reflect.set(sourceList,"1",null)&&!Reflect.defineProperty(sourceList,"0",{value:null})&&!Reflect.defineProperty(sourceList,"1",{get(){return null}})&&!Reflect.defineProperty(sourceList,"2",{})&&!Reflect.deleteProperty(sourceList,"0")&&Reflect.deleteProperty(sourceList,"1")&&!Reflect.preventExtensions(sourceList)&&Object.isExtensible(sourceList)&&sourceList[0]===sourceListFirst&&sourceList.length===1')! == 'true'
	assert runtime.evaluate_host('{let threw=false;try{Object.freeze(sourceList)}catch(reason){threw=reason instanceof TypeError}threw&&Object.isExtensible(sourceList)}')! == 'true'
	assert runtime.evaluate_host('{let threw=false;try{(function(){"use strict";sourceList[0]=null})()}catch(reason){threw=reason instanceof TypeError}threw}')! == 'true'
	runtime.evaluate_host('globalThis.sourceListSymbol=Symbol("ordinary");sourceList.z=3;Object.defineProperty(sourceList,"00",{value:4,enumerable:true,configurable:true});sourceList[sourceListSymbol]=5;sourceList["4294967295"]=6;Object.defineProperty(sourceList,"-0",{get(){return this.z+4},enumerable:true,configurable:true});')!
	assert runtime.evaluate_host('Reflect.ownKeys(sourceList).map(key=>typeof key==="symbol"?"symbol":key).join()==="0,z,00,4294967295,-0,symbol"&&sourceList["00"]===4&&sourceList["4294967295"]===6&&sourceList["-0"]===7&&sourceList[sourceListSymbol]===5&&Reflect.deleteProperty(sourceList,"z")&&!Object.hasOwn(sourceList,"z")')! == 'true'
	assert runtime.evaluate_host('{const child=Object.create(sourceList);!Reflect.set(sourceList,"0",null,child)&&Reflect.set(sourceList,"ordinary",9,child)&&child.ordinary===9&&!Object.hasOwn(sourceList,"ordinary")}')! == 'true'
	assert runtime.evaluate_host('{const prototype=Object.create(Object.getPrototypeOf(sourceList));let received;Object.defineProperty(prototype,"5",{set(value){received=[this,value]}});Object.setPrototypeOf(sourceList,prototype);Reflect.set(sourceList,"5",12)&&received[0]===sourceList&&received[1]===12&&!Object.hasOwn(sourceList,"5")}')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_file_list_generated_item_conversion_brand_and_error_identity() {
	$if !darwin {
		return
	}
	mut runtime, _, mut document := source_file_list_owner_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	mut list := fileapi.FileList.create()
	list.add_file(fileapi.File.create([u8(1)], 'one', '', 0))
	actual := runtime.javascript_file_list(list)!
	runtime.define_value_host_function('__sourceFileList', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	runtime.evaluate_host('globalThis.sourceList=__sourceFileList();globalThis.sourceListPrototype=Object.getPrototypeOf(sourceList);globalThis.sourceListConversionError={original:true};')!
	assert runtime.evaluate_host('sourceList.item(undefined)===sourceList[0]&&sourceList.item(NaN)===sourceList[0]&&sourceList.item(Infinity)===sourceList[0]&&sourceList.item(4294967296)===sourceList[0]&&sourceList.item(-1)===null&&sourceList.item({valueOf(){return 0}})===sourceList[0]')! == 'true'
	assert runtime.evaluate_host('{try{sourceList.item();false}catch(reason){reason instanceof TypeError&&reason.message==="item() needs one argument"}}')! == 'true'
	assert runtime.evaluate_host('{try{sourceList.item({valueOf(){throw sourceListConversionError}});false}catch(reason){reason===sourceListConversionError}}')! == 'true'
	assert runtime.evaluate_host('[1n,Symbol("index")].every(value=>{try{sourceList.item(value);return false}catch(reason){return reason instanceof TypeError}})')! == 'true'
	assert runtime.evaluate_host('{let converted=false;try{sourceListPrototype.item.call(Object.create(sourceListPrototype),{valueOf(){converted=true;return 0}});false}catch(reason){reason instanceof TypeError&&reason.message==="Not an object of type FileList"&&!converted}}')! == 'true'
	assert runtime.evaluate_host('{const getter=Object.getOwnPropertyDescriptor(sourceListPrototype,"length").get;[null,undefined,{},new Proxy(sourceList,{})].every(value=>{try{getter.call(value);return false}catch(reason){return reason instanceof TypeError&&reason.message==="Not an object of type FileList"}})}')! == 'true'
	if _ := runtime.native_file_list(runtime.evaluate_host_value('Object.create(sourceListPrototype)')!) {
		assert false
	}
	assert !runtime.libjs_vm().has_running_execution_context()
}
