module main

import math
import xpath
import x.json2

// https://dom.spec.whatwg.org/#xpath
// Evaluate with the translated XPath evaluator and return a snapshot of the
// result. The script-side XPathResult keeps that snapshot; iterator results
// become invalid once the document changes.
fn compact_xpath_number(value f64) json2.Any {
	if math.is_nan(value) { return json2.Any('NaN') }
	if math.is_inf(value, 1) { return json2.Any('Infinity') }
	if math.is_inf(value, -1) { return json2.Any('-Infinity') }
	return json2.Any(value)
}

fn (mut binding CompactElementQueryBinding) xpath_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	context := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
	expression := json_string_property(request, 'expression') or { '' }
	type_value := (request['type'] or { json2.Any(0) }).int()
	if type_value < 0 || type_value > int(xpath.ResultType.first_ordered_node) {
		return error('TypeError: Invalid XPathResult type ${type_value}')
	}
	requested := unsafe { xpath.ResultType(u16(type_value)) }
	evaluator := xpath.XPathEvaluator.construct()
	result := evaluator.evaluate(expression, context, none, requested, none)!
	mut nodes := []json2.Any{}
	for index in 0 .. int(result.snapshot_length()) {
		if node := result.snapshot_item(index) { nodes << binding.node_state(node) }
	}
	return json2.encode({
		'resultType':   json2.Any(int(result.result_type()))
		'numberValue':  compact_xpath_number(result.number_value())
		'stringValue':  json2.Any(result.string_value())
		'booleanValue': json2.Any(result.boolean_value())
		'nodes':        json2.Any(nodes)
	})
}

