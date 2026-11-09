module main

import browserjs
import css
import dom
import html
import math
import page
import x.json2

struct CompactInternalsWheelQuery {
	x       f64
	y       f64
	delta_x f64
	delta_y f64
}

// Internals wheel input follows native hit testing, trusted wheel dispatch and
// CSS scroll chaining. Each axis stops independently at a contained boundary.
fn (mut binding CompactElementQueryBinding) internals_wheel(source string) !string {
	query := compact_decode_query[CompactInternalsWheelQuery](source)!
	for value in [query.x, query.y, query.delta_x, query.delta_y] {
		if math.is_nan(value) || math.is_inf(value, 0) {
			return error('TypeError: Wheel coordinates and deltas must be finite')
		}
	}
	mut document := binding.document
	if !document.is_fully_active() || !document.has_page() || document.page().target == unsafe { nil } {
		return error('InvalidStateError: Wheel input requires an active Page')
	}
	mut point := page.PixelPoint{ x: query.x, y: query.y }
	mut hit := document.element_from_point(point.x, point.y) or { return 'null' }
	// Enter the actual child document under an iframe hit. The top-level
	// dispatch coordinates are translated to that child's content viewport.
	for _ in 0 .. 32 {
		mut entered := false
		for child in document.document_tree_child_navigables() {
			container := child.container() or { continue }
			if voidptr(container) != voidptr(hit.as_node()) { continue }
			nested := child.active_document() or { continue }
			rect := hit.get_bounding_client_rect()
			model := if node := hit.as_node().layout_node() {
				node.box_model()
			} else {
				&dom.LayoutBoxModel{}
			}
			scale := document.layout_coordinate_scale()
			point = page.PixelPoint{ x: point.x - rect.x - model.border_left / scale, y: point.y - rect.y - model.border_top / scale }
			document = nested
			hit = document.element_from_point(point.x, point.y) or { return 'null' }
			entered = true
			break
		}
		if !entered { break }
	}
	mut owner := unsafe { &page.Page(document.page().target) }
	mut handler := owner.event_handler
	handler.set_document_state(document.is_fully_active(), document.layout_node() != none)
	target := handler.target_node_for_mouse_position(document, point) or { return 'null' }
	result := handler.handle_mousewheel_with_parameters(page.InputTarget.from_node(target), point, point, 0, 0, 0, query.delta_x, query.delta_y, .precise, .none, false)
	if result !in [.cancelled, .dropped] {
		compact_wheel_scroll_chain(target, query.delta_x, query.delta_y)
	}
	mut runtime := unsafe { &browserjs.Runtime(binding.runtime) }
	runtime.mark_document_state_dirty()
	return 'null'
}

fn compact_wheel_scroll_chain(target &dom.Node, delta_x f64, delta_y f64) {
	mut dx, mut dy := delta_x, delta_y
	mut current := ?&dom.Node(target)
	for current != none && (dx != 0 || dy != 0) {
		node := current or { break }
		if mut element := node.as_element() {
			mut document := element.document()
			style := css.up_to_date_computed_properties_for_element(element)
			root := element.is_document_element()
			can_x := style.overflow_x() in [.auto_, .scroll] || (root && style.overflow_x() == .visible)
			can_y := style.overflow_y() in [.auto_, .scroll] || (root && style.overflow_y() == .visible)
			if root || can_x || can_y {
				before_x, before_y := element.scroll_left(), element.scroll_top()
				if root {
					if window := document.get_window() {
						mut model := unsafe { &html.WindowModel(window) }
						model.scroll_by(html.ScrollToOptions{ left: if can_x { dx } else { 0.0 }, top: if can_y {
							dy
						} else {
							0.0
						}, behavior: .instant })
					}
				} else {
					element.scroll_by_with_options(dom.ScrollToOptions_{ left: if can_x {
						dx
					} else {
						0.0
					}, top: if can_y { dy } else { 0.0 }, behavior: .instant })
				}
				after_x, after_y := element.scroll_left(), element.scroll_top()
				x_behavior := if value := style.property(.overscroll_behavior_x, .yes) {
					value.css_text
				} else {
					'auto'
				}
				y_behavior := if value := style.property(.overscroll_behavior_y, .yes) {
					value.css_text
				} else {
					'auto'
				}
				if after_x != before_x || (can_x && x_behavior in ['contain', 'none']) { dx = 0 }
				if after_y != before_y || (can_y && y_behavior in ['contain', 'none']) { dy = 0 }
			}
		}
		if node.is_document() {
			if navigable := node.document().navigable() {
				current = navigable.container()
				continue
			}
		}
		current = node.parent_or_shadow_host()
	}
}

fn compact_wheel_internals_bootstrap() string {
	return r'
if(window.internals)window.internals.wheel=({wheel(x,y,deltaX,deltaY){
 if(arguments.length<4)throw new TypeError("wheel requires coordinates and deltas");
 const values=[+x,+y,+deltaX,+deltaY];if(!values.every(Number.isFinite))throw new TypeError("Wheel coordinates and deltas must be finite");
 __queryElements("","internalsWheel",JSON.stringify({x:values[0],y:values[1],delta_x:values[2],delta_y:values[3]}),true);
}}).wheel;
'
}
