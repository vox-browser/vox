module browserjs

import webidl

fn test_source_native_shared_brand_never_uses_tostringtag_or_rejects_extra_internal_slots() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	// Preserve the pin's steps 22/23 FIXME: genuine Promise/WeakMap and Proxy
	// ordinary-object fallback is not replaced by a invented general slot gate.
	value := runtime.evaluate_host_value(r'globalThis.__sharedBrandReads=0;const fake={x:1};Object.defineProperty(fake,Symbol.toStringTag,{get(){++__sharedBrandReads;return "SharedArrayBuffer"}});({fake,promise:Promise.resolve(1),weak:new WeakMap(),proxy:new Proxy({y:2},{})})')!
	actual := bridge.clone(value)!
	runtime.define_value_host_function('__sharedBoundaryClone', fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
	assert runtime.evaluate_host(r'{const result=__sharedBoundaryClone();result.fake.x===1&&__sharedBrandReads===0&&Object.getPrototypeOf(result.promise)===Object.prototype&&Object.keys(result.promise).length===0&&Object.getPrototypeOf(result.weak)===Object.prototype&&result.proxy.y===2}')! == 'true'
}

fn test_source_native_shared_and_shared_views_reject_with_dataclone_when_engine_exposes_them() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	// This CAPI JSC currently omits SharedArrayBuffer. Keep real engine coverage
	// conditional; never fabricate an ordinary object as a shared buffer brand.
	if runtime.evaluate_host('typeof SharedArrayBuffer === "function"')! != 'true' { return }
	bridge := StructuredCloneBridge.create(runtime)!
	for source in ['new SharedArrayBuffer(4)', 'new Uint8Array(new SharedArrayBuffer(4))',
		'new DataView(new SharedArrayBuffer(4))'] {
		value := runtime.evaluate_host_value(source)!
		for for_storage in [false, true] {
			if _ := bridge.serialize(value, for_storage) { assert false } else {
				assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
			}
		}
	}
}
