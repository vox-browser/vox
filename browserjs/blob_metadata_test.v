module browserjs

import dom
import fileapi

fn test_source_blob_prototype_native_function_metadata_and_property_descriptors() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{'https://source-blob-metadata.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut host := BlobHost.create(document)!
	host.install(mut runtime)!
	actual := runtime.javascript_blob(fileapi.Blob.create([]u8{}, ''))!
	runtime.define_value_host_function('__metadataBlob', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	assert runtime.evaluate_host('const prototype=Object.getPrototypeOf(__metadataBlob());const get=Object.getOwnPropertyDescriptor;function nonConstructor(value){if(Object.hasOwn(value,"prototype"))return false;try{Reflect.construct(value,[]);return false}catch(reason){return reason instanceof TypeError}};["size","type"].every(name=>{const d=get(prototype,name);return d.get.name==="get "+name&&d.get.length===0&&nonConstructor(d.get)&&d.set===undefined&&d.enumerable&&d.configurable})&&["slice","stream","text","arrayBuffer","bytes"].every(name=>{const d=get(prototype,name);return d.value.name===name&&d.value.length===0&&nonConstructor(d.value)&&d.writable&&d.enumerable&&d.configurable})&&get(prototype,Symbol.toStringTag).value==="Blob"&&get(prototype,Symbol.toStringTag).writable===false&&get(prototype,Symbol.toStringTag).enumerable===false&&get(prototype,Symbol.toStringTag).configurable')! == 'true'
}
