module main

import browserjs
import css
import dom
import platform
import x.json2

struct CompactSheetRequest {
	op       string
	id       string
	value    string
	name     string
	priority string
	index    u32
	disabled bool
	media    string
	base_url ?string
	root_key string
}

fn (mut binding CompactElementQueryBinding) sheet_key(sheet &css.CSSStyleSheet) string {
	for key, candidate in binding.style_sheets {
		if voidptr(candidate) == voidptr(sheet) { return key }
	}
	binding.next_key++
	key := '__sheet_${binding.next_key}'
	binding.style_sheets[key] = sheet
	return key
}

fn (mut binding CompactElementQueryBinding) rule_key(rule &css.CSSRule) json2.Any {
	for key, candidate in binding.css_rules {
		if voidptr(candidate) == voidptr(rule) {
			return json2.Any({
				'id':   json2.Any(key)
				'type': json2.Any(int(rule.type_for_bindings()))
				'kind': json2.Any(rule.type_.str())
			})
		}
	}
	binding.next_key++
	key := '__rule_${binding.next_key}'
	binding.css_rules[key] = rule
	return json2.Any({
		'id':   json2.Any(key)
		'type': json2.Any(int(rule.type_for_bindings()))
		'kind': json2.Any(rule.type_.str())
	})
}

fn (mut binding CompactElementQueryBinding) rule_list_key(list &css.CSSRuleList) string {
	for key, candidate in binding.css_rule_lists {
		if voidptr(candidate) == voidptr(list) { return key }
	}
	binding.next_key++
	key := '__rules_${binding.next_key}'
	binding.css_rule_lists[key] = list
	return key
}

fn (mut binding CompactElementQueryBinding) link_sheet_query(key string) !string {
	mut allocations := binding.document.enter_native_storage()
	defer { allocations.finish() }
	node := binding.node_for_key(key) or { return 'null' }
	element := node.as_element() or { return 'null' }
	if !element.is_style_element_base()
		&& (!element.is_html_element() || element.local_name() != 'link') { return 'null' }
	sheet := css.style_sheet_for_owner_node(element.document(), element) or { return 'null' }
	return json2.encode(binding.sheet_key(sheet))
}

// https://drafts.csswg.org/cssom/#dom-documentorshadowroot-stylesheets
// The document or shadow root CSS style sheets, in tree order of their owner
// nodes. Adopted style sheets are not part of this list.
fn (mut binding CompactElementQueryBinding) document_style_sheets_query(root &dom.Node) !string {
	if !root.is_document() && !root.is_shadow_root() {
		return error('TypeError: Illegal DocumentOrShadowRoot receiver')
	}
	mut allocations := binding.document.enter_native_storage()
	defer { allocations.finish() }
	mut keys := []json2.Any{}
	for element in css.query_selector_all(root, 'style, link') {
		if voidptr(element.root()) != voidptr(root) { continue }
		sheet := css.style_sheet_for_owner_node(element.document(), element) or { continue }
		keys << json2.Any(binding.sheet_key(sheet))
	}
	return json2.encode(keys)
}

