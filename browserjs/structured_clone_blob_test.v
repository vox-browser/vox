module browserjs

import dom
import fileapi
import html
import libjs
import webidl

fn source_clone_blob_runtime(address string, constructor bool) &Runtime {
	mut runtime := Runtime.create()
	url := dom.URL{value: address}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut host := BlobHost.create(document) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	if constructor { host.install_constructor() or { panic(err) } }
	return runtime
}

fn test_native_blob_clone_serializes_actual_source_record_without_author_getters_or_properties() {
	$if !darwin {
		return
	}
	mut runtime := source_clone_blob_runtime('https://native-blob-clone.example.test/', true)
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	type_ := libjs.utf16_string_from_code_units([u16(0xd800), 0, 0xdc00])
	blob := fileapi.Blob.create_utf16([u8(7), 9], type_)
	actual := runtime.javascript_blob(blob)!
	runtime.define_value_host_function('__actualCloneBlob', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	value := runtime.evaluate_host_value('globalThis.originalBlobConstructor=Blob;globalThis.blobCloneGetters=0;const blob=__actualCloneBlob();for(const name of ["size","type","text","arrayBuffer","bytes","custom"])Object.defineProperty(blob,name,{enumerable:true,get(){++blobCloneGetters;throw "author Blob getter"}});globalThis.Blob=function FakeBlob(){};({blob,again:blob})')!
	for storage in [false, true] {
		record := bridge.serialize(value, storage)!
		cloned := bridge.deserialize(record)!
		runtime.define_value_host_function('__nativeBlobClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr {
			return cloned
		})!
		assert runtime.evaluate_host('{const blob=__nativeBlobClone().blob;blob===__nativeBlobClone().again&&blob instanceof originalBlobConstructor&&Object.getPrototypeOf(blob)===originalBlobConstructor.prototype&&blob.size===2&&blob.type===String.fromCharCode(0xd800,0,0xdc00)&&!Object.hasOwn(blob,"custom")&&blobCloneGetters===0}')! == 'true'
		cloned_blob := runtime.native_blob(runtime.evaluate_host_value('__nativeBlobClone().blob')!)!
		assert voidptr(cloned_blob) != voidptr(blob)
		assert cloned_blob.raw_bytes() == [u8(7), 9]
		assert cloned_blob.type_utf16().code_units() == type_.code_units()
	}
	mut descriptor := html.StructuredObject.create_blob(blob)
	assert bridge.serialize(actual, false)!.data == html.structured_serialize(html.structured_object_value(descriptor))!.data
	assert bridge.serialize(actual, true)!.data == html.structured_serialize_for_storage(html.structured_object_value(descriptor))!.data
}

fn test_native_blob_clone_target_exposure_uses_actual_installed_interface_state() {
	$if !darwin {
		return
	}
	mut source := source_clone_blob_runtime('https://source-blob-exposure.example.test/', true)
	defer { source.close() }
	source_bridge := StructuredCloneBridge.create(source)!
	actual := source.javascript_blob(fileapi.Blob.create([u8(1), 2], 'text/plain'))!
	for storage in [false, true] {
		record := source_bridge.serialize(actual, storage)!
		mut absent := source_clone_blob_runtime('https://absent-blob-exposure.example.test/', false)
		defer { absent.close() }
		absent.evaluate_host('globalThis.Blob=function ForgedBlob(){}')!
		absent_bridge := StructuredCloneBridge.create(absent)!
		if _ := absent_bridge.deserialize(record) {
			assert false
		} else {
			assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
		}
		// Blob exposure includes insecure Window globals.
		mut target := source_clone_blob_runtime('http://target-blob-exposure.example.test/', true)
		defer { target.close() }
		target.evaluate_host('globalThis.actualTargetBlob=Blob;delete globalThis.Blob')!
		target_bridge := StructuredCloneBridge.create(target)!
		cloned := target_bridge.deserialize(record)!
		target.define_value_host_function('__targetNativeBlobClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr {
			return cloned
		})!
		assert target.evaluate_host('__targetNativeBlobClone() instanceof actualTargetBlob&&__targetNativeBlobClone().size===2&&__targetNativeBlobClone().type==="text/plain"')! == 'true'
		assert target.native_blob(cloned)!.raw_bytes() == [u8(1), 2]
	}
	// Author-created XHR compatibility objects retain ordinary object semantics.
	facade := source.evaluate_host_value('({__xhrBlobKey:7,size:2,type:"text/plain"})')!
	cloned_facade := source_bridge.clone(facade)!
	if _ := source.native_blob(cloned_facade) {
		assert false
	}
}
