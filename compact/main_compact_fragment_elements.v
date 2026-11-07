module main

// ParentNode's element accessors also belong to inert template contents and
// newly constructed fragments. Query native children to preserve tree order
// and wrapper identity without making :scope depend on an element root.
fn compact_fragment_elements_bootstrap() string {
	return r'
const __compactFragmentElementLists=new WeakMap();
function __compactFragmentState(receiver){
 const state=__elementApply(__compactNodeGet,__compactNodeRecords,[receiver]);
 if(!state||state.nodeType!==11)throw new TypeError("Illegal DocumentFragment receiver");
 return state;
}
for(const [name,relation] of [["firstElementChild","first"],["lastElementChild","last"]]){
 Object.defineProperty(DocumentFragment.prototype,name,{get:function(){
  return __queryElements(__compactFragmentState(this).bridgeKey,"elementRelative",relation);
 },enumerable:true,configurable:true});
}
Object.defineProperty(DocumentFragment.prototype,"children",{get:function(){
 const state=__compactFragmentState(this);
 let list=__elementApply(__compactNodeGet,__compactFragmentElementLists,[this]);
 if(!list){
  list=__classCollection(state.bridgeKey,"",()=>__queryElements(state.bridgeKey,"childElements",""));
  __elementApply(__elementRecordSet,__compactFragmentElementLists,[this,list]);
 }
 return list;
},enumerable:true,configurable:true});
Object.defineProperty(DocumentFragment.prototype,"childElementCount",{get:function(){
 const state=__compactFragmentState(this);
 return __queryElements(state.bridgeKey,"childElements","").length;
},enumerable:true,configurable:true});
'
}
