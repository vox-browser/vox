module css

import dom
import platform

const computed_property_page_size = 16
const computed_property_page_count = (number_of_longhand_properties + computed_property_page_size - 1) / computed_property_page_size
const computed_property_page_pool_limit = 4096

@[heap]
struct ComputedPropertyPage {
mut:
	values [computed_property_page_size]&dom.StyleValue
	// Published pages share immutable values. A replacement invalidates this
	// conservative density-projection mask before the page can be read again.
	device_layout_candidates_ u64
}

// Record copies share this owner, preserving the raw array's existing aliases.
// Only unpublished pages with a set writable bit may be modified in place.
@[heap]
struct ComputedPropertyStore {
mut:
	pages    [computed_property_page_count]&ComputedPropertyPage
	writable u32
	recycling &ComputedPropertyPageRecycling = unsafe { nil }
	recycling_epoch u64
}

// Only exclusive pages discarded by publication enter this free list. The
// descriptor and its bounded vector survive batches. Epochs prevent a style
// kept beyond its batch from acquiring pages during an unrelated later pass.
@[heap]
struct ComputedPropertyPageRecycling {
mut:
	owner &platform.RetainedArena = unsafe { nil }
	epoch u64
	active bool
	pages []&ComputedPropertyPage
}

fn (pool &ComputedPropertyPageRecycling) can_reuse(epoch u64) bool {
	return pool.active && pool.epoch == epoch
		&& voidptr(pool.owner) == voidptr(platform.current_retained_arena())
		&& platform.arena_entered() && !platform.transient_arena_entered()
}

fn (computer &StyleComputer) prepare_computed_property_page_recycling(style &ComputedProperties) {
	$if prealloc {
		if computer.computed_property_page_batch_depth_ == 0
			|| computer.document_ == unsafe { nil } { return }
		owner := computer.document_.native_storage()
		if owner == unsafe { nil }
			|| voidptr(owner) != voidptr(platform.current_retained_arena())
			|| !platform.arena_entered() || platform.transient_arena_entered() { return }
		mut mutable := unsafe { &StyleComputer(computer) }
		if mutable.computed_property_page_recycling_ == unsafe { nil } {
			persistent := platform.enter_persistent()
			mut pool := &ComputedPropertyPageRecycling{owner: owner, pages: []&ComputedPropertyPage{cap: 64}}
			mutable.computed_property_page_recycling_ = pool
			mut storage := owner
			storage.add_cleanup(fn [mut pool] () {
				pool.active = false
				pool.pages.clear()
				pool.owner = unsafe { nil }
			})
			platform.leave_persistent(persistent)
		}
		mut pool := mutable.computed_property_page_recycling_
		if !pool.active { pool.epoch++; pool.active = true }
		mut store := unsafe { &ComputedPropertyStore(style.property_store_) }
		store.recycling = pool
		store.recycling_epoch = pool.epoch
	}
}

fn (mut store ComputedPropertyStore) copy_writable_page(source &ComputedPropertyPage) &ComputedPropertyPage {
	mut page := unsafe { &ComputedPropertyPage(nil) }
	if store.recycling != unsafe { nil } && store.recycling.can_reuse(store.recycling_epoch)
		&& store.recycling.pages.len > 0 {
		page = store.recycling.pages.pop()
	} else {
		return copy_computed_property_page(source)
	}
	for index in 0 .. computed_property_page_size { page.values[index] = source.values[index] }
	page.invalidate_device_layout_candidates()
	return page
}

@[heap]
struct ComputedPropertyPageInterner {
mut:
	pages map[u64]&ComputedPropertyPage
}

__global computed_empty_property_page &ComputedPropertyPage
__global computed_initial_property_store &ComputedPropertyStore

fn new_empty_computed_property_store() &ComputedPropertyStore {
	assert computed_property_page_count <= 32
	if computed_empty_property_page == unsafe { nil } {
		persistent := platform.enter_persistent()
		computed_empty_property_page = &ComputedPropertyPage{}
		platform.leave_persistent(persistent)
	}
	mut store := &ComputedPropertyStore{}
	for page in 0 .. computed_property_page_count {
		store.pages[page] = computed_empty_property_page
	}
	return store
}

