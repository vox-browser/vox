module main

import browserjs
import css
import dom
import html
import x.json2

// Detached documents belong to this realm but have their own native tree,
// URL, origin and DOMImplementation. Retain them until the realm closes.
fn install_compact_document_binding(binding &CompactElementQueryBinding, mut runtime browserjs.Runtime) ! {
	if runtime.engine == .javascriptcore {
		runtime.install_document_event_target_resolver(fn [binding] (key string) ?&dom.Document {
			if key == '' { return binding.document }
			node := binding.nodes[key] or { return none }
			return node.as_document()
		})!
	}
	runtime.define_number_host_function('__ladybirdDOMTreeVersion', fn [binding] () f64 {
		mut version := binding.document.dom_tree_version()
		for _, document in binding.documents {
			next := document.dom_tree_version()
			if next > u64(9007199254740991) || version > u64(9007199254740991) - next { return -1 }
			version += next
		}
		// Template fragments belong to an inert document. Its mutation clock
		// keeps saved live collections current after queued writes are replayed.
		// The embedding document owns this document's lifetime.
		for _, document in binding.template_documents {
			next := document.dom_tree_version()
			if next > u64(9007199254740991) || version > u64(9007199254740991) - next { return -1 }
			version += next
		}
		return if version <= u64(9007199254740991) { f64(version) } else { -1.0 }
	})!
	runtime.add_close_handler(fn [binding] () {
		for _, document in binding.documents {
			mut owner := unsafe { &dom.Document(document) }
			owner.finalize()
		}
	})
}

fn (mut binding CompactElementQueryBinding) document_state(document &dom.Document) json2.Any {
	key := if voidptr(document) == voidptr(binding.document) {
		''
	} else {
		'__document_${document.as_node().unique_id()}'
	}
	if key != '' { binding.nodes[key] = document.as_node() }
	return json2.Any({
		'bridgeKey': json2.Any(key)
		'nodeType':  json2.Any(9)
		'nodeName':  json2.Any('#document')
		'tagName':   json2.Any('#node')
	})
}

fn (mut binding CompactElementQueryBinding) document_query(root &dom.Node, action string, value string) !string {
	if action == 'documentNode' && value == 'activeElement' {
		active := if shadow := root.as_shadow_root() { shadow.active_element() } else if root.is_document() { root.document().active_element() } else { return error('TypeError: Illegal DocumentOrShadowRoot receiver') }
		return if element := active { json2.encode(binding.element_state(element)) } else { 'null' }
	}
	if action == 'ownerDocument' {
		return if root.is_document() {
			'null'
		} else {
			json2.encode(binding.document_state(root.document()))
		}
	}
	if action == 'elementURL' {
		element := root.as_element() or { return error('TypeError: Invalid Element receiver') }
		attribute := element.get_attribute(value) or { return json2.encode('') }
		return json2.encode(root.document().encoding_parse_and_serialize_url(attribute) or { attribute })
	}
	mut document := root.as_document() or { return error('TypeError: Invalid Document receiver') }
	if action == 'documentCurrentScript' {
		return if script := document.current_script() {
			json2.encode(binding.element_state(unsafe { &dom.Element(script) }))
		} else { 'null' }
	}
	if action == 'createHTMLDocument' {
		request := json2.decode[map[string]json2.Any](value)!
		created := document.implementation().create_html_document(json_string_property(request, 'title'))!
		html.install_document_fragment_parsing_hook(created)
		css.install_document_selector_query_hook(created)
		key := '__document_${created.as_node().unique_id()}'
		binding.documents[key] = created
		return json2.encode(binding.document_state(created))
	}
	if action == 'documentValue' {
		if value == 'hidden' { return json2.encode(document.hidden()) }
		if value == 'hasFocus' { return json2.encode(document.has_focus_for_bindings()) }
		return json2.encode(match value {
			'title' { document.title() }
			'URL', 'documentURI' { document.url.serialize() }
			'baseURI' { document.base_url().serialize() }
			'contentType' { document.get_content_type() }
			'compatMode' { document.compat_mode() }
			'characterSet' { document.character_set() }
			'readyState' { document.ready_state() }
			'visibilityState' { document.visibility_state() }
			'referrer' { document.referrer() }
			else { return error('Invalid Document property') }
		})
	}
	if action == 'setDocumentTitle' {
		document.set_title(value)!
		if voidptr(document) == voidptr(binding.document) { binding.note_node_tree_mutation() }
		return 'null'
	}
	if action == 'documentElementById' {
		return if element := document.get_element_by_id(value) {
			json2.encode(binding.element_state(element))
		} else {
			'null'
		}
	}
	if action == 'documentNode' {
		node := match value {
			'documentElement' {
				if element := document.document_element() {
					?&dom.Node(element.as_node())
				} else {
					none
				}
			}
			'head' {
				if element := document.head() { ?&dom.Node(element.as_node()) } else { none }
			}
			'body' {
				if element := document.body() { ?&dom.Node(element.as_node()) } else { none }
			}
			'doctype' {
				if item := document.doctype() { ?&dom.Node(item.as_node()) } else { none }
			}
			else { return error('Invalid Document node property') }
		}
		return if found := node { json2.encode(binding.node_state(found)) } else { 'null' }
	}
	if action == 'documentCreateElement' {
		return json2.encode(binding.element_state(document.create_element(value)!))
	}
	if action == 'documentCreateElementNS' {
		request := json2.decode[map[string]json2.Any](value)!
		name := json_string_property(request, 'name') or { return error('Missing qualified name') }
		return json2.encode(binding.element_state(document.create_element_ns(json_string_property(request, 'namespace'), name)!))
	}
	return error('Invalid Document action')
}

