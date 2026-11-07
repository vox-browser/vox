module main

import css
import dom
import html
import x.json2

// The constraint-validation control of a listed element, with its validity
// flags brought up to date, or none for listed elements that never validate.
fn compact_validation_control(element &dom.Element) ?&html.FormAssociatedElement {
	if !element.is_html_element() { return none }
	match element.local_name() {
		'input' {
			mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
			model.update_validity()
			return model.control
		}
		'textarea' {
			mut model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
			model.update_validity()
			return model.control
		}
		'select' { return html.HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(element) }).control }
		'button' { return html.HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(element) }).control }
		else { return none }
	}
}

fn compact_validity_state(control ?&html.FormAssociatedElement) json2.Any {
	value := control or {
		return json2.Any({
			'willValidate':      json2.Any(false)
			'validationMessage': json2.Any('')
			'flags':             json2.Any([]json2.Any{len: 10, init: json2.Any(false)})
		})
	}
	candidate := value.is_candidate_for_constraint_validation()
	flags := [value.suffering_from_being_missing(), value.suffering_from_a_type_mismatch(),
		value.suffering_from_a_pattern_mismatch(), value.suffering_from_being_too_long(),
		value.suffering_from_being_too_short(), value.suffering_from_an_underflow(),
		value.suffering_from_an_overflow(), value.suffering_from_a_step_mismatch(),
		value.suffering_from_bad_input(), value.suffering_from_a_custom_error()]
	return json2.Any({
		'willValidate':      json2.Any(candidate)
		'validationMessage': json2.Any(value.validation_message())
		'flags':             json2.Any(flags.map(json2.Any(it)))
	})
}

// https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#the-constraint-validation-api
fn (mut binding CompactElementQueryBinding) form_validation_query(key string, source string) !string {
	request := json2.decode[map[string]json2.Any](source)!
	op := json_string_property(request, 'op') or { return error('Invalid validation operation') }
	node := binding.equality_node(key, request['state'] or { json2.Any(json2.Null{}) })!
	element := node.as_element() or { return error('TypeError: Illegal receiver') }
	if element.is_html_element() && element.local_name() == 'form' {
		// The form validates every listed element it owns; their controls
		// join it once their models exist.
		mut valid := true
		for candidate in css.query_selector_all(binding.document.as_node(), 'input, select, textarea, button') {
			control := compact_validation_control(candidate) or { continue }
			owner := control.form() or { continue }
			if voidptr(owner) != voidptr(element) { continue }
			if !control.check_validity_steps() { valid = false }
		}
		return json2.encode({ 'value': json2.Any(valid) })
	}
	mut control := compact_validation_control(element)
	mut result := map[string]json2.Any{}
	match op {
		'state' {}
		'check', 'report' {
			result['value'] = json2.Any(if value := control {
				if op == 'check' { value.check_validity_steps() } else { value.report_validity_steps() }
			} else {
				true
			})
		}
		'setCustomValidity' {
			if mut value := control {
				value.set_custom_validity(json_string_property(request, 'message') or { '' })
			}
		}
		else { return error('Invalid validation operation') }
	}
	result['state'] = compact_validity_state(control)
	return json2.encode(result)
}

fn compact_form_validation_bootstrap() string {
	return r'
(function(){
 const names=["valueMissing","typeMismatch","patternMismatch","tooLong","tooShort","rangeUnderflow","rangeOverflow","stepMismatch","badInput","customError"];
 const owners=new WeakMap(),states=new WeakMap();
 function call(receiver,op,fields){
  const state=__elementApply(__elementRecordGet,__elementRecords,[receiver]);
  if(!state)throw new TypeError("Illegal invocation");
  return __queryElements(state.bridgeKey,"formValidation",JSON.stringify(Object.assign({op,state:state.created?state:undefined},fields||{})),true);
 }
 function ValidityState(){throw new TypeError("Illegal constructor");}
 for(const [index,name] of names.entries())Object.defineProperty(ValidityState.prototype,name,{get(){const owner=owners.get(this);if(!owner)throw new TypeError("Illegal invocation");return call(owner,"state").state.flags[index];},enumerable:true,configurable:true});
 Object.defineProperty(ValidityState.prototype,"valid",{get(){const owner=owners.get(this);if(!owner)throw new TypeError("Illegal invocation");const flags=call(owner,"state").state.flags;return !flags.some(Boolean);},enumerable:true,configurable:true});
 Object.defineProperty(ValidityState.prototype,Symbol.toStringTag,{value:"ValidityState",configurable:true});
 Object.defineProperty(globalThis,"ValidityState",{value:ValidityState,writable:true,configurable:true});
 function validity(element){let state=states.get(element);if(!state){state=Object.create(ValidityState.prototype);owners.set(state,element);states.set(element,state);}return state;}
 const members={
  get validity(){call(this,"state");return validity(this);},
  get willValidate(){return call(this,"state").state.willValidate;},
  get validationMessage(){return call(this,"state").state.validationMessage;},
  checkValidity(){return call(this,"check").value;},
  reportValidity(){return call(this,"report").value;},
  setCustomValidity(error){if(arguments.length<1)throw new TypeError("setCustomValidity requires an argument");if(typeof error==="symbol")throw new TypeError("Cannot convert a Symbol to a string");call(this,"setCustomValidity",{message:String(error)});}
 };
 function install(prototype,list){
  for(const name of list){
   if(Object.prototype.hasOwnProperty.call(prototype,name))continue;
   const descriptor=Object.getOwnPropertyDescriptor(members,name);
   if(typeof descriptor.value==="function")Object.defineProperty(prototype,name,{value:descriptor.value,writable:true,enumerable:true,configurable:true});
   else Object.defineProperty(prototype,name,{get:descriptor.get,enumerable:true,configurable:true});
  }
 }
 const all=Object.keys(members);
 for(const name of ["HTMLInputElement","HTMLTextAreaElement","HTMLSelectElement","HTMLButtonElement","HTMLFieldSetElement","HTMLOutputElement","HTMLObjectElement"])if(typeof globalThis[name]==="function")install(globalThis[name].prototype,all);
 if(typeof globalThis.HTMLFormElement==="function")install(HTMLFormElement.prototype,["checkValidity","reportValidity"]);
})();
'
}
