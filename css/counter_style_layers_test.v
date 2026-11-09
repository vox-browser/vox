module css

import dom

fn test_counter_style_conflicts_follow_layer_order_across_stylesheets() {
 for rules in [
  '@counter-style sample{system:cyclic;symbols:"AAAA"}@layer{@counter-style sample{system:cyclic;symbols:"BBB"}}',
  '@layer base,override;@layer override{@counter-style sample{system:cyclic;symbols:"AAAA"}}@layer base{@counter-style sample{system:cyclic;symbols:"BBB"}}'
 ] {
  mut document := dom.Document.create(dom.url_about_blank())
  defer { document.finalize() }
  add_document_author_style_sheet(document,rules)
  styles := registered_counter_styles_for_document(document)
  assert generate_a_counter_representation(styles['sample'],styles,1) == 'AAAA'
 }
 mut document := dom.Document.create(dom.url_about_blank())
 defer { document.finalize() }
 add_document_author_style_sheet(document,'@layer base,override;@layer override{@counter-style sample{system:cyclic;symbols:"AAAA"}}')
 _ = registered_counter_styles_for_document(document)
 add_document_author_style_sheet(document,'@layer base{@counter-style sample{system:cyclic;symbols:"BBB"}}')
 styles := registered_counter_styles_for_document(document)
 assert generate_a_counter_representation(styles['sample'],styles,1) == 'AAAA'
 add_document_author_style_sheet(document,'@layer override{@counter-style sample{system:cyclic;symbols:"CCCC"}}')
 changed := registered_counter_styles_for_document(document)
 assert generate_a_counter_representation(changed['sample'],changed,1) == 'CCCC'
}
