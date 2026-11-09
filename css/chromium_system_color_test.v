module css

import dom

fn test_chromium_system_control_colors_share_computation_and_cssom_serialization() {
 mut document := dom.Document.create(dom.url_about_blank())
 defer { document.finalize() }
 document.set_font_rendering_policy(.chromium)
 mut element := document.create_element('div') or { panic(err) }
 element.set_attribute_value('style','color-scheme:light;color:ButtonFace')
 mut computer := StyleComputer.new(document)
 style := computer.compute_style(dom.AbstractElement.new(element,none))
 color := style.property(.color,.no) or { panic('color') }
 assert color.css_text == 'rgb(239, 239, 239)'
 context := ColorResolutionContext{document:document,color_scheme:PreferredColorScheme.light}
 assert cssom_resolve_color_style_value(color,context).css_text == 'rgb(239, 239, 239)'
 red := parse_css_value(ParsingParams{},'red',.color) or { panic('red') }
 assert cssom_resolve_color_style_value(red,context).css_text == 'rgb(255, 0, 0)'
 assert SystemColor.button_face(.light) == Color.rgb(212,208,200)
}
