module layout

import css
import dom
import html
import os
import processmetrics
import time

fn test_github20_layout_instruction_workload() {
 eprintln('INLINE_INPUT_BYTES=${sizeof(RetainedInlineInput)}')
 markup := os.read_file('Build/github-20-instr/github-inline.html') or { panic(err) }
 address := dom.URL{value:'https://github.com/vlang/v'}
 mut document := html.create_navigation_document(address, address.origin(), none) or { panic(err) }
 document.set_font_rendering_policy(.chromium)
 document.enable_native_storage()
 mut allocations := document.enter_native_storage()
 html.parse_html_from_a_string(document, markup)
 if os.getenv('ZZ_PROFILE_SLEEP') != '' { time.sleep(4 * time.second) }
 for pass in 0 .. 2 {
  before := processmetrics.instruction_snapshot()
  _ = layout_document_typed_in_viewport(document, 1024, 768)
  count := processmetrics.instruction_snapshot().since(before) or { u64(0) }
  result := document_layout_result(document) or { panic('layout') }
  mut hash := u64(14695981039346656037)
  mut pending := [result.root]
  for pending.len > 0 {
   node := pending.pop()
   if styled := node.as_node_with_style() {
    if values := result.state.try_get(styled) {
     for value in [values.content_width().raw_value(),values.content_height().raw_value(),values.offset.x().raw_value(),values.offset.y().raw_value()] {
      hash = (hash ^ u64(value)) * u64(1099511628211)
     }
    }
   }
   pending << node.children()
  }
  eprintln('LAYOUT pass=${pass} instructions=${count} geometry=${hash:x}')
 }
 css.report_diagnostic_instruction_scopes()
 allocations.finish()
 document.finalize()
}
