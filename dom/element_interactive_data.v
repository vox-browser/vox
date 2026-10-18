module dom

// Scalars formerly embedded in every Element. Snapshots are immutable after
// publication so ordinary V value copies remain independent on later writes.
@[heap]
struct ElementInteractiveData {
mut:
	scroll_offset_ CSSPixelPoint_
	snapped_scroll_areas_x_ []ScrollSnapAreaReference_
	snapped_scroll_areas_y_ []ScrollSnapAreaReference_
	popover_target_element_ ?&Element
}

fn (e &Element) interactive_scroll_offset() CSSPixelPoint_ {
	if e.interactive_data_ == unsafe { nil } { return CSSPixelPoint_{} }
	return e.interactive_data_.scroll_offset_
}

fn (e &Element) copy_interactive_data() &ElementInteractiveData {
	if e.interactive_data_ == unsafe { nil } { return &ElementInteractiveData{} }
	old := e.interactive_data_
	return &ElementInteractiveData{
		scroll_offset_: old.scroll_offset_
		snapped_scroll_areas_x_: old.snapped_scroll_areas_x_
		snapped_scroll_areas_y_: old.snapped_scroll_areas_y_
		popover_target_element_: old.popover_target_element_
	}
}

// HTML state has no eager V maps. Even the numerous anchors allocate only this
// compact record when their href hook initializes the URL cache.
@[heap]
struct HTMLElementRareData {
mut:
	popover_visibility_state_ PopoverVisibilityState
	popover_showing_or_hiding bool
	popover_trigger_          ?&HTMLElement
	opened_in_popover_mode_   ?string
	popover_close_watcher_    voidptr = unsafe { nil }
	popover_toggle_task_id_   u64
	popover_toggle_old_state_ string
	attached_internals_       voidptr = unsafe { nil }
	click_in_progress_        bool
	inert_                    bool
	cryptographic_nonce_      string
	labels_                   ?&NodeList
	hyperlink_url_            ?URL
	hyperlink_url_initialized bool
}

fn (e &HTMLElement) copy_html_rare_data() &HTMLElementRareData {
	if e.html_rare_data_ == unsafe { nil } { return &HTMLElementRareData{} }
	old := e.html_rare_data_
	return &HTMLElementRareData{
		popover_visibility_state_: old.popover_visibility_state_
		popover_showing_or_hiding: old.popover_showing_or_hiding
		popover_trigger_: old.popover_trigger_
		opened_in_popover_mode_: old.opened_in_popover_mode_
		popover_close_watcher_: old.popover_close_watcher_
		popover_toggle_task_id_: old.popover_toggle_task_id_
		popover_toggle_old_state_: old.popover_toggle_old_state_
		attached_internals_: old.attached_internals_
		click_in_progress_: old.click_in_progress_
		inert_: old.inert_
		cryptographic_nonce_: old.cryptographic_nonce_
		labels_: old.labels_
		hyperlink_url_: old.hyperlink_url_
		hyperlink_url_initialized: old.hyperlink_url_initialized

	}
}

pub fn (element &HTMLElement) popover_visibility_state() PopoverVisibilityState {
	if element.html_rare_data_ == unsafe { nil } { return .hidden }
	return element.html_rare_data_.popover_visibility_state_
}

pub fn (mut element HTMLElement) set_popover_visibility_state(value PopoverVisibilityState) {
	if element.popover_visibility_state() == value { return }
	mut state := element.copy_html_rare_data()
	state.popover_visibility_state_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) popover_showing_or_hiding() bool {
	if element.html_rare_data_ == unsafe { nil } { return false }
	return element.html_rare_data_.popover_showing_or_hiding
}

pub fn (mut element HTMLElement) set_popover_showing_or_hiding(value bool) {
	if element.popover_showing_or_hiding() == value { return }
	mut state := element.copy_html_rare_data()
	state.popover_showing_or_hiding = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) popover_trigger() ?&HTMLElement {
	if element.html_rare_data_ == unsafe { nil } { return none }
	return element.html_rare_data_.popover_trigger_
}

pub fn (mut element HTMLElement) set_popover_trigger(value ?&HTMLElement) {
	if value == none && element.popover_trigger() == none { return }
	if target := value {
		if previous := element.popover_trigger() {
			if voidptr(target) == voidptr(previous) { return }
		}
	}
	mut state := element.copy_html_rare_data()
	state.popover_trigger_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) opened_in_popover_mode() ?string {
	if element.html_rare_data_ == unsafe { nil } { return none }
	return element.html_rare_data_.opened_in_popover_mode_
}

