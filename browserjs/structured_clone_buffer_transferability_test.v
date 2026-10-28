module browserjs

fn test_native_buffer_clone_keeps_source_and_result_detachable_including_empty_buffers() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	for length in [0, 3] {
		for for_storage in [false, true] {
			source := runtime.evaluate_host_value('globalThis.source=new ArrayBuffer(' + length.str() + ');globalThis.sourceView=new Uint8Array(source);sourceView.fill(42);source')!
			actual := bridge.deserialize(bridge.serialize(source, for_storage)!)!
			binding := '__detachableClone' + length.str() + if for_storage { 'Storage' } else { 'IPC' }
			runtime.define_value_host_function(binding, fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
			assert runtime.evaluate_host('globalThis.cloned=' + binding + '();globalThis.clonedView=new Uint8Array(cloned);cloned!==source&&!source.detached&&!cloned.detached&&clonedView.length===' + length.str() + '&&clonedView.every(value=>value===42)')! == 'true'
			assert runtime.evaluate_host('source.transfer();cloned.transfer();source.detached&&cloned.detached&&sourceView.byteLength===0&&clonedView.byteLength===0')! == 'true'
		}
	}
}

fn test_native_buffer_clone_copies_without_author_constructors_species_iterators_or_set() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	source := runtime.evaluate_host_value(r'
 globalThis.buffer=new ArrayBuffer(3);new Uint8Array(buffer).set([0,128,255]);
 globalThis.OriginalUint8=Uint8Array;
 const poison=()=>{throw new Error("author byte operation")};
 Object.defineProperty(buffer,"constructor",{get:poison});
 Object.defineProperty(Uint8Array,Symbol.species,{get:poison});
 Uint8Array.prototype[Symbol.iterator]=poison;
 Object.getPrototypeOf(Uint8Array.prototype).set=poison;
 ArrayBuffer.prototype.slice=poison;
 globalThis.Uint8Array=poison;Reflect.apply=poison;buffer;
 ')!
	actual := bridge.clone(source)!
	runtime.define_value_host_function('__unpoisonedClone', fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
	assert runtime.evaluate_host('const cloned=__unpoisonedClone(),view=new OriginalUint8(cloned);view.length===3&&view[0]===0&&view[1]===128&&view[2]===255')! == 'true'
	assert runtime.evaluate_host('buffer.transfer();__unpoisonedClone().transfer();buffer.detached&&__unpoisonedClone().detached')! == 'true'
}