fn compact_document_bootstrap() string {
	return r'
const __compactDocuments=new WeakMap(),__compactImplementations=new WeakMap(),__compactImplementationOwners=new WeakMap();
function Document(){throw new TypeError("Illegal Document constructor");}
function HTMLDocument(){throw new TypeError("Illegal HTMLDocument constructor");}
function DOMImplementation(){throw new TypeError("Illegal DOMImplementation constructor");}
for(const [constructor,parent,name] of [[Document,Node,"Document"],[HTMLDocument,Document,"HTMLDocument"],[DOMImplementation,Object,"DOMImplementation"]]){
 Object.setPrototypeOf(constructor,parent);Object.setPrototypeOf(constructor.prototype,parent.prototype);
 Object.defineProperty(constructor,"prototype",{writable:false});
 Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
 Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
}
function __compactDocumentState(receiver){const state=__elementApply(__compactNodeGet,__compactDocuments,[receiver]);if(!state)throw new TypeError("Illegal Document receiver");return state;}
function __compactDocumentString(value){if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);}
Object.defineProperty(Document.prototype,"hasFocus",{value:function hasFocus(){return __queryElements(__compactDocumentState(this).bridgeKey,"documentValue","hasFocus");},writable:true,enumerable:true,configurable:true});
Object.defineProperty(Document.prototype,"implementation",{get:function(){
 __compactDocumentState(this);let implementation=__elementApply(__compactNodeGet,__compactImplementations,[this]);
 if(!implementation){implementation=Object.create(DOMImplementation.prototype);__elementApply(__elementRecordSet,__compactImplementations,[this,implementation]);__elementApply(__elementRecordSet,__compactImplementationOwners,[implementation,this]);}return implementation;
},enumerable:true,configurable:true});
Object.defineProperty(DOMImplementation.prototype,"createHTMLDocument",{value:function createHTMLDocument(){
 const owner=__elementApply(__compactNodeGet,__compactImplementationOwners,[this]);if(!owner)throw new TypeError("Illegal DOMImplementation receiver");
 const title=arguments[0],request={};if(arguments.length&&title!==undefined)request.title=__compactDocumentString(title);
 return __queryElements(__compactDocumentState(owner).bridgeKey,"createHTMLDocument",JSON.stringify(request));
},writable:true,enumerable:true,configurable:true});
function __compactDocumentWrapper(state){
 if(state.bridgeKey==="")return document;if(state.__object)return state.__object;
 const object=Object.create(HTMLDocument.prototype);
 __elementApply(__elementRecordSet,__compactDocuments,[object,state]);__elementApply(__elementRecordSet,__compactNodeRecords,[object,state]);
 if(typeof __ladybirdDocumentEventTargetBind==="function")__ladybirdDocumentEventTargetBind(object,state.bridgeKey);
 Object.defineProperty(state,"__object",{value:object});return object;
}
Object.setPrototypeOf(document,HTMLDocument.prototype);
// Route creation through the native document factory. The earlier compact
// own methods otherwise allocate a second wrapper during custom construction.
delete document.createElement;delete document.createElementNS;
for(const name of ["addEventListener","removeEventListener","dispatchEvent"])Object.defineProperty(Document.prototype,name,{value:EventTarget.prototype[name],writable:true,enumerable:true,configurable:true});
const __compactDocumentLegacyAdd=document.addEventListener;
function __compactDocumentNativeEvent(name){return name==="click"||name==="keydown"||name==="keyup"||name==="keypress"||name==="beforeinput"||name==="input"||name==="change"||name==="submit"||name==="reset"||name==="formdata"||name==="invalid";}
document.addEventListener=function(name,callback,options){
 name=String(name);if(__compactDocumentNativeEvent(name))return EventTarget.prototype.addEventListener.call(this,name,callback,options);
 return __compactDocumentLegacyAdd.call(this,name,callback,options);
};
document.removeEventListener=function(name,callback,options){
 name=String(name);if(__compactDocumentNativeEvent(name))return EventTarget.prototype.removeEventListener.call(this,name,callback,options);
 const key=__listenerKey(null,name);__listeners[key]=(__listeners[key]||[]).filter(listener=>listener!==callback);
};
__elementApply(__elementRecordSet,__compactDocuments,[document,{bridgeKey:"",nodeType:9}]);
for(const name of ["documentElement","head","body","doctype","activeElement"]){Object.defineProperty(Document.prototype,name,{get:function(){return __queryElements(__compactDocumentState(this).bridgeKey,"documentNode",name);},enumerable:true,configurable:true});}
for(const name of ["title","URL","documentURI","baseURI","contentType","compatMode","characterSet","readyState","referrer","hidden","visibilityState"]){Object.defineProperty(Document.prototype,name,{get:function(){return __queryElements(__compactDocumentState(this).bridgeKey,"documentValue",name);},set:name==="title"?function(value){const state=__compactDocumentState(this);__queryElements(state.bridgeKey,"setDocumentTitle",__compactDocumentString(value));for(const title of __queryElements(state.bridgeKey,"querySelectorAll","title"))__compactInvalidateContent(__compactNodeState(title));}:undefined,enumerable:true,configurable:true});}
Object.defineProperty(Document.prototype,"currentScript",{get:function(){return __queryElements(__compactDocumentState(this).bridgeKey,"documentCurrentScript","");},enumerable:true,configurable:true});
for(const [name,value] of [["nodeType",9],["nodeName","#document"],["ownerDocument",null],["parentNode",null],["parentElement",null],["nodeValue",null],["textContent",null],["defaultView",null],["location",null]])Object.defineProperty(Document.prototype,name,{get:function(){__compactDocumentState(this);return value;},enumerable:true,configurable:true});
Object.defineProperty(Document.prototype,"childNodes",{get:function(){return __compactChildNodes(this,__compactDocumentState(this));},enumerable:true,configurable:true});
for(const name of ["firstChild","lastChild"])Object.defineProperty(Document.prototype,name,{get:function(){return __queryElements(__compactDocumentState(this).bridgeKey,name,"");},enumerable:true,configurable:true});
for(const name of ["querySelector","querySelectorAll","getElementById","getElementsByTagName","getElementsByClassName"]){Object.defineProperty(Document.prototype,name,{value:function(value){const state=__compactDocumentState(this);if(!arguments.length)throw new TypeError(name+" requires an argument");value=__compactDocumentString(value);return name==="getElementsByTagName"?__tagCollection(state.bridgeKey,value):__queryElements(state.bridgeKey,name==="getElementById"?"documentElementById":name,value);},writable:true,enumerable:true,configurable:true});}
for(const [name,action] of [["createElement","documentCreateElement"],["createTextNode","createText"],["createDocumentFragment","createFragment"]])Object.defineProperty(Document.prototype,name,{value:function(value){const state=__compactDocumentState(this);if(name!=="createDocumentFragment"&&!arguments.length)throw new TypeError(name+" requires an argument");return __queryElements(state.bridgeKey,action,name==="createDocumentFragment"?"":__compactDocumentString(value));},writable:true,enumerable:true,configurable:true});
Object.defineProperty(Document.prototype,"createElementNS",{value:function createElementNS(namespace,name){const state=__compactDocumentState(this);if(arguments.length<2)throw new TypeError("createElementNS requires two arguments");namespace=namespace==null?null:__compactDocumentString(namespace);name=__compactDocumentString(name);const element=__queryElements(state.bridgeKey,"documentCreateElementNS",JSON.stringify({namespace:namespace,name:name}));__compactNodeState(element).tagName=name;return element;},writable:true,enumerable:true,configurable:true});
function __compactOwnerDocument(object){return __queryElements(__compactNodeState(object).bridgeKey,"ownerDocument","");}
function __compactDocumentElementBindings(object,state){
 if(!state.ownerDocumentKey)return;
 object.appendChild=function appendChild(child){return __compactInsertNode(this,child,null,false);};
 object.insertBefore=function insertBefore(child,reference){return __compactInsertNode(this,child,reference,true);};
}
' + compact_tree_walker_bootstrap() + compact_adopted_style_sheets_bootstrap()
}
