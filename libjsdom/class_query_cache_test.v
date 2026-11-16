module libjsdom

import dom
import html
import libjs

fn class_cache_run(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'class-cache.js', unsafe { nil })!
	return vm.run(mut script)
}

fn test_class_collection_cache_remains_live_and_scoped_to_root_and_query() {
	for enabled in [false, true] {
		set_class_query_cache_for_testing(enabled)
		mut document := html.parse_document('<body><div id="r" class="x"><i id="a" class="x"></i><i id="b"></i></div></body>')
		document.set_browsing_context(&dom.BrowsingContext{active_document_:document})
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		mut host := Host.create(vm, vm.realm(), document, Hooks{})!
		defer { host.close() }
		diagnose_class_query_cache_for_testing(true)
		assert class_cache_run(mut vm, 'var r=document.getElementById("r"),a=document.getElementById("a"),b=document.getElementById("b");var c=r.getElementsByClassName("x");c.length===1&&c[0]===a')!.to_boolean()
		assert class_cache_run(mut vm, 'r.getElementsByClassName("x").length===1')!.to_boolean()
		assert (diagnose_class_query_cache_for_testing(false) > 0) == enabled
		assert class_cache_run(mut vm, 'b.className="x";c.length===2&&r.getElementsByClassName("x")[1]===b')!.to_boolean()
		assert class_cache_run(mut vm, 'a.remove();c.length===1&&c[0]===b&&document.getElementsByClassName("x").length===2')!.to_boolean()
		assert class_cache_run(mut vm, 'r.getElementsByClassName("missing").length===0&&r.getElementsByClassName(" ").length===0')!.to_boolean()
		if enabled { assert class_cache_run(mut vm, 'c===r.getElementsByClassName("x")')!.to_boolean() }
	}
	set_class_query_cache_for_testing(true)
}

fn test_class_collection_cache_bounds_and_quirks_mode_changes() {
	mut document := html.parse_document('<body><i class="X"></i></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	document.set_quirks_mode(.no)
	assert host.class_collection(document.as_node(), 'x').length() == 0
	document.set_quirks_mode(.yes)
	assert host.class_collection(document.as_node(), 'x').length() == 1
	for index in 0 .. 300 { host.class_collection(document.as_node(), 'class-${index}') }
	assert host.class_query_cache.len <= class_query_cache_limit
	host.close()
	assert host.class_query_cache.len == 0
}

fn test_class_collection_cache_validates_collisions_and_owns_filter_input() {
	mut document := html.parse_document('<body><i class="X"></i></body>')
	document.set_quirks_mode(.no)
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	mut input := 'X'.bytes()
	first := host.class_collection(document.as_node(), input.bytestr())
	input[0] = `Y`
	assert first.length() == 1
	key := host.class_query_cache.keys()[0]
	host.class_query_cache[key] = ClassQueryCacheEntry{
		root: document.document_element()?.as_node(), document: document,
		quirks: false, query: 'X', collection: first
	}
	second := host.class_collection(document.as_node(), 'X')
	assert voidptr(second) != voidptr(first) && second.length() == 1
	count := host.class_query_cache.len
	host.class_collection(document.as_node(), 'x'.repeat(129))
	assert host.class_query_cache.len == count
}
