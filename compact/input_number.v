module main

import dom
import html
import math
import x.json2

// HTMLInputElement valueAsNumber, valueAsDate, stepUp() and stepDown()
// through the translated input model.
fn (mut binding CompactElementQueryBinding) input_number_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid input operation') }
	node := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
	element := node.as_element() or { return error('TypeError: Illegal HTMLInputElement receiver') }
	if !element.is_html_element() || element.local_name() != 'input' {
		return error('TypeError: Illegal HTMLInputElement receiver')
	}
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	number := fn (value f64) json2.Any {
		return if math.is_nan(value) { json2.Any(json2.Null{}) } else { json2.Any(value) }
	}
	argument := request['value'] or { json2.Any(json2.Null{}) }
	match op {
		'getNumber' { return json2.encode({ 'value': number(model.value_as_number()) }) }
		'setNumber' {
			model.set_value_as_number(if argument is json2.Null { math.nan() } else { argument.f64() })!
		}
		'getDate' {
			value := model.value_as_date() or { return json2.encode({ 'value': json2.Any(json2.Null{}) }) }
			return json2.encode({ 'value': number(value) })
		}
		'setDate' {
			model.set_value_as_date(if argument is json2.Null { ?f64(none) } else { ?f64(argument.f64()) })!
		}
		'stepUp', 'stepDown' {
			steps := i32(argument.int())
			if op == 'stepUp' { model.step_up(steps)! } else { model.step_down(steps)! }
		}
		else { return error('Invalid input operation') }
	}
	return '{}'
}

fn compact_input_number_bootstrap() string {
	return r'
(function(){
 if(typeof globalThis.HTMLInputElement!=="function")return;
 function fail(error){
  const match=/^([A-Za-z]*Error):\s*(.*)/.exec(String(error&&error.message));
  if(!match)throw error;
  if(match[1]==="TypeError")throw new TypeError(match[2]);
  throw new DOMException(match[2],match[1]);
 }
 function call(receiver,op,value){
  const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
  if(!state)throw new TypeError("Illegal HTMLInputElement receiver");
  try{return __queryElements(state.bridgeKey,"inputNumber",JSON.stringify({op,value,state:state.created?state:undefined}),true);}catch(error){fail(error);}
 }
 function long(value){return value===undefined?1:(Number(value)|0);}
 const members={
  get valueAsNumber(){const value=call(this,"getNumber").value;return value===null?NaN:value;},
  set valueAsNumber(value){const number=Number(value);if(!isFinite(number)&&!Number.isNaN(number))throw new TypeError("The value must not be infinite");call(this,"setNumber",Number.isNaN(number)?null:number);},
  get valueAsDate(){const value=call(this,"getDate").value;return value===null?null:new Date(value);},
  set valueAsDate(value){
   if(value!==null&&!(value instanceof Date))throw new TypeError("The value must be a Date or null");
   const time=value===null?null:value.getTime();
   call(this,"setDate",time===null||Number.isNaN(time)?null:time);
  },
  stepUp(n){call(this,"stepUp",long(n));},
  stepDown(n){call(this,"stepDown",long(n));}
 };
 for(const name of Object.keys(members)){
  if(Object.prototype.hasOwnProperty.call(HTMLInputElement.prototype,name))continue;
  const descriptor=Object.getOwnPropertyDescriptor(members,name);
  if(typeof descriptor.value==="function")Object.defineProperty(HTMLInputElement.prototype,name,{value:descriptor.value,writable:true,enumerable:true,configurable:true});
  else Object.defineProperty(HTMLInputElement.prototype,name,{get:descriptor.get,set:descriptor.set,enumerable:true,configurable:true});
 }
})();
'
}
