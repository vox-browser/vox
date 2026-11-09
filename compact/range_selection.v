module main

import browserjs
import css
import dom
import x.json2

// https://dom.spec.whatwg.org/#interface-range
// https://w3c.github.io/selection-api/
// https://w3c.github.io/editing/docs/execCommand/
// Range, Selection and execCommand() operate on the native live ranges, the
// document selection and the translated editing commands. A script-visible
// Range keeps its native range by key, so getRangeAt() and the selection share
// one object. Operations that change the tree report the attributes of the
// elements they may have touched, which the realm uses to refresh its records.
fn (mut binding CompactElementQueryBinding) range_key(range &dom.Range) string {
	if key := binding.range_keys[voidptr(range)] { return key }
	binding.next_key++
	key := '__range_${binding.next_key}'
	binding.ranges[key] = range
	binding.range_keys[voidptr(range)] = key
	return key
}

fn (mut binding CompactElementQueryBinding) range_node_argument(request map[string]json2.Any, name string) !&dom.Node {
	value := request[name] or { return error('TypeError: Expected a Node') }
	if value !is map[string]json2.Any { return error('TypeError: Expected a Node') }
	object := value as map[string]json2.Any
	key := json_string_property(object, 'key') or { return error('TypeError: Expected a Node') }
	return binding.equality_node(key, object['state'] or { json2.Any(json2.Null{}) })
}

fn (mut binding CompactElementQueryBinding) range_argument(request map[string]json2.Any, name string) !&dom.Range {
	key := json_string_property(request, name) or { return error('TypeError: Expected a Range') }
	return binding.ranges[key] or { return error('TypeError: Expected a Range') }
}

fn compact_range_int(request map[string]json2.Any, name string) int {
	value := request[name] or { return 0 }
	return match value {
		f64 { int(i64(value)) }
		i64 { int(value) }
		int { value }
		else { 0 }
	}
}

fn compact_range_bool(request map[string]json2.Any, name string) bool {
	value := request[name] or { return false }
	return value is bool && value as bool
}

fn (mut binding CompactElementQueryBinding) range_state(range &dom.Range) json2.Any {
	return json2.Any({
		'key':                     json2.Any(binding.range_key(range))
		'startContainer':          binding.node_state(range.start_container())
		'startOffset':             json2.Any(range.start_offset())
		'endContainer':            binding.node_state(range.end_container())
		'endOffset':               json2.Any(range.end_offset())
		'collapsed':               json2.Any(range.collapsed())
		'commonAncestorContainer': binding.node_state(range.common_ancestor_container())
	})
}

fn compact_rect_value(rect dom.DOMRect) json2.Any {
	return json2.Any({
		'x':      json2.Any(rect.x)
		'y':      json2.Any(rect.y)
		'width':  json2.Any(rect.width)
		'height': json2.Any(rect.height)
	})
}

// Attributes of the realm-known elements in scope after a tree mutation.
fn (mut binding CompactElementQueryBinding) mutation_refresh(scope &dom.Node) json2.Any {
	binding.note_node_tree_mutation()
	mut refreshed := []json2.Any{}
	mut elements := []&dom.Element{}
	if element := scope.as_element() { elements << element }
	elements << css.query_selector_all(scope, '*')
	for element in elements {
		if entry := binding.attribute_refresh_entry(element) { refreshed << entry }
	}
	return json2.Any(refreshed)
}

fn (mut binding CompactElementQueryBinding) attribute_refresh_entry(element &dom.Element) ?json2.Any {
	key := binding.keys[voidptr(element)] or { return none }
	records, attributes := browserjs.compact_attribute_state(element)
	return json2.Any({
		'key':              json2.Any(key)
		'attributes':       json2.Any(attributes)
		'attributeRecords': json2.Any(records)
	})
}

// A mutation that moves, inserts or removes nodes but changes no existing
// element's attributes: the realm only drops the content it had cached.
// Serializing every element's attributes per operation made range-heavy
// pages allocate without bound.
fn (mut binding CompactElementQueryBinding) structure_refresh() json2.Any {
	binding.note_node_tree_mutation()
	return json2.Any([]json2.Any{})
}

