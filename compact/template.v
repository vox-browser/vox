module main

import dom
import css
import html
import platform
import x.json2

// Template children live in an inert document fragment rather than the host's
// ordinary children. Expose that native subtree for cloning and insertion.
fn (mut binding CompactElementQueryBinding) template_content_query(key string, source string) !string {
	mut storage := binding.document.native_storage()
	mut allocation_scope := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
	defer { allocation_scope.finish() }
	node := binding.node_for_key(key) or {
		state := json2.decode[map[string]json2.Any](source)!
		if !key.starts_with('__created_') || (json_string_property(state, 'bridgeKey') or { '' }) != key {
			return error('TypeError: Invalid HTMLTemplateElement receiver')
		}
		mut elements := binding.elements.clone()
		created := javascript_created_node(binding.document, state, mut elements) or {
			return error('TypeError: Invalid HTMLTemplateElement receiver')
		}
		for bridge_key, element in elements {
			binding.elements[bridge_key] = element
			binding.keys[voidptr(element)] = bridge_key
		}
		created
	}
	element := node.as_element() or { return error('TypeError: Invalid HTMLTemplateElement receiver') }
	if !element.is_html_element() || element.local_name() != 'template' {
		return error('TypeError: Invalid HTMLTemplateElement receiver')
	}
	template := unsafe { &dom.HTMLTemplateElement(element) }
	content := template.content().as_node()
	owner := content.document()
	css.install_document_selector_query_hook(owner)
	html.install_document_fragment_parsing_hook(owner)
	if voidptr(owner) != voidptr(binding.document) {
		binding.template_documents[voidptr(owner)] = owner
	}
	return binding.encode_node_state(content)
}

fn compact_template_bootstrap() string {
	return r'
function __compactIsTemplateState(state){return state.namespaceURI==="http://www.w3.org/1999/xhtml"&&String(state.tagName).split(":").pop()==="template";}
Object.defineProperty(HTMLTemplateElement.prototype,"content",{get:function(){
 const state=__elementApply(__elementRecordGet,__elementRecords,[this]);
 if(!state||!__compactIsTemplateState(state))throw new TypeError("Illegal HTMLTemplateElement receiver");
 return __queryElements(state.bridgeKey,"templateContent",JSON.stringify(state.created?state:{}));
},enumerable:true,configurable:true});
function __compactTemplateInnerHTML(state){
 __queryElements(state.bridgeKey,"templateContent",JSON.stringify(state.created?state:{}));
 return __readElementContent(String(state.bridgeKey)+":innerHTML");
}
function __compactElementContentBinding(object,state){
 if(!__compactIsTemplateState(state))Object.defineProperty(object,"content",{get:function(){return __compactNativeAttributes.read(state,"content",true)||"";},set:function(value){__compactNativeAttributes.write(state,"content",value,true);},configurable:true});
}
'
}
