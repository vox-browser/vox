module main

import browserjs
import dom
import html
import platform
import x.json2

struct CompactInputValueQuery {
	write    bool
	property string = 'value'
	value    string
	state    map[string]json2.Any
}

// Value belongs to the native control, including its dirty flag, sanitization,
// selection and placeholder. Detached script-created inputs need that same owner
// before insertion, rather than a separate value cached on their JS facade.
fn (mut binding CompactElementQueryBinding) input_value_query(key string, source string) !string {
	query := compact_decode_query[CompactInputValueQuery](source)!
	mut storage := binding.document.native_storage()
	mut allocation_scope := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
	defer { allocation_scope.finish() }
	mut node := binding.node_for_key(key) or {
		if !key.starts_with('__created_')
			|| (json_string_property(query.state, 'bridgeKey') or { '' }) != key {
			return error('TypeError: Invalid HTMLInputElement receiver')
		}
		mut elements := binding.elements.clone()
		created := javascript_created_node(binding.document, query.state, mut elements) or {
			return error('TypeError: Invalid HTMLInputElement receiver')
		}
		for bridge_key, element in elements {
			binding.elements[bridge_key] = element
			binding.keys[voidptr(element)] = bridge_key
		}
		created
	}
	mut element := node.as_element() or { return error('TypeError: Invalid text control receiver') }
	if !element.is_html_element() || element.local_name() !in ['input', 'textarea']
		|| query.property !in ['value', 'defaultValue'] {
		return error('TypeError: Invalid text control receiver')
	}
	mut value := ''
	if element.local_name() == 'input' {
		mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		if query.write {
			if query.property == 'defaultValue' {
				apply_javascript_element_attribute(mut element, 'value', query.value.clone())
			} else {
				model.set_value(query.value.clone()) or {
					return json2.encode({
						'exception': json2.Any('InvalidStateError')
						'message':   json2.Any(err.msg())
					})
				}
			}
		}
		value = if query.property == 'defaultValue' { model.default_value() } else { model.value() }
	} else {
		mut model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
		// Generic DOM text/markup replay precedes this query. Relay changed
		// default text to a clean native editor without touching a dirty value.
		if !model.dirty_value && model.text.relevant_value() != model.default_value() {
			model.children_changed(dom.ChildrenChangedMetadata{})
		}
		if query.write {
			if query.property == 'defaultValue' {
				model.set_default_value(query.value.clone())
			} else {
				model.set_value(query.value.clone())
			}
		}
		value = if query.property == 'defaultValue' { model.default_value() } else { model.value() }
	}
	if query.write {
		mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
		runtime.mark_document_state_dirty()
		runtime.mark_document_replay_effects()
	}
	allocation_scope.finish()
	records, attributes := browserjs.compact_attribute_state(element)
	return compact_replay_json_result(json2.encode({
		'value':            json2.Any(value)
		'attributeRecords': json2.Any(records)
		'attributes':       json2.Any(attributes)
	}))
}

fn compact_input_value_bootstrap() string {
	return r'
function __compactIsInputState(state){return state.namespaceURI==="http://www.w3.org/1999/xhtml"&&state.tagName==="input";}
const __compactInputFiles=globalThis.__ladybirdInputFiles;delete globalThis.__ladybirdInputFiles;
function __compactControlFiles(receiver,write,value){
 const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
 if(!state||!__compactIsInputState(state))throw new TypeError("Illegal HTMLInputElement receiver");
 __queryElements(state.bridgeKey,"inputFilesOwner",state.created?JSON.stringify(state):"null");
 return __compactInputFiles(state.bridgeKey,state.created?JSON.stringify(state):"",write,value);
}
Object.defineProperty(HTMLInputElement.prototype,"files",Object.getOwnPropertyDescriptor({get files(){return __compactControlFiles(this,false,undefined)},set files(value){__compactControlFiles(this,true,value)}},"files"));
function __compactControlValue(receiver,tag,property,write,value){
 const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
 if(!state||state.namespaceURI!=="http://www.w3.org/1999/xhtml"||state.tagName!==tag)throw new TypeError("Illegal text control receiver");
 if(write){if(value===null&&property==="value")value="";else{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");value=String(value);}}
 const result=__queryElements(state.bridgeKey,"inputValue",JSON.stringify({write,property,value,state:state.created?state:undefined}));
 if(result.exception)throw new DOMException(result.message,result.exception);
 state.attributes=result.attributes;state.attributeRecords=result.attributeRecords;
 if(tag==="textarea")state.nativeContent=true;
 if(tag==="textarea"&&write&&property==="defaultValue"){delete state.textContent;delete state.innerHTML;state.textContentDirty=false;state.innerHTMLDirty=false;}
 return result.value;
}
for(const [constructor,tag] of [[HTMLInputElement,"input"],[HTMLTextAreaElement,"textarea"]])for(const property of ["value","defaultValue"])Object.defineProperty(constructor.prototype,property,{get:function(){return __compactControlValue(this,tag,property,false);},set:function(value){__compactControlValue(this,tag,property,true,value);},enumerable:true,configurable:true});
function __compactElementValue(object,state){
 if(!(state.namespaceURI==="http://www.w3.org/1999/xhtml"&&["input","textarea","select"].includes(state.tagName)))Object.defineProperty(object,"value",{get:function(){return state.value;},set:function(value){state.value=String(value);},configurable:true});
}
'
}
