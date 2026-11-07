module main

import geometry
import math
import x.json2

// DOMMatrixReadOnly, DOMMatrix, DOMPointReadOnly and DOMPoint over the
// translated Geometry module. Script keeps a matrix's sixteen components; each
// operation rebuilds the native matrix from them and returns the result.
// Non-finite components cross the JSON boundary as strings.
// https://drafts.fxtf.org/geometry/
fn compact_matrix_number(value json2.Any) f64 {
	return match value {
		f64 {
			value
		}
		i64 {
			f64(value)
		}
		int {
			f64(value)
		}
		string {
			match value {
				'NaN' { math.nan() }
				'Infinity' { math.inf(1) }
				'-Infinity' { math.inf(-1) }
				else { value.f64() }
			}
		}
		else {
			0
		}
	}
}

fn compact_matrix_json_number(value f64) json2.Any {
	if math.is_nan(value) {
		return json2.Any('NaN')
	}
	if math.is_inf(value, 1) {
		return json2.Any('Infinity')
	}
	if math.is_inf(value, -1) {
		return json2.Any('-Infinity')
	}
	return json2.Any(value)
}

fn compact_matrix_optional(object map[string]json2.Any, name string) ?f64 {
	value := object[name] or { return none }
	if value is json2.Null {
		return none
	}
	return compact_matrix_number(value)
}

fn compact_matrix_record(matrix &geometry.DOMMatrixReadOnly) json2.Any {
	values := [matrix.m11(), matrix.m12(), matrix.m13(), matrix.m14(), matrix.m21(), matrix.m22(),
		matrix.m23(), matrix.m24(), matrix.m31(), matrix.m32(), matrix.m33(), matrix.m34(),
		matrix.m41(), matrix.m42(), matrix.m43(), matrix.m44()]
	return json2.Any({
		'v':    json2.Any(values.map(compact_matrix_json_number(it)))
		'is2D': json2.Any(matrix.is_2d())
	})
}

fn compact_matrix_from_record(record json2.Any) !&geometry.DOMMatrix {
	if record !is map[string]json2.Any {
		return error('TypeError: Invalid matrix')
	}
	object := record as map[string]json2.Any
	raw := object['v'] or { return error('TypeError: Invalid matrix') }
	if raw !is []json2.Any {
		return error('TypeError: Invalid matrix')
	}
	values := (raw as []json2.Any).map(compact_matrix_number(it))
	if values.len != 16 {
		return error('TypeError: Invalid matrix')
	}
	if is_2d := object['is2D'] {
		if is_2d is bool && is_2d {
			return geometry.DOMMatrix.construct([values[0], values[1], values[4], values[5],
				values[12], values[13]])!
		}
	}
	return geometry.DOMMatrix.construct(values)!
}

fn compact_matrix_init(value json2.Any) geometry.DOMMatrixInit {
	mut init := geometry.DOMMatrixInit{}
	if value !is map[string]json2.Any {
		return init
	}
	object := value as map[string]json2.Any
	init.a = compact_matrix_optional(object, 'a')
	init.b = compact_matrix_optional(object, 'b')
	init.c = compact_matrix_optional(object, 'c')
	init.d = compact_matrix_optional(object, 'd')
	init.e = compact_matrix_optional(object, 'e')
	init.f = compact_matrix_optional(object, 'f')
	init.m11 = compact_matrix_optional(object, 'm11')
	init.m12 = compact_matrix_optional(object, 'm12')
	init.m21 = compact_matrix_optional(object, 'm21')
	init.m22 = compact_matrix_optional(object, 'm22')
	init.m41 = compact_matrix_optional(object, 'm41')
	init.m42 = compact_matrix_optional(object, 'm42')
	init.m13 = compact_matrix_optional(object, 'm13') or { 0 }
	init.m14 = compact_matrix_optional(object, 'm14') or { 0 }
	init.m23 = compact_matrix_optional(object, 'm23') or { 0 }
	init.m24 = compact_matrix_optional(object, 'm24') or { 0 }
	init.m31 = compact_matrix_optional(object, 'm31') or { 0 }
	init.m32 = compact_matrix_optional(object, 'm32') or { 0 }
	init.m33 = compact_matrix_optional(object, 'm33') or { 1 }
	init.m34 = compact_matrix_optional(object, 'm34') or { 0 }
	init.m43 = compact_matrix_optional(object, 'm43') or { 0 }
	init.m44 = compact_matrix_optional(object, 'm44') or { 1 }
	if is_2d := object['is2D'] {
		if is_2d is bool {
			init.is2d = is_2d
		}
	}
	return init
}

