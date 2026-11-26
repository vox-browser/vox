// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import platform

fn test_select_options_and_selected_options_are_native_same_object_views() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option");a.id="one";a.value="v";s.appendChild(a);var o=s.options,c=s.selectedOptions;o===s.options&&c===s.selectedOptions&&o instanceof HTMLOptionsCollection&&o instanceof HTMLCollection&&c instanceof HTMLCollection&&!(c instanceof HTMLOptionsCollection)&&o.length===1&&c.length===1&&o[0]===a&&c[0]===a&&o.item(0)===a&&s.item(0)===a&&o.namedItem("one")===a&&s.namedItem("one")===a&&Object.getPrototypeOf(HTMLOptionsCollection)===HTMLCollection&&Object.prototype.toString.call(o)==="[object HTMLOptionsCollection]"')!.as_bool()
}

fn test_saved_selected_options_observes_selectedness_without_attribute_changes() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option"),b=document.createElement("option");s.multiple=true;a.value="a";b.value="b";a.id="first";b.name="second";s.append(a,b);var c=s.selectedOptions,ok=c.length===0;a.selected=true;ok=ok&&c.length===1&&c[0]===a&&c.namedItem("first")===a;b.selected=true;ok=ok&&c.length===2&&c[1]===b;a.selected=false;ok=ok&&c.length===1&&c[0]===b&&c[1]===undefined&&c.namedItem("first")===null;ok&&a.getAttribute("selected")===null&&b.getAttribute("selected")===null&&Array.from(c)[0]===b')!.as_bool()
}

fn test_options_length_mutates_native_option_tree_and_saved_views() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option");a.value="kept";s.appendChild(a);var o=s.options;s.length=3;var ok=o.length===3&&s.length===3&&o[0]===a&&o[1] instanceof HTMLOptionElement&&o[1].value==="";o.length=1;ok=ok&&s.length===1&&o[1]===undefined&&o.item(1)===null;o.length={valueOf(){return 4294967298}};ok&&s.length===2&&o.length===2')!.as_bool()
}

fn test_options_selected_index_uses_signed_conversion_and_native_selection() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option"),b=document.createElement("option");a.value="a";b.value="b";s.append(a,b);var o=s.options;o.selectedIndex=1;var ok=s.selectedIndex===1&&b.selected&&!a.selected&&s.selectedOptions[0]===b;o.selectedIndex=4294967295;ok=ok&&s.selectedIndex===-1&&s.selectedOptions.length===0;o.selectedIndex=4294967296;ok&&s.value==="a"&&o.selectedIndex===0')!.as_bool()
}

fn test_options_add_resolves_native_element_and_numeric_before_union() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option"),b=document.createElement("option"),c=document.createElement("option"),g=document.createElement("optgroup"),d=document.createElement("option");a.value="a";b.value="b";c.value="c";d.value="d";g.appendChild(d);s.add(a);s.add(b);var o=s.options;o.add(c,{valueOf(){return 1}});s.add(g,b);Array.from(o).map(x=>x.value).join() === "a,c,d,b"&&o.length===4&&d.parentNode===g&&g.parentNode===s')!.as_bool()
}

fn test_select_remove_distinguishes_child_node_and_index_overloads() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option"),b=document.createElement("option");s.append(a,b);document.body.appendChild(s);var o=s.options;s.remove(undefined);var ok=s.parentNode===document.body&&o.length===1&&o[0]===b;o.remove(-1);ok=ok&&o.length===1;s.remove();ok&&s.parentNode===null&&o.length===1')!.as_bool()
}

fn test_options_brands_and_union_rejection_precede_author_coercion() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),o=s.options,n=0,reads=0,arg={valueOf(){reads++;return 0}};for(var receiver of [{},s.selectedOptions,new Proxy(o,{})])try{HTMLOptionsCollection.prototype.remove.call(receiver,arg)}catch(e){if(e instanceof TypeError)n++}for(var call of [()=>o.add(document.createElement("div"),arg),()=>o.add(),()=>o.remove(),()=>s.item(),()=>s.namedItem(),()=>new HTMLOptionsCollection(),()=>HTMLOptionsCollection()])try{call()}catch(e){if(e instanceof TypeError)n++}n===10&&reads===0')!.as_bool()
}

fn test_options_conversion_preserves_author_throws_and_native_dom_errors() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),o=s.options,a=document.createElement("option"),outside=document.createElement("option"),caught=false,marker={},same=false;try{o.add(a,outside)}catch(e){caught=e instanceof DOMException&&e.name==="NotFoundError"}try{o.add(a,{valueOf(){throw marker}})}catch(e){same=e===marker}caught&&same&&o.length===0')!.as_bool()
	assert stream_eval(mut vm, 'var a=document.createElement("option");o.add(a);var value=o.item({valueOf(){var b=document.createElement("option");o.add(b);return 1}});value===o[1]&&o.length===2')!.as_bool()
}

fn test_select_collection_descriptors_and_history_clone_rejection() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var s=document.createElement("select"),o=s.options,d=Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,"options"),c=Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype,"selectedOptions"),l=Object.getOwnPropertyDescriptor(HTMLOptionsCollection.prototype,"length"),bad=0;for(var value of [o,s.selectedOptions])try{history.replaceState(value,"")}catch(e){if(e.name==="DataCloneError")bad++}d.set===undefined&&c.set===undefined&&d.enumerable&&d.configurable&&l.get.length===0&&l.set.length===1&&o.add.length===1&&o.remove.length===1&&s.remove.length===0&&bad===2')!.as_bool()
}

fn test_select_collection_views_survive_transient_arena_reset_and_clear_on_close() {
	mut host, mut vm := text_encoding_fixture()!
	mut arena := platform.new_arena('native select collection views')
	entry := arena.enter()
	stream_eval(mut vm, 'var s=document.createElement("select"),a=document.createElement("option");s.appendChild(a);var o=s.options,c=s.selectedOptions;o.length=2;o.selectedIndex=1;c.length===1')!
	arena.leave(entry)
	for _, native in host.options_collections { assert !arena.contains(native) }
	for _, object in host.selected_options_wrappers { assert !arena.contains(object) }
	arena.reset()
	assert stream_eval(mut vm, 'o===s.options&&c===s.selectedOptions&&c[0]===o[1]&&o.length===2')!.as_bool()
	host.close()
	assert host.options_collections.len == 0 && host.selected_options_wrappers.len == 0
}
