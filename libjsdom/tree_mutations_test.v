// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn tree_fixture() !(&Host, &libjs.VM, &dom.Document) {
	address := dom.URL{value: 'https://libjs-tree.test/'}
	mut document := html.parse_navigation_document('<head><title>Tree</title></head><body><div id="host"><span id="a">A</span><span id="b">B</span><span id="c">C</span></div></body>', address, address.origin(), none)!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm, document
}

fn tree_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-tree.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_node_insert_before_moves_actual_native_children_and_retains_wrapper_identity() {
	mut host, mut vm, document := tree_fixture()!
	defer { host.close() }
	assert tree_eval(mut vm, 'var h=document.getElementById("host"),a=document.getElementById("a"),b=document.getElementById("b"),c=document.getElementById("c");h.insertBefore(b,a)===b&&h.textContent==="BAC"&&h.firstChild===b&&b.nextSibling===a&&a.parentNode===h&&h.insertBefore(a,a)===a&&h.textContent==="BAC"')!.as_bool()
	assert tree_eval(mut vm, 'var x=document.createElement("i");x.id="new";x.textContent="D";h.insertBefore(x,undefined)===x&&h.lastChild===x&&h.textContent==="BACD"')!.as_bool()
	assert tree_eval(mut vm, 'var empty=a.firstChild;h.firstChild.previousSibling===null&&h.lastChild.previousSibling===c&&empty.firstChild===null&&empty.lastChild===null&&empty.previousSibling===null')!.as_bool()
	native := document.get_element_by_id('new') or { panic('Missing native insertion') }
	actual := vm.global_object().get(mut vm, libjs.PropertyName.from_str('x'))!
	assert voidptr(host.nodes[voidptr(actual.as_object())] or { panic('Missing wrapper') }) == voidptr(native.as_node())
}

fn test_tree_mutations_insert_fragments_and_adopt_from_real_foreign_documents() {
	mut host, mut vm, _ := tree_fixture()!
	defer { host.close() }
	assert tree_eval(mut vm, 'var h=document.getElementById("host"),c=document.getElementById("c"),list=h.childNodes,f=document.createDocumentFragment();f.append("X","Y");h.insertBefore(f,c)===f&&f.childNodes.length===0&&list.length===5&&h.textContent==="ABXYC"&&f.parentNode===null')!.as_bool()
	assert tree_eval(mut vm, 'var foreign=new Document(),e=foreign.createElement("x-native");e.textContent="F";h.insertBefore(e,c)===e&&e.ownerDocument===document&&e.nextSibling===c&&e.parentNode===h&&h.textContent==="ABXYFC"')!.as_bool()
}

fn test_node_replacement_and_removal_return_old_node_and_preserve_native_order() {
	mut host, mut vm, _ := tree_fixture()!
	defer { host.close() }
	assert tree_eval(mut vm, 'var h=document.getElementById("host"),a=document.getElementById("a"),c=document.getElementById("c");h.replaceChild(a,c)===c&&c.parentNode===null&&h.textContent==="BA"&&h.replaceChild(a,a)===a&&h.textContent==="BA"')!.as_bool()
	assert tree_eval(mut vm, 'var f=document.createDocumentFragment();f.append("X","Y");h.replaceChild(f,a)===a&&a.parentNode===null&&f.childNodes.length===0&&h.textContent==="BXY"&&h.removeChild(h.firstChild).textContent==="B"&&h.textContent==="XY"')!.as_bool()
}

fn test_node_tree_mutations_validate_brand_arity_nullable_reference_and_dom_exception_names() {
	mut host, mut vm, _ := tree_fixture()!
	defer { host.close() }
	assert tree_eval(mut vm, 'var h=document.getElementById("host"),a=document.getElementById("a"),count=0,converted=0;for(var run of [()=>h.insertBefore(a),()=>h.replaceChild(a),()=>h.appendChild(),()=>h.removeChild(),()=>h.insertBefore(null,null),()=>h.insertBefore(a,{}),()=>h.replaceChild(a,null),()=>h.appendChild({toString(){converted++;return "x"}}),()=>Node.prototype.insertBefore.call({},a,null),()=>Node.prototype.removeChild.call(Object.create(Node.prototype),a)])try{run()}catch(e){if(e instanceof TypeError)count++}count===10&&converted===0&&h.textContent==="ABC"')!.as_bool()
	assert tree_eval(mut vm, 'var notFound=0,hierarchy=0;for(var run of [()=>h.insertBefore(a,document.body),()=>h.removeChild(document.body),()=>h.replaceChild(a,document.body),()=>h.insertBefore(h,a),()=>document.insertBefore(a.firstChild,document.documentElement),()=>h.appendChild(document)])try{run()}catch(e){if(e instanceof DOMException){if(e.name==="NotFoundError"&&e.code===8)notFound++;if(e.name==="HierarchyRequestError"&&e.code===3)hierarchy++}}notFound===3&&hierarchy===3&&h.textContent==="ABC"')!.as_bool()
	assert tree_eval(mut vm, 'var ok=true;for(var name of ["insertBefore","appendChild","replaceChild","removeChild"]){var d=Object.getOwnPropertyDescriptor(Node.prototype,name);ok=ok&&d.writable&&d.enumerable&&d.configurable&&d.value.length===(name==="insertBefore"||name==="replaceChild"?2:1)}ok')!.as_bool()
}

fn test_native_insert_replace_reactions_and_observer_records_share_actual_nodes() {
	mut host, mut vm, _ := tree_fixture()!
	defer { host.close() }
	assert tree_eval(mut vm, 'var order="";class X extends HTMLElement{connectedCallback(){order+="c"}disconnectedCallback(){order+="d"}}customElements.define("x-tree-slice",X);var h=document.getElementById("host"),x=document.createElement("x-tree-slice"),a=document.getElementById("a"),observer=new MutationObserver(()=>0);observer.observe(h,{childList:true});h.insertBefore(x,a);var replacement=document.createElement("strong");h.replaceChild(replacement,x);var records=observer.takeRecords();order==="cd"&&records.length===2&&records[0].target===h&&records[0].addedNodes[0]===x&&records[1].removedNodes[0]===x&&records[1].addedNodes[0]===replacement')!.as_bool()
}

fn test_cached_github_style_insert_before_wrapper_runs_native_method_with_compiler_disabled() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-tree-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, _ := tree_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert tree_eval(mut vm, 'var native=Node.prototype.insertBefore;Node.prototype.insertBefore=function(n,r){return native.apply(this,[n,r])};var style=document.createElement("style");style.textContent="body{color:#000}";document.head.insertBefore(style,document.head.firstChild)===style&&document.head.firstChild===style')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
