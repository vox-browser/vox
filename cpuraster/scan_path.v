module cpuraster

import math
import math.bits

// SkScan::FillPath (google/skia ee20d565, SkScan_Path.cpp): the
// non-anti-aliased scan converter. SkBasicEdgeBuilder turns the path into
// SkEdge lines and forward-differenced quadratic and cubic segments in 16.16
// and 26.6 fixed point (SkEdge.cpp); walk_edges() steps them a row at a time
// and blits the winding or even-odd spans between pixel-center crossings,
// and walk_simple_edges() pairs the two edges of a convex path.

enum BasicEdgeType {
	line
	quad
	cubic
}

// SkEdge, SkQuadraticEdge and SkCubicEdge, linked by index.
struct BasicEdge {
mut:
	next      int
	prev      int
	x         i32
	dxdy      i32
	first_y   i32
	last_y    i32
	edge_type BasicEdgeType
	winding   int
	// fSegmentCount and fCurveShift.
	segments    int
	curve_shift int
	// SkQuadraticEdge.
	qx      i32
	qy      i32
	qdxdt   i32
	qdydt   i32
	qd2xdt2 i32
	qd2ydt2 i32
	qlast_x i32
	qlast_y i32
	// SkCubicEdge.
	cx           i32
	cy           i32
	cdxdt        i32
	cdydt        i32
	cd2xdt2      i32
	cd2ydt2      i32
	cd3xdt3      i32
	cd3ydt3      i32
	clast_x      i32
	clast_y      i32
	cubic_dshift int
}

// SkFloatToFDot6(): (SkFDot6)(x * 64).
@[inline]
fn float_to_fdot6(x f32) i32 {
	return saturate_to_i32(x * f32(64))
}

@[inline]
fn fdot6_round(x i32) i32 {
	return i32(u32(x) + 32) >> 6
}

// SkEdge_Compute_DY().
@[inline]
fn edge_compute_dy(top i32, y0 i32) i32 {
	return i32(u32(left_shift(top, 6)) + 32 - u32(y0))
}

// SkEdge::setLine().
fn (mut e BasicEdge) set_line(p0 Point, p1 Point) bool {
	mut x0 := float_to_fdot6(p0.x)
	mut y0 := float_to_fdot6(p0.y)
	mut x1 := float_to_fdot6(p1.x)
	mut y1 := float_to_fdot6(p1.y)
	mut winding := 1
	if y0 > y1 {
		x0, x1 = x1, x0
		y0, y1 = y1, y0
		winding = -1
	}
	top := fdot6_round(y0)
	bot := fdot6_round(y1)
	if top == bot {
		return false
	}
	slope := fdot6_div(i32(u32(x1) - u32(x0)), i32(u32(y1) - u32(y0)))
	dy := edge_compute_dy(top, y0)
	e.x = fdot6_to_fixed(i32(u32(x0) + u32(fixed_mul(slope, dy))))
	e.dxdy = slope
	e.first_y = top
	e.last_y = bot - 1
	e.edge_type = .line
	e.segments = 0
	e.winding = winding
	e.curve_shift = 0
	return true
}

// SkEdge::updateLine().
fn (mut e BasicEdge) update_line(x_start i32, y_start i32, x_end i32, y_end i32) bool {
	y0 := fixed_to_fdot6(y_start)
	y1 := fixed_to_fdot6(y_end)
	top := fdot6_round(y0)
	bot := fdot6_round(y1)
	if top == bot {
		return false
	}
	x0 := fixed_to_fdot6(x_start)
	x1 := fixed_to_fdot6(x_end)
	slope := fdot6_div(i32(u32(x1) - u32(x0)), i32(u32(y1) - u32(y0)))
	dy := edge_compute_dy(top, y0)
	e.x = fdot6_to_fixed(i32(u32(x0) + u32(fixed_mul(slope, dy))))
	e.dxdy = slope
	e.first_y = top
	e.last_y = bot - 1
	return true
}

// cheap_distance(): max + min / 2.
fn basic_cheap_distance(dx_in i32, dy_in i32) i32 {
	dx := abs32(dx_in)
	dy := abs32(dy_in)
	if dx > dy {
		return dx + (dy / 2)
	}
	return dy + (dx / 2)
}

// diff_to_shift().
fn basic_diff_to_shift(dx i32, dy i32, accuracy int) int {
	mut dist := basic_cheap_distance(dx, dy)
	dist = i32(u32(dist) + (u32(1) << (2 + accuracy))) >> (3 + accuracy)
	return (32 - bits.leading_zeros_32(u32(dist))) >> 1
}

