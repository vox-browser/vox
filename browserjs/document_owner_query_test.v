module browserjs

import platform

@[heap]
struct DocumentOwnerReadProbe {
mut:
	calls int
	root bool = true
}

fn test_document_owner_query_reads_live_boolean_and_does_not_coerce_arguments() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	mut probe := &DocumentOwnerReadProbe{}
	runtime.install_document_owner_query(fn [mut probe] (key string) bool {
		probe.calls++
		return probe.root && key == 'root-é😀'
	})!
	assert runtime.evaluate_host('__ladybirdRootDocumentOwner("root-é😀")===true')! == 'true'
	assert runtime.evaluate_host('__ladybirdRootDocumentOwner("unknown")===false')! == 'true'
	assert probe.calls == 2
	assert runtime.evaluate_host(r'
const uncoerced={toString(){throw new Error("coerced")},[Symbol.toPrimitive](){throw new Error("coerced")}};
[undefined,null,1,Symbol(),uncoerced,new String("root-é😀")].every(value=>__ladybirdRootDocumentOwner(value)===false)&&__ladybirdRootDocumentOwner()===false&&__ladybirdRootDocumentOwner("root-é😀",1)===false
')! == 'true'
	assert probe.calls == 2
	probe.root = false
	assert runtime.evaluate_host('__ladybirdRootDocumentOwner("root-é😀")===false')! == 'true'
	assert probe.calls == 3
}

fn test_document_owner_query_keeps_runtime_owners_and_temporary_keys_separate() {
	$if !darwin && !linux { return }
	mut first := Runtime.create_with_engine(.javascriptcore)
	mut second := Runtime.create_with_engine(.javascriptcore)
	defer { first.close(); second.close() }
	first.install_document_owner_query(fn (key string) bool { return key == 'first' })!
	second.install_document_owner_query(fn (key string) bool { return key == 'second' })!
	for _ in 0 .. 12 {
		work := platform.begin_thread_scratch('document owner evaluation')
		assert first.evaluate_host('__ladybirdRootDocumentOwner("first")&&!__ladybirdRootDocumentOwner("second")')! == 'true'
		assert second.evaluate_host('__ladybirdRootDocumentOwner("second")&&!__ladybirdRootDocumentOwner("first")')! == 'true'
		work.finish()
		churn := platform.begin_thread_scratch('document owner key overwrite')
		_ = []u8{len:128 * 1024, init:u8(0xa5)}
		churn.finish()
	}
	first.close()
	assert second.evaluate_host('__ladybirdRootDocumentOwner("second")')! == 'true'
	if _ := first.install_document_owner_query(fn (_ string) bool { return true }) {
		assert false
	} else { assert err.msg().contains('closed') }
	mut unsupported := Runtime.create_with_engine(.libjs)
	defer { unsupported.close() }
	if _ := unsupported.install_document_owner_query(fn (_ string) bool { return true }) {
		assert false
	} else { assert err.msg().contains('JavaScriptCore') }
}