fn new_initial_computed_property_store() &ComputedPropertyStore {
	assert computed_property_page_count <= 32
	if computed_initial_property_store == unsafe { nil } {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut initial := &ComputedPropertyStore{}
		for page_index in 0 .. computed_property_page_count {
			mut page := &ComputedPropertyPage{}
			for slot in 0 .. computed_property_page_size {
				index := page_index * computed_property_page_size + slot
				if index < number_of_longhand_properties {
					page.values[slot] = computed_interpolation_initial_value_cache[index]
				}
			}
			initial.pages[page_index] = page
		}
		computed_initial_property_store = initial
	}
	return copy_readonly_computed_property_store(computed_initial_property_store)
}

pub fn (c &ComputedProperties) raw_property_count() int {
	return if c.property_store_ == unsafe { nil } { 0 } else { number_of_longhand_properties }
}

pub fn (c &ComputedProperties) raw_property_at_index(index int) &dom.StyleValue {
	if c.property_store_ == unsafe { nil } || index < 0 || index >= number_of_longhand_properties {
		return unsafe { nil }
	}
	return c.property_store_.pages[index >> 4].values[index & 15]
}

fn (mut c ComputedProperties) set_raw_property_at_index(index int, value &dom.StyleValue) {
	assert index >= 0 && index < number_of_longhand_properties
	if c.property_store_ == unsafe { nil } {
		c.property_store_ = new_empty_computed_property_store()
	}
	mut store := c.property_store_
	page_index := index >> 4
	slot := index & 15
	if voidptr(store.pages[page_index].values[slot]) == voidptr(value) { return }
	bit := u32(1) << page_index
	if store.writable & bit == 0 {
		store.pages[page_index] = store.copy_writable_page(store.pages[page_index])
		store.writable |= bit
	}
	store.pages[page_index].values[slot] = unsafe { value }
	store.pages[page_index].invalidate_device_layout_candidates()
}

fn (c &ComputedProperties) clone_raw_property_store() &ComputedPropertyStore {
	if c.property_store_ == unsafe { nil } { return unsafe { nil } }
	mut source := unsafe { &ComputedPropertyStore(c.property_store_) }
	// All value aliases of the source see this freeze as well.
	source.writable = 0
	return copy_readonly_computed_property_store(source)
}

fn computed_property_pages_equal(first &ComputedPropertyPage, second &ComputedPropertyPage) bool {
	if voidptr(first) == voidptr(second) { return true }
	for index in 0 .. computed_property_page_size {
		if voidptr(first.values[index]) != voidptr(second.values[index]) { return false }
	}
	return true
}

fn computed_property_page_hash(page &ComputedPropertyPage) u64 {
	mut hash := u64(1469598103934665603)
	for value in page.values {
		hash = (hash ^ u64(voidptr(value))) * u64(1099511628211)
	}
	return hash
}

fn (mut pool ComputedPropertyPageInterner) intern(page &ComputedPropertyPage, hash u64) &ComputedPropertyPage {
	if previous := pool.pages[hash] {
		return if computed_property_pages_equal(previous, page) { previous } else { page }
	}
	if pool.pages.len < computed_property_page_pool_limit {
		pool.pages[hash] = unsafe { page }
	}
	return page
}

