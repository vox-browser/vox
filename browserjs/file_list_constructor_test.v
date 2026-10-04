module browserjs

import dom
import fileapi

fn source_file_list_constructor_runtime() (&Runtime, &FileListHost, &dom.Document) {
	mut runtime := Runtime.create()
	document := dom.Document.create(dom.URL{'https://source-file-list-constructor.example.test/'})
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

fn test_source_file_list_interface_constructor_exact_descriptors_and_rejected_calls() {
	$if !darwin {
		return
	}
	mut runtime, mut host, mut document := source_file_list_constructor_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host('typeof FileList')! == 'undefined'
	host.install_constructor()!
	retained := host.constructor
	host.install_constructor()!
	assert retained == host.constructor
	mut list := fileapi.FileList.create()
	list.add_file(fileapi.File.create([u8(1)], 'one', '', 0))
	actual := runtime.javascript_file_list(list)!
	runtime.define_value_host_function('__sourceFileList', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.evaluate_host('{const get=Object.getOwnPropertyDescriptor,global=get(globalThis,"FileList"),name=get(FileList,"name"),length=get(FileList,"length"),prototype=get(FileList,"prototype"),constructor=get(FileList.prototype,"constructor");FileList.name==="FileList"&&FileList.length===0&&Object.getPrototypeOf(FileList)===Function.prototype&&Reflect.ownKeys(FileList).join()==="length,name,prototype"&&!name.writable&&!name.enumerable&&name.configurable&&!length.writable&&!length.enumerable&&length.configurable&&!prototype.writable&&!prototype.enumerable&&!prototype.configurable&&constructor.value===FileList&&constructor.writable&&!constructor.enumerable&&constructor.configurable&&global.value===FileList&&global.writable&&!global.enumerable&&global.configurable&&__sourceFileList() instanceof FileList&&Object.getPrototypeOf(__sourceFileList())===FileList.prototype}')! == 'true'
	assert runtime.evaluate_host('{try{FileList();false}catch(reason){reason instanceof TypeError&&reason.message==="FileList constructor must be called with \u0027new\u0027"}}')! == 'true'
	assert runtime.evaluate_host('{try{new FileList();false}catch(reason){reason instanceof TypeError&&reason.message==="FileList is not a constructor"}}')! == 'true'
	assert runtime.evaluate_host('{let reads=0;const NewTarget=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype"){++reads;throw "author prototype"}return Reflect.get(target,key,receiver)}});try{Reflect.construct(FileList,[{valueOf(){throw "author argument"}}],NewTarget);false}catch(reason){reason instanceof TypeError&&reason.message==="FileList is not a constructor"&&reads===0}}')! == 'true'
	assert runtime.evaluate_host('{class Derived extends FileList{};try{new Derived();false}catch(reason){reason instanceof TypeError&&reason.message==="FileList is not a constructor"}}')! == 'true'
	assert runtime.evaluate_host('Object.getPrototypeOf(Reflect.construct(function(){},[],FileList))===FileList.prototype')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_file_list_interface_constructor_installs_on_actual_global_and_retains_owner() {
	$if !darwin {
		return
	}
	mut runtime, mut host, mut document := source_file_list_constructor_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host('globalThis.sourceFileListActualGlobal=globalThis;globalThis.sourceFileListFalseGlobal={};Object.defineProperty(globalThis,"globalThis",{value:sourceFileListFalseGlobal,writable:true,configurable:true});')!
	host.install_constructor()!
	assert runtime.evaluate_host('typeof sourceFileListActualGlobal.FileList==="function"&&!Object.hasOwn(sourceFileListFalseGlobal,"FileList")')! == 'true'
	runtime.evaluate_host('sourceFileListActualGlobal.globalThis=sourceFileListActualGlobal;globalThis.sourceFileListOriginal=FileList;globalThis.FileList=function ForgedFileList(){};')!
	actual := runtime.javascript_file_list(fileapi.FileList.create())!
	runtime.define_value_host_function('__sourceFileList', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.evaluate_host('__sourceFileList() instanceof sourceFileListOriginal&&!(__sourceFileList() instanceof FileList)&&__sourceFileList().length===0&&Object.getPrototypeOf(__sourceFileList())===sourceFileListOriginal.prototype')! == 'true'
	assert voidptr(runtime.native_file_list(actual)!) == voidptr(host.record(actual)!.list)
	assert !runtime.libjs_vm().has_running_execution_context()
}
