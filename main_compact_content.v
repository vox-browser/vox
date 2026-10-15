module main

import browserjs
import dom
import css
import strconv
import x.json2

@[heap]
struct CompactElementQueryBinding {
	document &dom.Document
	runtime  &browserjs.Runtime
mut:
	elements map[string]&dom.Element
	keys     map[voidptr]string
	next_key int
}

// Retain native node identity across insertions instead of serializing each
// ancestor's complete subtree into the compact script bridge's initial state.
fn install_compact_element_content_binding(document &dom.Document, mut runtime browserjs.Runtime) ! {
	elements := css.query_selector_all(unsafe { &dom.Node(document) }, '*')
	mut binding := &CompactElementQueryBinding{
		document: document
		runtime:  &runtime
	}
	for index, element in elements {
		key := '__element_${index}'
		binding.elements[key] = element
		binding.keys[voidptr(element)] = key
	}
	runtime.add_canvas_element_provider_with_lookup(fn [binding] () map[string]&dom.Element {
		return binding.elements.clone()
	}, fn [binding] (key string) ?&dom.Element {
		return binding.elements[key] or { return none }
	})
	runtime.define_host_function('__ladybirdReadElementContent', fn [elements, binding] (input string) !string {
		parts := input.split(':')
		if parts.len != 2 {
			return error('Invalid element content request')
		}
		element := binding.elements[parts[0]] or {
			index := strconv.atoi(parts[0])!
			if index < 0 || index >= elements.len {
				return error('Invalid element content index')
			}
			elements[index]
		}
		return match parts[1] {
			'textContent' { element.as_node().text_content() or { '' } }
			'innerHTML' { element.inner_html() or { '' } }
			else { return error('Invalid element content property') }
		}
	})!
	runtime.define_host_function('__ladybirdElementQuery', fn [binding] (input string) !string {
		mut mutable_binding := unsafe { &CompactElementQueryBinding(binding) }
		return mutable_binding.query(input)
	})!
}

fn (mut binding CompactElementQueryBinding) element_state(element &dom.Element) json2.Any {
	if key := binding.keys[voidptr(element)] {
		return json2.Any({
			'bridgeKey': json2.Any(key)
		})
	}
	binding.next_key++
	key := '__query_${binding.next_key}'
	binding.keys[voidptr(element)] = key
	binding.elements[key] = element
	attribute_records, attributes := browserjs.compact_attribute_state(element)
	return json2.Any({
		'bridgeKey':    json2.Any(key)
		'elementIndex': json2.Any(-1)
		'tagName':      json2.Any(element.local_name())
		'namespaceURI': json2.Any(element.namespace_uri() or { '' })
		'attributes':   json2.Any(attributes)
		'attributeRecords': json2.Any(attribute_records)
		'id':           json2.Any(element.get_attribute_value('id'))
		'src':          json2.Any(element.get_attribute_value('src'))
		'width':        json2.Any(element.get_attribute_value('width'))
		'height':       json2.Any(element.get_attribute_value('height'))
		'className':    json2.Any(element.get_attribute_value('class'))
		'styleText':    json2.Any(element.get_attribute_value('style'))
		'onclick':      json2.Any(element.get_attribute_value('onclick'))
		'hasChildren':  json2.Any(element.as_node().has_children())
		'disabled':     json2.Any(element.has_attribute('disabled'))
	})
}

fn (mut binding CompactElementQueryBinding) query(input string) !string {
	request := json2.decode[map[string]json2.Any](input)!
	if snapshot := json_string_property(request, 'snapshot') {
		mut messages := []string{}
		mut elements := map[string]&dom.Element{}
		if state := javascript_replay_state(snapshot, mut messages) {
			note_compact_replay_effects(state, binding.runtime)
			elements = binding.runtime.canvas_elements_for_keys(compact_replay_element_keys(state))
			apply_decoded_javascript_state(binding.document, state, elements, mut messages)
		}
		// Console output stays in the script snapshot for its normal consumer;
		// only DOM replay failures can reject this selector operation.
		mut log_count := json_int_property(request, 'logCount') or { 0 }
		if log_count < 0 { log_count = 0 }
		if log_count > messages.len { log_count = messages.len }
		if messages.len > log_count {
			return error(messages[..messages.len - log_count].join('\n'))
		}
		for key, element in elements {
			binding.elements[key] = element
			binding.keys[voidptr(element)] = key
		}
	}
	selector := json_string_property(request, 'selector') or {
		return error('Invalid selector request')
	}
	action := json_string_property(request, 'action') or { return error('Invalid selector action') }
	key := json_string_property(request, 'key') or { '' }
	root := if key == '' {
		unsafe { &dom.Node(binding.document) }
	} else {
		element := binding.elements[key] or {
			binding.runtime.canvas_element_for_binding(key) or {
				return error('TypeError: Invalid Element receiver')
			}
		}
		binding.elements[key] = element
		binding.keys[voidptr(element)] = key
		element.as_node()
	}
	if action == 'computedStyle' {
		return compact_computed_style_query(root, selector)
	}
	if action == 'getElementById' {
		return if element := binding.document.get_element_by_id(selector) {
			json2.encode(binding.element_state(element))
		} else {
			'null'
		}
	}
	if action == 'getElementsByClassName' {
		// Recreate the native filter per read: its cache currently versions tree
		// changes, while attribute-only class edits must also be visible here.
		mut parent := unsafe { &dom.ParentNode(root) }
		collection := parent.get_elements_by_class_name(selector)
		mut result := []json2.Any{}
		for element in collection.collect_matching_elements() {
			result << binding.element_state(element)
		}
		return json2.encode(result)
	}
	css.install_document_selector_query_hook(binding.document)
	// Use the DOM entry point for validation, preserving its SyntaxError before
	// queries that otherwise return no matches for an invalid selector.
	validation_element := root.as_element() or {
		binding.document.document_element() or { return error('Invalid selector document') }
	}
	matched := validation_element.matches(selector)!
	if action == 'matches' { return json2.encode(matched) }
	if action == 'closest' {
		return if element := validation_element.closest(selector) {
			json2.encode(binding.element_state(element))
		} else {
			'null'
		}
	}
	if action == 'querySelector' {
		parent := unsafe { &dom.ParentNode(root) }
		return if element := parent.query_selector(selector) {
			json2.encode(binding.element_state(element))
		} else {
			'null'
		}
	}
	if action == 'querySelectorAll' {
		mut result := []json2.Any{}
		parent := unsafe { &dom.ParentNode(root) }
		list := parent.query_selector_all(selector)!
		for node in list.nodes {
			element := node.as_element() or { continue }
			result << binding.element_state(element)
		}
		return json2.encode(result)
	}
	return error('Invalid selector action')
}