fn compact_matrix_argument(arguments []json2.Any, index int) ?f64 {
	if index >= arguments.len || arguments[index] is json2.Null {
		return none
	}
	return compact_matrix_number(arguments[index])
}

fn (mut binding CompactElementQueryBinding) dom_matrix_query(source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('TypeError: Invalid matrix operation') }
	match op {
		'construct' {
			init := request['init'] or { json2.Any(json2.Null{}) }
			matrix := if init is string {
				geometry.DOMMatrix.construct_from_string(init, true)!
			} else if init is []json2.Any {
				geometry.DOMMatrix.construct(init.map(compact_matrix_number(it)))!
			} else {
				geometry.DOMMatrix.create()
			}
			return json2.encode(compact_matrix_record(&matrix.DOMMatrixReadOnly))
		}
		'fromMatrix' {
			mut init := compact_matrix_init(request['other'] or { json2.Any(json2.Null{}) })
			matrix := geometry.DOMMatrix.from_matrix(mut init)!
			return json2.encode(compact_matrix_record(&matrix.DOMMatrixReadOnly))
		}
		'fromArray' {
			values := request['values'] or { json2.Any([]json2.Any{}) }
			numbers := if values is []json2.Any { values.map(compact_matrix_number(it)) } else { []f64{} }
			matrix := geometry.DOMMatrix.from_float64_array(numbers)!
			return json2.encode(compact_matrix_record(&matrix.DOMMatrixReadOnly))
		}
		'method' {}
		else {
			return error('TypeError: Invalid matrix operation')
		}
	}
	mut matrix := compact_matrix_from_record(request['matrix'] or { json2.Any(json2.Null{}) })!
	name := json_string_property(request, 'name') or { '' }
	raw_arguments := request['args'] or { json2.Any([]json2.Any{}) }
	arguments := if raw_arguments is []json2.Any { raw_arguments } else { []json2.Any{} }
	argument := fn [arguments] (index int) ?f64 {
		return compact_matrix_argument(arguments, index)
	}
	if name == 'toString' {
		return json2.encode(matrix.to_string()!)
	}
	if name == 'transformPoint' {
		point_value := request['point'] or { json2.Any(json2.Null{}) }
		mut point := geometry.DOMPointInit{}
		if point_value is map[string]json2.Any {
			point.x = compact_matrix_optional(point_value, 'x') or { 0 }
			point.y = compact_matrix_optional(point_value, 'y') or { 0 }
			point.z = compact_matrix_optional(point_value, 'z') or { 0 }
			point.w = compact_matrix_optional(point_value, 'w') or { 1 }
		}
		transformed := matrix.transform_point_from_init(point)
		return json2.encode({
			'x': compact_matrix_json_number(transformed.x())
			'y': compact_matrix_json_number(transformed.y())
			'z': compact_matrix_json_number(transformed.z())
			'w': compact_matrix_json_number(transformed.w())
		})
	}
	if name !in ['multiply', 'multiplySelf', 'preMultiplySelf', 'translate', 'translateSelf', 'scale',
		'scaleSelf', 'scaleNonUniform', 'scale3d', 'scale3dSelf', 'rotate', 'rotateSelf', 'rotateFromVector',
		'rotateFromVectorSelf', 'rotateAxisAngle', 'rotateAxisAngleSelf', 'skewX', 'skewXSelf', 'skewY',
		'skewYSelf', 'flipX', 'flipY', 'inverse', 'invertSelf', 'setMatrixValue'] {
		return error('TypeError: Invalid matrix operation')
	}
	result := match name {
		'multiply', 'multiplySelf' {
			mut other := compact_matrix_init(request['other'] or { json2.Any(json2.Null{}) })
			matrix.multiply_self(mut other)!
		}
		'preMultiplySelf' {
			mut other := compact_matrix_init(request['other'] or { json2.Any(json2.Null{}) })
			matrix.pre_multiply_self(mut other)!
		}
		'translate', 'translateSelf' {
			matrix.translate_self(argument(0), argument(1), argument(2))
		}
		'scale', 'scaleSelf' {
			matrix.scale_self(argument(0), argument(1), argument(2), argument(3), argument(4),
				argument(5))
		}
		'scaleNonUniform' {
			matrix.scale_non_uniform(argument(0), argument(1))
		}
		'scale3d', 'scale3dSelf' {
			matrix.scale3d_self(argument(0), argument(1), argument(2), argument(3))
		}
		'rotate', 'rotateSelf' {
			matrix.rotate_self(argument(0), argument(1), argument(2))
		}
		'rotateFromVector', 'rotateFromVectorSelf' {
			matrix.rotate_from_vector_self(argument(0), argument(1))
		}
		'rotateAxisAngle', 'rotateAxisAngleSelf' {
			matrix.rotate_axis_angle_self(argument(0), argument(1), argument(2), argument(3))
		}
		'skewX', 'skewXSelf' {
			matrix.skew_x_self(argument(0) or { 0 })
		}
		'skewY', 'skewYSelf' {
			matrix.skew_y_self(argument(0) or { 0 })
		}
		'flipX' {
			matrix.flip_x()
		}
		'flipY' {
			matrix.flip_y()
		}
		'inverse', 'invertSelf' {
			matrix.invert_self()
		}
		'setMatrixValue' {
			matrix.set_matrix_value(json_string_property(request, 'value') or { '' })!
		}
		else {
			geometry.DOMMatrix.create()
		}
	}
	return json2.encode(compact_matrix_record(&result.DOMMatrixReadOnly))
}

