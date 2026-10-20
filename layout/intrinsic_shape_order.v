module layout

// Keep the owner vector in insertion order. Large caches use only integer
// positions sorted by text, with equal keys retaining their original order.
// The remaining shape key is still checked by shape_text_for_layout().
struct IntrinsicTextShapeOrder {
mut:
	entries []int
}

fn intrinsic_shape_cache_range(text_node &TextNode, text string) (int, int) {
	count := text_node.cached_intrinsic_text_shapes_.len
	mut node := unsafe { &TextNode(text_node) }
	if count < 16 {
		node.cached_intrinsic_shape_order_ = unsafe { nil }
		return 0, count
	}
	if node.cached_intrinsic_shape_order_ == unsafe { nil }
		|| node.cached_intrinsic_shape_order_.entries.len != count {
		node.cached_intrinsic_shape_order_ = unsafe { nil }
		return 0, count
	}
	order := node.cached_intrinsic_shape_order_
	mut low := 0
	mut high := count
	for low < high {
		middle := low + (high - low) / 2
		if text_node.cached_intrinsic_text_shapes_[order.entries[middle]].text < text {
			low = middle + 1
		} else {
			high = middle
		}
	}
	start := low
	high = count
	for low < high {
		middle := low + (high - low) / 2
		if text < text_node.cached_intrinsic_text_shapes_[order.entries[middle]].text {
			high = middle
		} else {
			low = middle + 1
		}
	}
	return start, low
}

fn intrinsic_shape_cache_entry_index(node &TextNode, position int) int {
	if node.cached_intrinsic_shape_order_ != unsafe { nil } {
		return node.cached_intrinsic_shape_order_.entries[position]
	}
	return position
}

fn intrinsic_shape_order_insert(mut order IntrinsicTextShapeOrder, node &TextNode, index int) {
	text := node.cached_intrinsic_text_shapes_[index].text
	mut low := 0
	mut high := order.entries.len
	for low < high {
		middle := low + (high - low) / 2
		if text < node.cached_intrinsic_text_shapes_[order.entries[middle]].text {
			high = middle
		} else {
			low = middle + 1
		}
	}
	order.entries.insert(low, index)
}

// The caller appends inside the cache owner's allocation scope. Build or grow
// the integer index there too, so all later lookups remain allocation-free.
fn append_intrinsic_shape_cache_order(mut node TextNode) {
	count := node.cached_intrinsic_text_shapes_.len
	if count < 16 {
		node.cached_intrinsic_shape_order_ = unsafe { nil }
		return
	}
	if node.cached_intrinsic_shape_order_ != unsafe { nil }
		&& node.cached_intrinsic_shape_order_.entries.len == count - 1 {
		intrinsic_shape_order_insert(mut node.cached_intrinsic_shape_order_, node, count - 1)
		return
	}
	mut order := &IntrinsicTextShapeOrder{entries: []int{cap: count}}
	for index in 0 .. count { intrinsic_shape_order_insert(mut order, node, index) }
	node.cached_intrinsic_shape_order_ = order
}
