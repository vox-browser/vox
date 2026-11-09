module main

import browserjs
import browserjs.querywire
import css
import dom
import html
import x.json2

// Detached documents belong to this realm but have their own native tree,
// URL, origin and DOMImplementation. Retain them until the realm closes.
fn install_compact_document_binding(binding &CompactElementQueryBinding, mut runtime browserjs.Runtime) ! {
	if runtime.engine == .javascriptcore {
		install_compact_document_owner_query(binding, mut runtime)!
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
	// Cached element markup and text stay valid while no tree, character data
	// or attribute change has happened in any document of this realm.
	runtime.define_number_host_function('__ladybirdDOMContentVersion', fn [binding] () f64 {
		mut version := binding.document.dom_tree_version() + binding.document.character_data_version() +
			binding.document.attribute_version()
		for _, document in binding.documents {
			version += document.dom_tree_version() + document.character_data_version() + document.attribute_version()
		}
		for _, document in binding.template_documents {
			version += document.dom_tree_version() + document.character_data_version() + document.attribute_version()
		}
		return f64(version % u64(9007199254740991))
	})!
	// A node wrapper from another realm of this agent maps to this realm's
	// wrapper of the same native node.
	runtime.install_foreign_node_lookup(fn [binding] (node &dom.Node) string {
		mut owner := unsafe { &CompactElementQueryBinding(binding) }
		return json2.encode(owner.node_state(node))
	})!
	runtime.install_css_event_wrappers() or {}
	runtime.add_close_handler(fn [binding] () {
		for _, document in binding.documents {
			mut owner := unsafe { &dom.Document(document) }
			owner.finalize()
		}
	})
}

fn (mut binding CompactElementQueryBinding) document_key(document &dom.Document) string {
	key := if voidptr(document) == voidptr(binding.document) {
		''
	} else {
		'__document_${document.as_node().unique_id()}'
	}
	if key != '' { binding.nodes[key] = document.as_node() }
	return key
}

fn (mut binding CompactElementQueryBinding) encode_document_state(document &dom.Document) string {
	return querywire.encode_document_reply(binding.document_key(document))
}

fn (mut binding CompactElementQueryBinding) document_state(document &dom.Document) json2.Any {
	key := binding.document_key(document)
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
		return if element := active { binding.encode_element_state(element) } else { 'null' }
	}
	if action == 'ownerDocument' {
		return if root.is_document() {
			'null'
		} else {
			binding.encode_document_state(root.document())
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
			binding.encode_element_state(unsafe { &dom.Element(script) })
		} else { 'null' }
	}
	if action == 'createHTMLDocument' {
		request := json2.decode[map[string]json2.Any](value)!
		created := document.implementation().create_html_document(json_string_property(request, 'title'))!
		html.install_document_fragment_parsing_hook(created)
		css.install_document_selector_query_hook(created)
		key := '__document_${created.as_node().unique_id()}'
		binding.documents[key] = created
		return binding.encode_document_state(created)
	}
	if action in ['createDocument', 'constructDocument'] {
		request := json2.decode[map[string]json2.Any](value)!
		mut created := &dom.Document(unsafe { nil })
		if action == 'constructDocument' {
			// https://dom.spec.whatwg.org/#dom-document-document
			created = dom.Document.construct_impl()
			created.set_content_type('application/xml')
			created.set_document_type(.xml)
			created.set_origin(document.origin())
		} else {
			mut doctype := ?&dom.DocumentType(none)
			if doctype_key := json_string_property(request, 'doctype') {
				node := binding.node_for_key(doctype_key) or { return error('TypeError: Invalid DocumentType') }
				if !node.is_document_type() { return error('TypeError: Invalid DocumentType') }
				doctype = unsafe { &dom.DocumentType(node) }
			}
			namespace_ := request['namespace'] or { json2.Any(json2.Null{}) }
			xml_document := document.implementation().create_document(if namespace_ is string { ?string(namespace_) } else { none },
				json_string_property(request, 'qualifiedName') or { '' }, doctype)!
			created = xml_document.as_document()
		}
		html.install_document_fragment_parsing_hook(created)
		css.install_document_selector_query_hook(created)
		key := '__document_${created.as_node().unique_id()}'
		binding.documents[key] = created
		return binding.encode_document_state(created)
	}
	if action == 'createDocumentType' {
		request := json2.decode[map[string]json2.Any](value)!
		doctype := document.implementation().create_document_type(json_string_property(request, 'name') or { '' },
			json_string_property(request, 'publicId') or { '' }, json_string_property(request, 'systemId') or { '' })!
		return binding.encode_node_state(doctype.as_node())
	}
	if action == 'createProcessingInstruction' {
		request := json2.decode[map[string]json2.Any](value)!
		instruction := document.create_processing_instruction(json_string_property(request, 'target') or { '' },
			json_string_property(request, 'data') or { '' })!
		return binding.encode_node_state(unsafe { &dom.Node(instruction) })
	}
	if action == 'createCDATASection' {
		section := document.create_cdata_section(value)!
		return binding.encode_node_state(unsafe { &dom.Node(section) })
	}
	if action == 'parseFromString' {
		request := json2.decode[map[string]json2.Any](value)!
		kind := json_string_property(request, 'type') or { '' }
		supported := match kind {
			'text/html' { html.DOMParserSupportedType.text_html }
			'text/xml' { html.DOMParserSupportedType.text_xml }
			'application/xml' { html.DOMParserSupportedType.application_xml }
			'application/xhtml+xml' { html.DOMParserSupportedType.application_xhtml_xml }
			'image/svg+xml' { html.DOMParserSupportedType.image_svg_xml }
			else { return error('TypeError: Invalid DOMParser type') }
		}
		parser := html.DOMParser.create(document)
		created := parser.parse_from_string(json_string_property(request, 'input') or { '' }, supported)!
		css.install_document_selector_query_hook(created)
		key := '__document_${created.as_node().unique_id()}'
		binding.documents[key] = created
		return binding.encode_document_state(created)
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
			// charset and inputEncoding are legacy aliases of characterSet.
			'characterSet', 'charset', 'inputEncoding' { document.character_set() }
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
			binding.encode_element_state(element)
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
		return if found := node { binding.encode_node_state(found) } else { 'null' }
	}
	if action == 'documentCreateElement' {
		return binding.encode_element_state(document.create_element(value)!)
	}
	// createElement(localName, {is}) creates a customized built-in element.
	if action == 'documentCreateElementWithOptions' {
		request := json2.decode[map[string]json2.Any](value)!
		name := json_string_property(request, 'name') or { return error('Missing local name') }
		return binding.encode_element_state(document.create_element_with_options(name, dom.ElementCreationOptions{
			is_: json_string_property(request, 'is')
		})!)
	}
	if action == 'documentCreateElementNS' {
		request := json2.decode[map[string]json2.Any](value)!
		name := json_string_property(request, 'name') or { return error('Missing qualified name') }
		return binding.encode_element_state(document.create_element_ns(json_string_property(request, 'namespace'), name)!)
	}
	return error('Invalid Document action')
}