fn (mut binding CompactElementQueryBinding) css_sheet_query(source string) !string {
	request := compact_decode_query[CompactSheetRequest](source)!
	mut storage := binding.document.native_storage()
	mut allocations := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocations = storage.enter_nested() }
	defer { allocations.finish() }
	if request.op.starts_with('adopted') {
		return binding.adopted_style_sheets_query(request)
	}
	mut result := json2.Any(json2.Null{})
	if request.op == 'construct' {
		sheet := css.css_style_sheet_construct(css.CSSStyleSheetInit{
			base_url: request.base_url
			media:    request.media.clone()
			disabled: request.disabled
		}, binding.document)!
		result = binding.sheet_key(sheet)
	} else if mut sheet := binding.style_sheets[request.id] {
		if request.op in ['rules', 'insert', 'delete'] && !sheet.base.origin_clean {
			return error('SecurityError: Stylesheet rules are not origin-clean')
		}
		match request.op {
			'href' {
				// Inline sheets keep a parsing location for relative URLs in this
				// port, but LinkStyle's script-visible href is still null.
				inline_owner := if owner := sheet.base.owner_node { owner.is_style_element_base() } else { false }
				if !inline_owner {
					if href := sheet.href() { result = href }
				}
			}
			'title' {
				if title := sheet.base.title_for_bindings() { result = title }
			}
			'type' { result = sheet.type_() }
			'owner' {
				if owner := sheet.base.owner_node { result = binding.element_state(owner) }
			}
			'parent' {
				if parent := sheet.base.parent_style_sheet { result = binding.sheet_key(parent) }
			}
			'ownerRule' {
				if rule := sheet.owner_rule { result = binding.rule_key(rule) }
			}
			'disabled' { result = sheet.base.disabled }
			'setDisabled' { sheet.set_disabled(request.disabled) }
			'rules' { result = binding.rule_list_key(sheet.rules) }
			'insert' { result = int(sheet.insert_rule(request.value.clone(), request.index)!) }
			'delete' { sheet.delete_rule(request.index)! }
			'replace' { sheet.replace_sync(request.value.clone())! }
			'media' { result = sheet.base.media.media_text() }
			'mediaLength' { result = sheet.base.media.length() }
			'mediaItem' {
				if item := sheet.base.media.item(request.index) { result = item }
			}
			'setMedia' { sheet.set_media(request.value.clone()) }
			'appendMedium' { sheet.base.media.append_medium(request.value.clone()) }
			'deleteMedium' { sheet.base.media.delete_medium(request.value.clone())! }
			else { return error('Invalid stylesheet operation') }
		}
	} else if list := binding.css_rule_lists[request.id] {
		match request.op {
			'length' { result = list.length() }
			'item' {
				if rule := list.item(uint(request.index)) { result = binding.rule_key(rule) }
			}
			else { return error('Invalid CSSRuleList operation') }
		}
	} else if mut rule := binding.css_rules[request.id] {
		match request.op {
			'text' { result = rule.css_text() }
			'selector' { result = rule.selector_text() }
			'setSelector' { rule.set_selector_text(request.value.clone()) }
			'parent' {
				if parent := rule.parent_rule { result = binding.rule_key(parent) }
			}
			'sheet' {
				if sheet := rule.parent_style_sheet { result = binding.sheet_key(sheet) }
			}
			'rules' {
				if list := rule.css_rules() { result = binding.rule_list_key(list) }
			}
			'conditionText' { result = rule.condition_text() }
			'insert' { result = int(rule.insert_rule(request.value.clone(), request.index)!) }
			'delete' { rule.delete_rule(request.index)! }
			'keyText' { result = rule.key_text() }
			'setKeyText' { rule.set_key_text(request.value.clone()) }
			'name' {
				result = if rule.type_ == .keyframes { rule.keyframes_name() } else if rule.type_ == .position_try { rule.position_try_name() } else { rule.layer_name() or { '' } }
			}
			'setName' { rule.set_keyframes_name(request.value.clone()) }
			'prefix' { result = rule.namespace_rule_prefix() }
			'namespaceURI' { result = rule.namespace_rule_namespace_uri() }
			'href' { result = rule.href() }
			'importSheet' {
				if sheet := rule.loaded_style_sheet_for_bindings() { result = binding.sheet_key(sheet) }
			}
			'media', 'mediaLength', 'mediaItem', 'setMedia', 'appendMedium', 'deleteMedium' {
				mut media := rule.media_list_for_bindings() or { return error('TypeError: This CSS rule has no media list') }
				match request.op {
					'media' { result = media.media_text() }
					'mediaLength' { result = media.length() }
					'mediaItem' {
						if item := media.item(request.index) { result = item }
					}
					'setMedia' { media.set_media_text(request.value.clone()) }
					'appendMedium' { media.append_medium(request.value.clone()) }
					else { media.delete_medium(request.value.clone())! }
				}
			}
			'hasStyle' { result = rule.style() != none || rule.font_face_rule_ref() != none }
			else {
				// An @font-face rule's style is its CSSFontFaceDescriptors.
				if rule.style() == none {
					if mut font_face := rule.font_face_rule_ref() {
						mut descriptors := font_face.descriptors()
						match request.op {
							'styleValue' { result = descriptors.get_property_value(request.name) }
							'stylePriority' { result = '' }
							'styleLength' { result = descriptors.descriptors.len }
							'styleItem' {
								index := int(request.index)
								result = if index >= 0 && index < descriptors.descriptors.len {
									css.font_face_descriptor_property_name(descriptors.descriptors[index].id)
								} else {
									''
								}
							}
							'styleText' {
								mut parts := []string{}
								for descriptor in descriptors.descriptors {
									name := css.font_face_descriptor_property_name(descriptor.id)
									parts << '${name}: ${descriptors.get_property_value(name)};'
								}
								result = parts.join(' ')
							}
							'styleSet' {
								descriptors.set_property(request.name.clone(), request.value.clone(), request.priority.clone())!
							}
							'styleRemove' { result = descriptors.remove_property(request.name)! }
							'supported' { result = css.font_face_descriptor_id_from_property(request.name) != none }
							else { return error('TypeError: This CSS rule has no declaration') }
						}
						if request.op in ['styleSet', 'styleRemove'] {
							mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
							runtime.mark_document_state_dirty()
							runtime.mark_document_replay_effects()
						}
						allocations.finish()
						return json2.encode(result)
					}
				}
				mut declaration := rule.style() or { return error('TypeError: This CSS rule has no declaration') }
				match request.op {
					'styleText' { result = declaration.serialized() }
					'styleLength' { result = declaration.length() }
					'styleItem' { result = declaration.item(uint(request.index)) }
					'styleValue' { result = declaration.get_property_value(request.name) }
					'stylePriority' { result = declaration.get_property_priority(request.name) }
					'styleSet' {
						declaration.set_property(request.name.clone(), request.value.clone(), request.priority.clone())!
					}
					'styleRemove' { result = declaration.remove_property(request.name)! }
					'styleReplace' { declaration.set_css_text(request.value.clone())! }
					'supported' {
						result = if rule.type_ == .position_try {
							if property := css.property_id_from_string(request.name) { css.is_accepted_position_try_property(property) } else { false }
						} else { css.property_id_from_string(request.name) != none || request.name.starts_with('--') }
					}
					else { return error('Invalid CSSStyleDeclaration operation') }
				}
			}
		}
	} else {
		return error('TypeError: Illegal CSSOM receiver')
	}
	if request.op in ['setDisabled', 'insert', 'delete', 'replace', 'setMedia', 'appendMedium',
		'deleteMedium', 'setSelector', 'styleSet', 'styleRemove', 'styleReplace'] {
		mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
		runtime.mark_document_state_dirty()
		runtime.mark_document_replay_effects()
	}
	allocations.finish()
	return json2.encode(result)
}