// Reads flush pending compact mutations through the same native query boundary
// as selectors. A saved collection therefore stays live without maintaining a
// second JavaScript tree or escaping class names into a selector.
fn compact_class_collection_bootstrap() string {
	return r'
function __classCollection(key, classNames) {
 const read=()=>__queryElements(key,"getElementsByClassName",classNames);
 function named(elements,name) {
  if(name==="")return null;
  for(const element of elements){
   const state=__elementApply(__elementRecordGet,__elementRecords,[element]);
   if(state.id===name||(state.namespaceURI==="http://www.w3.org/1999/xhtml"&&state.attributes.name===name))return element;
  }
  return null;
 }
 function isIndex(property){return typeof property==="string"&&/^(0|[1-9][0-9]*)$/.test(property)&&Number(property)<4294967295;}
 const target={
  item(index){if(arguments.length===0)throw new TypeError("item requires an index");index=(+index)>>>0;return read()[index]||null;},
  namedItem(name){if(arguments.length===0)throw new TypeError("namedItem requires a name");if(typeof name==="symbol")throw new TypeError("Cannot convert a Symbol to a string");name=String(name);return named(read(),name);},
  *[Symbol.iterator](){let index=0;for(;;){const elements=read();if(index>=elements.length)return;yield elements[index++];}}
 };
 for(const method of ["item","namedItem",Symbol.iterator])Object.defineProperty(target,method,{enumerable:false});
 Object.defineProperty(target,Symbol.toStringTag,{value:"HTMLCollection",configurable:true});
 return new Proxy(target,{
  get(target,property,receiver){
   if(property==="length")return read().length;
   if(Reflect.has(target,property))return Reflect.get(target,property,receiver);
   if(isIndex(property))return read()[Number(property)];
   if(typeof property==="string")return named(read(),property)||undefined;
  },
  has(target,property){return property==="length"||Reflect.has(target,property)||(isIndex(property)?Number(property)<read().length:typeof property==="string"&&named(read(),property)!==null);},
  ownKeys(target){
   const elements=read(),keys=Reflect.ownKeys(target);
   for(let index=0;index<elements.length;index++)keys.push(String(index));
   for(const element of elements){const state=__elementApply(__elementRecordGet,__elementRecords,[element]);for(const name of [state.id,state.namespaceURI==="http://www.w3.org/1999/xhtml"?state.attributes.name:""])if(name&&name!=="length"&&!Reflect.has(target,name)&&!keys.includes(name))keys.push(name);}
   return keys;
  },
  getOwnPropertyDescriptor(target,property){
   const own=Reflect.getOwnPropertyDescriptor(target,property);if(own)return own;
   if(property==="length")return{value:read().length,writable:false,enumerable:false,configurable:true};
   if(isIndex(property)){const element=read()[Number(property)];if(element)return{value:element,writable:false,enumerable:true,configurable:true};}
   else if(typeof property==="string"){const element=named(read(),property);if(element)return{value:element,writable:false,enumerable:false,configurable:true};}
  }
 });
}
Object.defineProperty(Element.prototype,"getElementsByClassName",{value:function getElementsByClassName(classNames){
 "use strict";
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state)throw new TypeError("Illegal Element receiver");
 if(arguments.length===0)throw new TypeError("getElementsByClassName requires class names");
 if(typeof classNames==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 return __classCollection(state.bridgeKey,String(classNames));
},writable:true,enumerable:true,configurable:true});
document.getElementsByClassName=function getElementsByClassName(classNames){
 "use strict";
 if(this!==document)throw new TypeError("Illegal Document receiver");
 if(arguments.length===0)throw new TypeError("getElementsByClassName requires class names");
 if(typeof classNames==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 return __classCollection("",String(classNames));
};
'
}
