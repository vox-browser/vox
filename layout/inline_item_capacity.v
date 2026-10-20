module layout

import platform

// A text node supplies its complete chunk count, but a container can have
// hundreds of small text nodes. Exact reservations for each node repeatedly
// copy the full prefix; retain geometric growth across those reservations.
fn reserve_inline_item_capacity(mut items []InlineLevelItem, additional int) {
	if additional <= 0 || items.len > 2_147_483_647 - additional { return }
	required := items.len + additional
	if items.cap >= required { return }
	growth := if items.cap > 2_147_483_647 / 2 { 2_147_483_647 } else { items.cap * 2 }
	items.ensure_cap(if growth > required { growth } else { required })
}

fn reserve_inline_items_in_storage(mut items []InlineLevelItem, additional int, storage &platform.Arena) {
	if additional <= 0 || items.len > 2_147_483_647 - additional || items.cap >= items.len + additional { return }
	if storage == unsafe { nil } { reserve_inline_item_capacity(mut items, additional); return }
	entry := storage.enter()
	reserve_inline_item_capacity(mut items, additional)
	storage.leave(entry)
}
