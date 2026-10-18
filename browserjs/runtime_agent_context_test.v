module browserjs

fn C.JSContextGetGroup(context voidptr) voidptr

fn test_agent_vm_is_reused_without_sharing_page_globals_or_intrinsics() {
	mut first := Runtime.create()
	group := C.JSContextGetGroup(first.context)
	assert group != unsafe { nil }
	first.evaluate_host('globalThis.pageSecret=42; Object.prototype.pageSecret=17;')!
	mut second := Runtime.create()
	defer { second.close() }
	assert second.context != first.context
	assert C.JSContextGetGroup(second.context) == group
	assert second.evaluate_host('typeof pageSecret + ":" + typeof ({}).pageSecret')! == 'undefined:undefined'
	first.close()
	assert second.evaluate_host('6 * 7')! == '42'
	mut third := Runtime.create()
	defer { third.close() }
	assert C.JSContextGetGroup(third.context) == group
	assert third.evaluate_host('typeof pageSecret + ":" + typeof ({}).pageSecret')! == 'undefined:undefined'
}

fn report_worker_agent_group(groups chan voidptr, finish chan bool) {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	assert (runtime.evaluate_host('21 * 2') or { panic(err) }) == '42'
	groups <- C.JSContextGetGroup(runtime.context)
	_ := <-finish
}

fn test_agent_vm_groups_do_not_cross_threads() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	groups := chan voidptr{cap: 1}
	finish := chan bool{cap: 1}
	worker := spawn report_worker_agent_group(groups, finish)
	group := <-groups
	assert group != unsafe { nil }
	assert group != C.JSContextGetGroup(runtime.context)
	finish <- true
	worker.wait()
	assert runtime.evaluate_host('40 + 2')! == '42'
}
