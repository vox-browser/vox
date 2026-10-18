module main

fn compact_element_query_bootstrap() string {
	return r'
const __selectorResultHasOwn=Object.prototype.hasOwnProperty;
function __queryElements(key,action,selector){
 const request={key:key,action:action,selector:selector},pending=__pendingElementStates(false);
 if(__state.operations.length||Object.keys(pending).length){
  const snapshot=Object.assign({},__state,{elements:pending,logs:[]});
  delete snapshot.videoSources;
  request.snapshot=JSON.stringify(snapshot);request.logCount=0;__state.operations=[];
  for(const key of Object.keys(pending)){
   const s=pending[key];s.attributesDirty=false;s.textContentDirty=false;s.innerHTMLDirty=false;s.checkedDirty=false;s.indeterminateDirty=false;
  }
 }
 let result;
 try{result=JSON.parse(__nativeElementQuery(JSON.stringify(request)));}
 catch(error){
  if(String(error.message).indexOf("SyntaxError:")===0){
   throw new DOMException(String(error.message).slice(12).trim(),"SyntaxError");
  }
  throw error;
 }
 // Parse failures are ordinary host results. Construct the fresh exception
 // here instead of capturing a native exception stack before crossing back.
 if(result!==null&&typeof result==="object"&&__elementApply(__selectorResultHasOwn,result,["__voxSelectorSyntaxError"]))
  throw new DOMException(String(result.__voxSelectorSyntaxError).slice(12).trim(),"SyntaxError");
 return action==="matches"||action==="geometry"||action==="computedStyle"||action==="selectedIndex"||action==="setSelectedIndex"||action==="removeChild"||action==="nodeValue"||action==="setNodeValue"||action==="nodeText"||action==="setNodeText"||action==="getElementsByTagName"?result:(action==="querySelectorAll"||action==="getElementsByClassName"||action==="childNodes")?result.map(__queryElement):__queryElement(result);
}
'
}
