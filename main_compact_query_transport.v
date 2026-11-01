module main

import os

const disable_compact_query_fields = os.getenv('VOX_DISABLE_COMPACT_QUERY_FIELDS') == '1'
const compact_query_fields_diagnostics = os.getenv('VOX_COMPACT_QUERY_FIELDS_DIAGNOSTICS') == '1'

// Mutation replay keeps the JSON snapshot boundary. Plain string requests can
// carry their three fields directly, avoiding an otherwise redundant object
// encoder/decoder pair. Only keys and actions need separator checks; selectors
// retain their complete tail, including newlines and embedded NUL characters.
fn compact_element_query_bootstrap() string {
	code := r'function __queryElements(key,action,selector){const request={key:key,action:action,selector:selector},pending=__pendingElementStates(false);if(__state.operations.length||Object.keys(pending).length){const snapshot=Object.assign({},__state,{elements:pending,logs:[]});delete snapshot.videoSources;request.snapshot=JSON.stringify(snapshot);request.logCount=0;__state.operations=[];for(const key of Object.keys(pending)){const s=pending[key];s.attributesDirty=false;s.textContentDirty=false;s.innerHTMLDirty=false;s.checkedDirty=false;s.indeterminateDirty=false;}}let result;try{result=JSON.parse(__nativeElementQuery(JSON.stringify(request)));}catch(error){if(String(error.message).indexOf("SyntaxError:")===0)throw new DOMException(String(error.message).slice(12).trim(),"SyntaxError");throw error;}return action==="documentValue"||action==="setDocumentTitle"||action==="elementURL"||action==="matches"||action==="contains"||action==="isEqualNode"||action==="compareDocumentPosition"||action==="nodeConnected"||action==="geometry"||action==="computedStyle"||action==="inputValue"||action==="characterData"||action==="inlineStyle"||action==="cssSheet"||action==="linkSheet"||action==="formControls"||action==="dataset"||action==="shadowValue"||action==="setMarkup"||action==="selectedIndex"||action==="setSelectedIndex"||action==="selectValue"||action==="setSelectValue"||action==="removeChild"||action==="nodeValue"||action==="setNodeValue"||action==="nodeText"||action==="setNodeText"||action==="getElementsByTagName"||action==="eventAncestors"||action==="cachedParent"?result:(action==="querySelectorAll"||action==="getElementsByClassName"||action==="childNodes"||action==="childElements"||action==="elementsFromPoint")?result.map(__queryElement):__queryElement(result);}'
	if disable_compact_query_fields { return code }
	return code.replace('result=JSON.parse(__nativeElementQuery(JSON.stringify(request)));',
		r'result=JSON.parse(__nativeElementQuery(!request.snapshot&&typeof key==="string"&&typeof action==="string"&&typeof selector==="string"&&key.indexOf("\n")<0&&action.indexOf("\n")<0?"@"+key+"\n"+action+"\n"+selector:JSON.stringify(request)));')
}
