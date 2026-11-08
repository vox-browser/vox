module html

import dom

// Foreign (SVG / MathML) content handling for the tree-construction parser, translated from
// HTMLParser.cpp: the tree-construction dispatcher's foreign branch, the integration-point
// predicates, the MathML/SVG attribute and tag-name adjustments, and
// process_using_the_rules_for_foreign_content.
// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inforeign
const ns_xlink = 'http://www.w3.org/1999/xlink'
const ns_xml = 'http://www.w3.org/XML/1998/namespace'
const ns_xmlns = 'http://www.w3.org/2000/xmlns/'

// https://html.spec.whatwg.org/multipage/parsing.html#mathml-text-integration-point
// NOTE: mirrors the C++ which checks the local name only (no HTML element has these names).
fn is_mathml_text_integration_point(element &dom.Element) bool {
	return element.local_name() in ['mi', 'mo', 'mn', 'ms', 'mtext']
}

// https://html.spec.whatwg.org/multipage/parsing.html#html-integration-point
fn is_html_integration_point(element &dom.Element) bool {
	if element_in_namespace(element, ns_mathml) && element.local_name() == 'annotation-xml' {
		if encoding := element.get_attribute('encoding') {
			enc := encoding.to_lower()
			if enc == 'text/html' || enc == 'application/xhtml+xml' {
				return true
			}
		}
	}
	if element_in_namespace(element, ns_svg) && element.local_name() in [
		'foreignObject',
		'desc',
		'title',
	] {
		return true
	}
	return false
}

const svg_tag_name_adjustments = {
	'altglyph':            'altGlyph'
	'altglyphdef':         'altGlyphDef'
	'altglyphitem':        'altGlyphItem'
	'animatecolor':        'animateColor'
	'animatemotion':       'animateMotion'
	'animatetransform':    'animateTransform'
	'clippath':            'clipPath'
	'feblend':             'feBlend'
	'fecolormatrix':       'feColorMatrix'
	'fecomponenttransfer': 'feComponentTransfer'
	'fecomposite':         'feComposite'
	'feconvolvematrix':    'feConvolveMatrix'
	'fediffuselighting':   'feDiffuseLighting'
	'fedisplacementmap':   'feDisplacementMap'
	'fedistantlight':      'feDistantLight'
	'fedropshadow':        'feDropShadow'
	'feflood':             'feFlood'
	'fefunca':             'feFuncA'
	'fefuncb':             'feFuncB'
	'fefuncg':             'feFuncG'
	'fefuncr':             'feFuncR'
	'fegaussianblur':      'feGaussianBlur'
	'feimage':             'feImage'
	'femerge':             'feMerge'
	'femergenode':         'feMergeNode'
	'femorphology':        'feMorphology'
	'feoffset':            'feOffset'
	'fepointlight':        'fePointLight'
	'fespecularlighting':  'feSpecularLighting'
	'fespotlight':         'feSpotLight'
	'fetile':              'feTile'
	'feturbulence':        'feTurbulence'
	'foreignobject':       'foreignObject'
	'glyphref':            'glyphRef'
	'lineargradient':      'linearGradient'
	'radialgradient':      'radialGradient'
	'textpath':            'textPath'
}

const svg_attribute_adjustments = {
	'attributename':       'attributeName'
	'attributetype':       'attributeType'
	'basefrequency':       'baseFrequency'
	'baseprofile':         'baseProfile'
	'calcmode':            'calcMode'
	'clippathunits':       'clipPathUnits'
	'diffuseconstant':     'diffuseConstant'
	'edgemode':            'edgeMode'
	'filterunits':         'filterUnits'
	'glyphref':            'glyphRef'
	'gradienttransform':   'gradientTransform'
	'gradientunits':       'gradientUnits'
	'kernelmatrix':        'kernelMatrix'
	'kernelunitlength':    'kernelUnitLength'
	'keypoints':           'keyPoints'
	'keysplines':          'keySplines'
	'keytimes':            'keyTimes'
	'lengthadjust':        'lengthAdjust'
	'limitingconeangle':   'limitingConeAngle'
	'markerheight':        'markerHeight'
	'markerunits':         'markerUnits'
	'markerwidth':         'markerWidth'
	'maskcontentunits':    'maskContentUnits'
	'maskunits':           'maskUnits'
	'numoctaves':          'numOctaves'
	'pathlength':          'pathLength'
	'patterncontentunits': 'patternContentUnits'
	'patterntransform':    'patternTransform'
	'patternunits':        'patternUnits'
	'pointsatx':           'pointsAtX'
	'pointsaty':           'pointsAtY'
	'pointsatz':           'pointsAtZ'
	'preservealpha':       'preserveAlpha'
	'preserveaspectratio': 'preserveAspectRatio'
	'primitiveunits':      'primitiveUnits'
	'refx':                'refX'
	'refy':                'refY'
	'repeatcount':         'repeatCount'
	'repeatdur':           'repeatDur'
	'requiredextensions':  'requiredExtensions'
	'requiredfeatures':    'requiredFeatures'
	'specularconstant':    'specularConstant'
	'specularexponent':    'specularExponent'
	'spreadmethod':        'spreadMethod'
	'startoffset':         'startOffset'
	'stddeviation':        'stdDeviation'
	'stitchtiles':         'stitchTiles'
	'surfacescale':        'surfaceScale'
	'systemlanguage':      'systemLanguage'
	'tablevalues':         'tableValues'
	'targetx':             'targetX'
	'targety':             'targetY'
	'textlength':          'textLength'
	'viewbox':             'viewBox'
	'viewtarget':          'viewTarget'
	'xchannelselector':    'xChannelSelector'
	'ychannelselector':    'yChannelSelector'
	'zoomandpan':          'zoomAndPan'
}

