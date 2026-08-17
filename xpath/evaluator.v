// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XPath.cpp, XPathEvaluator, XPathExpression and
// XPathNSResolver. The native libxml evaluator boundary is represented by a
// typed evaluator over the translated DOM tree.
module xpath

import dom
import math
import strconv

pub type NamespaceResolver = fn (string) ?string

@[heap]
pub struct XPathEvaluator {}

pub fn XPathEvaluator.construct() &XPathEvaluator {
	return &XPathEvaluator{}
}

@[heap]
pub struct XPathExpression {
pub:
	expression string
	resolver   ?NamespaceResolver
}

pub fn (evaluator &XPathEvaluator) create_expression(expression string, resolver ?NamespaceResolver) !&XPathExpression {
	_ = evaluator
	// Current upstream stores the source and resolver here; libxml compilation
	// (and therefore SyntaxError) occurs only when evaluate() is called.
	return &XPathExpression{expression, resolver}
}

pub fn (evaluator &XPathEvaluator) create_ns_resolver(node &dom.Node) &dom.Node {
	_ = evaluator
	return node
}

pub fn (evaluator &XPathEvaluator) evaluate(expression string, context &dom.Node, resolver ?NamespaceResolver, requested ResultType, reusable ?&XPathResult) !&XPathResult {
	compiled := evaluator.create_expression(expression, resolver)!
	return compiled.evaluate(context, requested, reusable)
}

pub fn (expression &XPathExpression) evaluate(context &dom.Node, requested ResultType, reusable ?&XPathResult) !&XPathResult {
	mut result := reusable or { &XPathResult{} }
	evaluate_into(expression.expression, context, requested, mut result)!
	return result
}

fn validate_expression(expression string) ! {
	value := expression.trim_space()
	if value == '' {
		return error('SyntaxError: Invalid XPath expression')
	}
	mut parentheses := 0
	mut brackets := 0
	mut quote := u8(0)
	for character in value.bytes() {
		if quote != 0 {
			if character == quote {
				quote = 0
			}
			continue
		}
		if character in [`'`, `"`] {
			quote = character
		} else if character == `(` {
			parentheses++
		} else if character == `)` {
			parentheses--
		} else if character == `[` {
			brackets++
		} else if character == `]` {
			brackets--
		}
		if parentheses < 0 || brackets < 0 {
			return error('SyntaxError: Invalid XPath expression')
		}
	}
	if quote != 0 || parentheses != 0 || brackets != 0 || value.ends_with('/') {
		return error('SyntaxError: Invalid XPath expression')
	}
}

fn evaluate_into(expression string, context &dom.Node, requested ResultType, mut result XPathResult) ! {
	validate_expression(expression)!
	value := expression.trim_space()
	if value.len >= 2 && value[0] in [`'`, `"`] && value[value.len - 1] == value[0] {
		result.result_type = .string
		result.string_value = value[1..value.len - 1]
		return
	}
	if value == 'true()' || value == 'false()' {
		result.result_type = .boolean
		result.boolean_value = value == 'true()'
		return
	}
	for function_name in ['count', 'string', 'boolean', 'number'] {
		prefix := '${function_name}('
		if value.starts_with(prefix) && value.ends_with(')') {
			argument := value[prefix.len..value.len - 1]
			nodes, scalar := evaluate_path(argument, context)!
			match function_name {
				'count' {
					result.result_type = .number
					result.number_value = f64(nodes.len)
				}
				'boolean' {
					result.result_type = .boolean
					result.boolean_value = nodes.len > 0 || scalar != ''
				}
				'string' {
					result.result_type = .string
					result.string_value = first_string_value(nodes, scalar)
				}
				'number' {
					result.result_type = .number
					result.number_value = strconv.atof64(first_string_value(nodes, scalar)) or {
						math.nan()
					}
				}
				else {}
			}
			return
		}
	}
	if numeric := strconv.atof64(value) {
		result.result_type = .number
		result.number_value = numeric
		return
	}
	nodes, _ := evaluate_path(value, context)!
	// The current native conversion only uses `requested` to choose a node-set
	// result flavor; it does not coerce a node-set into a scalar XPath value.
	result.set_nodes(nodes, requested)
}

fn first_string_value(nodes []&dom.Node, scalar string) string {
	if scalar != '' {
		return scalar
	}
	if nodes.len == 0 {
		return ''
	}
	return nodes[0].text_content() or { '' }
}

struct Step {
	name       string
	descendant bool
	predicate  string
}