fn compact_dom_matrix_bootstrap() string {
	return r'
(function(){
 const records=new WeakMap(),points=new WeakMap(),get=WeakMap.prototype.get,set=WeakMap.prototype.set;
 const enc=value=>Number.isFinite(value)?value:String(value),dec=value=>typeof value==="string"?Number(value):value;
 const number=value=>{if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a number");return Number(value);};
 function call(request){
  try{return __queryElements("","domMatrix",JSON.stringify(request),true);}
  catch(error){
   // The bridge raises a native SyntaxError as a JavaScript SyntaxError; Geometry throws DOMExceptions.
   if(error&&(error.name==="SyntaxError"||error.name==="InvalidStateError")&&!(error instanceof DOMException))throw new DOMException(error.message,error.name);
   const match=/^([A-Za-z]*Error):\s*(.*)/.exec(String(error&&error.message));
   if(match&&match[1]!=="TypeError"&&match[1]!=="Error")throw new DOMException(match[2],match[1]);
   if(error instanceof DOMException)throw error;
   throw new TypeError(match?match[2]:String(error&&error.message));
  }
 }
 function state(receiver){const own=__elementApply(get,records,[receiver]);if(!own)throw new TypeError("Illegal invocation");return own;}
 function adopt(object,record){__elementApply(set,records,[object,{v:record.v.map(dec),is2D:record.is2D}]);return object;}
 function wire(receiver){const own=state(receiver);return {v:own.v.map(enc),is2D:own.is2D};}
 const names=["m11","m12","m13","m14","m21","m22","m23","m24","m31","m32","m33","m34","m41","m42","m43","m44"];
 const aliases={a:0,b:1,c:4,d:5,e:12,f:13};
 const identity=[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1];
 // (DOMString or sequence<unrestricted double>)
 function init(value){
  if(value===undefined)return null;
  if(value!==null&&typeof value==="object"&&typeof value[Symbol.iterator]==="function")return Array.from(value,number).map(enc);
  if(typeof value==="symbol")throw new TypeError("Cannot convert a Symbol to a string");
  return String(value);
 }
 // DOMMatrixInit, read in the lexicographic order WebIDL requires.
 function dictionary(value){
  if(value===undefined||value===null)return {};
  if(typeof value!=="object"&&typeof value!=="function")throw new TypeError("DOMMatrixInit must be an object");
  const out={};
  for(const key of ["a","b","c","d","e","f","is2D","m11","m12","m13","m14","m21","m22","m23","m24","m31","m32","m33","m34","m41","m42","m43","m44"]){
   const member=value[key];if(member===undefined)continue;
   out[key]=key==="is2D"?!!member:enc(number(member));
  }
  return out;
 }
 function DOMMatrixReadOnly(value){
  if(new.target===undefined)throw new TypeError("Constructor DOMMatrixReadOnly requires new");
  return adopt(Object.create(new.target.prototype),call({op:"construct",init:init(value)}));
 }
 function DOMMatrix(value){
  if(new.target===undefined)throw new TypeError("Constructor DOMMatrix requires new");
  return adopt(Object.create(new.target.prototype),call({op:"construct",init:init(value)}));
 }
 Object.setPrototypeOf(DOMMatrix,DOMMatrixReadOnly);
 Object.setPrototypeOf(DOMMatrix.prototype,DOMMatrixReadOnly.prototype);
 const accessor=(name,read,write)=>Object.getOwnPropertyDescriptor({get [name](){return read(this);},set [name](value){write(this,value);}},name);
 for(const [name,index] of [...names.map((name,index)=>[name,index]),...Object.entries(aliases)]){
  const readOnly=accessor(name,receiver=>state(receiver).v[index],()=>{});
  Object.defineProperty(DOMMatrixReadOnly.prototype,name,{get:readOnly.get,enumerable:true,configurable:true});
  const writable=accessor(name,receiver=>state(receiver).v[index],(receiver,value)=>{
   const own=state(receiver),converted=number(value);own.v[index]=converted;
   // A component outside the 2D subset makes the matrix 3D unless it keeps its identity value.
   if([2,3,6,7,8,9,11,14].includes(index)&&!Object.is(converted,0)&&!Object.is(converted,-0))own.is2D=false;
   if((index===10||index===15)&&converted!==1)own.is2D=false;
  });
  Object.defineProperty(DOMMatrix.prototype,name,{get:writable.get,set:writable.set,enumerable:true,configurable:true});
 }
 Object.defineProperty(DOMMatrixReadOnly.prototype,"is2D",{get:Object.getOwnPropertyDescriptor({get is2D(){return state(this).is2D;}},"is2D").get,enumerable:true,configurable:true});
 Object.defineProperty(DOMMatrixReadOnly.prototype,"isIdentity",{get:Object.getOwnPropertyDescriptor({get isIdentity(){return state(this).v.every((value,index)=>value===identity[index]);}},"isIdentity").get,enumerable:true,configurable:true});
 const method=(name,body)=>({[name](...args){return body.apply(this,args);}})[name];
 const define=(target,name,body,length)=>{const value=method(name,body);Object.defineProperty(value,"length",{value:length});Object.defineProperty(target,name,{value,writable:true,enumerable:true,configurable:true});};
 const optional=args=>args.map(value=>value===undefined?null:enc(number(value)));
 for(const [name,length] of [["translate",0],["scale",0],["scaleNonUniform",0],["scale3d",0],["rotate",0],["rotateFromVector",0],["rotateAxisAngle",0],["skewX",0],["skewY",0],["flipX",0],["flipY",0],["inverse",0]])
  define(DOMMatrixReadOnly.prototype,name,function(...args){return adopt(Object.create(DOMMatrix.prototype),call({op:"method",name,matrix:wire(this),args:optional(args)}));},length);
 define(DOMMatrixReadOnly.prototype,"multiply",function(other){return adopt(Object.create(DOMMatrix.prototype),call({op:"method",name:"multiply",matrix:wire(this),other:dictionary(other)}));},0);
 define(DOMMatrixReadOnly.prototype,"transformPoint",function(point){
  const own=wire(this),source=point===undefined||point===null?{}:point;
  if(typeof source!=="object"&&typeof source!=="function")throw new TypeError("DOMPointInit must be an object");
  const values={};for(const key of ["w","x","y","z"]){const member=source[key];if(member!==undefined)values[key]=enc(number(member));}
  const result=call({op:"method",name:"transformPoint",matrix:own,point:values});
  return new DOMPoint(dec(result.x),dec(result.y),dec(result.z),dec(result.w));
 },0);
 define(DOMMatrixReadOnly.prototype,"toFloat32Array",function(){return new Float32Array(state(this).v);},0);
 define(DOMMatrixReadOnly.prototype,"toFloat64Array",function(){return new Float64Array(state(this).v);},0);
 define(DOMMatrixReadOnly.prototype,"toJSON",function(){
  const own=state(this),result={};
  for(const [name,index] of Object.entries(aliases))result[name]=own.v[index];
  names.forEach((name,index)=>{result[name]=own.v[index];});
  result.is2D=own.is2D;result.isIdentity=this.isIdentity;return result;
 },0);
 define(DOMMatrixReadOnly.prototype,"toString",function(){return call({op:"method",name:"toString",matrix:wire(this)});},0);
 for(const name of ["multiplySelf","preMultiplySelf"])
  define(DOMMatrix.prototype,name,function(other){const record=call({op:"method",name,matrix:wire(this),other:dictionary(other)});adopt(this,record);return this;},0);
 for(const name of ["translateSelf","scaleSelf","scale3dSelf","rotateSelf","rotateFromVectorSelf","rotateAxisAngleSelf","skewXSelf","skewYSelf","invertSelf"])
  define(DOMMatrix.prototype,name,function(...args){const record=call({op:"method",name,matrix:wire(this),args:optional(args)});adopt(this,record);return this;},0);
 define(DOMMatrix.prototype,"setMatrixValue",function(value){if(arguments.length<1)throw new TypeError("setMatrixValue requires an argument");const record=call({op:"method",name:"setMatrixValue",matrix:wire(this),value:String(value)});adopt(this,record);return this;},1);
 for(const constructor of [DOMMatrixReadOnly,DOMMatrix]){
  define(constructor,"fromMatrix",function(other){return adopt(Object.create(constructor.prototype),call({op:"fromMatrix",other:dictionary(other)}));},0);
  for(const [name,type] of [["fromFloat32Array",Float32Array],["fromFloat64Array",Float64Array]])
   define(constructor,name,function(array){if(!(array instanceof type))throw new TypeError(name+" requires a "+type.name);return adopt(Object.create(constructor.prototype),call({op:"fromArray",values:Array.from(array).map(enc)}));},1);
 }
 // https://drafts.fxtf.org/geometry/#DOMPoint
 function pointState(receiver){const own=__elementApply(get,points,[receiver]);if(!own)throw new TypeError("Illegal invocation");return own;}
 function DOMPointReadOnly(x,y,z,w){
  if(new.target===undefined)throw new TypeError("Constructor DOMPointReadOnly requires new");
  const object=Object.create(new.target.prototype);
  __elementApply(set,points,[object,{x:x===undefined?0:number(x),y:y===undefined?0:number(y),z:z===undefined?0:number(z),w:w===undefined?1:number(w)}]);
  return object;
 }
 function DOMPoint(x,y,z,w){
  if(new.target===undefined)throw new TypeError("Constructor DOMPoint requires new");
  return Reflect.construct(DOMPointReadOnly,[x,y,z,w],new.target);
 }
 Object.setPrototypeOf(DOMPoint,DOMPointReadOnly);
 Object.setPrototypeOf(DOMPoint.prototype,DOMPointReadOnly.prototype);
 for(const name of ["x","y","z","w"]){
  Object.defineProperty(DOMPointReadOnly.prototype,name,{get:accessor(name,receiver=>pointState(receiver)[name],()=>{}).get,enumerable:true,configurable:true});
  const writable=accessor(name,receiver=>pointState(receiver)[name],(receiver,value)=>{pointState(receiver)[name]=number(value);});
  Object.defineProperty(DOMPoint.prototype,name,{get:writable.get,set:writable.set,enumerable:true,configurable:true});
 }
 define(DOMPointReadOnly.prototype,"matrixTransform",function(matrix){const own=pointState(this);return DOMMatrix.fromMatrix(matrix).transformPoint(own);},0);
 define(DOMPointReadOnly.prototype,"toJSON",function(){const own=pointState(this);return {x:own.x,y:own.y,z:own.z,w:own.w};},0);
 for(const constructor of [DOMPointReadOnly,DOMPoint])define(constructor,"fromPoint",function(other){const source=other==null?{}:other;return new constructor(source.x,source.y,source.z,source.w);},0);
 for(const [constructor,name] of [[DOMMatrixReadOnly,"DOMMatrixReadOnly"],[DOMMatrix,"DOMMatrix"],[DOMPointReadOnly,"DOMPointReadOnly"],[DOMPoint,"DOMPoint"]]){
  Object.defineProperty(constructor,"prototype",{writable:false});
  Object.defineProperty(constructor.prototype,Symbol.toStringTag,{value:name,configurable:true});
  if(typeof globalThis[name]!=="function")Object.defineProperty(globalThis,name,{value:constructor,writable:true,configurable:true});
 }
 // https://drafts.fxtf.org/geometry/#WebKitCSSMatrix
 if(typeof globalThis.WebKitCSSMatrix!=="function")Object.defineProperty(globalThis,"WebKitCSSMatrix",{value:DOMMatrix,writable:true,configurable:true});
})();
'
}
