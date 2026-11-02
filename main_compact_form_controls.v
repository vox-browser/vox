module main

import dom
import html
import platform
import x.json2

struct CompactFormControlsQuery {
	op    string
	name  string
	id    string
	value string
	state map[string]json2.Any
	submitter map[string]json2.Any
}

fn (mut binding CompactElementQueryBinding) form_controls_query(key string, source string) !string {
	query := compact_decode_query[CompactFormControlsQuery](source)!
	mut storage := binding.document.native_storage()
	mut scope := if storage != unsafe { nil } {
		storage.enter_nested()
	} else {
		platform.RetainedArenaScope{}
	}
	defer { scope.finish() }
	if query.op == 'owner' {
		node := binding.node_for_key(key) or {
			binding.materialize_shadow_host(key, json2.Any(query.state))!
		}
		element := node.as_element() or { return error('TypeError: Invalid form control receiver') }
		if !element.is_html_element() { return error('TypeError: Invalid form control receiver') }
		mut control := match element.local_name() {
			'input' { html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) }).control }
			'textarea' { html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) }).control }
			'button' { html.HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(element) }).control }
			else { return error('TypeError: Invalid form control receiver') }
		}
		if control.form() == none { control.reset_form_owner() }
		return if owner := control.form() {
			json2.encode(binding.element_state(unsafe { &dom.Element(owner) }))
		} else { 'null' }
	}
	if query.op in ['radioItems', 'radioValue', 'setRadioValue'] {
		mut list := binding.radio_lists[query.id] or { return error('TypeError: Invalid RadioNodeList receiver') }
		if query.op == 'radioValue' { return json2.encode(list.value()) }
		if query.op == 'setRadioValue' {
			list.set_value(query.value.clone())
			mut checks := map[string]json2.Any{}
			for node in list.collection() {
				element := node.as_element() or { continue }
				if element.is_html_element() && element.local_name() == 'input'
					&& element.get_attribute_value('type').to_lower() == 'radio' {
					checks[binding.element_key(element)] = json2.Any(html.html_input_element_checked(unsafe { &dom.HTMLInputElement(element) }))
				}
			}
			return json2.encode(checks)
		}
		mut result := []json2.Any{}
		for node in list.collection() {
			if element := node.as_element() { result << binding.element_state(element) }
		}
		return json2.encode(result)
	}
	node := binding.node_for_key(key) or {
		if !key.starts_with('__created_') || (json_string_property(query.state, 'bridgeKey') or { '' }) != key {
			return error('TypeError: Invalid HTMLFormElement receiver')
		}
		binding.materialize_shadow_host(key, json2.Any(query.state))!
	}
	element := node.as_element() or { return error('TypeError: Invalid HTMLFormElement receiver') }
	if !element.is_html_element() || element.local_name() != 'form' {
		return error('TypeError: Invalid HTMLFormElement receiver')
	}
	mut form := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
	if query.op == 'requestSubmit' {
		mut submitter := ?&html.FormAssociatedElement(none)
		if query.submitter.len > 0 {
			submitter_key := json_string_property(query.submitter, 'bridgeKey') or { return error('TypeError: Expected an HTMLElement') }
			submitter_node := binding.equality_node(submitter_key, json2.Any(query.submitter))!
			submitter_element := submitter_node.as_element() or { return error('TypeError: Expected an HTMLElement') }
			if !submitter_element.is_html_element() { return error('TypeError: Expected an HTMLElement') }
			mut control := match submitter_element.local_name() {
				'button' { html.HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(submitter_element) }).control }
				'input' { html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(submitter_element) }).control }
				else { return error('TypeError: the submitter is not a submit button') }
			}
			if control.form() == none { control.reset_form_owner() }
			submitter = control
		}
		form.request_submit(submitter)!
		return 'null'
	}
	collection := form.elements()
	if query.op == 'items' {
		mut result := []json2.Any{}
		for index in 0 .. collection.length() {
			if control := collection.item(index) { result << binding.element_state(control) }
		}
		return json2.encode(result)
	}
	if query.op == 'named' {
		item := collection.named_item_or_radio_node_list(query.name.clone())
		match item {
			html.HTMLFormControlsCollectionEmpty { return 'null' }
			html.HTMLFormControlsCollectionElement {
				return json2.encode({
					'kind':    json2.Any('element')
					'element': binding.element_state(item.element)
				})
			}
			html.HTMLFormControlsCollectionRadioNodeList {
				binding.next_key++
				id := '__radio_list_${binding.next_key}'
				binding.radio_lists[id] = item.list
				return json2.encode({
					'kind': json2.Any('radios')
					'id':   json2.Any(id)
				})
			}
		}
	}
	return error('Invalid form controls operation')
}

