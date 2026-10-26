module main

import browserjs
import dom
import html
import platform
import x.json2

struct CompactInputValueQuery {
	write bool
	value string
	state map[string]json2.Any
}

// Value belongs to the native control, including its dirty flag, sanitization,
// selection and placeholder. Detached script-created inputs need that same owner
// before insertion, rather than a separate value cached on their JS facade.
fn (mut binding CompactElementQueryBinding) input_value_query(key string, source string) !string {
	query := json2.decode[CompactInputValueQuery](source)!
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
	element := node.as_element() or { return error('TypeError: Invalid HTMLInputElement receiver') }
	if !element.is_html_element() || element.local_name() != 'input' {
		return error('TypeError: Invalid HTMLInputElement receiver')
	}
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	if query.write {
		model.set_value(query.value.clone()) or {
			// Preserve the native file-input restriction as a DOMException.
			return json2.encode({
				'exception': json2.Any('InvalidStateError')
				'message':   json2.Any(err.msg())
			})
		}
		mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
		runtime.mark_document_state_dirty()
		runtime.mark_document_replay_effects()
	}
	allocation_scope.finish()
	records, attributes := browserjs.compact_attribute_state(element)
	return json2.encode({
		'value':            json2.Any(model.value())
		'attributeRecords': json2.Any(records)
		'attributes':       json2.Any(attributes)
	})
}

fn compact_input_value_bootstrap() string {
	return r'
function __compactIsInputState(state){return state.namespaceURI==="http://www.w3.org/1999/xhtml"&&state.tagName==="input";}
function __compactInputValue(receiver,write,value){
 const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
 if(!state||!__compactIsInputState(state))throw new TypeError("Illegal HTMLInputElement receiver");
 if(write){if(value===null)value="";else{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");value=String(value);}}
 const result=__queryElements(state.bridgeKey,"inputValue",JSON.stringify({write,value,state:state.created?state:undefined}));
 if(result.exception)throw new DOMException(result.message,result.exception);
 state.attributes=result.attributes;state.attributeRecords=result.attributeRecords;
 return result.value;
}
Object.defineProperty(HTMLInputElement.prototype,"value",{get:function(){return __compactInputValue(this,false);},set:function(value){__compactInputValue(this,true,value);},enumerable:true,configurable:true});
function __compactElementValue(object,state){
 if(!__compactIsInputState(state))Object.defineProperty(object,"value",{get:function(){return state.value;},set:function(value){state.value=String(value);}});
}
'
}
