// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import platform

fn test_form_elements_returns_native_same_object_collection_and_inheritance() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),i=document.createElement("input");i.name="field";f.appendChild(i);document.body.appendChild(f);var c=f.elements;c===f.elements&&c instanceof HTMLFormControlsCollection&&c instanceof HTMLCollection&&!Array.isArray(c)&&c.length===1&&f.length===1&&c[0]===i&&c.item(0)===i&&c.namedItem("field")===i&&Object.prototype.toString.call(c)==="[object HTMLFormControlsCollection]"&&Object.getPrototypeOf(HTMLFormControlsCollection)===HTMLCollection')!.as_bool()
}

fn test_form_elements_and_length_discover_lazy_external_and_later_controls() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),outside=document.createElement("input"),image=document.createElement("input"),late=document.createElement("textarea");f.id="collection-owner";outside.setAttribute("form",f.id);outside.name="outside";image.type="image";f.appendChild(image);document.body.append(outside,f);var c=f.elements,ok=f.length===1&&c[0]===outside;f.appendChild(late);ok=ok&&f.length===2&&c.length===2&&c[1]===late;outside.setAttribute("form","other");ok&&f.length===1&&c.length===1&&c[0]===late')!.as_bool()
}

fn test_form_named_item_returns_null_element_or_live_radio_node_list() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input"),b=document.createElement("input");a.type=b.type="radio";a.name=b.name="choice";a.value="a";b.value="b";a.id="unique";f.append(a,b);document.body.appendChild(f);var c=f.elements,r=c.namedItem("choice"),ok=c.namedItem("")===null&&c.namedItem("missing")===null&&c.namedItem("unique")===a&&r instanceof RadioNodeList&&r instanceof NodeList&&r.length===2&&r.item(0)===a&&r[1]===b&&r.value==="";r.value="b";ok=ok&&r.value==="b"&&b.checked&&!a.checked;f.removeChild(b);ok&&r.length===1&&r[1]===undefined&&c.namedItem("choice")===a&&r.value===""')!.as_bool()
}

fn test_radio_node_list_value_uses_real_groups_and_preserves_explicit_empty_values() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input"),b=document.createElement("input"),x=document.createElement("input");a.type=b.type=x.type="radio";a.id=b.id="shared";a.name=x.name="a";b.name="b";a.value="";b.value="b";x.value="x";f.append(a,b,x);document.body.appendChild(f);a.checked=true;var r=f.elements.namedItem("shared");r.value="b";var ok=a.checked&&b.checked;r.value="";ok=ok&&a.checked&&b.checked&&r.value==="";x.checked=true;r.value="";ok&&a.checked&&!x.checked&&b.checked')!.as_bool()
}

fn test_form_collection_iterators_and_inherited_methods_are_live_native_views() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input"),b=document.createElement("input");a.name=b.name="same";f.appendChild(a);document.body.appendChild(f);var c=f.elements,it=c[Symbol.iterator](),first=it.next();f.appendChild(b);var second=it.next(),r=c.namedItem("same"),seen=[];r.forEach((e,i,self)=>seen.push(e===r[i]&&self===r));first.value===a&&second.value===b&&it.next().done&&Array.from(c)[1]===b&&HTMLCollection.prototype.item.call(c,1)===b&&HTMLCollection.prototype.namedItem.call(c,"same")===a&&NodeList.prototype.item.call(r,0)===a&&seen.length===2&&seen.every(Boolean)&&r.entries().next().value[0]===0&&Object.getPrototypeOf(RadioNodeList)===NodeList')!.as_bool()
}

fn test_form_collection_receivers_and_required_arguments_precede_coercion() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),c=f.elements,n=0,reads=0,arg={toString(){reads++;return "x"}};for(var receiver of [{},document.body.children,new Proxy(c,{})])try{HTMLFormControlsCollection.prototype.namedItem.call(receiver,arg)}catch(e){if(e instanceof TypeError)n++}for(var call of [()=>c.namedItem(),()=>c.item(),()=>new HTMLCollection(),()=>HTMLCollection(),()=>new HTMLFormControlsCollection(),()=>new RadioNodeList()])try{call()}catch(e){if(e instanceof TypeError)n++}n===9&&reads===0')!.as_bool()
}

fn test_radio_list_value_brand_and_conversion_order_preserve_author_errors() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input"),b=document.createElement("input");a.type=b.type="radio";a.name=b.name="g";a.value="a";b.value="b";f.append(a,b);document.body.appendChild(f);var r=f.elements.namedItem("g"),d=Object.getOwnPropertyDescriptor(RadioNodeList.prototype,"value"),reads=0,bad=0;for(var receiver of [{},f.childNodes,new Proxy(r,{})])try{d.set.call(receiver,{toString(){reads++;return "b"}})}catch(e){if(e instanceof TypeError)bad++}r.value={toString(){b.value="new";return "new"}};var marker={},same=false;try{r.value={toString(){throw marker}}}catch(e){same=e===marker}bad===3&&reads===0&&b.checked&&r.value==="new"&&same')!.as_bool()
}

fn test_collection_named_item_observes_dom_mutations_during_name_conversion() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input");document.body.appendChild(f);var c=f.elements;var result=c.namedItem({toString(){a.name="late";f.appendChild(a);return "late"}});result===a&&c.item(-1)===null&&c.item(4294967296)===a')!.as_bool()
}

fn test_collection_descriptors_and_readonly_form_members() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var p=HTMLFormElement.prototype,e=Object.getOwnPropertyDescriptor(p,"elements"),l=Object.getOwnPropertyDescriptor(p,"length"),n=Object.getOwnPropertyDescriptor(HTMLFormControlsCollection.prototype,"namedItem"),v=Object.getOwnPropertyDescriptor(RadioNodeList.prototype,"value");e.enumerable&&e.configurable&&e.set===undefined&&l.set===undefined&&n.enumerable&&n.writable&&n.configurable&&n.value.length===1&&v.get.length===0&&v.set.length===1&&v.enumerable&&v.configurable')!.as_bool()
}

fn test_collection_bindings_survive_transient_arena_and_release_host_maps() {
	mut host, mut vm := text_encoding_fixture()!
	mut arena := platform.new_arena('native form collection bindings')
	entry := arena.enter()
	stream_eval(mut vm, 'var f=document.createElement("form"),a=document.createElement("input"),b=document.createElement("input");a.name=b.name="g";f.append(a,b);document.body.appendChild(f);var c=f.elements,r=c.namedItem("g")')!
	arena.leave(entry)
	assert host.form_controls_collections.len == 1 && host.radio_node_lists.len == 1
	for _, native in host.form_controls_collections { assert !arena.contains(native) }
	for _, native in host.radio_node_lists { assert !arena.contains(native) }
	for _, object in host.collection_wrappers { assert !arena.contains(object) }
	arena.reset()
	assert stream_eval(mut vm, 'c===f.elements&&c.length===2&&r.length===2&&r[0]===a')!.as_bool()
	host.close()
	assert host.form_controls_collections.len == 0 && host.radio_node_lists.len == 0 && host.collection_wrappers.len == 0
}
