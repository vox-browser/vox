module browserjs

import dom
import fileapi
import html
import libjs
import webidl

fn source_clone_file_runtime(address string, constructor bool) (&Runtime, &dom.Document) {
	mut runtime := Runtime.create()
	url := dom.URL{address}
	document := dom.Document.create(url)
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut blobs := BlobHost.create(document) or { panic(err) }
	blobs.install(mut runtime) or { panic(err) }
	blobs.install_constructor() or { panic(err) }
	mut files := FileHost.create(document) or { panic(err) }
	files.install(mut runtime) or { panic(err) }
	if constructor { files.install_constructor() or { panic(err) } }
	return runtime, document
}

fn test_source_file_clone_uses_actual_primary_file_before_blob_base_and_preserves_raw_payload() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_clone_file_runtime('https://source-file-clone.example.test/', true)
	defer {
		runtime.close()
		document.finalize()
	}
	bridge := StructuredCloneBridge.create(runtime)!
	name := libjs.utf16_string_from_code_units([u16(0xd800), 0, 0xdc00])
	type_ := libjs.utf16_string_from_code_units([u16(0xdc00), 0xd800])
	file := fileapi.File.create_utf16([u8(7), 9], name, type_, -7)
	actual := runtime.javascript_file(file)!
	runtime.define_value_host_function('__actualSourceFile', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	value := runtime.evaluate_host_value('globalThis.originalFileConstructor=File;globalThis.originalBlobConstructor=Blob;globalThis.sourceFileCloneOwnReads=0;const file=__actualSourceFile();for(const name of ["size","type","name","lastModified","custom"])Object.defineProperty(file,name,{enumerable:true,get(){++sourceFileCloneOwnReads;throw "author File getter"}});Object.setPrototypeOf(file,Blob.prototype);globalThis.File=function ForgedFile(){};globalThis.Blob=function ForgedBlob(){};({file,again:file})')!
	for storage in [false, true] {
		record := bridge.serialize(value, storage)!
		cloned := bridge.deserialize(record)!
		runtime.define_value_host_function('__sourceFileClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr {
			return cloned
		})!
		assert runtime.evaluate_host('{const file=__sourceFileClone().file;file===__sourceFileClone().again&&file instanceof originalFileConstructor&&file instanceof originalBlobConstructor&&Object.getPrototypeOf(file)===originalFileConstructor.prototype&&file.name===String.fromCharCode(0xd800,0,0xdc00)&&file.type===String.fromCharCode(0xdc00,0xd800)&&file.size===2&&file.lastModified===-7&&!Object.hasOwn(file,"custom")&&sourceFileCloneOwnReads===0}')! == 'true'
		cloned_file := runtime.native_file(runtime.evaluate_host_value('__sourceFileClone().file')!)!
		assert voidptr(cloned_file) != voidptr(file)
		assert voidptr(runtime.native_blob(runtime.evaluate_host_value('__sourceFileClone().file')!)!) == voidptr(&cloned_file.Blob)
		assert cloned_file.raw_bytes() == file.raw_bytes()
		assert cloned_file.name_utf16().code_units() == name.code_units()
		assert cloned_file.type_utf16().code_units() == type_.code_units()
		assert cloned_file.last_modified() == -7
	}
	descriptor := html.StructuredObject.create_file(file)
	assert bridge.serialize(actual, false)!.data == html.structured_serialize(html.structured_object_value(descriptor))!.data
	assert bridge.serialize(actual, true)!.data == html.structured_serialize_for_storage(html.structured_object_value(descriptor))!.data
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_source_file_clone_target_exposure_uses_actual_installed_file_interface() {
	$if !darwin {
		return
	}
	mut source, mut document := source_clone_file_runtime('https://source-file-exposure.example.test/', true)
	defer {
		source.close()
		document.finalize()
	}
	bridge := StructuredCloneBridge.create(source)!
	actual := source.javascript_file(fileapi.File.create([u8(1), 2], 'source.txt', 'text/plain', -4))!
	for storage in [false, true] {
		record := bridge.serialize(actual, storage)!
		mut absent, mut absent_document := source_clone_file_runtime('https://absent-file-exposure.example.test/', false)
		defer {
			absent.close()
			absent_document.finalize()
		}
		absent.evaluate_host('globalThis.File=function ForgedFile(){}')!
		absent_bridge := StructuredCloneBridge.create(absent)!
		if _ := absent_bridge.deserialize(record) {
			assert false
		} else {
			assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
		}
		mut target, mut target_document := source_clone_file_runtime('http://target-file-exposure.example.test/', true)
		defer {
			target.close()
			target_document.finalize()
		}
		target.evaluate_host('globalThis.actualTargetFile=File;delete globalThis.File')!
		target_bridge := StructuredCloneBridge.create(target)!
		cloned := target_bridge.deserialize(record)!
		target.define_value_host_function('__targetSourceFile', fn [cloned] (_ voidptr, _ []voidptr) !voidptr {
			return cloned
		})!
		assert target.evaluate_host('__targetSourceFile() instanceof actualTargetFile&&__targetSourceFile().name==="source.txt"&&__targetSourceFile().lastModified===-4&&__targetSourceFile().size===2')! == 'true'
		assert target.native_file(cloned)!.raw_bytes() == [u8(1), 2]
	}
}

fn test_source_file_clone_discrimination_ignores_author_prototypes_and_fake_fields() {
	$if !darwin {
		return
	}
	mut runtime, mut document := source_clone_file_runtime('https://source-file-brand.example.test/', true)
	defer {
		runtime.close()
		document.finalize()
	}
	bridge := StructuredCloneBridge.create(runtime)!
	actual_blob := runtime.evaluate_host_value('const blob=new Blob(["source"]);Object.setPrototypeOf(blob,File.prototype);blob')!
	cloned_blob := bridge.clone(actual_blob)!
	assert runtime.native_blob(cloned_blob)!.raw_bytes() == 'source'.bytes()
	if _ := runtime.native_file(cloned_blob) {
		assert false
	}
	fake := runtime.evaluate_host_value('Object.create(File.prototype,{name:{value:"ordinary",enumerable:true},lastModified:{value:-7,enumerable:true},type:{value:"text/plain",enumerable:true},size:{value:2,enumerable:true}})')!
	cloned_fake := bridge.clone(fake)!
	if _ := runtime.native_file(cloned_fake) {
		assert false
	}
	if _ := runtime.native_blob(cloned_fake) {
		assert false
	}
	runtime.define_value_host_function('__ordinaryFileCarrierClone', fn [cloned_fake] (_ voidptr, _ []voidptr) !voidptr {
		return cloned_fake
	})!
	assert runtime.evaluate_host('Object.getPrototypeOf(__ordinaryFileCarrierClone())===Object.prototype&&__ordinaryFileCarrierClone().name==="ordinary"&&__ordinaryFileCarrierClone().lastModified===-7')! == 'true'
}