// SkFDot6ToFixedDiv2().
@[inline]
fn fdot6_to_fixed_div2_basic(value i32) i32 {
	return left_shift(value, 16 - 6 - 1)
}

// SkQuadraticEdge::setQuadratic().
fn (mut e BasicEdge) set_quadratic(pts []Point) bool {
	mut x0 := float_to_fdot6(pts[0].x)
	mut y0 := float_to_fdot6(pts[0].y)
	x1 := float_to_fdot6(pts[1].x)
	y1 := float_to_fdot6(pts[1].y)
	mut x2 := float_to_fdot6(pts[2].x)
	mut y2 := float_to_fdot6(pts[2].y)
	mut winding := 1
	if y0 > y2 {
		x0, x2 = x2, x0
		y0, y2 = y2, y0
		winding = -1
	}
	top := fdot6_round(y0)
	bot := fdot6_round(y2)
	if top == bot {
		return false
	}
	delta_x := i32(u32(2) * u32(x1) - u32(x0) - u32(x2)) >> 2
	delta_y := i32(u32(2) * u32(y1) - u32(y0) - u32(y2)) >> 2
	mut shift := basic_diff_to_shift(delta_x, delta_y, 0)
	if shift == 0 {
		shift = 1
	} else if shift > max_coeff_shift {
		shift = max_coeff_shift
	}
	e.winding = winding
	e.edge_type = .quad
	e.segments = 1 << shift
	e.curve_shift = shift - 1
	mut a_half := fdot6_to_fixed_div2_basic(i32(u32(x0) - u32(x1) - u32(x1) + u32(x2)))
	mut b_half := fdot6_to_fixed(i32(u32(x1) - u32(x0)))
	e.qdxdt = i32(u32(b_half) + u32(a_half >> shift))
	e.qd2xdt2 = a_half >> (shift - 1)
	a_half = fdot6_to_fixed_div2_basic(i32(u32(y0) - u32(y1) - u32(y1) + u32(y2)))
	b_half = fdot6_to_fixed(i32(u32(y1) - u32(y0)))
	e.qdydt = i32(u32(b_half) + u32(a_half >> shift))
	e.qd2ydt2 = a_half >> (shift - 1)
	e.qx = fdot6_to_fixed(x0)
	e.qy = fdot6_to_fixed(y0)
	e.qlast_x = fdot6_to_fixed(x2)
	e.qlast_y = fdot6_to_fixed(y2)
	return e.next_segment()
}

fn (mut e BasicEdge) next_quadratic_segment() bool {
	mut success := false
	mut count := e.segments
	mut oldx := e.qx
	mut oldy := e.qy
	mut dx := e.qdxdt
	mut dy := e.qdydt
	mut newx := i32(0)
	mut newy := i32(0)
	shift := e.curve_shift
	for {
		count--
		if count > 0 {
			newx = i32(u32(oldx) + u32(dx >> shift))
			dx = i32(u32(dx) + u32(e.qd2xdt2))
			newy = i32(u32(oldy) + u32(dy >> shift))
			dy = i32(u32(dy) + u32(e.qd2ydt2))
		} else {
			newx = e.qlast_x
			newy = e.qlast_y
		}
		success = e.update_line(oldx, oldy, newx, newy)
		oldx = newx
		oldy = newy
		if !(count > 0 && !success) {
			break
		}
	}
	e.qx = newx
	e.qy = newy
	e.qdxdt = dx
	e.qdydt = dy
	e.segments = count
	return success
}

// cubic_delta_from_line(): 19/512 approximates 1/27.
fn basic_cubic_delta_from_line(a i32, b i32, c i32, d i32) i32 {
	one_third := i32(u32(a) * 8 - u32(b) * 15 + 6 * u32(c) + u32(d)) * 19 >> 9
	two_third := i32(u32(a) + 6 * u32(b) - u32(c) * 15 + u32(d) * 8) * 19 >> 9
	t1 := abs32(one_third)
	t2 := abs32(two_third)
	return if t1 > t2 { t1 } else { t2 }
}

