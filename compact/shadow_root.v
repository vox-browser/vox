module main

import dom
import html
import platform
import x.json2

fn (mut binding CompactElementQueryBinding) materialize_shadow_host(key string, state json2.Any) !&dom.Node {
	if node := binding.node_for_key(key) { return node }
	if state !is map[string]json2.Any { return error('TypeError: Invalid shadow host') }
	if !key.starts_with('__created_') || (json_string_property(state, 'bridgeKey') or { '' }) != key {
		return error('TypeError: Invalid shadow host')
	}
	mut elements := binding.elements.clone()
	created := javascript_created_node(binding.document, state, mut elements) or {
		return error('TypeError: Invalid shadow host')
	}
	for element_key, element in elements {
		binding.elements[element_key] = element
		binding.keys[voidptr(element)] = element_key
	}
	binding.nodes[key] = created
	return created
}

fn (mut binding CompactElementQueryBinding) attach_shadow_query(key string, input string) !string {
	mut storage := binding.document.native_storage()
	mut allocation_scope := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
	defer { allocation_scope.finish() }
	request := json2.decode[map[string]json2.Any](input)!
	node := binding.materialize_shadow_host(key, request['state'] or { json2.Any(json2.Null{}) })!
	mut host := node.as_element() or { return error('TypeError: Invalid shadow host') }
	mode := json_string_property(request, 'mode') or { return error('TypeError: Missing shadow mode') }
	slot := json_string_property(request, 'slotAssignment') or { 'named' }
	if mode !in ['open', 'closed'] || slot !in ['named', 'manual'] {
		return error('TypeError: Invalid shadow root enumeration')
	}
	root := host.attach_shadow(dom.ShadowRootInit{
		mode: if mode == 'open' { .open } else { .closed }
		delegates_focus: json_bool_property(request, 'delegatesFocus')
		clonable: json_bool_property(request, 'clonable')
		serializable: json_bool_property(request, 'serializable')
		slot_assignment: if slot == 'manual' { .manual } else { .named }
	})!
	binding.note_node_tree_mutation()
	return binding.encode_node_state(root.as_node())
}

fn (mut binding CompactElementQueryBinding) shadow_query(root &dom.Node, action string, value string) !string {
	if action == 'getRootNode' {
		options := json2.decode[map[string]json2.Any](value)!
		found := if json_bool_property(options, 'composed') { root.shadow_including_root() } else { root.root() }
		return binding.encode_node_state(found)
	}
	if action == 'shadowRoot' {
		host := root.as_element() or { return error('TypeError: Invalid shadow host') }
		return if shadow := host.shadow_root_for_bindings() {
			binding.encode_node_state(shadow.as_node())
		} else { 'null' }
	}
	shadow := root.as_shadow_root() or { return error('TypeError: Illegal ShadowRoot receiver') }
	if action == 'shadowHost' {
		return if host := shadow.host() {
			binding.encode_element_state(host)
		} else { 'null' }
	}
	if action == 'shadowElementById' {
		// ID lookup stays in this tree, with no selector escaping and no
		// document-level lookup that could reveal a sibling shadow tree.
		if value == '' { return 'null' }
		mut current := root.first_child()
		for {
			node := current or { break }
			if element := node.as_element() {
				if element.get_attribute_value('id') == value {
					return binding.encode_element_state(element)
				}
			}
			current = node.next_in_pre_order(root)
		}
		return 'null'
	}
	return json2.encode(match value {
		'mode' { json2.Any(shadow.mode().str()) }
		'delegatesFocus' { json2.Any(shadow.delegates_focus_) }
		'clonable' { json2.Any(shadow.clonable_) }
		'serializable' { json2.Any(shadow.serializable_) }
		'slotAssignment' { json2.Any(shadow.slot_assignment_.str()) }
		'innerHTML' { json2.Any(shadow.inner_html()!) }
		else { return error('Invalid ShadowRoot property') }
	})
}

fn (mut binding CompactElementQueryBinding) set_markup_query(root &dom.Node, input string) !string {
	request := json2.decode[map[string]json2.Any](input)!
	source := json_string_property(request, 'html') or { return error('Missing HTML source') }
	unsafe_html := json_bool_property(request, 'unsafe')
	// Install the same fragment parser used by normal innerHTML, including
	// template ownership and the owning document's shadow/style scope.
	html.install_document_fragment_parsing_hook(root.document())
	if mut shadow := root.as_shadow_root() {
		if unsafe_html { shadow.set_html_unsafe(source)! } else { shadow.set_inner_html(source)! }
	} else if mut element := root.as_element() {
		if !unsafe_html { return error('TypeError: Expected a ShadowRoot') }
		element.set_html_unsafe(source)!
	} else {
		return error('TypeError: Invalid HTML insertion receiver')
	}
	binding.note_node_tree_mutation()
	return 'null'
}

