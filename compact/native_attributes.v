module main

import dom
import html
import platform
import x.json2

// The handle identifies one native Attr allocation. Removing and recreating
// the same namespace/local name therefore cannot reuse the old JS identity.
struct CompactNativeAttribute {
	attribute &dom.Attr_
	document  &dom.Document
}

struct CompactNativeAttributeQuery {
	op         string
	name       string
	namespace  ?string
	value      string
	attribute  string
	index      int
	force      ?bool
	namespaced bool
	state      map[string]json2.Any
}

struct CompactNativeAttributeChange {
	name      string
	namespace ?string
	old_value ?string
	input     &html.HTMLInputElementModel = unsafe { nil }
}

// The DOM owns the attribute and its mutation records. These concrete HTML
// model notifications match the existing compact native mutation boundary.
fn compact_native_attribute_change(element &dom.Element, name string, namespace ?string) CompactNativeAttributeChange {
	mut input := unsafe { &html.HTMLInputElementModel(nil) }
	if namespace == none && element.is_html_element() && element.local_name() == 'input' {
		input = html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		configure_browser_input_image_fetch(element, false)
	}
	return CompactNativeAttributeChange{
		name:      name
		namespace: namespace
		old_value: element.get_attribute_ns(namespace, name)
		input:     input
	}
}

fn (change CompactNativeAttributeChange) finish(element &dom.Element) {
	if change.namespace != none { return }
	value := element.get_attribute_ns(none, change.name)
	if change.input != unsafe { nil } {
		mut input := unsafe { &html.HTMLInputElementModel(change.input) }
		input.form_associated_element_attribute_changed(change.name, change.old_value, value, none)
	}
	if change.name == 'form' && element.is_html_element() && element.local_name() == 'button' {
		mut control := html.HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(element) }).control
		control.form_node_attribute_changed(change.name)
	}
	compact_image_attribute_changed(element, change.name, change.old_value, value,
		change.namespace)
	if element.is_html_element() && element.local_name() == 'canvas' && change.name in [
		'width',
		'height',
	] {
		html.html_canvas_element_attribute_changed(unsafe { &dom.HTMLCanvasElement(element) },
			change.name, change.old_value, value, none)
	}
	if element.is_html_element() && element.local_name() == 'object' && change.name in [
		'data',
		'type',
		'classid',
	] {
		object := unsafe { &dom.HTMLObjectElement(element) }
		html.html_object_element_form_associated_element_attribute_changed(object, change.name, change.old_value, value, none)
		if !element.document().is_fully_active() {
			mut model := html.html_object_element_model_for_dom_element(object)
			model.set_environment(element.as_node().is_connected(), true, false)
			model.queue_element_task_to_run_object_representation_steps()
		}
	}
}

fn (mut binding CompactElementQueryBinding) native_attribute_state(attribute &dom.Attr_, fallback &dom.Document) json2.Any {
	mut key := binding.attribute_keys[voidptr(attribute)] or { '' }
	document := if attribute.document() != unsafe { nil } { attribute.document() } else { fallback }
	if key == '' {
		binding.next_attribute_key++
		key = '__attribute_${binding.next_attribute_key}'
		binding.attribute_keys[voidptr(attribute)] = key
		binding.attribute_handles[key] = CompactNativeAttribute{ attribute: attribute, document: document }
		// The realm's registry can keep a detached Attr after its original
		// document retires. Share its existing balanced allocation lifetime.
		mut realm_document := unsafe { &dom.Document(binding.document) }
		realm_document.share_native_storage_lifetime(attribute.storage_owner())
	}
	return json2.Any({
		'key':           json2.Any(key)
		'name':          json2.Any(attribute.name())
		'localName':     json2.Any(attribute.local_name())
		'prefix':        compact_optional_json(attribute.prefix())
		'namespaceURI':  compact_optional_json(attribute.namespace_uri())
		'value':         json2.Any(attribute.value())
		'ownerElement':  if element := attribute.owner_element() {
			binding.element_state(element)
		} else {
			json2.Any(json2.Null{})
		}
		'ownerDocument': binding.document_state(document)
	})
}