// SkCubicEdge::setCubic().
fn (mut e BasicEdge) set_cubic(pts []Point) bool {
	mut x0 := float_to_fdot6(pts[0].x)
	mut y0 := float_to_fdot6(pts[0].y)
	mut x1 := float_to_fdot6(pts[1].x)
	mut y1 := float_to_fdot6(pts[1].y)
	mut x2 := float_to_fdot6(pts[2].x)
	mut y2 := float_to_fdot6(pts[2].y)
	mut x3 := float_to_fdot6(pts[3].x)
	mut y3 := float_to_fdot6(pts[3].y)
	mut winding := 1
	if y0 > y3 {
		x0, x3 = x3, x0
		x1, x2 = x2, x1
		y0, y3 = y3, y0
		y1, y2 = y2, y1
		winding = -1
	}
	top := fdot6_round(y0)
	bot := fdot6_round(y3)
	if top == bot {
		return false
	}
	dx := basic_cubic_delta_from_line(x0, x1, x2, x3)
	dy := basic_cubic_delta_from_line(y0, y1, y2, y3)
	mut shift := basic_diff_to_shift(dx, dy, 2) + 1
	if shift > max_coeff_shift {
		shift = max_coeff_shift
	}
	mut up_shift := 6
	mut down_shift := shift + up_shift - 10
	if down_shift < 0 {
		down_shift = 0
		up_shift = 10 - shift
	}
	e.winding = winding
	e.edge_type = .cubic
	e.segments = 1 << shift
	e.curve_shift = shift
	e.cubic_dshift = down_shift
	mut a := left_shift(i32(u32(x3) + 3 * (u32(x1) - u32(x2)) - u32(x0)), up_shift)
	mut b := left_shift(i32(3 * (u32(x0) - 2 * u32(x1) + u32(x2))), up_shift)
	mut c := left_shift(i32(3 * (u32(x1) - u32(x0))), up_shift)
	e.cdxdt = i32(u32(a >> (2 * shift)) + u32(b >> shift) + u32(c))
	e.cd2xdt2 = i32(u32(i32(3 * u32(a)) >> (shift - 1)) + 2 * u32(b))
	e.cd3xdt3 = i32(3 * u32(a)) >> (shift - 1)
	a = left_shift(i32(u32(y3) + 3 * (u32(y1) - u32(y2)) - u32(y0)), up_shift)
	b = left_shift(i32(3 * (u32(y0) - 2 * u32(y1) + u32(y2))), up_shift)
	c = left_shift(i32(3 * (u32(y1) - u32(y0))), up_shift)
	e.cdydt = i32(u32(a >> (2 * shift)) + u32(b >> shift) + u32(c))
	e.cd2ydt2 = i32(u32(i32(3 * u32(a)) >> (shift - 1)) + 2 * u32(b))
	e.cd3ydt3 = i32(3 * u32(a)) >> (shift - 1)
	e.cx = fdot6_to_fixed(x0)
	e.cy = fdot6_to_fixed(y0)
	e.clast_x = fdot6_to_fixed(x3)
	e.clast_y = fdot6_to_fixed(y3)
	return e.next_segment()
}

fn (mut e BasicEdge) next_cubic_segment() bool {
	mut success := false
	mut count := e.segments
	mut oldx := e.cx
	mut oldy := e.cy
	mut newx := i32(0)
	mut newy := i32(0)
	ddshift := e.curve_shift
	dshift := e.cubic_dshift
	for {
		count--
		if count > 0 {
			newx = i32(u32(oldx) + u32(e.cdxdt >> dshift))
			e.cdxdt = i32(u32(e.cdxdt) + u32(e.cd2xdt2 >> ddshift))
			e.cd2xdt2 = i32(u32(e.cd2xdt2) + u32(e.cd3xdt3))
			newy = i32(u32(oldy) + u32(e.cdydt >> dshift))
			e.cdydt = i32(u32(e.cdydt) + u32(e.cd2ydt2 >> ddshift))
			e.cd2ydt2 = i32(u32(e.cd2ydt2) + u32(e.cd3ydt3))
		} else {
			newx = e.clast_x
			newy = e.clast_y
		}
		if newy < oldy {
			newy = oldy
		}
		success = e.update_line(oldx, oldy, newx, newy)
		oldx = newx
		oldy = newy
		if !(count > 0 && !success) {
			break
		}
	}
	e.cx = newx
	e.cy = newy
	e.segments = count
	return success
}

// nextSegment().
fn (mut e BasicEdge) next_segment() bool {
	return match e.edge_type {
		.quad { e.next_quadratic_segment() }
		.cubic { e.next_cubic_segment() }
		.line { false }
	}
}

// SkBasicEdgeBuilder.
struct BasicEdgeBuilder {
mut:
	edges []BasicEdge
	list  []int
}

