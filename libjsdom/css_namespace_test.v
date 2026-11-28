// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import css
import html
import libjs

fn css_namespace_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-css-namespace.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000})
}

fn test_css_namespace_exposes_native_identifier_escaping_and_utf16_storage() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert css_namespace_eval(mut vm, r'CSS.escape("3d")==="\\33 d"&&CSS.escape("a.b:c")==="a\\.b\\:c"&&CSS.escape("-")==="\\-"&&CSS.escape("\u0000")==="�"&&CSS.escape("\ud800") === "\ud800"&&CSS.escape("😀9")==="😀9"')!.as_bool()
	assert css_namespace_eval(mut vm, 'Object.prototype.toString.call(CSS)==="[object CSS]"&&CSS.escape.length===1&&CSS.supports.length===1&&Object.getPrototypeOf(CSS)===Object.prototype')!.as_bool()
}

fn test_css_supports_overloads_match_the_native_property_and_condition_parsers() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert css_namespace_eval(mut vm, 'CSS.supports("display","grid")&&CSS.supports("(display: grid)")&&CSS.supports("display: grid")&&!CSS.supports("width","bogus")&&!CSS.supports("fake-property","yes")')!.as_bool()
	for property, value in {'display': 'flex', 'width': '12px', '--custom': 'yes', 'color': 'unknown-color'} {
		expected := css.supports_property(property, value)
		actual := css_namespace_eval(mut vm, 'CSS.supports("${property}","${value}")')!.as_bool()
		assert actual == expected
	}
}

fn test_css_namespace_converts_arguments_in_order_and_preserves_abrupt_values() {
	mut document := html.parse_document('<body></body>')
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert css_namespace_eval(mut vm, 'var log="";var first={toString(){log+="first;";return "display"}},second={toString(){log+="second;";return "grid"}};CSS.supports.call(null,first,second)&&log==="first;second;"')!.as_bool()
	assert css_namespace_eval(mut vm, 'var marker={},same=false;try{CSS.escape({toString(){throw marker}})}catch(e){same=e===marker}same')!.as_bool()
	for source in ['CSS.escape()', 'CSS.supports()', 'CSS.escape(Symbol())', 'CSS.supports(Symbol(),"value")'] {
		css_namespace_eval(mut vm, source) or {
			assert libjs.thrown_value(err).as_object().error_kind()? == .type_error
			continue
		}
		assert false, source
	}
}