fn (computer &StyleComputer) publish_computed_property_pages(style &ComputedProperties) {
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	if style.property_store_ == unsafe { nil } { return }
	mut owner := unsafe { &StyleComputer(computer) }
	// Only the index is temporary. Interned pages keep the allocation owner of
	// their styles and remain readable after the outer batch retires this map.
	mut index_arena := computer.computed_property_page_index_arena()
	entry := index_arena.enter()
	defer { index_arena.leave(entry) }
	if owner.computed_property_page_interner_ == unsafe { nil } {
		owner.computed_property_page_interner_ = &ComputedPropertyPageInterner{}
	}
	mut pool := owner.computed_property_page_interner_
	mut store := unsafe { &ComputedPropertyStore(style.property_store_) }
	writable := store.writable
	store.writable = 0
	for index in 0 .. computed_property_page_count {
		mut page := store.pages[index]
		canonical := pool.intern(page, computed_property_page_hash(page))
		store.pages[index] = canonical
		// A value-copy alias shares this store and observes the replacement.
		// clone_raw_property_store() clears writable on the source, so a page
		// referenced by any independent snapshot can never enter this list.
		mut recycling := store.recycling
		if recycling != unsafe { nil } && recycling.active
			&& recycling.epoch == store.recycling_epoch
			&& voidptr(recycling) == voidptr(owner.computed_property_page_recycling_)
			&& writable & (u32(1) << index) != 0 && voidptr(page) != voidptr(canonical)
			&& recycling.owner.arena.contains(voidptr(page)) && recycling.pages.len < 64 {
			for slot in 0 .. computed_property_page_size { page.values[slot] = unsafe { nil } }
			page.invalidate_device_layout_candidates()
			recycling.pages << page
		}
	}
}

fn (computer &StyleComputer) computed_property_page_index_arena() &platform.Arena {
	mut owner := unsafe { &StyleComputer(computer) }
	if owner.computed_property_page_arena_ == unsafe { nil } {
		persistent := platform.enter_persistent()
		mut arena := platform.new_arena('computed property page index')
		owner.computed_property_page_arena_ = arena
		if computer.document_ != unsafe { nil } {
			mut storage := computer.document_.native_storage()
			if storage != unsafe { nil } {
				storage.add_cleanup(fn [mut arena] () { arena.release() })
			}
		}
		platform.leave_persistent(persistent)
	}
	return owner.computed_property_page_arena_
}

fn copy_computed_property_page(source &ComputedPropertyPage) &ComputedPropertyPage {
	mut page := &ComputedPropertyPage{}
	for index in 0 .. computed_property_page_size { page.values[index] = source.values[index] }
	return page
}

fn copy_readonly_computed_property_store(source &ComputedPropertyStore) &ComputedPropertyStore {
	mut store := &ComputedPropertyStore{}
	for index in 0 .. computed_property_page_count { store.pages[index] = source.pages[index] }
	return store
}

// A late successful initial-value parse updates only the template's page.
// Earlier styles retain the nil or previous pointer captured by their constructor.
fn update_initial_computed_property_page(index int, value &dom.StyleValue) {
	if computed_initial_property_store == unsafe { nil } { return }
	page_index := index >> 4
	mut page := copy_computed_property_page(computed_initial_property_store.pages[page_index])
	page.values[index & 15] = unsafe { value }
	computed_initial_property_store.pages[page_index] = page
}

fn (computer &StyleComputer) begin_computed_property_page_batch() {
	mut owner := unsafe { &StyleComputer(computer) }
	if owner.computed_property_page_batch_depth_ == 0 {
		owner.computed_property_page_interner_ = unsafe { nil }
	}
	owner.computed_property_page_batch_depth_++
}

fn (computer &StyleComputer) end_computed_property_page_batch() {
	mut owner := unsafe { &StyleComputer(computer) }
	assert owner.computed_property_page_batch_depth_ > 0
	owner.computed_property_page_batch_depth_--
	if owner.computed_property_page_batch_depth_ == 0 {
		// Drop the entire pool: map.clear retains stale values in the fallback.
		// Published readonly pages remain owned by the installed styles.
		owner.computed_property_page_interner_ = unsafe { nil }
		if owner.computed_property_page_recycling_ != unsafe { nil } {
			owner.computed_property_page_recycling_.active = false
		}
		if owner.computed_property_page_arena_ != unsafe { nil } {
			mut arena := owner.computed_property_page_arena_
			arena.reset()
		}
	}
}