// SkBasicEdgeBuilder::combineVertical().
fn combine_basic_vertical(edge &BasicEdge, mut last BasicEdge) Combine {
	if last.edge_type != .line || last.dxdy != 0 || edge.x != last.x {
		return .no
	}
	if edge.winding == last.winding {
		if edge.last_y + 1 == last.first_y {
			last.first_y = edge.first_y
			return .partial
		}
		if edge.first_y == last.last_y + 1 {
			last.last_y = edge.last_y
			return .partial
		}
		return .no
	}
	if edge.first_y == last.first_y {
		if edge.last_y == last.last_y {
			return .total
		}
		if edge.last_y < last.last_y {
			last.first_y = edge.last_y + 1
			return .partial
		}
		last.first_y = last.last_y + 1
		last.last_y = edge.last_y
		last.winding = edge.winding
		return .partial
	}
	if edge.last_y == last.last_y {
		if edge.first_y > last.first_y {
			last.last_y = edge.first_y - 1
			return .partial
		}
		last.last_y = last.first_y - 1
		last.first_y = edge.first_y
		last.winding = edge.winding
		return .partial
	}
	return .no
}

fn (mut b BasicEdgeBuilder) add_line(p0 Point, p1 Point) {
	mut edge := BasicEdge{}
	if !edge.set_line(p0, p1) {
		return
	}
	mut combine := Combine.no
	if edge.dxdy == 0 && edge.edge_type == .line && b.list.len > 0 {
		last := b.list.last()
		combine = combine_basic_vertical(&edge, mut b.edges[last])
	}
	match combine {
		.total {
			b.list.delete_last()
		}
		.partial {}
		.no {
			b.list << b.edges.len
			b.edges << edge
		}
	}
}

fn (mut b BasicEdgeBuilder) add_quad(pts []Point) {
	mut edge := BasicEdge{}
	if edge.set_quadratic(pts) {
		b.list << b.edges.len
		b.edges << edge
	}
}

fn (mut b BasicEdgeBuilder) add_cubic(pts []Point) {
	mut edge := BasicEdge{}
	if edge.set_cubic(pts) {
		b.list << b.edges.len
		b.edges << edge
	}
}

fn (mut b BasicEdgeBuilder) add_mono_y_quads(pts []Point) {
	mono := chop_quad_at_extrema(pts, true)
	for i := 0; i * 2 + 2 < mono.len; i++ {
		b.add_quad(mono[i * 2..i * 2 + 3])
	}
}

// SkEdgeBuilder::buildEdges() with SkBasicEdgeBuilder's unshifted clip.
fn build_basic_edges(path Path, clip ?Rect, convex bool) BasicEdgeBuilder {
	can_cull_to_the_right := !convex
	mut b := BasicEdgeBuilder{}
	edges := path_edges(path)
	if path.segment_mask() == segment_line {
		// buildPoly().
		for e in edges {
			if c := clip {
				lines := clip_line(e.pts, c, can_cull_to_the_right)
				for i in 0 .. lines.len - 1 {
					b.add_line(lines[i], lines[i + 1])
				}
			} else {
				b.add_line(e.pts[0], e.pts[1])
			}
		}
		return b
	}
	if c := clip {
		// SkEdgeClipper::ClipPath(): a non-finite clipped segment empties
		// the edge list.
		mut clipper := EdgeClipper{
			can_cull_to_the_right: can_cull_to_the_right
		}
		mut finite := true
		for e in edges {
			clipper.segments.clear()
			match e.verb {
				.line {
					clipper.clip_line(e.pts[0], e.pts[1], c)
				}
				.quad {
					clipper.clip_quad(e.pts, c)
				}
				.conic {
					quads := conic_to_quads(e.pts, e.weight, conic_tolerance)
					for i := 0; i + 2 < quads.len; i += 2 {
						clipper.clip_quad(quads[i..i + 3], c)
					}
				}
				.cubic {
					clipper.clip_cubic(e.pts, c)
				}
				else {}
			}
			for segment in clipper.segments {
				for p in segment.pts {
					if !is_finite_f32(p.x) || !is_finite_f32(p.y) {
						finite = false
					}
				}
				if !finite {
					break
				}
				match segment.verb {
					.line { b.add_line(segment.pts[0], segment.pts[1]) }
					.quad { b.add_quad(segment.pts) }
					.cubic { b.add_cubic(segment.pts) }
					else {}
				}
			}
			if !finite {
				break
			}
		}
		if !finite {
			b.list.clear()
		}
		return b
	}
	for e in edges {
		match e.verb {
			.line {
				b.add_line(e.pts[0], e.pts[1])
			}
			.quad {
				b.add_mono_y_quads(e.pts)
			}
			.conic {
				quads := conic_to_quads(e.pts, e.weight, conic_tolerance)
				for i := 0; i + 2 < quads.len; i += 2 {
					b.add_mono_y_quads(quads[i..i + 3])
				}
			}
			.cubic {
				mono := chop_cubic_at_extrema(e.pts, true)
				for i := 0; i * 3 + 3 < mono.len; i++ {
					b.add_cubic(mono[i * 3..i * 3 + 4])
				}
			}
			else {}
		}
	}
	return b
}

