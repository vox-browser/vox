module css

import dom
import os

fn test_github20_bucket_shape_workload() {
	mut document := dom.Document.create(dom.URL{value:'https://github.com/vlang/v'})
	document.set_document_type(.html)
	document.set_font_rendering_policy(.chromium)
	document.set_viewport_rect(dom.Rect{0,0,1024,768})
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	mut root := document.create_element('html') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut seen := map[string]bool{}
	for path in os.read_lines('Build/github-20-instr/stylesheets.txt') or { panic(err) } {
		if seen[path] { continue }
		seen[path] = true
		add_document_author_style_sheet(document, os.read_file(path) or { panic(err) })
	}
	mut scope := css_style_scope_for_document(document)
	scope.build_rule_cache_if_needed()
	computer := css_style_computer_for(document)
	cache := computer.rule_cache_for_cascade_origin(.author, none, none) or { panic('author cache') }
	mut disjunctions := 0
	mut eligible := 0
	for rule in cache.other_rules {
		compounds := rule.selector.compound_selectors()
		if compounds.len == 0 { continue }
		for simple in compounds[compounds.len - 1].simple_selectors {
			if simple.type_ != .pseudo_class { continue }
			pseudo := simple.pseudo_class()
			if pseudo.type_ !in [.is_, .where] || pseudo.argument_selector_list.selectors.len < 2 { continue }
			disjunctions++
			mut covered := true
			for alternative in pseudo.argument_selector_list.selectors {
				parts := alternative.compound_selectors()
				mut found := false
				if parts.len > 0 {
					for candidate in parts[parts.len - 1].simple_selectors {
						if subject_bucket_name(candidate) != none { found = true; break }
					}
				}
				if !found { covered = false; break }
			}
			if covered { eligible++ }
			eprintln('BUCKET disjunction eligible=${covered} ${rule.selector.text()}')
			break
		}
	}
	eprintln('BUCKET other=${cache.other_rules.len} disjunctions=${disjunctions} eligible=${eligible} classes=${cache.rules_by_class.len} tags=${cache.rules_by_tag_name.len}')
	owner.finish()
	document.finalize()
}
