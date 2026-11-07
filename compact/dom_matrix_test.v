module main

import browserjs
import dom

fn test_compact_dom_matrix_constructs_and_transforms_through_geometry() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><body></body>', dom.URL{
		value: 'https://example.test/'
	}, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const fail=message=>{throw new Error(message);};
const identity=new DOMMatrix();
if(!identity.isIdentity||!identity.is2D||identity.m44!==1||!(identity instanceof DOMMatrixReadOnly))fail("identity");
const parsed=new DOMMatrixReadOnly("scale(2) translateX(5px) translateY(5px)");
if(parsed.a!==2||parsed.e!==10||parsed.f!==10||!parsed.is2D||parsed.isIdentity)fail("string "+parsed.toString());
if(new DOMMatrix([1,0,0,1,7,8]).toString()!=="matrix(1, 0, 0, 1, 7, 8)")fail("serialization");
const sixteen=new DOMMatrix(new Float64Array([2,0,0,0,0,2,0,0,0,0,1,0,10,10,0,1]));
if(sixteen.is2D||sixteen.m41!==10||sixteen.m11!==2)fail("sequence");
if(new DOMMatrix(new DOMMatrix("translate(3px, 4px)")).f!==4)fail("matrix argument");
for(const value of ["translateX(5em)","rotate(5)","inherit",";"]){let threw=false;try{new DOMMatrix(value);}catch(error){threw=error instanceof DOMException&&error.name==="SyntaxError";}if(!threw)fail("syntax "+value);}
let threw=false;try{new DOMMatrix([1,2,3]);}catch(error){threw=error instanceof TypeError;}if(!threw)fail("length");
const moved=identity.translate(5,6);
if(moved.e!==5||moved.f!==6||identity.e!==0||!(moved instanceof DOMMatrix))fail("translate");
identity.scaleSelf(3);if(identity.a!==3||identity.d!==3)fail("scaleSelf");
identity.m13=1;if(identity.is2D)fail("3D component");
const point=new DOMMatrix([1,0,0,1,10,20]).transformPoint({x:1,y:2});
if(!(point instanceof DOMPoint)||point.x!==11||point.y!==22||point.w!==1)fail("transformPoint");
const inverse=new DOMMatrix([2,0,0,2,0,0]).inverse();if(inverse.a!==0.5)fail("inverse");
if(DOMMatrix.fromMatrix({a:4,d:4}).a!==4||!(DOMMatrixReadOnly.fromFloat32Array(new Float32Array([1,0,0,1,2,3])) instanceof DOMMatrixReadOnly))fail("static");
if(Number.isNaN(new DOMMatrix([NaN,0,0,1,0,0]).a)!==true)fail("non-finite");
console.log("dom matrix passed");
'], runtime, mut messages)
	assert messages == ['dom matrix passed'], messages.str()
}
