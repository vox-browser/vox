// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math
import time

// Runtime/Date.{h,cpp}: [[DateValue]], TimeClip, MakeDay/MakeTime/MakeDate.
// The host supplies the wall clock and local UTC offsets; calendar arithmetic
// and JavaScript conversions stay in LibJS.
@[heap]
pub struct DateObject {
pub:
	object &Object
pub mut:
	date_value f64
}

fn create_date_object(realm &Realm, prototype &Object, value f64) &Object {
	mut object := Object.create(realm, prototype)
	object.class_name = 'Date'
	object.mut_slots().date_object = &DateObject{ object: object, date_value: value }
	return object
}

fn date_time_clip(value f64) f64 {
	if !Value.from_f64(value).is_finite_number() || math.abs(value) > 8.64e15 {
		return math.nan()
	}
	// TimeClip returns positive zero for either sign of a truncated zero.
	return if value == 0 || math.abs(value) < 1 { 0.0 } else { math.trunc(value) }
}

fn date_day_from_year(year f64) f64 {
	return 365 * (year - 1970) + math.floor((year - 1969) / 4) -
		math.floor((year - 1901) / 100) + math.floor((year - 1601) / 400)
}

fn date_make_day(year f64, month f64, day f64) f64 {
	if !Value.from_f64(year).is_finite_number() || !Value.from_f64(month).is_finite_number()
		|| !Value.from_f64(day).is_finite_number() {
		return math.nan()
	}
	y := math.trunc(year) + math.floor(math.trunc(month) / 12)
	m := int(math.fmod(math.fmod(math.trunc(month), 12) + 12, 12))
	leap := math.fmod(y, 4) == 0 && (math.fmod(y, 100) != 0 || math.fmod(y, 400) == 0)
	before := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	return date_day_from_year(y) + before[m] + (if leap && m >= 2 { 1 } else { 0 }) + math.trunc(day) - 1
}

fn date_make_time(hour f64, minute f64, second f64, millisecond f64) f64 {
	for value in [hour, minute, second, millisecond] {
		if !Value.from_f64(value).is_finite_number() { return math.nan() }
	}
	return math.trunc(hour) * 3600000 + math.trunc(minute) * 60000 +
		math.trunc(second) * 1000 + math.trunc(millisecond)
}

fn date_make_date(year f64, month f64, day f64, hour f64, minute f64, second f64, millisecond f64) f64 {
	return date_make_day(year, month, day) * 86400000 + date_make_time(hour, minute, second, millisecond)
}

fn date_local_time(value f64) f64 {
	local := time.unix_milli(i64(value)).local()
	return f64(local.local_unix() * 1000 + local.nanosecond / 1000000)
}

// UTC(t), including compatible disambiguation: the earlier instant for an
// overlap, and the offset before a forward transition for a skipped time.
fn date_utc_time(value f64) f64 {
	if !Value.from_f64(value).is_finite_number() || math.abs(value) > 8.64e15 + 172800000 {
		return math.nan()
	}
	before := value - 86400000
	after := value + 86400000
	before_offset := date_local_time(before) - before
	after_offset := date_local_time(after) - after
	mut found := false
	mut earliest := 0.0
	for offset in [before_offset, after_offset] {
		candidate := value - offset
		if date_local_time(candidate) == value && (!found || candidate < earliest) {
			found = true
			earliest = candidate
		}
	}
	return if found { earliest } else { value - before_offset }
}

fn this_date_object(mut vm VM) !&DateObject {
	value := vm.this_value()
	if value.is_object() {
		if date := value.as_object().slots.date_object { return date }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'Date')
}

fn date_year_text(year int, extended bool) string {
	if extended && (year < 0 || year > 9999) {
		return if year < 0 { '-${-year:06}' } else { '+${year:06}' }
	}
	return if year < 0 { '-${-year:04}' } else { '${year:04}' }
}

fn date_iso_string(value f64) string {
	t := time.unix_milli(i64(value))
	return '${date_year_text(t.year, true)}-${t.month:02}-${t.day:02}T${t.hour:02}:${t.minute:02}:${t.second:02}.${t.nanosecond / 1000000:03}Z'
}

fn date_date_string(value f64, utc bool) string {
	t := time.unix_milli(i64(value))
	weekdays := ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	day := int(math.fmod(math.fmod(math.floor(value / 86400000) + 4, 7) + 7, 7))
	return if utc {
		'${weekdays[day]}, ${t.day:02} ${months[t.month - 1]} ${date_year_text(t.year, false)}'
	} else {
		'${weekdays[day]} ${months[t.month - 1]} ${t.day:02} ${date_year_text(t.year, false)}'
	}
}

fn date_time_string(value f64) string {
	local := date_local_time(value)
	t := time.unix_milli(i64(local))
	offset := int((local - value) / 60000)
	abs_offset := if offset < 0 { -offset } else { offset }
	sign := if offset < 0 { '-' } else { '+' }
	return '${t.hour:02}:${t.minute:02}:${t.second:02} GMT${sign}${abs_offset / 60:02}${abs_offset % 60:02}'
}

fn date_to_string(value f64) string {
	if math.is_nan(value) { return 'Invalid Date' }
	return date_date_string(date_local_time(value), false) + ' ' + date_time_string(value)
}