// The attributes of one changed element.
fn (mut binding CompactElementQueryBinding) element_attribute_refresh(element &dom.Element) json2.Any {
	binding.note_node_tree_mutation()
	if entry := binding.attribute_refresh_entry(element) { return json2.Any([entry]) }
	return json2.Any([]json2.Any{})
}

fn (mut binding CompactElementQueryBinding) range_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid Range operation') }
	if op == 'create' {
		node := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
		range := dom.Range.create(node.document())
		return json2.encode({ 'range': binding.range_state(range) })
	}
	mut range := binding.range_argument(request, 'range')!
	mut result := map[string]json2.Any{}
	match op {
		'state' {}
		'setStart' { range.set_start(binding.range_node_argument(request, 'node')!, compact_range_int(request, 'offset'))! }
		'setEnd' { range.set_end(binding.range_node_argument(request, 'node')!, compact_range_int(request, 'offset'))! }
		'setStartBefore' { range.set_start_before(binding.range_node_argument(request, 'node')!)! }
		'setStartAfter' { range.set_start_after(binding.range_node_argument(request, 'node')!)! }
		'setEndBefore' { range.set_end_before(binding.range_node_argument(request, 'node')!)! }
		'setEndAfter' { range.set_end_after(binding.range_node_argument(request, 'node')!)! }
		'collapse' { range.collapse(compact_range_bool(request, 'toStart')) }
		'selectNode' { range.select_node(binding.range_node_argument(request, 'node')!)! }
		'selectNodeContents' { range.select_node_contents(binding.range_node_argument(request, 'node')!)! }
		'compareBoundaryPoints' {
			how := compact_range_int(request, 'how')
			if how < 0 || how > 3 { return error('NotSupportedError: Invalid comparison type') }
			source_range := binding.range_argument(request, 'source')!
			result['value'] = json2.Any(range.compare_boundary_points(unsafe { dom.HowToCompareBoundaryPoints(how) }, source_range)!)
		}
		'cloneRange' { result['value'] = binding.range_state(range.clone_range()) }
		'isPointInRange' {
			result['value'] = json2.Any(range.is_point_in_range(binding.range_node_argument(request, 'node')!, compact_range_int(request, 'offset'))!)
		}
		'comparePoint' {
			result['value'] = json2.Any(range.compare_point(binding.range_node_argument(request, 'node')!, compact_range_int(request, 'offset'))!)
		}
		'intersectsNode' { result['value'] = json2.Any(range.intersects_node(binding.range_node_argument(request, 'node')!)) }
		'toString' { result['value'] = json2.Any(range.to_string()) }
		'getBoundingClientRect' { result['value'] = compact_rect_value(range.get_bounding_client_rect()) }
		'getClientRects' {
			list := range.get_client_rects()
			result['value'] = json2.Any(list.rects.map(compact_rect_value(it)))
		}
		'createContextualFragment' {
			fragment := range.create_contextual_fragment(json_string_property(request, 'value') or { '' })!
			result['value'] = binding.node_state(unsafe { &dom.Node(fragment) })
		}
		'deleteContents', 'extractContents', 'cloneContents', 'insertNode', 'surroundContents' {
			match op {
				'deleteContents' { range.delete_contents()! }
				'extractContents' { result['value'] = binding.node_state(unsafe { &dom.Node(range.extract_contents()!) }) }
				'cloneContents' { result['value'] = binding.node_state(unsafe { &dom.Node(range.clone_contents()!) }) }
				'insertNode' { range.insert_node(binding.range_node_argument(request, 'node')!)! }
				else { range.surround_contents(binding.range_node_argument(request, 'node')!)! }
			}
			if op != 'cloneContents' { result['refresh'] = binding.structure_refresh() }
		}
		else { return error('Invalid Range operation') }
	}
	// Boundary updates need no reply; the realm asks for state when it reads.
	if op == 'state' { result['range'] = binding.range_state(range) }
	return json2.encode(result)
}

fn (mut binding CompactElementQueryBinding) selection_state(selection &dom.Selection) json2.Any {
	anchor := if node := selection.anchor_node() { binding.node_state(node) } else { json2.Any(json2.Null{}) }
	focus := if node := selection.focus_node() { binding.node_state(node) } else { json2.Any(json2.Null{}) }
	return json2.Any({
		'anchorNode':   anchor
		'anchorOffset': json2.Any(selection.anchor_offset())
		'focusNode':    focus
		'focusOffset':  json2.Any(selection.focus_offset())
		'isCollapsed':  json2.Any(selection.is_collapsed())
		'rangeCount':   json2.Any(selection.range_count())
		'type':         json2.Any(selection.type_())
		'direction':    json2.Any(selection.direction())
	})
}