fn compact_link_sheet_bootstrap() string {
	return r'
const __cssSheetRecords=new WeakMap(),__cssSheetCache=new Map(),__cssListRecords=new WeakMap(),__cssListCache=new Map(),__cssRuleRecords=new WeakMap(),__cssRuleCache=new Map(),__cssMediaRecords=new WeakMap(),__cssMediaCache=new Map();
function __cssCall(id,op,fields={}){try{return __queryElements("","cssSheet",JSON.stringify(Object.assign({id,op},fields)));}catch(error){const match=/^(SecurityError|SyntaxError|IndexSizeError|HierarchyRequestError|NotAllowedError|InvalidStateError|NotFoundError):\s*(.*)/.exec(String(error.message));if(match)throw new DOMException(match[2],match[1]);throw error;}}
const __cssString=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
function __cssId(records,receiver){const id=__elementApply(__elementRecordGet,records,[receiver]);if(!id)throw new TypeError("Illegal CSSOM receiver");return id;}
function StyleSheet(){throw new TypeError("Illegal StyleSheet constructor");}
function CSSStyleSheet(options={}){if(!new.target)throw new TypeError("CSSStyleSheet requires new");if(options===null)options={};const disabled=!!options.disabled,media=options.media===undefined?"":__cssString(options.media),baseURL=options.baseURL;const fields={disabled,media};if(baseURL!==undefined)fields.base_url=__cssString(baseURL);const id=__cssCall("","construct",fields);__cssSheetRecords.set(this,id);__cssSheetCache.set(id,this);}
Object.setPrototypeOf(CSSStyleSheet,StyleSheet);Object.setPrototypeOf(CSSStyleSheet.prototype,StyleSheet.prototype);
for(const ctor of [StyleSheet,CSSStyleSheet]){Object.defineProperty(ctor,"prototype",{writable:false});Object.defineProperty(ctor.prototype,Symbol.toStringTag,{value:ctor.name,configurable:true});Object.defineProperty(globalThis,ctor.name,{value:ctor,writable:true,configurable:true});}
function __cssSheet(id){if(id===null)return null;if(!__cssSheetCache.has(id)){const sheet=Object.create(CSSStyleSheet.prototype);__cssSheetRecords.set(sheet,id);__cssSheetCache.set(id,sheet);}return __cssSheetCache.get(id);}
function __linkStyleSheet(state){return __cssSheet(__queryElements(state.bridgeKey,"linkSheet",""));}
for(const name of ["href","title","type"])Object.defineProperty(StyleSheet.prototype,name,{get(){return __cssCall(__cssId(__cssSheetRecords,this),name);},enumerable:true,configurable:true});
Object.defineProperties(StyleSheet.prototype,{
 ownerNode:{get(){return __queryElement(__cssCall(__cssId(__cssSheetRecords,this),"owner"));},enumerable:true,configurable:true},
 parentStyleSheet:{get(){return __cssSheet(__cssCall(__cssId(__cssSheetRecords,this),"parent"));},enumerable:true,configurable:true},
 disabled:{get(){return __cssCall(__cssId(__cssSheetRecords,this),"disabled");},set(value){__cssCall(__cssId(__cssSheetRecords,this),"setDisabled",{disabled:!!value});},enumerable:true,configurable:true},
 media:{get(){const id=__cssId(__cssSheetRecords,this);if(!__cssMediaCache.has(id)){const media=Object.create(MediaList.prototype);__cssMediaRecords.set(media,id);__cssMediaCache.set(id,media);}return __cssMediaCache.get(id);},set(value){__cssCall(__cssId(__cssSheetRecords,this),"setMedia",{value:__cssString(value)});},enumerable:true,configurable:true}
});
Object.defineProperties(CSSStyleSheet.prototype,{
 ownerRule:{get(){return __cssRule(__cssCall(__cssId(__cssSheetRecords,this),"ownerRule"));},enumerable:true,configurable:true},
 cssRules:{get(){return __cssList(__cssCall(__cssId(__cssSheetRecords,this),"rules"));},enumerable:true,configurable:true},
 rules:{get(){return this.cssRules;},enumerable:true,configurable:true},
 insertRule:{value:function insertRule(rule,index=0){const id=__cssId(__cssSheetRecords,this);if(!arguments.length)throw new TypeError("insertRule requires a rule");return __cssCall(id,"insert",{value:__cssString(rule),index:(+index)>>>0});},writable:true,configurable:true},
 deleteRule:{value:function deleteRule(index){const id=__cssId(__cssSheetRecords,this);if(!arguments.length)throw new TypeError("deleteRule requires an index");__cssCall(id,"delete",{index:(+index)>>>0});},writable:true,configurable:true},
 replaceSync:{value:function replaceSync(text){const id=__cssId(__cssSheetRecords,this);if(!arguments.length)throw new TypeError("replaceSync requires text");__cssCall(id,"replace",{value:__cssString(text)});},writable:true,configurable:true},
 replace:{value:function replace(text){const id=__cssId(__cssSheetRecords,this);try{if(!arguments.length)throw new TypeError("replace requires text");__cssCall(id,"replace",{value:__cssString(text)});return Promise.resolve(this);}catch(error){return Promise.reject(error);}},writable:true,configurable:true}
});
function CSSRuleList(){throw new TypeError("Illegal CSSRuleList constructor");}
Object.defineProperty(CSSRuleList.prototype,Symbol.toStringTag,{value:"CSSRuleList",configurable:true});
Object.defineProperties(CSSRuleList.prototype,{
 length:{get(){return __cssCall(__cssId(__cssListRecords,this),"length");},configurable:true},
 item:{value:function item(index){const id=__cssId(__cssListRecords,this);if(!arguments.length)throw new TypeError("item requires an index");return __cssRule(__cssCall(id,"item",{index:(+index)>>>0}));},writable:true,configurable:true},
 [Symbol.iterator]:{value:function*(){__cssId(__cssListRecords,this);for(let i=0;i<this.length;i++)yield this.item(i);},configurable:true}
});
function __cssList(id){if(id===null)return null;if(!__cssListCache.has(id)){const target=Object.create(CSSRuleList.prototype),list=new Proxy(target,{get(target,key,receiver){if(typeof key==="string"&&/^(0|[1-9][0-9]*)$/.test(key))return receiver.item(Number(key))||undefined;return Reflect.get(target,key,receiver);}});__cssListRecords.set(list,id);__cssListCache.set(id,list);}return __cssListCache.get(id);}
function CSSRule(){throw new TypeError("Illegal CSSRule constructor");}
function CSSStyleRule(){throw new TypeError("Illegal CSSStyleRule constructor");}
Object.setPrototypeOf(CSSStyleRule,CSSRule);Object.setPrototypeOf(CSSStyleRule.prototype,CSSRule.prototype);
for(const [name,value] of [["STYLE_RULE",1],["CHARSET_RULE",2],["IMPORT_RULE",3],["MEDIA_RULE",4],["FONT_FACE_RULE",5],["PAGE_RULE",6],["KEYFRAMES_RULE",7],["KEYFRAME_RULE",8],["MARGIN_RULE",9],["NAMESPACE_RULE",10],["COUNTER_STYLE_RULE",11],["SUPPORTS_RULE",12],["FONT_FEATURE_VALUES_RULE",14]])for(const target of [CSSRule,CSSRule.prototype])Object.defineProperty(target,name,{value,enumerable:true});
Object.defineProperties(CSSRule.prototype,{
 [Symbol.toStringTag]:{value:"CSSRule",configurable:true},
 type:{get(){const id=__cssId(__cssRuleRecords,this);return __cssRuleCache.get(id).type;},configurable:true},
 cssText:{get(){return __cssCall(__cssId(__cssRuleRecords,this),"text");},set(value){__cssId(__cssRuleRecords,this);__cssString(value);},configurable:true},
 parentRule:{get(){return __cssRule(__cssCall(__cssId(__cssRuleRecords,this),"parent"));},configurable:true},
 parentStyleSheet:{get(){return __cssSheet(__cssCall(__cssId(__cssRuleRecords,this),"sheet"));},configurable:true}
});
Object.defineProperties(CSSStyleRule.prototype,{
 [Symbol.toStringTag]:{value:"CSSStyleRule",configurable:true},
 selectorText:{get(){return __cssCall(__cssId(__cssRuleRecords,this),"selector");},set(value){__cssCall(__cssId(__cssRuleRecords,this),"setSelector",{value:__cssString(value)});},configurable:true},
 cssRules:{get(){return __cssList(__cssCall(__cssId(__cssRuleRecords,this),"rules"));},configurable:true},
 style:{get(){const id=__cssId(__cssRuleRecords,this),entry=__cssRuleCache.get(id);if(!entry.style)entry.style=__cssDeclaration(id,this);return entry.style;},set(value){__cssCall(__cssId(__cssRuleRecords,this),"styleReplace",{value:__cssString(value)});},configurable:true}
});
function __cssRule(record){if(record===null)return null;if(!__cssRuleCache.has(record.id)){const rule=Object.create(__cssRulePrototype(record));__cssRuleRecords.set(rule,record.id);__cssRuleCache.set(record.id,{rule,type:record.type});}return __cssRuleCache.get(record.id).rule;}
// CSSOM rule interfaces other than CSSStyleRule. Each wrapper reads its
// native rule; grouping rules share CSSRuleList wrappers and media rules
// share the MediaList wrapper keyed by the rule.
const __cssRuleInterfaces={};
function __cssRuleInterface(name,parent,properties){
 const constructor={[name]:function(){throw new TypeError("Illegal "+name+" constructor");}}[name];
 Object.setPrototypeOf(constructor,parent);Object.setPrototypeOf(constructor.prototype,parent.prototype);
 Object.defineProperty(constructor,"prototype",{writable:false});
 Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
 for(const [key,descriptor] of Object.entries(properties)){if(descriptor.get)Object.defineProperty(descriptor.get,"name",{value:"get "+key,configurable:true});if(descriptor.set)Object.defineProperty(descriptor.set,"name",{value:"set "+key,configurable:true});Object.defineProperty(constructor.prototype,key,Object.assign({enumerable:true,configurable:true},descriptor));}
 Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 __cssRuleInterfaces[name]=constructor;return constructor;
}
const __cssRuleId=receiver=>__cssId(__cssRuleRecords,receiver);
const __cssRuleStyle={get(){const id=__cssRuleId(this),entry=__cssRuleCache.get(id);if(!entry.style)entry.style=__cssDeclaration(id,this);return entry.style;},set(value){__cssCall(__cssRuleId(this),"styleReplace",{value:__cssString(value)});}};
const __cssRuleMedia={get(){const id=__cssRuleId(this);if(!__cssMediaCache.has(id)){const media=Object.create(MediaList.prototype);__cssMediaRecords.set(media,id);__cssMediaCache.set(id,media);}return __cssMediaCache.get(id);},set(value){__cssCall(__cssRuleId(this),"setMedia",{value:__cssString(value)});}};
const __cssGrouping=__cssRuleInterface("CSSGroupingRule",CSSRule,{
 cssRules:{get(){return __cssList(__cssCall(__cssRuleId(this),"rules"));}},
 insertRule:{value:function insertRule(rule,index=0){const id=__cssRuleId(this);if(!arguments.length)throw new TypeError("insertRule requires a rule");return __cssCall(id,"insert",{value:__cssString(rule),index:(+index)>>>0});},writable:true},
 deleteRule:{value:function deleteRule(index){const id=__cssRuleId(this);if(!arguments.length)throw new TypeError("deleteRule requires an index");__cssCall(id,"delete",{index:(+index)>>>0});},writable:true}
});
const __cssCondition=__cssRuleInterface("CSSConditionRule",__cssGrouping,{conditionText:{get(){return __cssCall(__cssRuleId(this),"conditionText");}}});
__cssRuleInterface("CSSMediaRule",__cssCondition,{media:__cssRuleMedia});
__cssRuleInterface("CSSSupportsRule",__cssCondition,{});
__cssRuleInterface("CSSContainerRule",__cssCondition,{});
__cssRuleInterface("CSSLayerBlockRule",__cssGrouping,{name:{get(){return __cssCall(__cssRuleId(this),"name");}}});
__cssRuleInterface("CSSLayerStatementRule",CSSRule,{});
__cssRuleInterface("CSSScopeRule",__cssGrouping,{});
__cssRuleInterface("CSSPageRule",__cssGrouping,{style:__cssRuleStyle,selectorText:{get(){return __cssCall(__cssRuleId(this),"selector");},set(value){__cssCall(__cssRuleId(this),"setSelector",{value:__cssString(value)});}}});
__cssRuleInterface("CSSFontFaceRule",CSSRule,{style:{get:__cssRuleStyle.get}});
__cssRuleInterface("CSSPositionTryRule",CSSRule,{name:{get(){return __cssCall(__cssRuleId(this),"name");}},style:__cssRuleStyle});
function CSSPositionTryDescriptors(){throw new TypeError("Illegal CSSPositionTryDescriptors constructor");}
Object.defineProperty(CSSPositionTryDescriptors,"prototype",{writable:false});
const __cssDescriptorOwners=new WeakMap();
const __cssDescriptorOwner=value=>{const query=__cssDescriptorOwners.get(value);if(!query)throw new TypeError("Illegal CSSPositionTryDescriptors receiver");return query;};
for(const name of "margin margin-top margin-right margin-bottom margin-left margin-block margin-block-start margin-block-end margin-inline margin-inline-start margin-inline-end inset top left right bottom inset-block inset-block-start inset-block-end inset-inline inset-inline-start inset-inline-end width height min-width max-width min-height max-height block-size min-block-size max-block-size inline-size min-inline-size max-inline-size place-self align-self justify-self position-anchor position-area".split(" ")){
 for(const attribute of new Set([name,name.replace(/-([a-z])/g,(_,letter)=>letter.toUpperCase())])){
  const get=function(){return __cssDescriptorOwner(this)("styleValue",{name});};
  const set=function(value){const query=__cssDescriptorOwner(this);query("styleSet",{name,value:value===null?"":__cssString(value)});};
  Object.defineProperty(get,"name",{value:"get "+attribute,configurable:true});Object.defineProperty(set,"name",{value:"set "+attribute,configurable:true});
  Object.defineProperty(CSSPositionTryDescriptors.prototype,attribute,{get,set,enumerable:true,configurable:true});
 }
}
Object.defineProperty(CSSPositionTryDescriptors.prototype,Symbol.toStringTag,{value:"CSSPositionTryDescriptors",configurable:true});
Object.defineProperty(globalThis,"CSSPositionTryDescriptors",{value:CSSPositionTryDescriptors,writable:true,configurable:true});
__cssRuleInterface("CSSKeyframeRule",CSSRule,{style:__cssRuleStyle,keyText:{get(){return __cssCall(__cssRuleId(this),"keyText");},set(value){__cssCall(__cssRuleId(this),"setKeyText",{value:__cssString(value)});}}});
__cssRuleInterface("CSSKeyframesRule",CSSRule,{
 name:{get(){return __cssCall(__cssRuleId(this),"name");},set(value){__cssCall(__cssRuleId(this),"setName",{value:__cssString(value)});}},
 cssRules:{get(){return __cssList(__cssCall(__cssRuleId(this),"rules"));}},
 length:{get(){return this.cssRules.length;}}
});
__cssRuleInterface("CSSNamespaceRule",CSSRule,{prefix:{get(){return __cssCall(__cssRuleId(this),"prefix");}},namespaceURI:{get(){return __cssCall(__cssRuleId(this),"namespaceURI");}}});
__cssRuleInterface("CSSImportRule",CSSRule,{href:{get(){return __cssCall(__cssRuleId(this),"href");}},media:__cssRuleMedia,styleSheet:{get(){return __cssSheet(__cssCall(__cssRuleId(this),"importSheet"));}}});
__cssRuleInterface("CSSNestedDeclarations",CSSRule,{style:{get:__cssRuleStyle.get}});
__cssRuleInterface("CSSPropertyRule",CSSRule,{});
__cssRuleInterface("CSSCounterStyleRule",CSSRule,{});
__cssRuleInterface("CSSFontFeatureValuesRule",CSSRule,{});
const __cssRuleKinds={style:CSSStyleRule,media:"CSSMediaRule",supports:"CSSSupportsRule",container_rule:"CSSContainerRule",layer_block:"CSSLayerBlockRule",layer_statement:"CSSLayerStatementRule",scope:"CSSScopeRule",page:"CSSPageRule",font_face:"CSSFontFaceRule",keyframe:"CSSKeyframeRule",keyframes:"CSSKeyframesRule",namespace_rule:"CSSNamespaceRule",import_rule:"CSSImportRule",nested_declarations:"CSSNestedDeclarations",property:"CSSPropertyRule",counter_style:"CSSCounterStyleRule",font_feature_values:"CSSFontFeatureValuesRule",position_try:"CSSPositionTryRule"};
function __cssRulePrototype(record){
 const kind=__cssRuleKinds[record.kind];
 if(kind===undefined)return record.type===1?CSSStyleRule.prototype:CSSRule.prototype;
 return (typeof kind==="string"?__cssRuleInterfaces[kind]:kind).prototype;
}
function __cssDeclaration(id,rule){const query=(op,fields={})=>__cssCall(id,op,fields),target={
 get cssText(){return query("styleText");},set cssText(value){query("styleReplace",{value:__cssString(value)});},
 get parentRule(){return rule;},get length(){return query("styleLength");},
 getPropertyValue(name){if(!arguments.length)throw new TypeError("getPropertyValue requires a name");return query("styleValue",{name:__cssString(name)});},
 getPropertyPriority(name){if(!arguments.length)throw new TypeError("getPropertyPriority requires a name");return query("stylePriority",{name:__cssString(name)});},
 setProperty(name,value,priority=""){if(arguments.length<2)throw new TypeError("setProperty requires a name and value");query("styleSet",{name:__cssString(name),value:value===null?"":__cssString(value),priority:priority===null?"":__cssString(priority)});},
 removeProperty(name){if(!arguments.length)throw new TypeError("removeProperty requires a name");return query("styleRemove",{name:__cssString(name)});},
 item(index){if(!arguments.length)throw new TypeError("item requires an index");return query("styleItem",{index:(+index)>>>0});},
 *[Symbol.iterator](){for(let i=0;i<this.length;i++)yield this.item(i);}
 };if(rule instanceof CSSPositionTryRule){Object.setPrototypeOf(target,CSSPositionTryDescriptors.prototype);__cssDescriptorOwners.set(target,query);}const proxy=new Proxy(target,{get(target,key,receiver){if(Reflect.has(target,key)||typeof key!=="string")return Reflect.get(target,key,receiver);if(/^(0|[1-9][0-9]*)$/.test(key))return target.item(Number(key))||undefined;const name=__inlineStyleName(key);return query("supported",{name})?query("styleValue",{name}):undefined;},set(target,key,value,receiver){if(Reflect.has(target,key)||typeof key!=="string")return Reflect.set(target,key,value,receiver);const name=__inlineStyleName(key);if(!query("supported",{name}))return Reflect.set(target,key,value,receiver);query("styleSet",{name,value:value===null?"":__cssString(value)});return true;}});if(rule instanceof CSSPositionTryRule)__cssDescriptorOwners.set(proxy,query);return proxy;}
function MediaList(){throw new TypeError("Illegal MediaList constructor");}
Object.defineProperties(MediaList.prototype,{
 [Symbol.toStringTag]:{value:"MediaList",configurable:true},
 mediaText:{get(){return __cssCall(__cssId(__cssMediaRecords,this),"media");},set(value){__cssCall(__cssId(__cssMediaRecords,this),"setMedia",{value:__cssString(value)});},configurable:true},
 length:{get(){return __cssCall(__cssId(__cssMediaRecords,this),"mediaLength");},configurable:true},
 item:{value:function item(index){const id=__cssId(__cssMediaRecords,this);if(!arguments.length)throw new TypeError("item requires an index");return __cssCall(id,"mediaItem",{index:(+index)>>>0});},configurable:true},
 appendMedium:{value:function appendMedium(value){const id=__cssId(__cssMediaRecords,this);if(!arguments.length)throw new TypeError("appendMedium requires a value");__cssCall(id,"appendMedium",{value:__cssString(value)});},configurable:true},
 deleteMedium:{value:function deleteMedium(value){const id=__cssId(__cssMediaRecords,this);if(!arguments.length)throw new TypeError("deleteMedium requires a value");__cssCall(id,"deleteMedium",{value:__cssString(value)});},configurable:true},
 toString:{value:function(){return __cssCall(__cssId(__cssMediaRecords,this),"media");},configurable:true}
});
for(const ctor of [CSSRuleList,CSSRule,CSSStyleRule,MediaList]){Object.defineProperty(ctor,"prototype",{writable:false});Object.defineProperty(globalThis,ctor.name,{value:ctor,writable:true,configurable:true});}
'
}
