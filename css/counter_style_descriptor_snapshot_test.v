module css

import dom

fn test_counter_style_descriptor_reads_keep_snapshots_across_rule_mutation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	sheet :=
		parse_css_stylesheet_with_parser('@counter-style descriptor-probe {system:fixed 2;symbols:"A" "B";negative:"(" ")";prefix:"[";suffix:"]";range:2 3;pad:3 "0";fallback:decimal;speak-as:words}', none)
	mut rule := sheet.rules.rules[0].counter_style_rule_value() or { panic('missing rule') }
	context := ComputationContext{
		length_resolution_context: LengthResolutionContext.for_document(document)
	}
	original := CounterStyleDefinition.from_counter_style_rule(rule, context) or {
		panic('missing definition')
	}
	assert rule.name() == 'descriptor-probe'
	assert rule.system() == 'fixed 2'
	assert rule.negative() == '"(" ")"'
	assert rule.prefix() == '"["'
	assert rule.suffix() == '"]"'
	assert rule.range() == '2 3'
	assert rule.pad() == '3 "0"'
	assert rule.fallback() == 'decimal'
	assert rule.symbols() == '"A" "B"'
	assert rule.additive_symbols() == ''
	assert rule.speak_as() == 'words'
	assert rule.serialized().contains('symbols: "A" "B";')
	symbols := rule.symbols_style_value() or { panic('symbols') }
	system := rule.system_style_value() or { panic('system') }
	negative := rule.negative_style_value() or { panic('negative') }
	prefix := rule.prefix_style_value() or { panic('prefix') }
	suffix := rule.suffix_style_value() or { panic('suffix') }
	range := rule.range_style_value() or { panic('range') }
	pad := rule.pad_style_value() or { panic('pad') }
	fallback := rule.fallback_style_value() or { panic('fallback') }
	speak_as := rule.speak_as_style_value() or { panic('speak-as') }
	assert rule.additive_symbols_style_value() == none
	rule.set_system('fixed 5')
	rule.set_symbols('"C" "D"')
	rule.set_negative('"-"')
	rule.set_prefix('"{"')
	rule.set_suffix('"}"')
	rule.set_range('5 6')
	rule.set_pad('4 "x"')
	rule.set_fallback('disc')
	rule.set_speak_as('bullets')
	rule.set_name('after-mutation')
	gc_collect()
	assert symbols.serialize(.normal) == '"A" "B"'
	assert system.serialize(.normal) == 'fixed 2'
	assert negative.serialize(.normal) == '"(" ")"'
	assert prefix.serialize(.normal) == '"["'
	assert suffix.serialize(.normal) == '"]"'
	assert range.serialize(.normal) == '2 3'
	assert pad.serialize(.normal) == '3 "0"'
	assert fallback.serialize(.normal) == 'decimal'
	assert speak_as.serialize(.normal) == 'words'
	assert original.name() == 'descriptor-probe'
	changed := CounterStyleDefinition.from_counter_style_rule(rule, context) or {
		panic('changed definition')
	}
	assert changed.name() == 'after-mutation'
	assert (original.prefix() or { panic('original prefix') }) == '['
	assert (changed.prefix() or { panic('changed prefix') }) == '{'
	assert (original.suffix() or { panic('original suffix') }) == ']'
	assert (changed.suffix() or { panic('changed suffix') }) == '}'
	assert rule.serialized().contains('symbols: "C" "D";')
}

fn test_counter_style_additive_descriptor_snapshot_and_value_receiver_call() {
	sheet :=
		parse_css_stylesheet_with_parser('@counter-style additive-probe {system:additive;additive-symbols:10 "X",1 "I"}', none)
	mut rule := sheet.rules.rules[0].counter_style_rule_value() or { panic('missing rule') }
	original := rule.additive_symbols_style_value() or { panic('additive symbols') }
	value_copy := *rule
	assert value_copy.name() == 'additive-probe'
	assert value_copy.additive_symbols() == '10 "X", 1 "I"'
	assert value_copy.system() == 'additive'
	rule.set_additive_symbols('10 "Z", 1 "J"')
	gc_collect()
	assert original.serialize(.normal) == '10 "X", 1 "I"'
	assert value_copy.additive_symbols() == '10 "X", 1 "I"'
	assert rule.additive_symbols() == '10 "Z", 1 "J"'
}