fn (mut binding CompactElementQueryBinding) selection_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid Selection operation') }
	node := binding.equality_node(key, json2.Any(json2.Null{}))!
	document := node.document()
	mut selection := document.get_selection() or { return 'null' }
	mut result := map[string]json2.Any{}
	match op {
		'state' {}
		'getRangeAt' {
			index := compact_range_int(request, 'index')
			if index < 0 || index >= selection.range_count() { return error('IndexSizeError: Selection range index out of range') }
			result['value'] = binding.range_state(selection.get_range_at(index)!)
		}
		'addRange' { selection.add_range(binding.range_argument(request, 'range')!) }
		'removeRange' { selection.remove_range(binding.range_argument(request, 'range')!)! }
		'removeAllRanges' { selection.remove_all_ranges() }
		'collapse' {
			if (request['node'] or { json2.Any(json2.Null{}) }) is json2.Null {
				selection.collapse(none, 0)!
			} else {
				selection.collapse(binding.range_node_argument(request, 'node')!, compact_range_int(request, 'offset'))!
			}
		}
		'collapseToStart' { selection.collapse_to_start()! }
		'collapseToEnd' { selection.collapse_to_end()! }
		'extend' { selection.extend(binding.range_node_argument(request, 'node')!, compact_range_int(request, 'offset'))! }
		'setBaseAndExtent' {
			selection.set_base_and_extent(binding.range_node_argument(request, 'anchor')!, compact_range_int(request, 'anchorOffset'),
				binding.range_node_argument(request, 'focus')!, compact_range_int(request, 'focusOffset'))!
		}
		'selectAllChildren' { selection.select_all_children(binding.range_node_argument(request, 'node')!)! }
		'containsNode' {
			result['value'] = json2.Any(selection.contains_node(binding.range_node_argument(request, 'node')!, compact_range_bool(request, 'partial')))
		}
		'toString' { result['value'] = json2.Any(selection.to_string()) }
		'modify' {
			selection.modify(json_string_property(request, 'alter'), json_string_property(request, 'direction'),
				json_string_property(request, 'granularity'))!
		}
		'deleteFromDocument' {
			selection.delete_from_document()!
			result['refresh'] = binding.structure_refresh()
		}
		else { return error('Invalid Selection operation') }
	}
	if op !in ['state', 'getRangeAt', 'containsNode', 'toString'] { binding.note_node_tree_mutation() }
	result['selection'] = binding.selection_state(selection)
	return json2.encode(result)
}

fn (mut binding CompactElementQueryBinding) editing_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid editing operation') }
	node := binding.equality_node(key, json2.Any(json2.Null{}))!
	mut document := unsafe { &dom.Document(node.document()) }
	command := json_string_property(request, 'command') or { '' }
	mut result := map[string]json2.Any{}
	match op {
		'exec' {
			result['value'] = json2.Any(document.exec_command(command, compact_range_bool(request, 'showUI'),
				json_string_property(request, 'value') or { '' })!)
			result['refresh'] = binding.mutation_refresh(document.as_node())
		}
		'enabled' { result['value'] = json2.Any(document.query_command_enabled(command)!) }
		'indeterm' { result['value'] = json2.Any(document.query_command_indeterm(command)!) }
		'state' { result['value'] = json2.Any(document.query_command_state(command)!) }
		'supported' { result['value'] = json2.Any(document.query_command_supported(command)!) }
		'value' { result['value'] = json2.Any(document.query_command_value(command)!) }
		else { return error('Invalid editing operation') }
	}
	return json2.encode(result)
}