fn compact_form_controls_bootstrap() string {
	return r'
function HTMLCollection(){throw new TypeError("Illegal HTMLCollection constructor");}
function HTMLFormControlsCollection(){throw new TypeError("Illegal HTMLFormControlsCollection constructor");}
function RadioNodeList(){throw new TypeError("Illegal RadioNodeList constructor");}
Object.setPrototypeOf(HTMLFormControlsCollection,HTMLCollection);Object.setPrototypeOf(HTMLFormControlsCollection.prototype,HTMLCollection.prototype);
Object.setPrototypeOf(RadioNodeList,NodeList);Object.setPrototypeOf(RadioNodeList.prototype,NodeList.prototype);
for(const constructor of [HTMLCollection,HTMLFormControlsCollection,RadioNodeList]){
 Object.defineProperty(constructor,"prototype",{writable:false});
 Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:constructor.name,configurable:true});
 Object.defineProperty(globalThis,constructor.name,{value:constructor,writable:true,configurable:true});
}
const __formCollections=new WeakMap(),__formCollectionStates=new WeakMap(),__radioListStates=new WeakMap();
function __formControlsState(receiver){const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);if(!state||state.namespaceURI!=="http://www.w3.org/1999/xhtml"||String(state.tagName).split(":").pop()!=="form")throw new TypeError("Illegal HTMLFormElement receiver");return state;}
function __formControlsQuery(state,request){if(state.created)request.state=state;return __queryElements(state.bridgeKey,"formControls",JSON.stringify(request));}
for(const [constructor,tag] of [[HTMLInputElement,"input"],[HTMLTextAreaElement,"textarea"],[HTMLButtonElement,"button"]])Object.defineProperty(constructor.prototype,"form",{get:function(){
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!state||state.namespaceURI!=="http://www.w3.org/1999/xhtml"||String(state.tagName).split(":").pop()!==tag)throw new TypeError("Illegal form control receiver");
 const owner=__formControlsQuery(state,{op:"owner"});return owner===null?null:__queryElement(owner);
},enumerable:true,configurable:true});
function __formNamedControl(state,name){
 const result=__formControlsQuery(state,{op:"named",name});if(result===null)return null;
 if(result.kind==="element")return __queryElement(result.element);
 const owner={state,id:result.id},list=__compactNodeList(()=>__formControlsQuery(state,{op:"radioItems",id:owner.id}).map(__queryElement));
 Object.setPrototypeOf(list,RadioNodeList.prototype);__elementApply(__elementRecordSet,__radioListStates,[list,owner]);return list;
}
Object.defineProperty(RadioNodeList.prototype,"value",{get:function(){const owner=__elementApply(__compactNodeGet,__radioListStates,[this]);if(!owner)throw new TypeError("Illegal RadioNodeList receiver");return __formControlsQuery(owner.state,{op:"radioValue",id:owner.id});},set:function(value){
 const owner=__elementApply(__compactNodeGet,__radioListStates,[this]);if(!owner)throw new TypeError("Illegal RadioNodeList receiver");
 if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
 const checks=__formControlsQuery(owner.state,{op:"setRadioValue",id:owner.id,value:String(value)});
 for(const key of Object.keys(checks)){const state=__state.elements[key];if(state){state.checked=checks[key];state.checkedDirty=false;}}
},enumerable:true,configurable:true});
Object.defineProperty(HTMLFormControlsCollection.prototype,"namedItem",{value:function namedItem(name){
 const state=__elementApply(__compactNodeGet,__formCollectionStates,[this]);if(!state)throw new TypeError("Illegal HTMLFormControlsCollection receiver");
 if(arguments.length===0)throw new TypeError("namedItem requires a name");if(typeof name==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return __formNamedControl(state,String(name));
},writable:true,enumerable:true,configurable:true});
Object.defineProperty(HTMLFormElement.prototype,"elements",{get:function(){
 const state=__formControlsState(this);let collection=__elementApply(__compactNodeGet,__formCollections,[this]);if(collection)return collection;
 collection=__classCollection(state.bridgeKey,"",()=>__formControlsQuery(state,{op:"items"}).map(__queryElement),name=>__formNamedControl(state,name));
 Object.setPrototypeOf(collection,HTMLFormControlsCollection.prototype);delete collection.namedItem;delete collection[Symbol.toStringTag];
 __elementApply(__elementRecordSet,__formCollectionStates,[collection,state]);__elementApply(__elementRecordSet,__formCollections,[this,collection]);return collection;
},enumerable:true,configurable:true});
Object.defineProperty(HTMLFormElement.prototype,"length",{get:function(){__formControlsState(this);return this.elements.length;},enumerable:true,configurable:true});
Object.defineProperty(HTMLFormElement.prototype,"requestSubmit",{value:({requestSubmit(){
 "use strict";const state=__formControlsState(this),submitter=arguments[0],request={op:"requestSubmit"};
 if(submitter!==undefined&&submitter!==null){
  const target=__elementApply(__elementRecordGet,__elementRecords,[submitter]);
  if(!target||target.namespaceURI!=="http://www.w3.org/1999/xhtml")throw new TypeError("Expected an HTMLElement");
  request.submitter=target;
 }
 try{__formControlsQuery(state,request);}catch(error){
  const match=/^(TypeError|NotFoundError):\s*(.*)/.exec(String(error.message));
  if(match){if(match[1]==="TypeError")throw new TypeError(match[2]);throw new DOMException(match[2],match[1]);}throw error;
 }
}}).requestSubmit,writable:true,enumerable:true,configurable:true});
'
}