fn compact_document_bootstrap() string {
	return r'
const __compactDocuments=new WeakMap(),__compactImplementations=new WeakMap(),__compactImplementationOwners=new WeakMap();
function Document(){
 if(!new.target)throw new TypeError("Document constructor requires new");
 const created=__queryElements("","constructDocument","{}"),prototype=new.target.prototype;
 Object.setPrototypeOf(created,prototype!==null&&(typeof prototype==="object"||typeof prototype==="function")?prototype:Document.prototype);
 return created;
}
function HTMLDocument(){throw new TypeError("Illegal HTMLDocument constructor");}
function XMLDocument(){throw new TypeError("Illegal XMLDocument constructor");}
function DOMImplementation(){throw new TypeError("Illegal DOMImplementation constructor");}
function DocumentType(){throw new TypeError("Illegal DocumentType constructor");}
for(const [constructor,parent,name] of [[Document,Node,"Document"],[HTMLDocument,Document,"HTMLDocument"],[XMLDocument,Document,"XMLDocument"],[DOMImplementation,Object,"DOMImplementation"],[DocumentType,Node,"DocumentType"]]){
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
function DOMParser(){if(!new.target)throw new TypeError("DOMParser constructor requires new");}
Object.defineProperty(DOMParser,"prototype",{writable:false});
Object.defineProperty(DOMParser.prototype,Symbol.toStringTag,{value:"DOMParser",configurable:true});
const __compactDOMParserTypes=["text/html","text/xml","application/xml","application/xhtml+xml","image/svg+xml"];
Object.defineProperty(DOMParser.prototype,"parseFromString",{value:function parseFromString(string,type){
 if(!(this instanceof DOMParser))throw new TypeError("Illegal DOMParser receiver");
 if(arguments.length<2)throw new TypeError("parseFromString requires a string and a type");
 const input=__compactDocumentString(string),kind=__compactDocumentString(type);
 if(!__compactDOMParserTypes.includes(kind))throw new TypeError("The provided value is not a valid DOMParserSupportedType");
 return __queryElements("","parseFromString",JSON.stringify({input,type:kind}));
},writable:true,enumerable:true,configurable:true});
Object.defineProperty(globalThis,"DOMParser",{value:DOMParser,writable:true,configurable:true});
const __compactNullableString=value=>value===null||value===undefined?null:__compactDocumentString(value);
function __compactDocumentRequest(receiver,action,request){
 try{return __queryElements(__compactDocumentState(receiver).bridgeKey,action,typeof request==="string"?request:JSON.stringify(request));}
 catch(error){const match=/^(InvalidCharacterError|NamespaceError|NotSupportedError|HierarchyRequestError):\s*(.*)/.exec(String(error.message));if(match)throw new DOMException(match[2],match[1]);throw error;}
}
Object.defineProperty(DOMImplementation.prototype,"createDocument",{value:function createDocument(namespace,qualifiedName){
 const owner=__elementApply(__compactNodeGet,__compactImplementationOwners,[this]);if(!owner)throw new TypeError("Illegal DOMImplementation receiver");
 if(arguments.length<2)throw new TypeError("createDocument requires a namespace and a qualified name");
 const doctype=arguments.length>2?arguments[2]:null,request={namespace:__compactNullableString(namespace),qualifiedName:qualifiedName===null?"":__compactDocumentString(qualifiedName)};
 if(doctype!==null&&doctype!==undefined){if(!(doctype instanceof DocumentType))throw new TypeError("createDocument requires a DocumentType or null");request.doctype=__compactNodeState(doctype).bridgeKey;}
 const created=__compactDocumentRequest(owner,"createDocument",request);
 Object.setPrototypeOf(created,XMLDocument.prototype);return created;
},writable:true,enumerable:true,configurable:true});
Object.defineProperty(DOMImplementation.prototype,"createDocumentType",{value:function createDocumentType(name,publicId,systemId){
 const owner=__elementApply(__compactNodeGet,__compactImplementationOwners,[this]);if(!owner)throw new TypeError("Illegal DOMImplementation receiver");
 if(arguments.length<3)throw new TypeError("createDocumentType requires a name, public id and system id");
 return __compactDocumentRequest(owner,"createDocumentType",{name:__compactDocumentString(name),publicId:__compactDocumentString(publicId),systemId:__compactDocumentString(systemId)});
},writable:true,enumerable:true,configurable:true});
Object.defineProperty(DOMImplementation.prototype,"hasFeature",{value:function hasFeature(){return true;},writable:true,enumerable:true,configurable:true});
Object.defineProperty(Document.prototype,"createProcessingInstruction",{value:function createProcessingInstruction(target,data){
 if(arguments.length<2)throw new TypeError("createProcessingInstruction requires a target and data");
 return __compactDocumentRequest(this,"createProcessingInstruction",{target:__compactDocumentString(target),data:__compactDocumentString(data)});
},writable:true,enumerable:true,configurable:true});
Object.defineProperty(Document.prototype,"createCDATASection",{value:function createCDATASection(data){
 if(arguments.length<1)throw new TypeError("createCDATASection requires data");
 return __compactDocumentRequest(this,"createCDATASection",__compactDocumentString(data));
},writable:true,enumerable:true,configurable:true});
for(const name of ["name","publicId","systemId"])Object.defineProperty(DocumentType.prototype,name,{get:function(){
 const state=__elementApply(__compactNodeGet,__compactNodeRecords,[this]);if(!state||state.nodeType!==10)throw new TypeError("Illegal DocumentType receiver");
 return __queryElements(state.bridgeKey,"doctypeValue",name,true);
},enumerable:true,configurable:true});
function StyleSheetList(){throw new TypeError("Illegal StyleSheetList constructor");}
Object.defineProperty(StyleSheetList,"prototype",{writable:false});
Object.defineProperty(StyleSheetList.prototype,Symbol.toStringTag,{value:"StyleSheetList",configurable:true});
Object.defineProperty(globalThis,"StyleSheetList",{value:StyleSheetList,writable:true,configurable:true});
const __compactStyleSheetLists=new WeakMap(),__compactStyleSheetReaders=new WeakMap();
function __compactStyleSheetRead(receiver){const read=__elementApply(__compactNodeGet,__compactStyleSheetReaders,[receiver]);if(!read)throw new TypeError("Illegal StyleSheetList receiver");return read();}
Object.defineProperty(StyleSheetList.prototype,"length",{get:function(){return __compactStyleSheetRead(this).length;},enumerable:true,configurable:true});
Object.defineProperty(StyleSheetList.prototype,"item",{value:function item(index){if(arguments.length===0)throw new TypeError("StyleSheetList.item requires an index");return __compactStyleSheetRead(this)[(+index)>>>0]||null;},writable:true,enumerable:true,configurable:true});
Object.defineProperty(StyleSheetList.prototype,Symbol.iterator,{value:function*values(){yield* __compactStyleSheetRead(this);},writable:true,configurable:true});
function __compactStyleSheetList(owner,state){
 const cached=__elementApply(__compactNodeGet,__compactStyleSheetLists,[owner]);if(cached)return cached;
 const read=()=>__queryElements(state.bridgeKey,"documentStyleSheets","",true).map(__cssSheet);
 const indexed=key=>typeof key==="string"&&/^(0|[1-9][0-9]*)$/.test(key)&&Number(key)<4294967295;
 const list=new Proxy(Object.create(StyleSheetList.prototype),{
  get(target,key,receiver){return indexed(key)?read()[Number(key)]:Reflect.get(target,key,receiver);},
  has(target,key){return indexed(key)?Number(key)<read().length:Reflect.has(target,key);},
  ownKeys(target){return read().map((_,index)=>String(index)).concat(Reflect.ownKeys(target));},
  getOwnPropertyDescriptor(target,key){if(indexed(key)){const sheet=read()[Number(key)];return sheet?{value:sheet,writable:false,enumerable:true,configurable:true}:undefined;}return Reflect.getOwnPropertyDescriptor(target,key);},
  set(target,key,value,receiver){return indexed(key)?false:Reflect.set(target,key,value,receiver);},
  defineProperty(target,key,descriptor){return indexed(key)?false:Reflect.defineProperty(target,key,descriptor);},
  deleteProperty(target,key){return indexed(key)?false:Reflect.deleteProperty(target,key);}
 });
 __elementApply(__elementRecordSet,__compactStyleSheetReaders,[list,read]);
 __elementApply(__elementRecordSet,__compactStyleSheetLists,[owner,list]);
 return list;
}
Object.defineProperty(Document.prototype,"styleSheets",{get:function(){return __compactStyleSheetList(this,__compactDocumentState(this));},enumerable:true,configurable:true});
if(typeof ShadowRoot==="function")Object.defineProperty(ShadowRoot.prototype,"styleSheets",{get:function(){const state=__compactNodeState(this);if(!state.isShadowRoot)throw new TypeError("Illegal ShadowRoot receiver");return __compactStyleSheetList(this,state);},enumerable:true,configurable:true});
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
const __compactDocumentPointerTypes=new Set(' + json2.encode(browserjs.native_pointer_event_names()) + r');
const __compactDocumentPointerHas=Set.prototype.has;
function __compactDocumentNativeEvent(name){return Reflect.apply(__compactDocumentPointerHas,__compactDocumentPointerTypes,[name])||name==="keydown"||name==="keyup"||name==="keypress"||name==="beforeinput"||name==="input"||name==="change"||name==="submit"||name==="reset"||name==="formdata"||name==="invalid";}
document.addEventListener=function(name,callback,options){
 name=String(name);if(__compactDocumentNativeEvent(name))return EventTarget.prototype.addEventListener.call(this,name,callback,options);
 return __compactDocumentLegacyAdd.call(this,name,callback,options);
};
document.removeEventListener=function(name,callback,options){
 name=String(name);if(__compactDocumentNativeEvent(name))return EventTarget.prototype.removeEventListener.call(this,name,callback,options);
 const key=__listenerKey(null,name);__listeners[key]=(__listeners[key]||[]).filter(listener=>listener!==callback);
};
__elementApply(__elementRecordSet,__compactDocuments,[document,{bridgeKey:"",nodeType:9}]);
// Parser-created roots change while scripts run. Always resolve the live DOM.
for(const name of ["documentElement","head","body"])delete document[name];
for(const name of ["documentElement","head","body","doctype","activeElement"]){Object.defineProperty(Document.prototype,name,{get:function(){return __queryElements(__compactDocumentState(this).bridgeKey,"documentNode",name);},enumerable:true,configurable:true});}
for(const name of ["title","URL","documentURI","baseURI","contentType","compatMode","characterSet","charset","inputEncoding","readyState","referrer","hidden","visibilityState"]){Object.defineProperty(Document.prototype,name,{get:function(){return __queryElements(__compactDocumentState(this).bridgeKey,"documentValue",name);},set:name==="title"?function(value){const state=__compactDocumentState(this);__queryElements(state.bridgeKey,"setDocumentTitle",__compactDocumentString(value));for(const title of __queryElements(state.bridgeKey,"querySelectorAll","title"))__compactInvalidateContent(__compactNodeState(title));}:undefined,enumerable:true,configurable:true});}
Object.defineProperty(Document.prototype,"currentScript",{get:function(){return __queryElements(__compactDocumentState(this).bridgeKey,"documentCurrentScript","");},enumerable:true,configurable:true});
for(const [name,value] of [["nodeType",9],["nodeName","#document"],["ownerDocument",null],["parentNode",null],["parentElement",null],["nodeValue",null],["textContent",null],["defaultView",null],["location",null]])Object.defineProperty(Document.prototype,name,{get:function(){__compactDocumentState(this);return value;},enumerable:true,configurable:true});
Object.defineProperty(Document.prototype,"childNodes",{get:function(){return __compactChildNodes(this,__compactDocumentState(this));},enumerable:true,configurable:true});
for(const name of ["firstChild","lastChild"])Object.defineProperty(Document.prototype,name,{get:function(){return __queryElements(__compactDocumentState(this).bridgeKey,name,"");},enumerable:true,configurable:true});
for(const name of ["querySelector","querySelectorAll","getElementById","getElementsByTagName","getElementsByClassName"]){Object.defineProperty(Document.prototype,name,{value:function(value){const state=__compactDocumentState(this);if(!arguments.length)throw new TypeError(name+" requires an argument");value=__compactDocumentString(value);return name==="getElementsByTagName"?__tagCollection(state.bridgeKey,value):__queryElements(state.bridgeKey,name==="getElementById"?"documentElementById":name,value);},writable:true,enumerable:true,configurable:true});}
for(const [name,action] of [["createElement","documentCreateElement"],["createTextNode","createText"],["createDocumentFragment","createFragment"]])Object.defineProperty(Document.prototype,name,{value:function(value){const state=__compactDocumentState(this);if(name!=="createDocumentFragment"&&!arguments.length)throw new TypeError(name+" requires an argument");
 if(name==="createElement"&&arguments.length>1){const options=arguments[1];if(options!==null&&typeof options==="object"&&options.is!==undefined)return __queryElements(state.bridgeKey,"documentCreateElementWithOptions",JSON.stringify({name:__compactDocumentString(value),is:__compactDocumentString(options.is)}));}
 return __queryElements(state.bridgeKey,action,name==="createDocumentFragment"?"":__compactDocumentString(value));},writable:true,enumerable:true,configurable:true});
Object.defineProperty(Document.prototype,"createElementNS",{value:function createElementNS(namespace,name){const state=__compactDocumentState(this);if(arguments.length<2)throw new TypeError("createElementNS requires two arguments");namespace=namespace==null?null:__compactDocumentString(namespace);name=__compactDocumentString(name);const element=__queryElements(state.bridgeKey,"documentCreateElementNS",JSON.stringify({namespace:namespace,name:name}));__compactNodeState(element).tagName=name;return element;},writable:true,enumerable:true,configurable:true});
function __compactDocumentElementBindings(object,state){
 __compactHrefTextBindings(object,state);
 if(!state.ownerDocumentKey)return;
 object.appendChild=function appendChild(child){return __compactInsertNode(this,child,null,false);};
 object.insertBefore=function insertBefore(child,reference){return __compactInsertNode(this,child,reference,true);};
}
' + compact_url_pattern_bootstrap() + compact_web_animations_bootstrap() + compact_document_owner_bootstrap() + compact_tree_walker_bootstrap() + compact_node_iterator_bootstrap() + compact_register_property_bootstrap() + compact_event_interfaces_bootstrap() + compact_xpath_bootstrap() + compact_text_selection_bootstrap() + compact_range_selection_bootstrap() + compact_document_write_bootstrap() + compact_outer_html_bootstrap() + compact_inner_text_bootstrap() + compact_element_members_bootstrap() + compact_reflected_attributes_bootstrap() + compact_dom_token_list_bootstrap() + compact_element_reflection_bootstrap() + compact_form_validation_bootstrap() + compact_input_number_bootstrap() + compact_origin_bootstrap() + compact_dom_matrix_bootstrap() + compact_svg_geometry_bootstrap() + compact_dialog_bootstrap() + compact_adopted_style_sheets_bootstrap() + compact_document_name_collection_bootstrap() + compact_highlights_bootstrap()
}