fn adjust_mathml_attributes_impl(mut token HTMLToken) {
	token.adjust_attribute_name('definitionurl', 'definitionURL')
}

fn adjust_svg_tag_names_impl(mut token HTMLToken) {
	for from, to in svg_tag_name_adjustments {
		token.adjust_tag_name(from, to)
	}
}

fn adjust_svg_attributes_impl(mut token HTMLToken) {
	for from, to in svg_attribute_adjustments {
		token.adjust_attribute_name(from, to)
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#adjust-foreign-attributes
fn adjust_foreign_attributes_impl(mut token HTMLToken) {
	token.adjust_foreign_attribute('xlink:actuate', 'xlink', 'actuate', ns_xlink)
	token.adjust_foreign_attribute('xlink:arcrole', 'xlink', 'arcrole', ns_xlink)
	token.adjust_foreign_attribute('xlink:href', 'xlink', 'href', ns_xlink)
	token.adjust_foreign_attribute('xlink:role', 'xlink', 'role', ns_xlink)
	token.adjust_foreign_attribute('xlink:show', 'xlink', 'show', ns_xlink)
	token.adjust_foreign_attribute('xlink:title', 'xlink', 'title', ns_xlink)
	token.adjust_foreign_attribute('xlink:type', 'xlink', 'type', ns_xlink)
	token.adjust_foreign_attribute('xml:lang', 'xml', 'lang', ns_xml)
	token.adjust_foreign_attribute('xml:space', 'xml', 'space', ns_xml)
	token.adjust_foreign_attribute('xmlns', none, 'xmlns', ns_xmlns)
	token.adjust_foreign_attribute('xmlns:xlink', 'xmlns', 'xlink', ns_xmlns)
}

// HTMLParser's foreign-content attribute-adjustment entry points.
fn (p &HTMLParser) adjust_mathml_attributes(mut token HTMLToken) {
	_ = p
	adjust_mathml_attributes_impl(mut token)
}

fn (p &HTMLParser) adjust_svg_tag_names(mut token HTMLToken) {
	_ = p
	adjust_svg_tag_names_impl(mut token)
}

fn (p &HTMLParser) adjust_svg_attributes(mut token HTMLToken) {
	_ = p
	adjust_svg_attributes_impl(mut token)
}

fn HTMLParser.adjust_foreign_attributes(mut token HTMLToken) {
	adjust_foreign_attributes_impl(mut token)
}

// The tree-construction dispatcher's test for whether to use the HTML-content rules (vs. foreign).
fn (mut p HTMLParser) should_process_using_html_rules(token &HTMLToken) bool {
	if p.stack_of_open_elements.is_empty() {
		return true
	}
	acn := p.adjusted_current_node() or { return true }
	if element_in_namespace(acn, ns_html) {
		return true
	}
	if is_mathml_text_integration_point(acn) && token.is_start_tag() && token.tag_name != 'mglyph' && token.tag_name != 'malignmark' {
		return true
	}
	if is_mathml_text_integration_point(acn) && token.is_character() {
		return true
	}
	if element_in_namespace(acn, ns_mathml) && acn.local_name() == 'annotation-xml' && token.is_start_tag() && token.tag_name == 'svg' {
		return true
	}
	if is_html_integration_point(acn) && (token.is_start_tag() || token.is_character()) {
		return true
	}
	if token.is_end_of_file() {
		return true
	}
	return false
}

// HTML start tags that break out of foreign content back to HTML rules.
const foreign_breakout_tags = ['b', 'big', 'blockquote', 'body', 'br', 'center', 'code', 'dd', 'div',
	'dl', 'dt', 'em', 'embed', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'head', 'hr', 'i', 'img', 'li',
	'listing', 'menu', 'meta', 'nobr', 'ol', 'p', 'pre', 'ruby', 's', 'small', 'span', 'strong',
	'strike', 'sub', 'sup', 'table', 'tt', 'u', 'ul', 'var']

// https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inforeign
fn (mut p HTMLParser) process_using_the_rules_for_foreign_content(mut token HTMLToken) {
	if token.is_character() {
		if token.code_point == 0 {
			p.insert_character(rune(0xfffd))
			return
		}
		p.insert_character(token.code_point)
		if !token.is_parser_whitespace() {
			p.frameset_ok = false
		}
		return
	}
	if token.is_comment_or_processing_instruction() {
		p.insert_comment(token)
		return
	}
	if token.is_doctype() {
		return
	}

	is_breakout_start := token.is_start_tag() && token.tag_name in foreign_breakout_tags
	is_font_breakout := token.is_start_tag() && token.tag_name == 'font' && (token.has_attribute('color') || token.has_attribute('face') || token.has_attribute('size'))
	is_breakout_end := token.is_end_tag() && token.tag_name in ['br', 'p']
	if is_breakout_start || is_font_breakout || is_breakout_end {
		// Pop until the current node is a MathML text integration point, an HTML integration point,
		// or an HTML-namespace element; then reprocess with the current insertion mode.
		for {
			cn := p.current_node() or { break }
			if is_mathml_text_integration_point(cn) || is_html_integration_point(cn) || element_in_namespace(cn, ns_html) {
				break
			}
			p.stack_of_open_elements.pop()
		}
		p.process_using_the_rules_for(p.insertion_mode, mut token)
		return
	}

	if token.is_start_tag() {
		acn := p.adjusted_current_node() or { return }
		if element_in_namespace(acn, ns_mathml) {
			p.adjust_mathml_attributes(mut token)
		} else if element_in_namespace(acn, ns_svg) {
			p.adjust_svg_tag_names(mut token)
			p.adjust_svg_attributes(mut token)
		}
		HTMLParser.adjust_foreign_attributes(mut token)
		acn_namespace := acn.namespace_uri()
		if token.tag_name == 'script' && element_in_namespace(acn, ns_svg) {
			location := p.find_appropriate_place_for_inserting_node()
			parent := location.parent or { return }
			element := p.create_element_for(token, acn_namespace, parent)
			if p.document_.is_scripting_enabled_by_embedder() {
				p.register_parser_inserted_svg_script(element, token)
			}
			p.insert_an_element_at_the_adjusted_insertion_location(element)
			p.stack_of_open_elements.push(element)
			if token.is_self_closing() {
				token.acknowledge_self_closing_flag_if_set()
				p.process_svg_script_end_tag(element)
			}
			return
		}
		p.insert_foreign_element(token, acn_namespace, false)
		if token.is_self_closing() {
			p.stack_of_open_elements.pop()
			token.acknowledge_self_closing_flag_if_set()
		}
		return
	}

	// Any other end tag.
	if token.is_end_tag() {
		mut node := p.current_node() or { return }
		if token.tag_name == 'script' && element_in_namespace(node, ns_svg)
			&& node.local_name() == 'script' {
			p.process_svg_script_end_tag(node)
			return
		}
		for i := p.stack_of_open_elements.elements.len - 1; i >= 0; i-- {
			if same_element(node, p.stack_of_open_elements.first()) {
				return
			}
			if node.local_name().to_lower() == token.tag_name {
				for {
					cn := p.current_node() or { break }
					if same_element(cn, node) {
						break
					}
					p.stack_of_open_elements.pop()
				}
				p.stack_of_open_elements.pop()
				return
			}
			if i - 1 < 0 {
				return
			}
			node = p.stack_of_open_elements.elements[i - 1]
			if !element_in_namespace(node, ns_html) {
				continue
			}
			p.process_using_the_rules_for(p.insertion_mode, mut token)
			return
		}
	}
}

fn (mut p HTMLParser) process_svg_script_end_tag(element &dom.Element) {
	p.stack_of_open_elements.pop()
	if !p.document_.is_scripting_enabled_by_embedder() {
		return
	}
	p.tokenizer.store_old_insertion_point()
	p.tokenizer.update_insertion_point()
	p.increment_script_nesting_level()
	p.parser_pause_flag = true
	p.flush_character_insertions()

	mut script := svg_script_element_model_for_dom_element(unsafe { &dom.SVGScriptElement(element) })
	script.set_text(element.as_node().child_text_content())
	script.process_the_script_element()

	p.decrement_script_nesting_level()
	if p.script_nesting_level == 0 {
		p.parser_pause_flag = false
	}
	p.tokenizer.restore_old_insertion_point()
	if p.document_.pending_parsing_blocking_svg_script() != none {
		p.parser_pause_flag = true
		p.schedule_resume_check()
	}
}
