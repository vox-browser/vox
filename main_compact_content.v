module main

import browserjs
import dom
import css
import html
import strconv
import x.json2

@[heap]
struct CompactElementQueryBinding {
	document &dom.Document
	runtime  &browserjs.Runtime
mut:
	elements map[string]&dom.Element
	documents map[string]&dom.Document
	template_documents map[voidptr]&dom.Document
	nodes    map[string]&dom.Node
	keys     map[voidptr]string
	materialized map[string]bool
	style_sheets map[string]&css.CSSStyleSheet
	css_rules map[string]&css.CSSRule
	css_rule_lists map[string]&css.CSSRuleList
	next_key int
}

fn install_compact_element_content_binding_with_policy(document &dom.Document, mut runtime browserjs.Runtime, policy CompactInitialElementPolicy) ! {
	elements := css.query_selector_all(unsafe { &dom.Node(document) }, '*')
	mut binding := &CompactElementQueryBinding{
		document: document
		runtime:  &runtime
	}
	install_compact_document_binding(binding, mut runtime)!
	for index, element in elements {
		key := '__element_${index}'
		binding.elements[key] = element
		binding.keys[voidptr(element)] = key
		binding.materialized[key] = policy == .all_elements || compact_initial_element_state_needed(element)
	}
	runtime.add_canvas_element_provider_with_identity_lookup(fn [binding] () map[string]&dom.Element {
		return binding.elements.clone()
	}, fn [binding] (key string) ?&dom.Element {
		return binding.elements[key] or { return none }
	}, fn [binding] (element &dom.Element) []string {
		if key := binding.keys[voidptr(element)] { return [key] }
		return []string{}
	})
	runtime.define_host_function('__ladybirdReadElementContent', fn [elements, binding] (input string) !string {
		parts := input.split(':')
		if parts.len != 2 {
			return error('Invalid element content request')
		}
		element := binding.elements[parts[0]] or {
			binding.runtime.canvas_element_for_binding(parts[0]) or {
				index := strconv.atoi(parts[0])!
				if index < 0 || index >= elements.len {
					return error('Invalid element content index')
				}
				elements[index]
			}
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

fn (mut binding CompactElementQueryBinding) node_for_key(key string) ?&dom.Node {
	if node := binding.nodes[key] { return node }
	element := binding.elements[key] or {
		binding.runtime.canvas_element_for_binding(key) or { return none }
	}
	binding.elements[key] = element
	binding.keys[voidptr(element)] = key
	return element.as_node()
}

fn (mut binding CompactElementQueryBinding) element_key(element &dom.Element) string {
	if key := binding.keys[voidptr(element)] {
		return key
	}
	// A native host can materialize a script-created element before a selector
	// replays its state. Keep that host's key and its existing owning wrapper.
	if key := binding.runtime.canvas_element_key_for_binding(element) {
		binding.keys[voidptr(element)] = key
		binding.elements[key] = element
		return key
	}
	binding.next_key++
	key := '__query_${binding.next_key}'
	binding.keys[voidptr(element)] = key
	binding.elements[key] = element
	return key
}

fn (mut binding CompactElementQueryBinding) element_state(element &dom.Element) json2.Any {
	key := binding.element_key(element)
	if binding.materialized[key] {
		return json2.Any({'bridgeKey': json2.Any(key)})
	}
	binding.materialized[key] = true
	parent_key := if parent := element.as_node().parent_element() {
		binding.keys[voidptr(parent)] or { '' }
	} else {
		''
	}
	index := if key.starts_with('__element_') { key['__element_'.len..].int() } else { -1 }
	mut state := javascript_initial_element_state(element, key, index, parent_key,
		element.document().url.serialize(), true)
	if voidptr(element.document()) != voidptr(binding.document) {
		state['ownerDocumentKey'] = json2.Any('__document_${element.document().as_node().unique_id()}')
	}
	return json2.Any(state)
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
	if action == 'cssSheet' { return binding.css_sheet_query(selector) }
	if action == 'linkSheet' { return binding.link_sheet_query(key) }
	if action == 'inputValue' { return binding.input_value_query(key, selector) }
	if action == 'templateContent' { return binding.template_content_query(key, selector) }
	if action == 'attachShadow' { return binding.attach_shadow_query(key, selector) }
	if key.starts_with('__created_') && action in ['shadowRoot', 'setMarkup', 'getRootNode'] {
		if binding.node_for_key(key) == none {
			request_state := json2.decode[map[string]json2.Any](selector)!
			state := if action == 'shadowRoot' { json2.Any(request_state) } else {
				request_state['state'] or { json2.Any(json2.Null{}) }
			}
			binding.materialize_shadow_host(key, state)!
		}
	}
	if action in ['elementFromPoint', 'elementsFromPoint'] {
		return binding.hit_test_query(action, selector)
	}
	if action == 'state' {
		node := binding.node_for_key(key) or { return 'null' }
		return json2.encode(binding.node_state(node))
	}
	if action == 'snapshotStates' {
		mut states := []json2.Any{}
		for element in css.query_selector_all(binding.document.as_node(), '*') {
			states << binding.element_state(element)
		}
		return json2.encode(states)
	}
	// A script-created element can remain entirely in the compact realm until
	// its first insertion. Once materialized, its live native owner also tracks
	// subtree adoption and removal without relying on a cached parent key.
	if action == 'ownerDocument' && key.starts_with('__created_') {
		if node := binding.node_for_key(key) {
			return binding.document_query(node, action, selector)
		}
		return json2.encode(binding.document_state(binding.document))
	}
	root := if key == '' {
		unsafe { &dom.Node(binding.document) }
	} else {
		binding.node_for_key(key) or { return error('TypeError: Invalid Element receiver') }
	}
	if action in ['createHTMLDocument', 'documentNode', 'documentValue', 'documentCurrentScript', 'setDocumentTitle',
		'documentCreateElement', 'documentCreateElementNS', 'documentElementById', 'ownerDocument', 'elementURL'] {
		return binding.document_query(root, action, selector)
	}
	if action == 'removeChild' { return binding.remove_child_query(root, selector) }
	if action == 'contains' { return binding.contains_query(root, selector) }
	if action == 'nodeConnected' { return json2.encode(root.is_connected()) }
	if action == 'insertAdjacentHTML' { return binding.insert_adjacent_html_query(root, selector) }
	if action == 'childNodeMutation' { return binding.child_node_query(root, selector) }
	if action == 'parentNodeMutation' { return binding.parent_node_query(root, selector) }
	if action == 'dataset' { return compact_dataset_query(root, selector) }
	if action in ['shadowRoot', 'shadowHost', 'shadowValue', 'shadowElementById', 'getRootNode'] {
		return binding.shadow_query(root, action, selector)
	}
	if action == 'setMarkup' { return binding.set_markup_query(root, selector) }
	if action == 'inlineStyle' { return compact_inline_style_query(root, selector, binding.runtime) }
	if action == 'createComment' { return binding.create_comment_query(root, selector) }
	if action in ['createText', 'createFragment', 'childNodes', 'childElements', 'nodeText', 'setNodeText', 'appendNode', 'insertNode'] {
		return binding.node_tree_query(root, action, selector)
	}
	if action == 'getElementsByTagName' { return binding.tag_collection_query(root, selector) }
	if action == 'lastChild' { return binding.node_relation_query(root, 'last') }
	if action == 'firstChild' { return binding.node_relation_query(root, 'first') }
	if action == 'nextSibling' { return binding.node_relation_query(root, 'next') }
	if action == 'previousSibling' { return binding.node_relation_query(root, 'previous') }
	if action == 'nodeParent' { return binding.node_relation_query(root, 'parent') }
	if action == 'cachedParent' { return binding.cached_parent_query(root) }
	if action == 'geometry' { return compact_element_geometry_query(root, selector) }
	if action == 'setScroll' { return compact_element_set_scroll(root, selector, binding.runtime) }
	if action == 'offsetParent' {
		element := root.as_element() or { return error('TypeError: Invalid Element receiver') }
		if !element.is_html_element() { return 'null' }
		parent := html.html_element_offset_parent(unsafe { &dom.HTMLElement(element) }) or { return 'null' }
		return json2.encode(binding.element_state(parent))
	}
	if action in ['nodeValue', 'setNodeValue'] {
		return binding.node_value_query(root, action, selector)
	}
	if action == 'computedStyle' {
		return compact_computed_style_query(root, selector)
	}
	if action == 'eventAncestors' {
		// Snapshot the native element path before JavaScript listeners can move
		// the target. One request also hydrates any previously unseeded owner.
		mut ancestors := []json2.Any{}
		mut current := root.parent_element()
		for current != none {
			parent := current or { break }
			ancestors << binding.element_state(parent)
			current = parent.as_node().parent_element()
		}
		return json2.encode(ancestors)
	}
	if action == 'elementRelative' {
		// NonDocumentTypeChildNode and ParentNode element navigation.
		parent := unsafe { &dom.ParentNode(root) }
		found := match selector {
			'next' { root.next_element_sibling() }
			'previous' { root.previous_element_sibling() }
			'first' { parent.first_element_child() }
			'last' { parent.last_element_child() }
			else { return error('Invalid element relation') }
		}
		return if element := found { json2.encode(binding.element_state(element)) } else { 'null' }
	}
	if action in ['selectedIndex', 'setSelectedIndex', 'selectValue', 'setSelectValue'] {
		// HTMLSelectElement value and selectedIndex over the live options.
		element := root.as_element() or { return error('TypeError: Invalid Element receiver') }
		if !element.is_html_element() || element.local_name() != 'select' {
			return error('TypeError: Illegal HTMLSelectElement receiver')
		}
		select_element := unsafe { &dom.HTMLSelectElement(element) }
		if action == 'selectValue' || action == 'setSelectValue' {
			mut model := html.HTMLSelectElementModel.create(select_element)
			// Plain parsed documents may be queried before layout initializes the
			// control. Initialize once, preserving explicitly cleared selections.
			if element.shadow_root() == none { html.html_select_element_update_selectedness(select_element) }
			model.create_shadow_tree_if_needed()
			if action == 'setSelectValue' { html.set_html_select_element_value(select_element, selector) }
			return json2.encode(html.html_select_element_value(select_element))
		}
		if action == 'setSelectedIndex' {
			mut model := html.HTMLSelectElementModel.create(select_element)
			model.create_shadow_tree_if_needed()
			html.set_html_select_element_selected_index(select_element, i32(selector.int()))
		}
		return json2.encode(if element.shadow_root() != none {
			html.html_select_element_selected_index(select_element)
		} else {
			compact_select_selected_index(select_element)
		})
	}
	if action == 'cloneNode' {
		// Node.cloneNode() on the live element: the detached copy keeps a bridge
		// key, so later attribute writes, queries and insertion reach it.
		working_copy := root.clone_node_binding(selector == 'deep')!
		copy_compact_script_started_state(root, working_copy)
		return json2.encode(binding.node_state(working_copy))
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
function __classCollection(key, classNames, reader) {
 const read=reader||(()=>__queryElements(key,"getElementsByClassName",classNames));
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
// ParentNode.children: the child elements, read from the live document. An
// element that exists only in the script has none there yet.
Object.defineProperty(Element.prototype,"children",{get:function(){
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state)throw new TypeError("Illegal Element receiver");
 // Wrapper caches must not enter mutation snapshots: serializing a live
 // collection would query native state while that snapshot is being flushed.
 if(!state.__children)Object.defineProperty(state,"__children",{value:__classCollection(state.bridgeKey,"",function(){
  if(state.created&&!state.parentKey)return [];
  return __queryElements(state.bridgeKey,"querySelectorAll",":scope > *");
 })});
 return state.__children;
},enumerable:true,configurable:true});
// Element navigation read from the live document. An element that exists only
// in the script has no document relatives yet.
for(const [name,relation] of [["nextElementSibling","next"],["previousElementSibling","previous"],["firstElementChild","first"],["lastElementChild","last"]]){
 Object.defineProperty(Element.prototype,name,{get:function(){
  const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
  if(!state)throw new TypeError("Illegal Element receiver");
  if(state.created&&!state.parentKey)return null;
  return __queryElements(state.bridgeKey,"elementRelative",relation);
 },enumerable:true,configurable:true});
}
Object.defineProperty(Element.prototype,"childElementCount",{get:function(){return this.children.length;},enumerable:true,configurable:true});
// Node.hasChildNodes(): pending content writes from the script take precedence
// over the children the document reported.
Object.defineProperty(Element.prototype,"hasChildNodes",{value:function hasChildNodes(){
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state)throw new TypeError("Illegal Element receiver");
 if(state.innerHTMLDirty)return state.innerHTML!=="";
 if(state.textContentDirty)return state.textContent!=="";
 return !!state.hasChildren;
},writable:true,enumerable:true,configurable:true});
// Document.forms: the form elements of the document, named by id or name.
{
 const forms=__classCollection("","",()=>__queryElements("","querySelectorAll","form"));
 Object.defineProperty(document,"forms",{get:function(){return forms;},enumerable:true,configurable:true});
}
document.getElementsByClassName=function getElementsByClassName(classNames){
 "use strict";
 if(this!==document)throw new TypeError("Illegal Document receiver");
 if(arguments.length===0)throw new TypeError("getElementsByClassName requires class names");
 if(typeof classNames==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 return __classCollection("",String(classNames));
};
'
}
