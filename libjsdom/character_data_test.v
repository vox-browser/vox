// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn character_fixture() !(&Host, &libjs.VM, &dom.Document) {
	mut document := html.parse_document('<body><div id="root">before</div></body>')
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm, document
}

fn character_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-character-data.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions:100000}) or { return error(exception_message(err)) }
}

fn test_native_text_comment_factories_and_constructor_ancestry_share_actual_wrappers() {
	mut host, mut vm, _ := character_fixture()!
	defer { host.close() }
	assert character_eval(mut vm, 'var t=document.createTextNode("A😀B"),c=document.createComment("comment"),h=document.getElementById("root");h.replaceChildren(t,c);t instanceof Text&&t instanceof CharacterData&&t instanceof Node&&c instanceof Comment&&c instanceof CharacterData&&t.nodeType===3&&c.nodeType===8&&t.length===4&&t.data==="A😀B"&&c.nodeValue==="comment"&&t.parentNode===h&&t.ownerDocument===document&&h.firstChild===t&&h.lastChild===c')!.as_bool()
	assert character_eval(mut vm, 'class T extends Text{}var t=new T("text"),c=new Comment(null);t instanceof T&&t instanceof Text&&t.data==="text"&&new Text().data===""&&new Text(null).data==="null"&&c.data==="null"&&Object.getPrototypeOf(Text)===CharacterData&&Object.getPrototypeOf(CharacterData)===Node&&Object.prototype.toString.call(t)==="[object Text]"')!.as_bool()
}

fn test_character_data_mutations_update_native_tree_ranges_and_observer_records() {
	mut host, mut vm, document := character_fixture()!
	defer { host.close() }
	assert character_eval(mut vm, 'var h=document.getElementById("root"),t=h.firstChild,observer=new MutationObserver(()=>{});observer.observe(h,{subtree:true,characterData:true,characterDataOldValue:true,childList:true});t.data="abcd";t.insertData(2,"X");t.deleteData(0,1);t.replaceData(1,1,"Y");t.appendData("Z");var s=t.splitText(2);t.data==="bY"&&s.data==="cdZ"&&t.wholeText==="bYcdZ"&&s.wholeText===t.wholeText&&s.previousSibling===t&&h.textContent==="bYcdZ"&&t.substringData(0,100)==="bY"')!.as_bool()
	assert character_eval(mut vm, 's.nodeValue="tail";var r=observer.takeRecords();r.length>=7&&r[0].target===t&&r[0].oldValue==="before"&&h.textContent==="bYtail"&&s.nodeValue==="tail"&&s.data==="tail"')!.as_bool()
	native := document.get_element_by_id('root')?
	assert native.as_node().text_content()? == 'bYtail'
	assert character_eval(mut vm, 't.data=null;s.nodeValue=undefined;t.length===0&&s.data===""&&h.textContent===""')!.as_bool()
}

fn test_character_data_brands_arity_and_native_index_errors_preserve_data() {
	mut host, mut vm, _ := character_fixture()!
	defer { host.close() }
	assert character_eval(mut vm, 'var t=new Text("abc"),n=0;for(var run of [()=>new CharacterData(),()=>Text(),()=>document.createTextNode(),()=>document.createComment(),()=>t.substringData(0),()=>t.splitText(),()=>CharacterData.prototype.appendData.call({},"x"),()=>Text.prototype.splitText.call(new Comment(),0)])try{run()}catch(e){if(e instanceof TypeError)n++}var indexes=0;for(var run of [()=>t.substringData(4,0),()=>t.deleteData(-1,0),()=>t.splitText(4)])try{run()}catch(e){if(e instanceof DOMException&&e.name==="IndexSizeError")indexes++}n===8&&indexes===3&&t.data==="abc"')!.as_bool()
}

fn test_native_node_utilities_and_child_node_mutations_keep_tree_identity() {
	mut host, mut vm, _ := character_fixture()!
	defer { host.close() }
	assert character_eval(mut vm, 'var h=document.getElementById("root"),a=document.createElement("b"),t=new Text("T");h.replaceChildren(a);a.after(t,"tail");t.before("before");t.replaceWith(t,"after");var clone=h.cloneNode(true);h.contains(t)&&!t.contains(h)&&t.isConnected&&t.getRootNode()===document&&t.isSameNode(t)&&!t.isSameNode(null)&&h.isEqualNode(clone)&&clone!==h&&!clone.isConnected&&clone.hasChildNodes()&&clone.firstChild!==a&&(h.compareDocumentPosition(t)&16)!==0&&h.textContent==="beforeTaftertail"')!.as_bool()
	assert character_eval(mut vm, 't.remove();t.parentNode===null&&!t.isConnected&&t.getRootNode()===t&&h.textContent==="beforeaftertail"&&t.nodeValue==="T"')!.as_bool()
	assert character_eval(mut vm, 'h.normalize();h.childNodes.length===2&&h.lastChild.data==="beforeaftertail"&&h.nodeValue===null&&(h.nodeValue="ignored",h.textContent==="beforeaftertail")')!.as_bool()
}

fn test_cached_react_style_text_update_and_comment_anchor_use_native_nodes_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-character-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, _ := character_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert character_eval(mut vm, 'function update(h,value){var t=h.firstChild;if(t&&t===h.lastChild&&t.nodeType===3)t.nodeValue=value;else h.textContent=value}var h=document.getElementById("root");update(h,"hydrated");var marker=document.createComment("anchor");h.appendChild(marker);marker.before(document.createTextNode("!"));h.textContent==="hydrated!"&&h.contains(marker)&&marker.previousSibling instanceof Text')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