fn split_steps(path string) ![]Step {
	mut steps := []Step{}
	mut start := 0
	mut bracket_depth := 0
	mut descendant := false
	mut position := 0
	for position < path.len {
		if path[position] == `[` {
			bracket_depth++
		} else if path[position] == `]` {
			bracket_depth--
		} else if path[position] == `/` && bracket_depth == 0 {
			if position > start {
				steps << parse_step(path[start..position], descendant)!
			}
			descendant = position + 1 < path.len && path[position + 1] == `/`
			if descendant {
				position++
			}
			start = position + 1
		}
		position++
	}
	if start < path.len {
		steps << parse_step(path[start..], descendant)!
	}
	return steps
}

fn parse_step(raw string, descendant bool) !Step {
	part := raw.trim_space()
	if part == '' {
		return error('SyntaxError: empty XPath step')
	}
	if open := part.index('[') {
		if !part.ends_with(']') {
			return error('SyntaxError: malformed XPath predicate')
		}
		return Step{part[..open], descendant, part[open + 1..part.len - 1]}
	}
	return Step{part, descendant, ''}
}

fn evaluate_path(path string, context &dom.Node) !([]&dom.Node, string) {
	trimmed := path.trim_space()
	effective_context := if document := context.as_document() {
		root := document.document_element() or {
			return error('OperationError: XPath evaluation failed')
		}
		root.as_node()
	} else {
		context
	}
	if trimmed == '.' {
		return [effective_context], ''
	}
	if trimmed == '' {
		return error('SyntaxError: empty XPath path')
	}
	mut roots := [effective_context]
	mut actual := trimmed
	mut leading_absolute_descendant := false
	mut leading_relative_descendant := false
	mut absolute := false
	if actual.starts_with('//') {
		leading_absolute_descendant = true
		actual = actual[2..]
	} else if actual.starts_with('.//') {
		leading_relative_descendant = true
		actual = actual[3..]
	} else if actual.starts_with('/') {
		absolute = true
		actual = actual.trim_left('/')
	}
	steps := split_steps(actual)!
	mut current := roots.clone()
	mut scalar := ''
	for step_index, step in steps {
		if step.name.starts_with('@') {
			if step_index != steps.len - 1 {
				return error('SyntaxError: attribute axis must be terminal')
			}
			name := step.name[1..]
			for node in current {
				if element := node.as_element() {
					if attribute := element.get_attribute(name) {
						scalar = attribute
						break
					}
				}
			}
			return []&dom.Node{}, scalar
		}
		mut candidates := []&dom.Node{}
		for node in current {
			if step_index == 0 && absolute {
				candidates << node
			} else if step_index == 0 && leading_absolute_descendant {
				candidates << node
				collect_descendants(node, mut candidates)
			} else if step.descendant || (step_index == 0 && leading_relative_descendant) {
				collect_descendants(node, mut candidates)
			} else {
				candidates << node.children_as_vector()
			}
		}
		mut matched := candidates.filter(node_matches_step(it, step.name))
		matched = apply_predicate(matched, step.predicate)!
		current = matched.clone()
	}
	return current, scalar
}

fn collect_descendants(node &dom.Node, mut output []&dom.Node) {
	for child in node.children_as_vector() {
		output << child
		collect_descendants(child, mut output)
	}
}

fn node_matches_step(node &dom.Node, name string) bool {
	if name == 'node()' {
		return true
	}
	if name == 'text()' {
		return node.is_text()
	}
	element := node.as_element() or { return false }
	if name == '*' {
		return true
	}
	// XPathNSResolver is retained by the bindings but the current upstream
	// libxml context does not register it. A prefixed test therefore cannot
	// match, while unprefixed tests see the mirrored local name.
	if name.contains(':') {
		return false
	}
	return element.local_name() == name
}

fn apply_predicate(nodes []&dom.Node, predicate string) ![]&dom.Node {
	value := predicate.trim_space()
	if value == '' {
		return nodes
	}
	if index := strconv.atoi(value) {
		if index <= 0 || index > nodes.len {
			return []&dom.Node{}
		}
		return [nodes[index - 1]]
	}
	if value == 'last()' {
		if nodes.len == 0 {
			return []&dom.Node{}
		}
		return [nodes.last()]
	}
	if value.starts_with('@') {
		condition := value[1..]
		mut filtered := []&dom.Node{}
		if equals := condition.index('=') {
			name := condition[..equals].trim_space()
			expected := condition[equals + 1..].trim_space().trim('\'"')
			for node in nodes {
				element := node.as_element() or { continue }
				if element.get_attribute(name) or { continue } == expected {
					filtered << node
				}
			}
			return filtered
		}
		for node in nodes {
			element := node.as_element() or { continue }
			if element.has_attribute(condition) {
				filtered << node
			}
		}
		return filtered
	}
	return error('SyntaxError: unsupported XPath predicate')
}
