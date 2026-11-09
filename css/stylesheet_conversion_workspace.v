module css

import processmetrics
import dom

import platform

// The public token-stream API still owns its input. Whole-sheet parsing can
// instead retire that input after conversion: selectors and query preludes own
// their retained spans, typed values own decoded text, and lazy declarations
// retain source spelling rather than tokenizer trees.
fn parse_css_stylesheet_in_workspace(params ParsingParams, text string, location ?string, media_list ?&MediaList, deferred bool) &CSSStyleSheet {
	load_instruction_stage := processmetrics.begin_instruction_stage('css_parsing')
	defer { load_instruction_stage.finish() }
	// The raw syntax grammar depends on the initial rule context. Only
	// top-level stylesheets share a template; all conversion context is fresh.
	cache_rules := !disable_stylesheet_rule_cache && params.rule_context.len == 0
		&& stylesheet_rule_cache_.eligible(text)
	if cache_rules {
		if entry := stylesheet_rule_cache_.lookup(text) {
			defer { entry.release() }
			mut parser := RuleSelectorParser{
				document: params.document
				mode: params.mode
				value_context: params.value_context.clone()
				rule_context: params.rule_context.clone()
				declared_namespaces: params.declared_namespaces.clone()
				is_ua_style_sheet: params.is_ua_style_sheet
				defer_style_declarations: deferred
				raw_rules_transient: true
				component_input_transient: true
			}
			rules := CSSRuleList.create(parser.convert_rules(entry.rules))
			media := media_list or { MediaList.create_empty() }
			return CSSStyleSheet.create(rules, media, location)
		}
	}
	$if prealloc {
		scratch := platform.begin_thread_scratch('stylesheet conversion input')
		mut parser := RuleSelectorParser{
			token_stream:             stylesheet_conversion_input(text)
			document:                 params.document
			mode:                     params.mode
			value_context:            params.value_context.clone()
			rule_context:             params.rule_context.clone()
			declared_namespaces:      params.declared_namespaces.clone()
			is_ua_style_sheet:        params.is_ua_style_sheet
			defer_style_declarations: deferred
		}
		raw := parser.parse_a_stylesheet(location)
		scratch.leave()
		defer { scratch.finish() }
		if cache_rules { stylesheet_rule_cache_.store(text, raw.rules) }
		parser.raw_rules_transient = true
		parser.component_input_transient = true
		parser.token_stream = ParserTokenStream{}
		parser.value_context = params.value_context.clone()
		parser.rule_context = params.rule_context.clone()
		parser.declared_namespaces = params.declared_namespaces.clone()
		rules := CSSRuleList.create(parser.convert_rules(raw.rules))
		media := if provided := media_list { provided } else { MediaList.create_empty() }
		return CSSStyleSheet.create(rules, media, location)
	}
	mut parser := RuleSelectorParser.create_for_stylesheet(params, text)
	parser.defer_style_declarations = deferred
	if cache_rules {
		raw := parser.parse_a_stylesheet(location)
		stylesheet_rule_cache_.store(text, raw.rules)
		rules := CSSRuleList.create(parser.convert_rules(raw.rules))
		media := media_list or { MediaList.create_empty() }
		return CSSStyleSheet.create(rules, media, location)
	}
	return parser.parse_as_css_stylesheet(location, media_list)
}

fn own_transient_rule_prelude(rule Rule) Rule {
	match rule {
		AtRule {
			name := rule.name.to_lower()
			// Descriptor converters may retain nested component values directly,
			// including function defaults and font-feature declaration lists.
			if name in ['font-face', 'font-feature-values', 'counter-style', 'property', 'function',
				'page', 'keyframes', '-webkit-keyframes'] {
				return own_transient_rule_tree(rule)
			}
			// These grouping converters serialize the prelude or build selectors
			// from independently owned source. Ignored rules retain no prelude.
			if name in ['media', 'supports', 'scope']
				|| (name !in ['container', 'import', 'layer', 'namespace', 'position-try']
					&& !is_margin_rule_name(name)) {
				return rule
			}
			return Rule(AtRule{ ...rule, name: rule.name.clone(), prelude: own_stylesheet_components(rule.prelude) })
		}
		QualifiedRule {
			// Selector conversion serializes its input before constructing the
			// retained selector graph. No component of this prelude escapes.
			return rule
		}
	}
}

fn own_transient_rule_tree(rule Rule) Rule {
	match rule {
		AtRule {
			return Rule(AtRule{
				...rule
				name:                                  rule.name.clone()
				prelude:                               own_stylesheet_components(rule.prelude)
				child_rules_and_lists_of_declarations: own_transient_rule_children(rule.child_rules_and_lists_of_declarations)
			})
		}
		QualifiedRule {
			return Rule(QualifiedRule{
				prelude:      own_stylesheet_components(rule.prelude)
				declarations: own_transient_declarations(rule.declarations)
				child_rules:  own_transient_rule_children(rule.child_rules)
			})
		}
	}
}

fn own_transient_rule_children(children []RuleOrListOfDeclarations) []RuleOrListOfDeclarations {
	mut result := []RuleOrListOfDeclarations{cap: children.len}
	for child in children {
		match child {
			RuleNode {
				result << RuleOrListOfDeclarations(RuleNode{ rule: own_transient_rule_tree(child.rule) })
			}
			DeclarationList {
				result << RuleOrListOfDeclarations(DeclarationList{ declarations: own_transient_declarations(child.declarations) })
			}
		}
	}
	return result
}

fn own_transient_declarations(declarations []Declaration) []Declaration {
	mut result := []Declaration{cap: declarations.len}
	for declaration in declarations {
		result << Declaration{
			...declaration
			name:                declaration.name.clone()
			value:               own_stylesheet_components(declaration.value)
			original_value_text: if text := declaration.original_value_text {
				?string(text.clone())
			} else {
				none
			}
			original_full_text:  if text := declaration.original_full_text {
				?string(text.clone())
			} else {
				none
			}
		}
	}
	return result
}

fn deferred_property_sources(declarations []Declaration) []DeferredPropertySource {
	mut result := []DeferredPropertySource{cap: declarations.len}
	for declaration in declarations {
		result << DeferredPropertySource{
			name:      declaration.name.clone()
			text:      parser_component_values_original_text(declaration.value)
			important: declaration.important
		}
	}
	return result
}

fn (mut parser RuleSelectorParser) convert_source_declarations(sources []DeferredPropertySource) &CSSStyleProperties {
	mut parsed_values := []&dom.StyleValue{}
	if !disable_simple_declaration_value_reuse && css_parsed_value_cache_enabled {
		parsed_values = []&dom.StyleValue{len: sources.len, init: unsafe { nil }}
		params := parser.parsing_params()
		for index, source in sources {
			if value := parse_simple_source_declaration(params, source) { parsed_values[index] = value }
		}
	}
	scratch := platform.begin_thread_scratch('deferred declaration input')
	mut declarations := []Declaration{cap: sources.len}
	for index, source in sources {
		declarations << Declaration{
			name:                source.name
			value:               if index < parsed_values.len && parsed_values[index] != unsafe { nil } { []ComponentValue{} } else { parse_component_values_for_value_logic(source.text) }
			important:           source.important
			original_value_text: source.text
		}
	}
	scratch.leave()
	defer { scratch.finish() }
	parser.raw_rules_transient = true
	parser.component_input_transient = true
	return parser.convert_to_style_declaration_with_values(declarations, parsed_values)
}
