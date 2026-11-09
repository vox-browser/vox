module main

import browserjs
import dom

fn test_svg_geometry_queries_use_computed_shapes_inside_hidden_content() {
	mut document := parse_browser_navigation_document('<!doctype html><style>#hidden{content-visibility:hidden}path,rect{stroke:green;stroke-width:5px}</style><div id="hidden"><svg id="root"><path id="path" d="M5 5 L10 5 L10 10 L5 10 Z"/><rect id="rect" x="5" y="5" width="10" height="10"/></svg></div>',dom.URL{value:'https://svg-geometry.test/'},none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,document.url.serialize(),[r'
for(const id of ["path","rect"]){
 const element=document.getElementById(id);
 if(element.getTotalLength()!==(id==="path"?20:40))throw new Error("length "+id);
 const first=element.getPointAtLength(0);if(first.x!==5||first.y!==5)throw new Error("first "+id);
 if(!element.isPointInFill({x:7,y:7})||!element.isPointInStroke({x:7,y:7}))throw new Error("inside "+id);
 if(element.isPointInFill({x:70,y:70})||element.isPointInStroke({x:70,y:70}))throw new Error("outside "+id);
 const bounds=element.getBBox();if(bounds.x!==5||bounds.y!==5||bounds.width!==(id==="path"?5:10))throw new Error("bounds "+id);
}
const region={x:10,y:10,width:50,height:50},enclosure={x:0,y:0,width:50,height:50};
if(!root.checkIntersection(path,region)||!root.checkEnclosure(path,enclosure)||root.checkEnclosure(path,{x:5,y:5,width:5,height:5}))throw new Error("region geometry");
const hits=root.getIntersectionList(region,null);if(!(hits instanceof NodeList)||!Array.from(hits).includes(path))throw new Error("intersection list");
if(!Array.from(root.getEnclosureList(enclosure,null)).includes(rect)||root.getEnclosureList(enclosure,path).length!==0)throw new Error("enclosure/reference list");
rect.setAttribute("transform","translate(100 0)");if(root.checkIntersection(rect,enclosure)||!root.checkEnclosure(rect,{x:100,y:0,width:50,height:50}))throw new Error("region transform");
if(hits.length!==2)throw new Error("list must be static");
let getters=0;if(path.isPointInFill({get x(){getters++;return Infinity;},y:7})||getters!==1)throw new Error("point conversion");
let converted=false,branded=false;try{SVGGeometryElement.prototype.getPointAtLength.call({}, {valueOf(){converted=true;return 0;}});}catch(e){branded=e instanceof TypeError;}if(!branded||converted)throw new Error("brand ordering");
path.setAttribute("d","M10 20 L40 20");if(path.getTotalLength()!==30||path.getPointAtLength(15).x!==25)throw new Error("live shape");
globalThis.svgGeometryPassed=true;
'],runtime,mut messages)
	assert messages == []string{},messages.str()
	assert runtime.evaluate_host('svgGeometryPassed')! == 'true'
}
