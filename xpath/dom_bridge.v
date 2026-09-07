// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Connect XPath's evaluator to Document without introducing a DOM -> XPath
// package cycle. The wrapper retains the compiled expression/result identity
// needed by the WebIDL-facing DOM types.
module xpath

import dom

fn checked_result_type(value u16) !ResultType {
	if value > u16(ResultType.first_ordered_node) {
		return error('TypeError: Invalid XPathResult type ${value}')
	}
	return unsafe { ResultType(value) }
}

fn namespace_resolver_from_dom(resolver ?&dom.XPathNSResolver) ?NamespaceResolver {
	dom_resolver := resolver or { return none }
	return dom_resolver.callback()
}

fn wrap_xpath_result(result &XPathResult, reusable ?&dom.XPathResult) &dom.XPathResult {
	wrapped_pointer := reusable or { &dom.XPathResult{} }
	mut wrapped := unsafe { &dom.XPathResult(wrapped_pointer) }
	unsafe {
		wrapped.target = voidptr(result)
	}
	wrapped.result_type_ = unsafe { dom.XPathResultType(u16(result.result_type())) }
	wrapped.number_value_ = result.number_value()
	wrapped.string_value_ = result.string_value()
	wrapped.boolean_value_ = result.boolean_value()
	wrapped.invalid_iterator_state_ = result.invalid_iterator_state()
	wrapped.nodes.clear()
	for index in 0 .. int(result.snapshot_length()) {
		if node := result.snapshot_item(index) {
			wrapped.nodes << node
		}
	}
	wrapped.iterator_index = 0
	return wrapped
}

fn reusable_xpath_result(result ?&dom.XPathResult) ?&XPathResult {
	dom_result := result or { return none }
	if dom_result.target == unsafe { nil } {
		return none
	}
	return unsafe { &XPathResult(dom_result.target) }
}

fn evaluate_dom_xpath_expression(target voidptr, context &dom.Node, type_ u16, reusable ?&dom.XPathResult) !&dom.XPathResult {
	if target == unsafe { nil } {
		return error('InvalidStateError: XPath expression has no evaluator')
	}
	expression := unsafe { &XPathExpression(target) }
	result := expression.evaluate(context, checked_result_type(type_)!, reusable_xpath_result(reusable))!
	return wrap_xpath_result(result, reusable)
}

fn create_dom_xpath_expression(source string, resolver ?&dom.XPathNSResolver) !&dom.XPathExpression {
	evaluator := XPathEvaluator.construct()
	expression := evaluator.create_expression(source, namespace_resolver_from_dom(resolver))!
	return &dom.XPathExpression{
		target:            voidptr(expression)
		expression:        source
		evaluate_callback: evaluate_dom_xpath_expression
	}
}

fn evaluate_dom_xpath(source string, context &dom.Node, resolver ?&dom.XPathNSResolver, type_ u16, reusable ?&dom.XPathResult) !&dom.XPathResult {
	evaluator := XPathEvaluator.construct()
	result := evaluator.evaluate(source, context, namespace_resolver_from_dom(resolver), checked_result_type(type_)!, reusable_xpath_result(reusable))!
	return wrap_xpath_result(result, reusable)
}

pub fn install_dom_xpath_bridge() {
	dom.install_xpath_bridge(create_dom_xpath_expression, evaluate_dom_xpath)
}