// SkTQSort() of indices with a strict ordering.
fn sort_indices(mut list []int, less fn (int, int) bool) {
	n := list.len
	if n <= 1 {
		return
	}
	depth := 2 * next_log2(n - 1)
	intro_sort_indices(mut list, less, depth, 0, n)
}

fn intro_sort_indices(mut list []int, less fn (int, int) bool, depth_in int, left_in int, count_in int) {
	mut depth := depth_in
	mut left := left_in
	mut count := count_in
	for {
		if count <= 32 {
			insertion_sort_indices(mut list, less, left, count)
			return
		}
		if depth == 0 {
			heap_sort_indices(mut list, less, left, count)
			return
		}
		depth--
		middle := left + ((count - 1) >> 1)
		// SkTQSort's partition about the middle element.
		right := left + count - 1
		pivot_value := list[middle]
		list[middle], list[right] = list[right], list[middle]
		mut new_pivot := left
		for i := left; i < right; i++ {
			if less(list[i], pivot_value) {
				list[i], list[new_pivot] = list[new_pivot], list[i]
				new_pivot++
			}
		}
		list[new_pivot], list[right] = list[right], list[new_pivot]
		pivot_count := new_pivot - left
		intro_sort_indices(mut list, less, depth, left, pivot_count)
		left += pivot_count + 1
		count -= pivot_count + 1
	}
}

fn insertion_sort_indices(mut list []int, less fn (int, int) bool, left int, count int) {
	right := left + count - 1
	for next := left + 1; next <= right; next++ {
		if !less(list[next], list[next - 1]) {
			continue
		}
		insert := list[next]
		mut hole := next
		for {
			list[hole] = list[hole - 1]
			hole--
			if !(left < hole && less(insert, list[hole - 1])) {
				break
			}
		}
		list[hole] = insert
	}
}

fn heap_sort_indices(mut list []int, less fn (int, int) bool, base int, count int) {
	for i := count >> 1; i > 0; i-- {
		heap_sift_down_indices(mut list, less, base, i, count)
	}
	for i := count - 1; i > 0; i-- {
		list[base], list[base + i] = list[base + i], list[base]
		heap_sift_up_indices(mut list, less, base, 1, i)
	}
}

fn heap_sift_up_indices(mut list []int, less fn (int, int) bool, base int, root_in int, bottom int) {
	mut root := root_in
	x := list[base + root - 1]
	start := root
	mut j := root * 2
	for j <= bottom {
		if j < bottom && less(list[base + j - 1], list[base + j]) {
			j++
		}
		list[base + root - 1] = list[base + j - 1]
		root = j
		j = root * 2
	}
	j = root / 2
	for j >= start {
		if less(list[base + j - 1], x) {
			list[base + root - 1] = list[base + j - 1]
			root = j
			j = root / 2
		} else {
			break
		}
	}
	list[base + root - 1] = x
}

fn heap_sift_down_indices(mut list []int, less fn (int, int) bool, base int, root_in int, bottom int) {
	mut root := root_in
	x := list[base + root - 1]
	mut child := root * 2
	for child <= bottom {
		if child < bottom && less(list[base + child - 1], list[base + child]) {
			child++
		}
		if less(x, list[base + child - 1]) {
			list[base + root - 1] = list[base + child - 1]
			root = child
			child = root * 2
		} else {
			break
		}
	}
	list[base + root - 1] = x
}

// The edge list: edges, then the head and tail sentinels.
struct BasicEdgeList {
mut:
	edges []BasicEdge
	head  int
	tail  int
}

fn (mut l BasicEdgeList) remove_edge(i int) {
	prev := l.edges[i].prev
	next := l.edges[i].next
	l.edges[prev].next = next
	l.edges[next].prev = prev
}