pub fn (mut element HTMLElement) set_opened_in_popover_mode(value ?string) {
	if value == none && element.opened_in_popover_mode() == none { return }
	if mode := value {
		if previous := element.opened_in_popover_mode() {
			if mode == previous { return }
		}
	}
	mut state := element.copy_html_rare_data()
	state.opened_in_popover_mode_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) popover_close_watcher_handle() voidptr {
	if element.html_rare_data_ == unsafe { nil } { return unsafe { nil } }
	return element.html_rare_data_.popover_close_watcher_
}

pub fn (mut element HTMLElement) set_popover_close_watcher_handle(value voidptr) {
	if element.popover_close_watcher_handle() == value { return }
	mut state := element.copy_html_rare_data()
	state.popover_close_watcher_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) popover_toggle_task_id() u64 {
	if element.html_rare_data_ == unsafe { nil } { return u64(0) }
	return element.html_rare_data_.popover_toggle_task_id_
}

pub fn (mut element HTMLElement) set_popover_toggle_task_id(value u64) {
	if element.popover_toggle_task_id() == value { return }
	mut state := element.copy_html_rare_data()
	state.popover_toggle_task_id_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) popover_toggle_old_state() string {
	if element.html_rare_data_ == unsafe { nil } { return '' }
	return element.html_rare_data_.popover_toggle_old_state_
}

pub fn (mut element HTMLElement) set_popover_toggle_old_state(value string) {
	if element.popover_toggle_old_state() == value { return }
	mut state := element.copy_html_rare_data()
	state.popover_toggle_old_state_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) attached_internals_handle() voidptr {
	if element.html_rare_data_ == unsafe { nil } { return unsafe { nil } }
	return element.html_rare_data_.attached_internals_
}

pub fn (mut element HTMLElement) set_attached_internals_handle(value voidptr) {
	if element.attached_internals_handle() == value { return }
	mut state := element.copy_html_rare_data()
	state.attached_internals_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) click_in_progress() bool {
	if element.html_rare_data_ == unsafe { nil } { return false }
	return element.html_rare_data_.click_in_progress_
}

pub fn (mut element HTMLElement) set_click_in_progress(value bool) {
	if element.click_in_progress() == value { return }
	mut state := element.copy_html_rare_data()
	state.click_in_progress_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) inert() bool {
	if element.html_rare_data_ == unsafe { nil } { return false }
	return element.html_rare_data_.inert_
}

pub fn (mut element HTMLElement) set_inert(value bool) {
	if element.inert() == value { return }
	mut state := element.copy_html_rare_data()
	state.inert_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) cryptographic_nonce() string {
	if element.html_rare_data_ == unsafe { nil } { return '' }
	return element.html_rare_data_.cryptographic_nonce_
}

pub fn (mut element HTMLElement) set_cryptographic_nonce(value string) {
	if element.cryptographic_nonce() == value { return }
	mut state := element.copy_html_rare_data()
	state.cryptographic_nonce_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) labels_list() ?&NodeList {
	if element.html_rare_data_ == unsafe { nil } { return none }
	return element.html_rare_data_.labels_
}

pub fn (mut element HTMLElement) set_labels_list(value ?&NodeList) {
	if value == none && element.labels_list() == none { return }
	if target := value {
		if previous := element.labels_list() {
			if voidptr(target) == voidptr(previous) { return }
		}
	}
	mut state := element.copy_html_rare_data()
	state.labels_ = value
	element.html_rare_data_ = state
}

pub fn (element &HTMLElement) cached_hyperlink_url() ?URL {
	if element.html_rare_data_ == unsafe { nil } { return none }
	return element.html_rare_data_.hyperlink_url_
}

pub fn (element &HTMLElement) hyperlink_url_is_initialized() bool {
	return element.html_rare_data_ != unsafe { nil } && element.html_rare_data_.hyperlink_url_initialized
}

// Keep the null initialization separate: the compatibility compiler boxes a
// by-value Optional<URL> argument before a function's early-return guard.
pub fn (mut element HTMLElement) initialize_null_hyperlink_url_cache() {
	if element.hyperlink_url_is_initialized() && element.cached_hyperlink_url() == none { return }
	mut state := element.copy_html_rare_data()
	state.hyperlink_url_ = none
	state.hyperlink_url_initialized = true
	element.html_rare_data_ = state
}

pub fn (mut element HTMLElement) set_hyperlink_url_cache(value URL) {
	mut state := element.copy_html_rare_data()
	state.hyperlink_url_ = value
	state.hyperlink_url_initialized = true
	element.html_rare_data_ = state
}