fn (mut binding CompactElementQueryBinding) native_attribute_query(key string, source string) !string {
	query := compact_decode_query[CompactNativeAttributeQuery](source)!
	if query.op == 'set' {
		return binding.set_trusted_attribute(key, query.namespace, query.name, query.value,
			query.namespaced, json2.encode(query.state))
	}
	if query.op in ['attribute', 'setValue'] {
		handle := binding.attribute_handles[query.attribute] or { return error('TypeError: Invalid Attr receiver') }
		mut attribute := unsafe { &dom.Attr_(handle.attribute) }
		if query.op == 'setValue' {
			mut document := if attribute.document() != unsafe { nil } {
				attribute.document()
			} else {
				handle.document
			}
			mut storage := document.native_storage()
			mut scope := if storage != unsafe { nil } {
				storage.enter_nested()
			} else {
				platform.RetainedArenaScope{}
			}
			defer { scope.finish() }
			mut value := query.value.clone()
			if element := attribute.owner_element() {
				value = document.trusted_types_compliant_attribute_value(element, attribute.local_name(), attribute.namespace_uri(), value)!
			}
			// A Trusted Types policy can detach or move the attribute while
			// converting the value. Mutate the same native identity afterwards.
			if element := attribute.owner_element() {
				change := compact_native_attribute_change(element, attribute.local_name(), attribute.namespace_uri())
				mut target_storage := element.document().native_storage()
				mut target_scope := if target_storage != unsafe { nil } {
					target_storage.enter_nested()
				} else {
					platform.RetainedArenaScope{}
				}
				old_value := attribute.value()
				attribute.value_ = value.clone()
				attribute.handle_attribute_changes(element, old_value, attribute.value())
				change.finish(element)
				target_scope.finish()
				binding.note_node_tree_mutation()
			} else {
				attribute.value_ = value.clone()
			}
		}
		return json2.encode(binding.native_attribute_state(attribute, handle.document))
	}
	mut node := binding.equality_node(key, json2.Any(query.state))!
	mut element := node.as_element() or { return error('TypeError: Illegal Element receiver') }
	mut storage := element.document().native_storage()
	mut scope := if storage != unsafe { nil } {
		storage.enter_nested()
	} else {
		platform.RetainedArenaScope{}
	}
	defer { scope.finish() }
	match query.op {
		'get' { return json2.encode(compact_optional_json(element.get_attribute(query.name))) }
		'getNS' {
			return json2.encode(compact_optional_json(element.get_attribute_ns(query.namespace, query.name)))
		}
		'has' { return json2.encode(element.has_attribute(query.name)) }
		'hasNS' { return json2.encode(element.has_attribute_ns(query.namespace, query.name)) }
		'hasAttributes' { return json2.encode(element.has_attributes()) }
		'names' { return json2.encode(element.get_attribute_names()) }
		'length' { return json2.encode(element.attribute_list_size()) }
		'supportedNames' {
			return json2.encode(element.attributes().supported_property_names())
		}
		'supportsName' {
			return json2.encode(element.attributes().is_supported_property_name(query.name))
		}
		'getNode', 'getNodeNS', 'item' {
			mut candidate := ?&dom.Attr_(none)
			match query.op {
				'getNode' { candidate = element.get_attribute_node(query.name) }
				'getNodeNS' {
					candidate = element.get_attribute_node_ns(query.namespace, query.name)
				}
				else {
					if list := element.attribute_list() { candidate = list.item(query.index) }
				}
			}
			attribute := candidate or { return 'null' }
			return json2.encode(binding.native_attribute_state(attribute, element.document()))
		}
		'remove', 'removeNS', 'removeNamed', 'removeNamedNS', 'removeNode' {
			mut candidate := ?&dom.Attr_(none)
			if query.op == 'removeNode' {
				handle := binding.attribute_handles[query.attribute] or { return error('TypeError: Expected an Attr') }
				candidate = handle.attribute
			} else if query.op in ['removeNS', 'removeNamedNS'] {
				candidate = element.get_attribute_node_ns(query.namespace, query.name)
			} else {
				candidate = element.get_attribute_node(query.name)
			}
			attribute := candidate or {
				if query.op in ['removeNamed', 'removeNamedNS', 'removeNode'] {
					return error('NotFoundError: Attribute not found')
				}
				return 'null'
			}
			change := compact_native_attribute_change(element, attribute.local_name(), attribute.namespace_uri())
			removed := element.remove_attribute_node(attribute)!
			change.finish(element)
			binding.note_node_tree_mutation()
			return json2.encode(binding.native_attribute_state(removed, element.document()))
		}
		'setNode' {
			handle := binding.attribute_handles[query.attribute] or { return error('TypeError: Expected an Attr') }
			attribute := handle.attribute
			change := compact_native_attribute_change(element, attribute.local_name(), attribute.namespace_uri())
			mut attributes := element.attributes()
			result := attributes.set_attribute_with_result(attribute)!
			if previous := result.previous {
				if voidptr(previous) == voidptr(attribute) {
					return json2.encode(binding.native_attribute_state(previous, element.document()))
				}
			}
			change.finish(element)
			binding.note_node_tree_mutation()
			if old := result.previous {
				return json2.encode(binding.native_attribute_state(old, element.document()))
			}
			return 'null'
		}
		'toggle' {
			previous := element.get_attribute_node(query.name)
			name := if attribute := previous {
				attribute.local_name()
			} else if element.is_html_element() && element.document().is_html_document() {
				query.name.bytes().map(if it >= `A` && it <= `Z` { it + u8(32) } else { it }).bytestr()
			} else {
				query.name
			}
			namespace := if attribute := previous { attribute.namespace_uri() } else { none }
			change := compact_native_attribute_change(element, name, namespace)
			value := element.toggle_attribute(query.name.clone(), query.force)!
			if (previous != none) != value {
				change.finish(element)
				binding.note_node_tree_mutation()
			}
			return json2.encode(value)
		}
		else { return error('TypeError: Invalid native attribute operation') }
	}
}

