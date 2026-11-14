module css

fn test_probe_sizing_calc_parse() {
	for pair in [['block-size', 'calc(0% + 0%)'], ['height', 'calc(0% + 0%)'], ['height', 'calc(0px + 0em)'], ['scroll-padding-top', 'calc(0% + 0%)'], ['gap', 'calc(0% + 0%)'], ['flex-basis', 'calc(0% + 0%)'], ['border-top-left-radius', 'calc(0% + 0%)'], ['text-indent', 'calc(0px + 0em)'], ['left', 'calc(0% + 0%)']] {
		mut parser := Parser.from_css_text(pair[1])
		property := property_id_from_string(pair[0]) or { panic('p') }
		parsed := parser.parse_css_value(property) or {
			println('${pair} no parse')
			continue
		}
		println('${pair} -> ${parsed.type_()} ${parsed.to_string()}')
	}
}