fn compact_shadow_root_bootstrap() string {
	return r'
function ShadowRoot(){throw new TypeError("Illegal ShadowRoot constructor");}
Object.setPrototypeOf(ShadowRoot,DocumentFragment);Object.setPrototypeOf(ShadowRoot.prototype,DocumentFragment.prototype);
Object.defineProperty(ShadowRoot,"prototype",{writable:false});
Object.defineProperty(ShadowRoot.prototype,Symbol.toStringTag,{value:"ShadowRoot",configurable:true});
Object.defineProperty(globalThis,"ShadowRoot",{value:ShadowRoot,writable:true,configurable:true});
function __compactShadowState(receiver){const state=__elementApply(__compactNodeGet,__compactNodeRecords,[receiver]);if(!state||!state.isShadowRoot)throw new TypeError("Illegal ShadowRoot receiver");return state;}
function __compactShadowCall(state,action,value){try{return __queryElements(state.bridgeKey,action,value);}catch(error){const match=/^(NotSupportedError|InvalidStateError|HierarchyRequestError|SyntaxError|NoModificationAllowedError):\s*(.*)/.exec(String(error.message));if(match)throw new DOMException(match[2],match[1]);throw error;}}
const __compactShadowString=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
Object.defineProperty(Element.prototype,"attachShadow",{value:function attachShadow(init){
 "use strict";
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!state)throw new TypeError("Illegal Element receiver");
 if(!init||(typeof init!=="object"&&typeof init!=="function"))throw new TypeError("attachShadow requires an options dictionary");
 const clonable=!!init.clonable,delegatesFocus=!!init.delegatesFocus,rawMode=init.mode;
 if(rawMode===undefined)throw new TypeError("Shadow mode is required");
 const mode=__compactShadowString(rawMode),serializable=!!init.serializable,rawSlot=init.slotAssignment,slotAssignment=rawSlot===undefined?"named":__compactShadowString(rawSlot);
 if(!["open","closed"].includes(mode)||!["named","manual"].includes(slotAssignment))throw new TypeError("Invalid shadow root enumeration");
 return __compactShadowCall(state,"attachShadow",JSON.stringify({mode,clonable,delegatesFocus,serializable,slotAssignment,state:state.created?state:{}}));
},writable:true,enumerable:true,configurable:true});
Object.defineProperty(Element.prototype,"shadowRoot",{get:function(){const state=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!state)throw new TypeError("Illegal Element receiver");return state.created&&!state.nativeParent?__compactShadowCall(state,"shadowRoot",JSON.stringify(state)):__compactShadowCall(state,"shadowRoot","");},enumerable:true,configurable:true});
for(const name of ["mode","delegatesFocus","clonable","serializable","slotAssignment"])Object.defineProperty(ShadowRoot.prototype,name,{get:function(){return __compactShadowCall(__compactShadowState(this),"shadowValue",name);},enumerable:true,configurable:true});
Object.defineProperty(ShadowRoot.prototype,"host",{get:function(){return __compactShadowCall(__compactShadowState(this),"shadowHost","");},enumerable:true,configurable:true});
Object.defineProperty(ShadowRoot.prototype,"activeElement",{get:function(){return __queryElements(__compactShadowState(this).bridgeKey,"documentNode","activeElement");},enumerable:true,configurable:true});
Object.defineProperty(ShadowRoot.prototype,"innerHTML",{get:function(){return __compactShadowCall(__compactShadowState(this),"shadowValue","innerHTML");},set:function(value){const state=__compactShadowState(this);__compactShadowCall(state,"setMarkup",JSON.stringify({html:value===null?"":__compactShadowString(value),unsafe:false}));__compactInvalidateContent(state);},enumerable:true,configurable:true});
Object.defineProperty(ShadowRoot.prototype,"getElementById",{value:function getElementById(id){const state=__compactShadowState(this);if(!arguments.length)throw new TypeError("getElementById requires an ID");return __compactShadowCall(state,"shadowElementById",__compactShadowString(id));},writable:true,enumerable:true,configurable:true});
for(const [prototype,isShadow] of [[Element.prototype,false],[ShadowRoot.prototype,true]])Object.defineProperty(prototype,"setHTMLUnsafe",{value:function setHTMLUnsafe(value){
 "use strict";const state=isShadow?__compactShadowState(this):__elementApply(__elementRecordGet,__elementRecords,[this]);if(!state)throw new TypeError("Illegal Element receiver");if(!arguments.length)throw new TypeError("setHTMLUnsafe requires HTML");
 __compactShadowCall(state,"setMarkup",JSON.stringify({html:__compactShadowString(value),unsafe:true,state:state.created?state:{}}));__compactInvalidateContent(state);
},writable:true,enumerable:true,configurable:true});
Object.defineProperty(Node.prototype,"getRootNode",{value:function getRootNode(options){"use strict";const state=__compactNodeState(this);if(options!==undefined&&options!==null&&typeof options!=="object"&&typeof options!=="function")throw new TypeError("Expected root options");return __queryElements(state.bridgeKey,"getRootNode",JSON.stringify({composed:!!(options&&options.composed),state:state.created?state:{}}));},writable:true,enumerable:true,configurable:true});
'
}
