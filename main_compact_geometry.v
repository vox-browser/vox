module main

import dom
import html
import x.json2

// Use the translated CSSOM View algorithms after the shared query boundary has
// flushed pending DOM and style mutations. Menu positioning must see live boxes.
fn compact_element_geometry_query(root &dom.Node, name string) !string {
	if name in ['scrollX', 'scrollY'] {
		document := root.document()
		window := document.get_window() or { return '0' }
		owner := unsafe { &html.WindowModel(window) }
		value := if name == 'scrollX' { owner.scroll_x() } else { owner.scroll_y() }
		return json2.encode(value)
	}
	element := root.as_element() or { return error('TypeError: Invalid Element receiver') }
	if name == 'rect' {
		rect := element.get_bounding_client_rect()
		return json2.encode({
			'x':      rect.x
			'y':      rect.y
			'width':  rect.width
			'height': rect.height
			'top':    rect.y
			'left':   rect.x
			'right':  rect.x + rect.width
			'bottom': rect.y + rect.height
		})
	}
	if name == 'clientTop' { return element.client_top().str() }
	if name == 'clientLeft' { return element.client_left().str() }
	if name == 'clientWidth' { return element.client_width().str() }
	if name == 'clientHeight' { return element.client_height().str() }
	if name == 'scrollTop' { return json2.encode(element.scroll_top()) }
	if name == 'scrollLeft' { return json2.encode(element.scroll_left()) }
	if name in ['scrollWidth', 'scrollHeight'] {
		mut owner := unsafe { &dom.Element(element) }
		mut document := unsafe { &dom.Document(element.document()) }
		document.update_layout(if name == 'scrollWidth' { .element_scroll_width } else { .element_scroll_height })
		return if name == 'scrollWidth' { owner.scroll_width().str() } else { owner.scroll_height().str() }
	}
	if !element.is_html_element() { return error('TypeError: Invalid HTMLElement receiver') }
	host := unsafe { &dom.HTMLElement(element) }
	return match name {
		'offsetTop' { html.html_element_offset_top(host).str() }
		'offsetLeft' { html.html_element_offset_left(host).str() }
		'offsetWidth' { html.html_element_offset_width(host).str() }
		'offsetHeight' { html.html_element_offset_height(host).str() }
		else { return error('Invalid element geometry property') }
	}
}

fn compact_element_geometry_bootstrap() string {
	return r'
function __compactElementGeometry(object,state){
 const read=function(receiver,name){const own=__elementApply(__elementRecordGet,__elementRecords,[receiver]);if(!own)throw new TypeError("Illegal Element receiver");return __queryElements(own.bridgeKey,"geometry",name);};
 object.getBoundingClientRect=function getBoundingClientRect(){return read(this,"rect");};
 for(const name of ["clientTop","clientLeft","clientWidth","clientHeight","scrollWidth","scrollHeight"]){
  Object.defineProperty(object,name,{get(){return read(this,name);},enumerable:true,configurable:true});
 }
 for(const name of ["scrollTop","scrollLeft"]){
  Object.defineProperty(object,name,{get(){return read(this,name);},set(value){
   const own=__elementApply(__elementRecordGet,__elementRecords,[this]);if(!own)throw new TypeError("Illegal Element receiver");
   value=+value;if(!__compactScrollFinite(value))value=0;
   __queryElements(own.bridgeKey,"setScroll",JSON.stringify({name,value}));
  },enumerable:true,configurable:true});
 }
 if(state.namespaceURI!=="http://www.w3.org/1999/xhtml")return;
 for(const name of ["offsetTop","offsetLeft","offsetWidth","offsetHeight"]){
  Object.defineProperty(object,name,{get(){return read(this,name);},enumerable:true,configurable:true});
 }
 Object.defineProperty(object,"offsetParent",{get(){return __queryElements(state.bridgeKey,"offsetParent","");},enumerable:true,configurable:true});
}
const __compactScrollFinite=Number.isFinite;
Object.defineProperty(Element.prototype,"ownerDocument",{get:function(){
 if(!__elementApply(__elementRecordGet,__elementRecords,[this]))throw new TypeError("Illegal Node receiver");
 return __compactOwnerDocument(this);
},enumerable:true,configurable:true});
Object.defineProperty(document,"defaultView",{get(){return globalThis;},enumerable:true,configurable:true});
for(const [name,axis] of [["pageXOffset","scrollX"],["pageYOffset","scrollY"],["scrollX","scrollX"],["scrollY","scrollY"]]){
 Object.defineProperty(globalThis,name,{get(){return __queryElements("","geometry",axis);},enumerable:true,configurable:true});
}'
}
