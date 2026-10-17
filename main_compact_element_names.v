module main

// Element.tagName, nodeName, localName, namespaceURI, prefix and nodeType on
// compact element facades, with Document.nodeType and nodeName. An HTML
// element reports its qualified name in ASCII uppercase; other elements keep
// its case, such as SVG's foreignObject.
fn compact_element_names_bootstrap() string {
	return r'
{
 const state=function(element){
  const s=__elementApply(__elementRecordGet,__elementRecords,[element]);
  if(!s)throw new TypeError("Illegal Element receiver");
  return s;
 };
 const separator=function(s){return String(s.tagName).indexOf(":");};
 const tag=function(s){
  const name=String(s.tagName);
  return s.namespaceURI==="http://www.w3.org/1999/xhtml"?name.replace(/[a-z]/g,function(c){return c.toUpperCase();}):name;
 };
 const readers={
  tagName:tag,
  nodeName:tag,
  localName:function(s){const index=separator(s);return index<0?String(s.tagName):String(s.tagName).slice(index+1);},
  namespaceURI:function(s){return s.namespaceURI?String(s.namespaceURI):null;},
  prefix:function(s){const index=separator(s);return index<0?null:String(s.tagName).slice(0,index);},
  nodeType:function(){return 1;}
 };
 for(const name of Object.keys(readers)){
  const read=readers[name];
  Object.defineProperty(Element.prototype,name,{get:function(){return read(state(this));},enumerable:true,configurable:true});
 }
 if(!("nodeType" in document))Object.defineProperty(document,"nodeType",{value:9,enumerable:true,configurable:true});
 if(!("nodeName" in document))Object.defineProperty(document,"nodeName",{value:"#document",enumerable:true,configurable:true});
}
'
}
