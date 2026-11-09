module main

fn compact_document_name_collection_bootstrap() string {
	return r'
const __nativeDocumentNameCollection=globalThis.__ladybirdDocumentNameCollection;
delete globalThis.__ladybirdDocumentNameCollection;
Object.defineProperty(Document.prototype,"getElementsByName",{value:{getElementsByName(name){
 "use strict";
 const read=arguments.length?__nativeDocumentNameCollection(this,name):__nativeDocumentNameCollection(this);
 return __compactNodeList(()=>{__compactFlushDOMMutations();return read();});
}}.getElementsByName,writable:true,enumerable:true,configurable:true});
'
}
