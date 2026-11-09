module main

import dom
import layout
import x.json2

fn (mut binding CompactElementQueryBinding) svg_geometry_query(key string, input string) !string {
	request := json2.decode[map[string]json2.Any](input)!
	node := binding.equality_node(key,request['state'] or { json2.Any(json2.Null{}) })!
	element := node.as_element() or { return error('TypeError: Expected SVG geometry element') }
	if !element.is_svg_element() || element.local_name() !in ['path','rect','circle','ellipse','line','polyline','polygon'] {
		return error('TypeError: Expected SVG geometry element')
	}
	geometry := layout.svg_dom_geometry(element)
	op := json_string_property(request,'op') or { return error('Invalid SVG geometry operation') }
	match op {
		'getTotalLength' { return json2.encode(geometry.path.length()) }
		'getPointAtLength' {
			if geometry.path.instructions.len == 0 { return error('InvalidStateError: The element has no path') }
			point := geometry.point_at_length((request['distance'] or { json2.Any(0.0) }).f64())
			return json2.encode({'x':point.x,'y':point.y})
		}
		'isPointInFill','isPointInStroke' {
			x := (request['x'] or { json2.Any(0.0) }).f64()
			y := (request['y'] or { json2.Any(0.0) }).f64()
			return json2.encode(geometry.contains_point(x,y,op == 'isPointInStroke'))
		}
		'getBBox' { return json2.encode(compact_rect_value(geometry.bounds)) }
  'checkIntersection','checkEnclosure' {
   root_node := binding.equality_node((request['rootKey'] or { json2.Any('') }).str(),request['rootState'] or { json2.Any(json2.Null{}) })!
   root := root_node.as_element() or { return error('TypeError: Expected SVG viewport') }
   rect := dom.DOMRect{x:(request['x'] or { json2.Any(0.0) }).f64(),y:(request['y'] or { json2.Any(0.0) }).f64(),width:(request['width'] or { json2.Any(0.0) }).f64(),height:(request['height'] or { json2.Any(0.0) }).f64()}
   return json2.encode(layout.svg_dom_region_matches(element,root,rect,op == 'checkEnclosure'))
  }
		else { return error('Invalid SVG geometry operation') }
	}
}

fn compact_svg_geometry_bootstrap() string {
	return r'
(function(){
 if(typeof SVGGeometryElement!=="function")return;
 const get=WeakMap.prototype.get,apply=Reflect.apply,stringify=JSON.stringify;
 const Point=globalThis.DOMPoint,Rect=globalThis.DOMRect;
 const geometryNames=new Set(["path","rect","circle","ellipse","line","polyline","polygon"]);
 function own(receiver){
  const state=apply(get,__elementRecords,[receiver]);
  if(!state||state.namespaceURI!=="http://www.w3.org/2000/svg"||!geometryNames.has(stringLocal(state.tagName)))throw new TypeError("Illegal SVGGeometryElement receiver");
  return state;
 }
 function stringLocal(name){return String(name).split(":").pop();}
 function call(state,op,args){
  try{return __queryElements(state.bridgeKey,"svgGeometry",stringify(Object.assign({op,state:state.created?state:undefined},args)),true);}catch(error){const match=/^([A-Za-z]*Error):\s*(.*)/.exec(String(error&&error.message));if(!match)throw error;if(match[1]==="TypeError")throw new TypeError(match[2]);throw new DOMException(match[2],match[1]);}
 }
 function finite(value){const converted=+value;if(!Number.isFinite(converted))throw new TypeError("Expected finite SVG coordinate");return converted;}
 function method(name,operation,length){const value=({[name](){return apply(operation,this,arguments);}})[name];Object.defineProperty(value,"length",{value:length});Object.defineProperty(SVGGeometryElement.prototype,name,{value,writable:true,enumerable:true,configurable:true});}
 method("getTotalLength",function(){return call(own(this),"getTotalLength",{});},0);
 method("getPointAtLength",function(distance){const state=own(this);if(arguments.length<1)throw new TypeError("getPointAtLength requires distance");const result=call(state,"getPointAtLength",{distance:finite(distance)});return new Point(result.x,result.y);},1);
 for(const name of ["isPointInFill","isPointInStroke"]){method(name,function(point){const state=own(this);if(point!==undefined&&point!==null&&typeof point!=="object"&&typeof point!=="function")throw new TypeError("Expected point dictionary");const memberX=point==null?undefined:point.x,memberY=point==null?undefined:point.y;const x=memberX===undefined?0:+memberX,y=memberY===undefined?0:+memberY;if(!Number.isFinite(x)||!Number.isFinite(y))return false;return call(state,name,{x,y});},0);}
 Object.defineProperty(SVGGraphicsElement.prototype,"getBBox",{value:function getBBox(){const state=own(this),result=call(state,"getBBox",{});return new Rect(result.x,result.y,result.width,result.height);},writable:true,enumerable:true,configurable:true});

 function viewport(receiver){const state=apply(get,__elementRecords,[receiver]);if(!state||state.namespaceURI!=="http://www.w3.org/2000/svg"||stringLocal(state.tagName)!=="svg")throw new TypeError("Illegal SVGSVGElement receiver");return state;}
 function rectangle(rect){if(!rect||typeof rect!=="object")throw new TypeError("Expected SVG rectangle");return {x:finite(rect.x),y:finite(rect.y),width:finite(rect.width),height:finite(rect.height)};}
 function region(root,element,rect,enclosed){const state=apply(get,__elementRecords,[element]);if(!state||state.namespaceURI!=="http://www.w3.org/2000/svg")throw new TypeError("Expected SVG element");if(!geometryNames.has(stringLocal(state.tagName)))return false;return call(state,enclosed?"checkEnclosure":"checkIntersection",Object.assign({rootKey:root.bridgeKey,rootState:root.created?root:undefined},rect));}
 for(const name of ["checkIntersection","checkEnclosure"]){const value=({[name](element,rect){const root=viewport(this);if(arguments.length<2)throw new TypeError(name+" requires element and rectangle");return region(root,element,rectangle(rect),name==="checkEnclosure");}})[name];Object.defineProperty(SVGSVGElement.prototype,name,{value,writable:true,enumerable:true,configurable:true});}
 for(const name of ["getIntersectionList","getEnclosureList"]){const value=({[name](rect,referenceElement){const root=viewport(this);if(arguments.length<2)throw new TypeError(name+" requires rectangle and reference element");const bounds=rectangle(rect);if(referenceElement!=null){const state=apply(get,__elementRecords,[referenceElement]);if(!state||state.namespaceURI!=="http://www.w3.org/2000/svg")throw new TypeError("Expected SVG reference element");}const nodes=Array.from(this.querySelectorAll("path,rect,circle,ellipse,line,polyline,polygon")).filter(element=>(referenceElement==null||(element!==referenceElement&&referenceElement.contains(element)))&&region(root,element,bounds,name==="getEnclosureList"));return __compactNodeList(()=>nodes);}})[name];Object.defineProperty(SVGSVGElement.prototype,name,{value,writable:true,enumerable:true,configurable:true});}
})();
'
}