fn (mut l BasicEdgeList) insert_edge_after(i int, after int) {
	l.edges[i].prev = after
	l.edges[i].next = l.edges[after].next
	l.edges[l.edges[after].next].prev = i
	l.edges[after].next = i
}

// backward_insert_edge_based_on_x(): stops at the head, whose x is the
// minimum.
fn (mut l BasicEdgeList) backward_insert_edge_based_on_x(i int) {
	x := l.edges[i].x
	mut prev := l.edges[i].prev
	for l.edges[prev].prev >= 0 && l.edges[prev].x > x {
		prev = l.edges[prev].prev
	}
	if l.edges[prev].next != i {
		l.remove_edge(i)
		l.insert_edge_after(i, prev)
	}
}

// backward_insert_start().
fn (l &BasicEdgeList) backward_insert_start(prev_in int, x i32) int {
	mut prev := prev_in
	for l.edges[prev].prev >= 0 && l.edges[prev].x > x {
		prev = l.edges[prev].prev
	}
	return prev
}

// insert_new_edges().
fn (mut l BasicEdgeList) insert_new_edges(new_edge_in int, curr_y i32) {
	mut new_edge := new_edge_in
	if l.edges[new_edge].first_y != curr_y {
		return
	}
	prev := l.edges[new_edge].prev
	if l.edges[prev].x <= l.edges[new_edge].x {
		return
	}
	mut start := l.backward_insert_start(prev, l.edges[new_edge].x)
	for {
		next := l.edges[new_edge].next
		mut inserted := false
		for {
			if l.edges[start].next == new_edge {
				inserted = true
				break
			}
			after := l.edges[start].next
			if l.edges[after].x >= l.edges[new_edge].x {
				break
			}
			start = after
		}
		if !inserted {
			l.remove_edge(new_edge)
			l.insert_edge_after(new_edge, start)
		}
		start = new_edge
		new_edge = next
		if l.edges[new_edge].first_y != curr_y {
			break
		}
	}
}

// SkFixedRoundToInt().
@[inline]
fn fixed_round_to_int(x i32) int {
	return int(i32(u32(x) + 0x8000) >> 16)
}

// walk_edges().
fn (mut l BasicEdgeList) walk_edges(even_odd bool, mut blitter Blitter, start_y int, stop_y int, right_clip int) {
	mut curr_y := start_y
	winding_mask := if even_odd { 1 } else { -1 }
	for {
		mut w := 0
		mut left := 0
		mut curr := l.edges[l.head].next
		mut prev_x := l.edges[l.head].x
		for l.edges[curr].first_y <= curr_y {
			x := fixed_round_to_int(l.edges[curr].x)
			if w & winding_mask == 0 {
				left = x
			}
			w += l.edges[curr].winding
			if w & winding_mask == 0 {
				width := x - left
				if width > 0 {
					blitter.blit_h(left, curr_y, width)
				}
			}
			next := l.edges[curr].next
			mut new_x := i32(0)
			mut advance := true
			if l.edges[curr].last_y == curr_y {
				if l.edges[curr].segments != 0 && l.edges[curr].next_segment() {
					new_x = l.edges[curr].x
				} else {
					l.remove_edge(curr)
					advance = false
				}
			} else {
				new_x = i32(u32(l.edges[curr].x) + u32(l.edges[curr].dxdy))
				l.edges[curr].x = new_x
			}
			if advance {
				if new_x < prev_x {
					l.backward_insert_edge_based_on_x(curr)
				} else {
					prev_x = new_x
				}
			}
			curr = next
		}
		if w & winding_mask != 0 {
			width := right_clip - left
			if width > 0 {
				blitter.blit_h(left, curr_y, width)
			}
		}
		curr_y++
		if curr_y >= stop_y {
			break
		}
		l.insert_new_edges(curr, i32(curr_y))
	}
}

// update_edge(): whether the edge continues after last_y.
fn (mut l BasicEdgeList) update_edge(i int, last_y i32) bool {
	if last_y != l.edges[i].last_y {
		return true
	}
	if l.edges[i].segments == 0 {
		return false
	}
	return l.edges[i].next_segment()
}

