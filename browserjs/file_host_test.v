module browserjs

import dom
import fileapi
import html
import libjs

fn source_file_owner_runtime() (&Runtime, &FileHost, &dom.Document) {
	mut runtime := Runtime.create()
	url := dom.URL{value: 'https://source-file-owner.example.test/'}
	document := dom.Document.create(url)
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blobs := BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	mut files := FileHost.create(document) or { panic(err) }
	files.install(mut runtime) or { panic(err) }
	return runtime, files, document
}

fn test_source_file_owner_reuses_embedded_blob_and_preserves_native_getter_metadata() {
	$if !darwin {
		return
	}
	mut runtime, host, mut document := source_file_owner_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	name := libjs.utf16_string_from_code_units([u16(0xd800), 0, 0xdc00])
	type_ := libjs.utf16_string_from_code_units([u16(0xdc00), 0xd800])
	file := fileapi.File.create_utf16([u8(0), 128, 255], name, type_, -7)
	actual := runtime.javascript_file(file)!
	assert actual == runtime.javascript_file(file)!
	assert actual == runtime.javascript_blob(&file.Blob)!
	assert voidptr(runtime.native_file(actual)!) == voidptr(file)
	assert voidptr(runtime.native_blob(actual)!) == voidptr(&file.Blob)
	runtime.define_value_host_function('__sourceFile', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	runtime.evaluate_host('globalThis.sourceFile=__sourceFile();')!
	assert runtime.evaluate_host('sourceFile instanceof Blob&&Object.getPrototypeOf(Object.getPrototypeOf(sourceFile))===Blob.prototype&&sourceFile.size===3&&sourceFile.name===String.fromCharCode(0xd800,0,0xdc00)&&sourceFile.type===String.fromCharCode(0xdc00,0xd800)&&sourceFile.lastModified===-7&&Object.prototype.toString.call(sourceFile)==="[object File]"')! == 'true'
	assert runtime.evaluate_host('const prototype=Object.getPrototypeOf(sourceFile),get=Object.getOwnPropertyDescriptor;["name","lastModified"].every(name=>{const property=get(prototype,name);return property.enumerable&&property.configurable&&property.set===undefined&&property.get.name==="get "+name&&property.get.length===0&&!Object.hasOwn(property.get,"prototype")});')! == 'true'
	assert runtime.evaluate_host('const tag=get(Object.getPrototypeOf(sourceFile),Symbol.toStringTag);tag.value==="File"&&!tag.writable&&!tag.enumerable&&tag.configurable&&["name","lastModified"].every(name=>{try{get(Object.getPrototypeOf(sourceFile),name).get.call(new Blob());return false}catch(reason){return reason instanceof TypeError}})')! == 'true'
	runtime.evaluate_host('globalThis.sourceFileOwnReads=0;for(const name of ["size","type","name","lastModified","toString"])Object.defineProperty(sourceFile,name,{get(){++sourceFileOwnReads;throw "author File getter"}});globalThis.sourceFileCopy=new Blob([sourceFile]);globalThis.sourceFileSlice=Blob.prototype.slice.call(sourceFile,1);')!
	copy := runtime.native_blob(runtime.evaluate_host_value('sourceFileCopy')!)!
	assert copy.raw_bytes() == file.raw_bytes()
	slice := runtime.native_blob(runtime.evaluate_host_value('sourceFileSlice')!)!
	assert slice.raw_bytes() == [u8(128), 255]
	if _ := runtime.native_file(runtime.evaluate_host_value('sourceFileSlice')!) {
		assert false
	}
	assert runtime.evaluate_host('sourceFileOwnReads===0')! == 'true'
	assert host.constructor == unsafe { nil }
	assert runtime.evaluate_host('typeof File')! == 'undefined'
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_file_inherited_bytes_reads_use_same_actual_blob_owner_and_file_reading_tasks() {
	$if !darwin {
		return
	}
	mut runtime, host, mut document := source_file_owner_runtime()
	defer {
		runtime.close()
		document.finalize()
	}
	file := fileapi.File.create([u8(65), 66], 'source.txt', 'text/plain', 4)
	actual := runtime.javascript_file(file)!
	runtime.define_value_host_function('__sourceFile', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	runtime.evaluate_host('globalThis.sourceFileBytesDone=false;globalThis.sourceFileBytesFailure=null;globalThis.sourceFilePending=__sourceFile().bytes();sourceFilePending.then(view=>{sourceFileBytesDone=view instanceof Uint8Array&&view[0]===65&&view[1]===66},reason=>sourceFileBytesFailure=reason);')!
	assert runtime.evaluate_host('sourceFilePending instanceof Promise&&!sourceFileBytesDone&&sourceFileBytesFailure===null')! == 'true'
	mut queue := host.settings.responsible_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
		return task.source() == .file_reading
	})?
	assert task.document() == host.settings.responsible_document()
	task.execute()
	assert runtime.evaluate_host('sourceFileBytesDone&&sourceFileBytesFailure===null')! == 'true'
	assert voidptr(runtime.native_blob(actual)!) == voidptr(&file.Blob)
	assert !runtime.libjs_vm().has_running_execution_context()
}
