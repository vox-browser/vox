module css

@[heap]
struct FontVariationAxisStorage {
mut:
	values map[string]f64
}

pub fn (settings &FontVariationSettings) axis_count() int {
	if settings.axis_storage_ == unsafe { nil } {
		return 0
	}
	return settings.axis_storage_.values.len
}

pub fn (settings &FontVariationSettings) has_axes() bool {
	return settings.axis_count() != 0
}

pub fn (settings &FontVariationSettings) axis_value(tag string) ?f64 {
	if settings.axis_storage_ == unsafe { nil } {
		return none
	}
	return settings.axis_storage_.values[tag] or { return none }
}

// Public snapshots own their map; internal empty reads use axis_value/count.
pub fn (settings &FontVariationSettings) axis_values() map[string]f64 {
	if settings.axis_storage_ == unsafe { nil } {
		return map[string]f64{}
	}
	return settings.axis_storage_.values.clone()
}

pub fn (mut settings FontVariationSettings) set_axis(tag string, value f64) {
	if settings.axis_storage_ == unsafe { nil } {
		settings.axis_storage_ = &FontVariationAxisStorage{
			values: map[string]f64{}
		}
	}
	settings.axis_storage_.values[tag] = value
}

pub fn (mut settings FontVariationSettings) set_axes(values map[string]f64) {
	if values.len == 0 {
		settings.axis_storage_ = unsafe { nil }
		return
	}
	settings.axis_storage_ = &FontVariationAxisStorage{
		values: values.clone()
	}
}

pub fn (mut settings FontVariationSettings) remove_axis(tag string) {
	if settings.axis_storage_ == unsafe { nil } {
		return
	}
	settings.axis_storage_.values.delete(tag)
	if settings.axis_storage_.values.len == 0 {
		settings.axis_storage_ = unsafe { nil }
	}
}

pub fn (settings &FontVariationSettings) axis_values_equal(other &FontVariationSettings) bool {
	if !settings.has_axes() {
		return !other.has_axes()
	}
	if !other.has_axes() {
		return false
	}
	return settings.axis_storage_.values == other.axis_storage_.values
}

// Cascade copies retain numeric inputs and own each nonempty mutable axis map.
// Ordinary fonts have no axis map, so copying them allocates no map or holder.
pub fn (settings &FontVariationSettings) owned_clone() FontVariationSettings {
	mut result := FontVariationSettings{
		weight: settings.weight
		width: settings.width
		opsz: settings.opsz
	}
	if settings.has_axes() {
		result.axis_storage_ = &FontVariationAxisStorage{
			values: settings.axis_storage_.values.clone()
		}
	}
	return result
}