// Wrappers own conversion and identity. Every semantic read goes through the
// same native query boundary, including reads of a retained NamedNodeMap/Attr.
fn compact_native_attributes_bootstrap() string {
	return r'
const __compactNativeAttributes=(function(){
 "use strict";
 const S=String,stringify=JSON.stringify,assign=Object.assign;
 function string(value){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return S(value);}
 function nullable(value){return value===null||value===undefined?null:string(value);}
 function state(receiver){const own=__elementApply(__elementRecordGet,__elementRecords,[receiver]);if(!own)throw new TypeError("Illegal Element receiver");return own;}
 function call(own,op,fields){return __queryElements(own?own.bridgeKey:"","nativeAttribute",stringify(assign({op,state:own&&own.created?own:undefined},fields)),true);}
 function read(own,name,nullNamespace){return call(own,nullNamespace?"getNS":"get",{name,namespace:null});}
 function contains(own,name,nullNamespace){return call(own,nullNamespace?"hasNS":"has",{name,namespace:null});}
 function write(own,name,value,namespaced){
  const object=__element(own);
  if(__compactTrustedTypes.nativeAttributes)__compactTrustedTypes.setAttribute(object,null,name,value,!!namespaced);
  else{const result=call(own,"set",{name,value:string(value),namespace:null,namespaced:!!namespaced});globalThis.__compactApplyMutationRefresh(result);__compactCustomElementFlush(own);}
  return call(own,namespaced?"getNodeNS":"getNode",{name,namespace:null});
 }
 function remove(own,name,namespaced,namespace=null){
  const previous=call(own,namespaced?"removeNS":"remove",{name,namespace});
  if(previous){
   if(previous.namespaceURI===null&&own.tagName==="canvas"&&(previous.localName==="width"||previous.localName==="height"))delete own[previous.localName];
   __compactCustomElementFlush(own);
  }
  return previous;
 }
 function method(name,value){Object.defineProperty(Element.prototype,name,{value,writable:true,enumerable:true,configurable:true});}
 method("getAttribute",{getAttribute(name){const own=state(this);if(arguments.length===0)throw new TypeError("getAttribute requires a name");return call(own,"get",{name:string(name)});}}.getAttribute);
 method("hasAttribute",{hasAttribute(name){const own=state(this);if(arguments.length===0)throw new TypeError("hasAttribute requires a name");return call(own,"has",{name:string(name)});}}.hasAttribute);
 method("getAttributeNS",{getAttributeNS(namespace,name){const own=state(this);if(arguments.length<2)throw new TypeError("getAttributeNS requires two arguments");return call(own,"getNS",{namespace:nullable(namespace),name:string(name)});}}.getAttributeNS);
 method("hasAttributeNS",{hasAttributeNS(namespace,name){const own=state(this);if(arguments.length<2)throw new TypeError("hasAttributeNS requires two arguments");return call(own,"hasNS",{namespace:nullable(namespace),name:string(name)});}}.hasAttributeNS);
 method("getAttributeNames",{getAttributeNames(){return call(state(this),"names");}}.getAttributeNames);
 method("removeAttribute",{removeAttribute(name){const own=state(this);if(arguments.length===0)throw new TypeError("removeAttribute requires a name");remove(own,string(name),false);}}.removeAttribute);
 method("removeAttributeNS",{removeAttributeNS(namespace,name){const own=state(this);if(arguments.length<2)throw new TypeError("removeAttributeNS requires two arguments");namespace=nullable(namespace);remove(own,string(name),true,namespace);}}.removeAttributeNS);
 method("toggleAttribute",{toggleAttribute(name,force){const own=state(this);if(arguments.length===0)throw new TypeError("toggleAttribute requires a name");const result=call(own,"toggle",{name:string(name),force:force===undefined?undefined:!!force});__compactCustomElementFlush(own);return result;}}.toggleAttribute);
 return {state,call,string,read,contains,write,remove};
})();
function __compactInstallNativeAttributeMutations(){
 // These internal callers include IDL reflection, dataset, media/canvas
 // adapters and legacy facades. Publish their writes before returning too.
 __setAttribute=function(own,name,value){return __compactNativeAttributes.write(own,__compactNativeAttributes.string(name),value,false);};
 __removeAttribute=function(own,name){return __compactNativeAttributes.remove(own,__compactNativeAttributes.string(name),false);};
}
'
}