// walk_simple_edges(): the two edges of a path whose y changes direction
// once.
fn (mut l BasicEdgeList) walk_simple_edges(mut blitter Blitter, start_y int, stop_y int) {
	mut left_e := l.edges[l.head].next
	mut rite_e := l.edges[left_e].next
	mut curr := l.edges[rite_e].next
	mut local_top := int(if l.edges[left_e].first_y > l.edges[rite_e].first_y {
		l.edges[left_e].first_y
	} else {
		l.edges[rite_e].first_y
	})
	if local_top < start_y {
		return
	}
	for local_top < stop_y {
		mut local_bot := int(if l.edges[left_e].last_y < l.edges[rite_e].last_y {
			l.edges[left_e].last_y
		} else {
			l.edges[rite_e].last_y
		})
		if local_bot > stop_y - 1 {
			local_bot = stop_y - 1
		}
		if !(local_top <= local_bot) {
			return
		}
		mut left := l.edges[left_e].x
		d_left := l.edges[left_e].dxdy
		mut rite := l.edges[rite_e].x
		d_rite := l.edges[rite_e].dxdy
		mut count := local_bot - local_top
		if d_left == 0 && d_rite == 0 {
			mut lx := fixed_round_to_int(left)
			mut rx := fixed_round_to_int(rite)
			if lx > rx {
				lx, rx = rx, lx
			}
			if lx < rx {
				count++
				blitter.blit_rect(lx, local_top, rx - lx, count)
			}
			local_top = local_bot + 1
		} else {
			for {
				mut lx := fixed_round_to_int(left)
				mut rx := fixed_round_to_int(rite)
				if lx > rx {
					lx, rx = rx, lx
				}
				if lx < rx {
					blitter.blit_h(lx, local_top, rx - lx)
				}
				left = i32(u32(left) + u32(d_left))
				rite = i32(u32(rite) + u32(d_rite))
				local_top++
				count--
				if count < 0 {
					break
				}
			}
		}
		l.edges[left_e].x = left
		l.edges[rite_e].x = rite
		if !l.update_edge(left_e, i32(local_bot)) {
			if l.edges[curr].first_y >= stop_y {
				return
			}
			left_e = curr
			curr = l.edges[curr].next
			if l.edges[left_e].first_y != local_top {
				return
			}
		}
		if !l.update_edge(rite_e, i32(local_bot)) {
			if l.edges[curr].first_y >= stop_y {
				return
			}
			rite_e = curr
			curr = l.edges[curr].next
			if l.edges[rite_e].first_y != local_top {
				return
			}
		}
	}
}

// sk_fill_path() of a non-inverse path.
fn sk_fill_path(path Path, convex bool, clip_rect IRect, mut blitter Blitter, start_y_in int, stop_y_in int, contained bool) {
	clip := if contained {
		?Rect(none)
	} else {
		?Rect(Rect{f32(clip_rect.left), f32(clip_rect.top), f32(clip_rect.right), f32(clip_rect.bottom)})
	}
	builder := build_basic_edges(path, clip, convex)
	count := builder.list.len
	if count == 0 {
		return
	}
	mut list := builder.list.clone()
	edges := builder.edges
	sort_indices(mut list, fn [edges] (a int, b int) bool {
		if edges[a].first_y != edges[b].first_y {
			return edges[a].first_y < edges[b].first_y
		}
		return edges[a].x < edges[b].x
	})
	// The sorted edges, then the head and tail sentinels.
	mut l := BasicEdgeList{}
	for i in list {
		l.edges << builder.edges[i]
	}
	l.head = l.edges.len
	l.tail = l.edges.len + 1
	l.edges << BasicEdge{
		prev:    -1
		next:    0
		first_y: min_i32
		x:       min_i32
	}
	l.edges << BasicEdge{
		prev:    count - 1
		next:    -1
		first_y: max_i32
	}
	for i in 0 .. count {
		l.edges[i].prev = if i == 0 { l.head } else { i - 1 }
		l.edges[i].next = if i == count - 1 { l.tail } else { i + 1 }
	}
	mut start_y := start_y_in
	mut stop_y := stop_y_in
	if !contained && start_y < clip_rect.top {
		start_y = clip_rect.top
	}
	if !contained && stop_y > clip_rect.bottom {
		stop_y = clip_rect.bottom
	}
	if convex && count >= 2 {
		l.walk_simple_edges(mut blitter, start_y, stop_y)
	} else {
		l.walk_edges(path.fill_type == .even_odd, mut blitter, start_y, stop_y, clip_rect.right)
	}
}

// conservative_round_to_int()'s biased rounding.
const conservative_round_bias = 0.5 + 1.5 / 64.0

