// Production executable regression: checks must run when -prod removes assert.
module main

import browserjs

fn main() {
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	chunk := runtime.evaluate_host_value('globalThis.actualChunk={answer:42};actualChunk') or { panic(err) }
	runtime.define_value_host_function('__nativeChunk', fn [chunk] (_ voidptr, args []voidptr) !voidptr {
		if args.len > 0 { return args[0] }
		return chunk
	}) or { panic(err) }
	identity := runtime.evaluate_host('const cycle={};cycle.self=cycle;const symbol=Symbol("actual");__nativeChunk()===actualChunk && __nativeChunk(cycle)===cycle && __nativeChunk(symbol)===symbol') or { panic(err) }
	if identity != 'true' { panic('Native callback lost actual JavaScript chunk identity') }
	capability := runtime.create_javascript_promise() or { panic(err) }
	runtime.define_value_host_function('__nativePromise', fn [capability] (_ voidptr, _ []voidptr) !voidptr { return capability.promise }) or { panic(err) }
	pending := runtime.evaluate_host('globalThis.settled=[];const promise=__nativePromise();promise.then(value=>settled.push(value));promise instanceof Promise && promise===__nativePromise() && settled.length===0') or { panic(err) }
	if pending != 'true' { panic('Native Promise capability lost pending state or actual identity') }
	thenable := runtime.evaluate_host_value('({then(resolve){Promise.resolve().then(()=>resolve(actualChunk))}})') or { panic(err) }
	runtime.resolve_javascript_promise(capability, thenable) or { panic(err) }
	settled := runtime.evaluate_host('settled.length===1 && settled[0]===actualChunk') or { panic(err) }
	if settled != 'true' { panic('Real engine thenable adoption lost actual fulfillment value') }
	runtime.release_javascript_promise(capability)
	println('Native production JavaScript values and Promise capabilities passed')
}
