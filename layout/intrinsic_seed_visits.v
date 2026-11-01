module layout

import os

const disable_intrinsic_seed_visits = os.getenv('VOX_DISABLE_INTRINSIC_SEED_VISITS') != ''
const intrinsic_seed_visit_diagnostics = os.getenv('VOX_INTRINSIC_SEED_VISIT_DIAGNOSTICS') != ''

__global intrinsic_seed_visits_reported bool

// A completed layout tree has dense geometry indexes. One visitation vector
// belongs to this formatting pass, outside every shorter-lived probe arena.
// Epochs avoid allocating a hash table, or clearing the vector, for each probe.
fn (mut state LayoutState) prepare_intrinsic_seed_visits(root &Node) {
	if disable_intrinsic_seed_visits || state.measurement_chunk_pool_ == unsafe { nil } { return }
	order := root.tree_order_
	if order == unsafe { nil } || !order.valid || root.tree_order_owner_ != voidptr(root) { return }
	mut pool := state.measurement_chunk_pool_
	if pool.closed || pool.intrinsic_seed_order_ != unsafe { nil } { return }
	pool.intrinsic_seed_order_ = order
	pool.intrinsic_seed_stamps_ = []u32{len: int(order.next_index)}
}

fn try_populate_intrinsic_external_blocks_with_visits(mut throwaway LayoutState,
	mut source LayoutState, root &Node, node &Node) bool {
	if disable_intrinsic_seed_visits || source.measurement_chunk_pool_ == unsafe { nil } { return false }
	mut pool := source.measurement_chunk_pool_
	order := pool.intrinsic_seed_order_
	if pool.closed || order == unsafe { nil } || !order.valid
		|| voidptr(root.tree_order_) != voidptr(order)
		|| root.tree_order_owner_ != voidptr(root) { return false }
	pool.intrinsic_seed_epoch_++
	if pool.intrinsic_seed_epoch_ == 0 {
		for mut stamp in pool.intrinsic_seed_stamps_ { stamp = 0 }
		pool.intrinsic_seed_epoch_ = 1
	}
	if !populate_intrinsic_external_blocks_with_visits(mut throwaway, mut source, root, node, mut pool) {
		// A staged or foreign containing block needs the original general walk.
		// It skips any values already copied by this partial traversal.
		return false
	}
	if intrinsic_seed_visit_diagnostics && !intrinsic_seed_visits_reported {
		intrinsic_seed_visits_reported = true
		eprintln('Vox intrinsic seed visits: reused pass visitation storage')
	}
	return true
}

fn populate_intrinsic_external_blocks_with_visits(mut throwaway LayoutState,
	mut source LayoutState, root &Node, node &Node, mut pool MeasurementUsedValuesChunkPool) bool {
	mut containing := node.containing_block()
	for containing != none {
		box := containing or { break }
		candidate := unsafe { &Node(box) }
		index := int(box.layout_index())
		if voidptr(candidate.tree_order_) != voidptr(pool.intrinsic_seed_order_)
			|| candidate.tree_order_owner_ != voidptr(candidate)
			|| index >= pool.intrinsic_seed_stamps_.len { return false }
		if pool.intrinsic_seed_stamps_[index] == pool.intrinsic_seed_epoch_ { break }
		pool.intrinsic_seed_stamps_[index] = pool.intrinsic_seed_epoch_
		if !root.is_inclusive_ancestor_of(candidate) {
			if styled := candidate.as_node_with_style() {
				if throwaway.try_get(styled) == none { throwaway.populate_node_from(mut source, styled) }
			}
		}
		containing = candidate.containing_block()
	}
	for child in node.children() {
		if !populate_intrinsic_external_blocks_with_visits(mut throwaway, mut source, root, child, mut pool) {
			return false
		}
	}
	return true
}
