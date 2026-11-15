// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math
import time

struct IntlTimeZone {
	identifier string
	location ?&time.Location
	offset_seconds int
}

fn intl_offset_identifier(offset int) string {
	positive := if offset < 0 { -offset } else { offset }
	return (if offset < 0 { '-' } else { '+' }) + '${positive / 3600:02}:${positive % 3600 / 60:02}'
}

fn intl_parse_time_zone(mut vm VM, value Value) !IntlTimeZone {
	core := intl_core_data(mut vm)!
	if value.is_undefined() {
		location := time.load_location('Local') or { return vm.throw_error(.internal_error, 'Unable to load system time zone') }
		if location.name != 'Local' {
			return IntlTimeZone{identifier: core.zone_alias[location.name.to_lower()] or { location.name }, location: location}
		}
		zone := location.zone_at(time.now().unix()) or { return vm.throw_error(.internal_error, 'Unable to resolve system time zone') }
		return IntlTimeZone{identifier: intl_offset_identifier(zone.offset), location: location}
	}
	text := intl_ascii(mut vm, value.to_primitive_string(mut vm)!.utf16)!
	if text.starts_with('+') || text.starts_with('-') {
		body := text[1..].replace(':', '')
		if (body.len != 2 && body.len != 4) || !intl_digits(body) || (text.contains(':') && (text.len != 6 || text[3] != `:`)) { return vm.throw_error(.range_error, 'Invalid Intl time zone offset') }
		hours := body[..2].int(); minutes := if body.len == 4 { body[2..].int() } else { 0 }
		if hours >= 24 || minutes >= 60 { return vm.throw_error(.range_error, 'Invalid Intl time zone offset') }
		offset := (hours * 3600 + minutes * 60) * if text[0] == `-` { -1 } else { 1 }
		return IntlTimeZone{identifier: intl_offset_identifier(offset), offset_seconds: offset}
	}
	identifier := core.zone_alias[text.to_lower()] or { return vm.throw_error(.range_error, 'Unknown Intl time zone: ' + text) }
	location := time.load_location(identifier) or { return vm.throw_error(.range_error, 'Unavailable Intl time zone: ' + identifier) }
	return IntlTimeZone{identifier: identifier, location: location}
}

fn intl_time_zone_rule(mut vm VM, zone IntlTimeZone, stamp f64) !time.Zone {
	if location := zone.location { return location.zone_at(i64(math.floor(stamp / 1000))) or { return vm.throw_error(.range_error, 'Unable to resolve Intl time zone rule') } }
	return time.Zone{name: zone.identifier, offset: zone.offset_seconds}
}

fn intl_zone_offset_name(data &IntlDateLocaleData, offset int, long bool) string {
	if offset == 0 { return data.gmt_zero }
	abs := if offset < 0 { -offset } else { offset }
	patterns := data.hour_format.split(';')
	pattern := patterns[if offset < 0 && patterns.len > 1 { 1 } else { 0 }]
	mut text := pattern.replace('HH', if long { '${abs / 3600:02}' } else { '${abs / 3600}' }).replace('mm', '${abs % 3600 / 60:02}')
	if !long && abs % 3600 == 0 {
		text = text.replace(':00', '').replace('.00', '')
	}
	if abs % 60 != 0 { text += ':${abs % 60:02}' }
	return data.gmt_format.replace('{0}', text)
}

fn intl_zone_name(mut vm VM, data &IntlDateLocaleData, zone IntlTimeZone, rule time.Zone, stamp f64, style string) !string {
	if style.ends_with('Offset') { return intl_zone_offset_name(data, rule.offset, style.starts_with('long')) }
	core := intl_core_data(mut vm)!
	width := if style.starts_with('long') { 'long' } else { 'short' }
	kind := if style.ends_with('Generic') { 'generic' } else if rule.is_dst { 'daylight' } else { 'standard' }
	key := if zone.identifier == 'UTC' { 'Etc/UTC' } else { zone.identifier }
	names := (data.zone_names[key] or { map[string]string{} }).clone()
	if name := names[width + '_' + kind] { return name }
	// CLDR metazone intervals are in UTC, independent of the display zone.
	iso := date_iso_string(stamp)
	instant := if iso.starts_with('-') { '' } else if iso.starts_with('+') { '~' } else { iso.replace('T', ' ')[..16] }
	for period in core.meta_zones[zone.identifier] {
		if (period.start == '' || instant >= period.start) && (period.end == '' || instant < period.end) {
			if name := data.meta_zone_names[period.name][width + '_' + kind] { return name }
			break
		}
	}
	if style.ends_with('Generic') {
		if city := names['city'] { if city != '' { return data.region_format.replace('{0}', city) } }
	}
	return intl_zone_offset_name(data, rule.offset, style.starts_with('long'))
}
