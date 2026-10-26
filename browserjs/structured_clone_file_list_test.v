module browserjs

import dom
import fileapi
import html
import libjs
import webidl

fn source_clone_file_list_runtime(list_constructor bool, file_constructor bool) (&Runtime, &dom.Document) {
	mut runtime := Runtime.create()
	document := dom.Document.create(dom.URL{value: 'http://source-file-list-clone.example.test/'})
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blobs := BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	mut files := FileHost.create(document) or { panic(err) }
	files.install(mut runtime) or { panic(err) }
	if file_constructor { files.install_constructor() or { panic(err) } }
	mut lists := FileListHost.create(document) or { panic(err) }
	lists.install(mut runtime) or { panic(err) }
	if list_constructor { lists.install_constructor() or { panic(err) } }
	return runtime, document
}

fn test_source_file_list_native_clone_exact_primary_payload_and_source_nested_identity_rules() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_clone_file_list_runtime(true, true)
	defer {
		runtime.close()
		document.finalize()
	}
	bridge := StructuredCloneBridge.create(runtime)!
	name := libjs.utf16_string_from_code_units([u16(0xd800), 0, 0xdc00])
	type_ := libjs.utf16_string_from_code_units([u16(0xdc00), 0xd800])
	file := fileapi.File.create_utf16([u8(0), 128, 255], name, type_, -7)
	mut list := fileapi.FileList.create()
	list.add_file(file)
	list.add_file(file)
	actual := runtime.javascript_file_list(list)!
	file_wrapper := runtime.javascript_file(file)!
	runtime.define_value_host_function('__sourceFileList', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	runtime.define_value_host_function('__sourceFile', fn [file_wrapper] (_ voidptr, _ []voidptr) !voidptr {
		return file_wrapper
	})!
	value := runtime.evaluate_host_value('globalThis.sourceFileListOriginal=FileList;globalThis.sourceFileOriginal=File;globalThis.sourceFileListCloneOwnReads=0;globalThis.sourceList=__sourceFileList();for(const name of ["length","item","custom"])Object.defineProperty(sourceList,name,{enumerable:true,get(){++sourceFileListCloneOwnReads;throw "author FileList getter"}});Object.setPrototypeOf(sourceList,null);for(const name of ["type","name","lastModified"])Object.defineProperty(__sourceFile(),name,{get(){++sourceFileListCloneOwnReads;throw "author File getter"}});globalThis.FileList=function ForgedFileList(){};globalThis.File=function ForgedFile(){};({list:sourceList,again:sourceList,file:__sourceFile()})')!
	for storage in [false, true] {
		record := bridge.serialize(value, storage)!
		cloned := bridge.deserialize(record)!
		runtime.define_value_host_function('__sourceFileListClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr {
			return cloned
		})!
		assert runtime.evaluate_host('{const result=__sourceFileListClone(),list=result.list;list===result.again&&list instanceof sourceFileListOriginal&&Object.getPrototypeOf(list)===sourceFileListOriginal.prototype&&list.length===2&&list[0]===list.item(0)&&list[0] instanceof sourceFileOriginal&&list[0]!==list[1]&&list[0]!==result.file&&list[1]!==result.file&&list[0].name===String.fromCharCode(0xd800,0,0xdc00)&&list[0].type===String.fromCharCode(0xdc00,0xd800)&&list[0].lastModified===-7&&list[0].size===3&&!Object.hasOwn(list,"custom")&&sourceFileListCloneOwnReads===0}')! == 'true'
		cloned_list := runtime.native_file_list(runtime.evaluate_host_value('__sourceFileListClone().list')!)!
		assert voidptr(cloned_list) != voidptr(list)
		assert cloned_list.length() == 2
		first := cloned_list.item(0)?
		second := cloned_list.item(1)?
		assert voidptr(first) != voidptr(second)
		assert voidptr(first) != voidptr(file)
		assert first.name_utf16().code_units() == name.code_units()
		assert first.type_utf16().code_units() == type_.code_units()
		assert first.last_modified() == -7
		assert first.raw_bytes() == file.raw_bytes()
		assert voidptr(runtime.native_blob(runtime.evaluate_host_value('__sourceFileListClone().list[0]')!)!) == voidptr(&first.Blob)
	}
	descriptor := html.StructuredObject.create_file_list(list)
	assert bridge.serialize(actual, false)!.data == html.structured_serialize(html.structured_object_value(descriptor))!.data
	assert bridge.serialize(actual, true)!.data == html.structured_serialize_for_storage(html.structured_object_value(descriptor))!.data
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_file_list_clone_target_exposure_and_direct_nested_file_gate_bypass() {
	$if !darwin {
		return
	}
	mut source, mut source_document := source_clone_file_list_runtime(true, true)
	defer {
		source.close()
		source_document.finalize()
	}
	bridge := StructuredCloneBridge.create(source)!
	mut list := fileapi.FileList.create()
	list.add_file(fileapi.File.create([u8(7)], 'source.txt', 'text/plain', -5))
	actual := source.javascript_file_list(list)!
	for storage in [false, true] {
		record := bridge.serialize(actual, storage)!
		mut absent, mut absent_document := source_clone_file_list_runtime(false, true)
		defer {
			absent.close()
			absent_document.finalize()
		}
		absent.evaluate_host('globalThis.FileList=function ForgedFileList(){}')!
		absent_bridge := StructuredCloneBridge.create(absent)!
		if _ := absent_bridge.deserialize(record) {
			assert false
		} else {
			assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
		}
		// Source FileList.cpp directly creates/deserializes nested Files and
		// bypasses the general inner File exposure/memory path.
		mut target, mut target_document := source_clone_file_list_runtime(true, false)
		defer {
			target.close()
			target_document.finalize()
		}
		target.evaluate_host('globalThis.sourceFileListTargetOriginal=FileList;delete globalThis.FileList;globalThis.File=function ForgedFile(){}')!
		target_bridge := StructuredCloneBridge.create(target)!
		cloned := target_bridge.deserialize(record)!
		target.define_value_host_function('__sourceFileListClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr {
			return cloned
		})!
		assert target.evaluate_host('__sourceFileListClone() instanceof sourceFileListTargetOriginal&&__sourceFileListClone().length===1&&__sourceFileListClone()[0].name==="source.txt"&&__sourceFileListClone()[0].lastModified===-5&&__sourceFileListClone()[0].size===1')! == 'true'
		assert target.native_file_list(cloned)!.item(0)?.raw_bytes() == [u8(7)]
		// Materialize the optional reference before forwarding it: current V
		// otherwise passes the address of the option payload as the File itself.
		file := list.item(0)?
		file_wrapper := source.javascript_file(file)!
		assert voidptr(source.native_file(file_wrapper)!) == voidptr(file)
		file_record := bridge.serialize(file_wrapper, storage)!
		if _ := target_bridge.deserialize(file_record) {
			assert false
		} else {
			assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
		}
	}
}

fn test_source_file_list_native_clone_ignores_forged_author_prototypes_and_fields() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_clone_file_list_runtime(true, true)
	defer {
		runtime.close()
		document.finalize()
	}
	bridge := StructuredCloneBridge.create(runtime)!
	fake := runtime.evaluate_host_value('Object.create(FileList.prototype,{length:{value:1,enumerable:true},"0":{value:"ordinary",enumerable:true}})')!
	cloned := bridge.clone(fake)!
	if _ := runtime.native_file_list(cloned) {
		assert false
	}
	runtime.define_value_host_function('__sourceFileListOrdinaryClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr {
		return cloned
	})!
	assert runtime.evaluate_host('Object.getPrototypeOf(__sourceFileListOrdinaryClone())===Object.prototype&&__sourceFileListOrdinaryClone().length===1&&__sourceFileListOrdinaryClone()[0]==="ordinary"')! == 'true'
	assert !runtime.libjs_vm().has_running_execution_context()
}