fn conservative_round_to_int(src Rect) IRect {
	down := fn (x f32) int {
		v := math.ceil(f64(x) - conservative_round_bias)
		return double_saturate_to_int(v)
	}
	up := fn (x f32) int {
		v := math.floor(f64(x) + conservative_round_bias)
		return double_saturate_to_int(v)
	}
	return IRect{down(src.left), down(src.top), up(src.right), up(src.bottom)}
}

// sk_double_saturate2int().
fn double_saturate_to_int(v f64) int {
	if v != v {
		return max_i32
	}
	if v >= f64(max_i32) {
		return max_i32
	}
	if v <= f64(min_i32) {
		return min_i32
	}
	return int(v)
}

// SkScan::FillPath(raw, region, blitter) for a rect region.
fn fill_path_region(path Path, convex bool, clip_in IRect, mut blitter Blitter) {
	if clip_in.is_empty() {
		return
	}
	// clip_to_limit(): the 16.16 range.
	limit := 32767 >> 1
	mut clip := clip_in
	limit_rect := IRect{-limit, -limit, limit, limit}
	if !limit_rect.contains(clip) {
		clip = clip.intersect(limit_rect) or { return }
	}
	mut bounds := path.bounds() or { Rect{} }
	mut pre_clipped := false
	large := f32(2147483520)
	large_rect := Rect{-large, -large, large, large}
	if !rect_contains_rect(large_rect, bounds) {
		bounds = rect_intersect(bounds, large_rect) or { Rect{} }
		pre_clipped = true
	}
	ir := conservative_round_to_int(bounds)
	if ir.is_empty() {
		return
	}
	// SkScanClipper.
	if !irect_intersects(clip, ir) {
		return
	}
	if !pre_clipped && clip.contains(ir) {
		sk_fill_path(path, convex, clip, mut blitter, ir.top, ir.bottom, true)
		return
	}
	if pre_clipped || clip.left > ir.left || clip.right < ir.right {
		mut wrapper := RectClipBlitter{
			clip:  clip
			inner: blitter
		}
		sk_fill_path(path, convex, clip, mut wrapper, ir.top, ir.bottom, false)
		return
	}
	sk_fill_path(path, convex, clip, mut blitter, ir.top, ir.bottom, false)
}

// fill_path is SkScan::FillPath() with a rectangular device clip. Returns
// false, without blitting, for inverse fills, which are not ported.
pub fn fill_path(path Path, clip IRect, mut blitter Blitter) bool {
	rc := new_raster_clip(clip)
	return fill_path_clip(path, false, &rc, mut blitter)
}

// fill_path_clip is Draw::drawDevPath()'s non-anti-aliased fill through a
// raster clip: SkScan::FillPath(raw, rasterClip, blitter), inside an
// SkAAClip through SkAAClipBlitter. Inverse fills are not ported and
// return false before blitting.
fn fill_path_clip(path Path, known_convex bool, rc &RasterClip, mut blitter Blitter) bool {
	if path.is_inverse_fill() {
		return false
	}
	if rc.is_empty || path.verbs.len == 0 {
		return true
	}
	convex := known_convex || path.convexity() != .concave
	if rc.is_bw {
		fill_path_region(path, convex, rc.rect, mut blitter)
		return true
	}
	mut aa := new_aaclip_blitter(blitter, &rc.aa)
	fill_path_region(path, convex, rc.aa.bounds, mut aa)
	return true
}

// A span set: SkRgnBuilder's input when SkRegion::setPath() fills a path
// into a region.
struct SpanCollector {
mut:
	spans []IRect
}

fn (mut c SpanCollector) blit_h(x int, y int, width int) {
	c.spans << IRect{x, y, x + width, y + 1}
}

fn (mut c SpanCollector) blit_rect(x int, y int, width int, height int) {
	for row in 0 .. height {
		c.blit_h(x, y + row, width)
	}
}

fn (mut c SpanCollector) blit_anti_h(x int, y int, mut aa []u8, mut runs []i16) {}

fn (mut c SpanCollector) blit_v(x int, y int, height int, alpha u8) {}

fn (mut c SpanCollector) blit_anti_rect(x int, y int, width int, height int, left_alpha u8, right_alpha u8) {}

fn (mut c SpanCollector) blit_mask(mask &Mask, clip IRect) {}

fn (mut c SpanCollector) blit_anti_h2(x int, y int, a0 u8, a1 u8) {}

fn (mut c SpanCollector) blit_anti_v2(x int, y int, a0 u8, a1 u8) {}