fn compact_xpath_bootstrap() string {
	return r'
(function(){
 const records=new WeakMap(),expressions=new WeakMap(),get=WeakMap.prototype.get,set=WeakMap.prototype.set;
 const treeVersion=globalThis.__ladybirdDOMTreeVersion;
 // Pending script writes reach the native tree, and its version, on flush.
 const version=()=>{if(typeof __ladybirdFlushPendingScriptMutations==="function")__ladybirdFlushPendingScriptMutations();return treeVersion();};
 const string=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");return String(value);};
 const types=[["ANY_TYPE",0],["NUMBER_TYPE",1],["STRING_TYPE",2],["BOOLEAN_TYPE",3],["UNORDERED_NODE_ITERATOR_TYPE",4],["ORDERED_NODE_ITERATOR_TYPE",5],["UNORDERED_NODE_SNAPSHOT_TYPE",6],["ORDERED_NODE_SNAPSHOT_TYPE",7],["ANY_UNORDERED_NODE_TYPE",8],["FIRST_ORDERED_NODE_TYPE",9]];
 function expose(name,constructor){
  Object.defineProperty(constructor,"prototype",{writable:false});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 function XPathResult(){throw new TypeError("Illegal XPathResult constructor");}
 function XPathExpression(){throw new TypeError("Illegal XPathExpression constructor");}
 expose("XPathResult",XPathResult);expose("XPathExpression",XPathExpression);
 for(const [name,value] of types){Object.defineProperty(XPathResult,name,{value,enumerable:true});Object.defineProperty(XPathResult.prototype,name,{value,enumerable:true});}
 function record(receiver){const own=__elementApply(get,records,[receiver]);if(!own)throw new TypeError("Illegal XPathResult receiver");return own;}
 function typed(receiver,allowed,name){const own=record(receiver);if(!allowed.includes(own.resultType))throw new TypeError("XPathResult."+name+" is not available for result type "+own.resultType);return own;}
 const getters={
  resultType(){return record(this).resultType;},
  numberValue(){return typed(this,[1],"numberValue").numberValue;},
  stringValue(){return typed(this,[2],"stringValue").stringValue;},
  booleanValue(){return typed(this,[3],"booleanValue").booleanValue;},
  singleNodeValue(){return typed(this,[8,9],"singleNodeValue").nodes[0]||null;},
  invalidIteratorState(){const own=record(this);return (own.resultType===4||own.resultType===5)&&own.version!==version();},
  snapshotLength(){return typed(this,[6,7],"snapshotLength").nodes.length;}
 };
 for(const [name,value] of Object.entries(getters))Object.defineProperty(XPathResult.prototype,name,{get:value,enumerable:true,configurable:true});
 Object.defineProperty(XPathResult.prototype,"iterateNext",{value:function iterateNext(){
  const own=typed(this,[4,5],"iterateNext");
  if(own.version!==version())throw new DOMException("The document has changed since the result was returned","InvalidStateError");
  return own.index<own.nodes.length?own.nodes[own.index++]:null;
 },writable:true,enumerable:true,configurable:true});
 Object.defineProperty(XPathResult.prototype,"snapshotItem",{value:function snapshotItem(index){
  const own=typed(this,[6,7],"snapshotItem");if(arguments.length<1)throw new TypeError("snapshotItem requires an index");
  return own.nodes[(+index)>>>0]||null;
 },writable:true,enumerable:true,configurable:true});
 function evaluate(expression,context,type,reuse){
  const state=__compactNodeState(context);
  let snapshot;
  try{snapshot=__queryElements(state.bridgeKey,"xpath",JSON.stringify({expression,type,state:state.created?state:undefined}),true);}
  catch(error){const match=/^(TypeError|SyntaxError|NamespaceError|OperationError|NotSupportedError):\s*(.*)/.exec(String(error.message));if(!match)throw error;if(match[1]==="TypeError")throw new TypeError(match[2]);throw new DOMException(match[2],match[1]);}
  const own={resultType:snapshot.resultType,numberValue:typeof snapshot.numberValue==="string"?Number(snapshot.numberValue):snapshot.numberValue,stringValue:snapshot.stringValue,booleanValue:snapshot.booleanValue,nodes:snapshot.nodes.map(__queryElement),index:0,version:version()};
  // A node-set converts to the requested primitive type as XPath boolean(),
  // string() and number() do: the string value of its first node.
  if(type>=1&&type<=3&&own.resultType>=4){
   const text=own.nodes.length?String(own.nodes[0].nodeType===2?own.nodes[0].value:own.nodes[0].textContent||""):"";
   const trimmed=text.trim();
   own.resultType=type;own.booleanValue=own.nodes.length>0;own.stringValue=text;
   own.numberValue=/^-?(\d+(\.\d*)?|\.\d+)$/.test(trimmed)?Number(trimmed):NaN;
  }else if(type>=4&&own.resultType<4)throw new TypeError("The XPath result is not a node-set");
  const result=reuse!==null&&reuse!==undefined&&__elementApply(get,records,[reuse])?reuse:Object.create(XPathResult.prototype);
  __elementApply(set,records,[result,own]);
  return result;
 }
 function convertType(value){return value===undefined?0:(Number(value)&65535);}
 function checkResolver(resolver){if(resolver!==null&&resolver!==undefined&&typeof resolver!=="object"&&typeof resolver!=="function")throw new TypeError("XPathNSResolver must be an object");}
 function createExpression(expression,resolver){
  if(arguments.length<1)throw new TypeError("createExpression requires an expression");
  checkResolver(resolver);const text=string(expression);
  evaluate(text,document,0,null);
  const object=Object.create(XPathExpression.prototype);__elementApply(set,expressions,[object,text]);return object;
 }
 function documentEvaluate(expression,contextNode,resolver=null,type=0,result=null){
  if(arguments.length<2)throw new TypeError("evaluate requires an expression and a context node");
  checkResolver(resolver);return evaluate(string(expression),contextNode,convertType(type),result);
 }
 Object.defineProperty(XPathExpression.prototype,"evaluate",{value:function evaluate_(contextNode,type=0,result=null){
  const text=__elementApply(get,expressions,[this]);if(text===undefined)throw new TypeError("Illegal XPathExpression receiver");
  if(arguments.length<1)throw new TypeError("evaluate requires a context node");
  return evaluate(text,contextNode,convertType(type),result);
 },writable:true,enumerable:true,configurable:true});
 const methods={createExpression,createNSResolver(node){return node;},evaluate:documentEvaluate};
 class XPathEvaluator{}
 expose("XPathEvaluator",XPathEvaluator);
 for(const [name,value] of Object.entries(methods)){
  Object.defineProperty(XPathEvaluator.prototype,name,{value,writable:true,enumerable:true,configurable:true});
  Object.defineProperty(Document.prototype,name,{value,writable:true,enumerable:true,configurable:true});
 }
})();
'
}