fn compact_range_selection_bootstrap() string {
	return r'
(function(){
 const wrappers=new Map(),records=new WeakMap(),get=WeakMap.prototype.get,set=WeakMap.prototype.set;
 const selections=new WeakMap();
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
 const unsigned=value=>Number(value)>>>0;
 function fail(error){
  const match=/^([A-Za-z]*Error):\s*(.*)/.exec(String(error&&error.message));
  if(!match)throw error;
  if(match[1]==="TypeError")throw new TypeError(match[2]);
  throw new DOMException(match[2],match[1]);
 }
 function call(key,action,request){try{return __queryElements(key,action,JSON.stringify(request),true);}catch(error){fail(error);}}
 function node(value,name){
  if(value===null||value===undefined||(typeof value!=="object"&&typeof value!=="function"))throw new TypeError((name||"argument")+" is not a Node");
  const state=__compactNodeState(value);
  return {key:state.bridgeKey,state:state.created?state:undefined};
 }
 function refresh(result){
  if(!result||!result.refresh)return result;
  for(const entry of result.refresh){
   const state=__state.elements[entry.key];if(!state)continue;
   state.attributes=entry.attributes;state.attributeRecords=entry.attributeRecords;
   state.id=entry.attributes.id===undefined?"":String(entry.attributes.id);
   state.className=entry.attributes.class===undefined?"":String(entry.attributes.class);
  }
  __compactInvalidateAllContent();
  return result;
 }
 globalThis.__compactApplyMutationRefresh=refresh;
 function AbstractRange(){throw new TypeError("Illegal AbstractRange constructor");}
 function Range(){
  if(!new.target)throw new TypeError("Range constructor requires new");
  const created=call("","range",{op:"create"}).range;
  adopt(this,created);
  return this;
 }
 function Selection(){throw new TypeError("Illegal Selection constructor");}
 Object.setPrototypeOf(Range,AbstractRange);Object.setPrototypeOf(Range.prototype,AbstractRange.prototype);
 for(const [constructor,name] of [[AbstractRange,"AbstractRange"],[Range,"Range"],[Selection,"Selection"]]){
  Object.defineProperty(constructor,"prototype",{writable:false});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 for(const [name,value] of [["START_TO_START",0],["START_TO_END",1],["END_TO_END",2],["END_TO_START",3]]){
  Object.defineProperty(Range,name,{value,enumerable:true});Object.defineProperty(Range.prototype,name,{value,enumerable:true});
 }
 function adopt(object,state){__elementApply(set,records,[object,state.key]);wrappers.set(state.key,object);return object;}
 function wrap(state){if(state===null||state===undefined)return null;const existing=wrappers.get(state.key);return existing||adopt(Object.create(Range.prototype),state);}
 function key(receiver){const own=__elementApply(get,records,[receiver]);if(!own)throw new TypeError("Illegal Range receiver");return own;}
 // Range state stays valid until another range, selection or editing
 // operation, or a DOM change, which the content version reflects.
 const contentVersion=globalThis.__ladybirdDOMContentVersion;
 let epoch=0;const states=new Map();
 function version(){
  if(typeof contentVersion!=="function")return -1;
  if(__compactHasPendingDOMState())return -1;
  return contentVersion();
 }
 function op(receiver,name,fields){
  const own=key(receiver);
  if(name!=="state")epoch++;
  return refresh(call("","range",Object.assign({op:name,range:own},fields||{})));
 }
 function rangeState(receiver){
  const own=key(receiver),current=version(),cached=states.get(own);
  if(cached&&current>=0&&cached.version===current&&cached.epoch===epoch)return cached.state;
  const state=op(receiver,"state").range,after=version();
  if(after>=0)states.set(own,{state,version:after,epoch});
  return state;
 }
 for(const name of ["startContainer","endContainer","commonAncestorContainer"])Object.defineProperty(AbstractRange.prototype,name,{get:function(){return __queryElement(rangeState(this)[name]);},enumerable:true,configurable:true});
 for(const name of ["startOffset","endOffset","collapsed"])Object.defineProperty(AbstractRange.prototype,name,{get:function(){return rangeState(this)[name];},enumerable:true,configurable:true});
 if(typeof __ladybirdInstallStaticRange==="function")__ladybirdInstallStaticRange(AbstractRange);
 const point=name=>function(target,offset){if(arguments.length<2)throw new TypeError(name+" requires a node and an offset");op(this,name,{node:node(target,"node"),offset:unsigned(offset)});};
 const boundary=name=>function(target){if(arguments.length<1)throw new TypeError(name+" requires a node");op(this,name,{node:node(target,"node")});};
 const fragment=name=>function(){const result=op(this,name).value;return result===undefined?undefined:__queryElement(result);};
 const methods={
  setStart:point("setStart"),setEnd:point("setEnd"),
  setStartBefore:boundary("setStartBefore"),setStartAfter:boundary("setStartAfter"),
  setEndBefore:boundary("setEndBefore"),setEndAfter:boundary("setEndAfter"),
  selectNode:boundary("selectNode"),selectNodeContents:boundary("selectNodeContents"),
  insertNode:boundary("insertNode"),surroundContents:boundary("surroundContents"),
  collapse(toStart=false){op(this,"collapse",{toStart:!!toStart});},
  compareBoundaryPoints(how,source){
   if(arguments.length<2)throw new TypeError("compareBoundaryPoints requires a type and a Range");
   const value=Number(how)&65535;if(value>3)throw new DOMException("Invalid comparison type","NotSupportedError");
   return op(this,"compareBoundaryPoints",{how:value,source:key(source)}).value;
  },
  deleteContents(){op(this,"deleteContents");},
  extractContents:fragment("extractContents"),cloneContents:fragment("cloneContents"),
  cloneRange(){return wrap(op(this,"cloneRange").value);},
  detach(){key(this);},
  isPointInRange(target,offset){if(arguments.length<2)throw new TypeError("isPointInRange requires a node and an offset");return op(this,"isPointInRange",{node:node(target,"node"),offset:unsigned(offset)}).value;},
  comparePoint(target,offset){if(arguments.length<2)throw new TypeError("comparePoint requires a node and an offset");return op(this,"comparePoint",{node:node(target,"node"),offset:unsigned(offset)}).value;},
  intersectsNode(target){if(arguments.length<1)throw new TypeError("intersectsNode requires a node");return op(this,"intersectsNode",{node:node(target,"node")}).value;},
  toString(){return op(this,"toString").value;},
  createContextualFragment(markup){if(arguments.length<1)throw new TypeError("createContextualFragment requires markup");return __queryElement(op(this,"createContextualFragment",{value:string(markup)}).value);},
  getBoundingClientRect(){const rect=op(this,"getBoundingClientRect").value;return typeof DOMRect==="function"?new DOMRect(rect.x,rect.y,rect.width,rect.height):rect;},
  getClientRects(){return op(this,"getClientRects").value.map(rect=>typeof DOMRect==="function"?new DOMRect(rect.x,rect.y,rect.width,rect.height):rect);}
 };
 for(const [name,value] of Object.entries(methods))Object.defineProperty(Range.prototype,name,{value,writable:true,enumerable:true,configurable:true});
 Object.defineProperty(Document.prototype,"createRange",{value:function createRange(){
  const state=__compactDocumentState(this);
  return wrap(call(state.bridgeKey,"range",{op:"create"}).range);
 },writable:true,enumerable:true,configurable:true});
 delete document.createRange;
 function selectionOwner(receiver){const owner=__elementApply(get,selections,[receiver]);if(owner===undefined)throw new TypeError("Illegal Selection receiver");return owner;}
 function selectionOp(receiver,name,fields){
  const owner=selectionOwner(receiver);
  if(name!=="state"&&name!=="containsNode"&&name!=="toString")epoch++;
  const result=refresh(call(owner,"selection",Object.assign({op:name},fields||{})));
  return result;
 }
 const selectionState=receiver=>selectionOp(receiver,"state").selection;
 for(const name of ["anchorNode","focusNode"])Object.defineProperty(Selection.prototype,name,{get:function(){const value=selectionState(this)[name];return value===null?null:__queryElement(value);},enumerable:true,configurable:true});
 for(const name of ["anchorOffset","focusOffset","isCollapsed","rangeCount","type","direction"])Object.defineProperty(Selection.prototype,name,{get:function(){return selectionState(this)[name];},enumerable:true,configurable:true});
 const selectionMethods={
  getRangeAt(index){if(arguments.length<1)throw new TypeError("getRangeAt requires an index");return wrap(selectionOp(this,"getRangeAt",{index:unsigned(index)}).value);},
  addRange(range){if(arguments.length<1)throw new TypeError("addRange requires a Range");selectionOp(this,"addRange",{range:key(range)});},
  removeRange(range){if(arguments.length<1)throw new TypeError("removeRange requires a Range");selectionOp(this,"removeRange",{range:key(range)});},
  removeAllRanges(){selectionOp(this,"removeAllRanges");},
  empty(){selectionOp(this,"removeAllRanges");},
  collapse(target,offset=0){if(arguments.length<1)throw new TypeError("collapse requires a node");selectionOp(this,"collapse",{node:target===null?null:node(target,"node"),offset:unsigned(offset)});},
  setPosition(target,offset=0){if(arguments.length<1)throw new TypeError("setPosition requires a node");selectionOp(this,"collapse",{node:target===null?null:node(target,"node"),offset:unsigned(offset)});},
  collapseToStart(){selectionOp(this,"collapseToStart");},
  collapseToEnd(){selectionOp(this,"collapseToEnd");},
  extend(target,offset=0){if(arguments.length<1)throw new TypeError("extend requires a node");selectionOp(this,"extend",{node:node(target,"node"),offset:unsigned(offset)});},
  setBaseAndExtent(anchor,anchorOffset,focus,focusOffset){if(arguments.length<4)throw new TypeError("setBaseAndExtent requires four arguments");selectionOp(this,"setBaseAndExtent",{anchor:node(anchor,"anchorNode"),anchorOffset:unsigned(anchorOffset),focus:node(focus,"focusNode"),focusOffset:unsigned(focusOffset)});},
  selectAllChildren(target){if(arguments.length<1)throw new TypeError("selectAllChildren requires a node");selectionOp(this,"selectAllChildren",{node:node(target,"node")});},
  deleteFromDocument(){selectionOp(this,"deleteFromDocument");},
  containsNode(target,partial=false){if(arguments.length<1)throw new TypeError("containsNode requires a node");return selectionOp(this,"containsNode",{node:node(target,"node"),partial:!!partial}).value;},
  modify(alter,direction,granularity){const fields={};if(alter!==undefined)fields.alter=string(alter);if(direction!==undefined)fields.direction=string(direction);if(granularity!==undefined)fields.granularity=string(granularity);selectionOp(this,"modify",fields);},
  toString(){return selectionOp(this,"toString").value;}
 };
 for(const [name,value] of Object.entries(selectionMethods))Object.defineProperty(Selection.prototype,name,{value,writable:true,enumerable:true,configurable:true});
 const documentSelections=new WeakMap();
 function selectionFor(owner){
  const state=__compactDocumentState(owner);
  if(call(state.bridgeKey,"selection",{op:"state"})===null)return null;
  let selection=__elementApply(get,documentSelections,[owner]);
  if(!selection){selection=Object.create(Selection.prototype);__elementApply(set,selections,[selection,state.bridgeKey]);__elementApply(set,documentSelections,[owner,selection]);}
  return selection;
 }
 Object.defineProperty(Document.prototype,"getSelection",{value:function getSelection(){return selectionFor(this);},writable:true,enumerable:true,configurable:true});
 Object.defineProperty(globalThis,"getSelection",{value:function getSelection(){return selectionFor(document);},writable:true,enumerable:true,configurable:true});
 function editing(receiver,name,command,fields){
  const state=__compactDocumentState(receiver);
  if(name==="exec")epoch++;
  return refresh(call(state.bridgeKey,"editing",Object.assign({op:name,command:string(command)},fields||{}))).value;
 }
 const commands={
  execCommand(command,showUI=false,value=""){if(arguments.length<1)throw new TypeError("execCommand requires a command");return editing(this,"exec",command,{showUI:!!showUI,value:value===null?"":string(value)});},
  queryCommandEnabled(command){if(arguments.length<1)throw new TypeError("queryCommandEnabled requires a command");return editing(this,"enabled",command);},
  queryCommandIndeterm(command){if(arguments.length<1)throw new TypeError("queryCommandIndeterm requires a command");return editing(this,"indeterm",command);},
  queryCommandState(command){if(arguments.length<1)throw new TypeError("queryCommandState requires a command");return editing(this,"state",command);},
  queryCommandSupported(command){if(arguments.length<1)throw new TypeError("queryCommandSupported requires a command");return editing(this,"supported",command);},
  queryCommandValue(command){if(arguments.length<1)throw new TypeError("queryCommandValue requires a command");return editing(this,"value",command);}
 };
 for(const [name,value] of Object.entries(commands))Object.defineProperty(Document.prototype,name,{value,writable:true,enumerable:true,configurable:true});
})();
'
}
