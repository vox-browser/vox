// Copyright (c) 2024-2025, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the self-contained data records of Libraries/LibWeb/Geolocation — GeolocationCoordinates
// (and its backing CoordinatesData), GeolocationPosition, and GeolocationPositionError. These are read-only
// value/record types used by the acquisition algorithm in geolocation.v.
// https://w3c.github.io/geolocation/
module geolocation

// https://w3c.github.io/geolocation/#the-epochtimestamp-typedef — a count of milliseconds since the Unix
// epoch (HighResolutionTime::EpochTimeStamp, an unsigned long long).
pub type EpochTimeStamp = u64

// The backing data for GeolocationCoordinates. accuracy/latitude/longitude are always present; the rest
// are null (none) when unavailable.
pub struct CoordinatesData {
pub:
	accuracy          f64
	latitude          f64
	longitude         f64
	altitude          ?f64
	altitude_accuracy ?f64
	heading           ?f64
	speed             ?f64
}

// https://w3c.github.io/geolocation/#coordinates_interface
@[heap]
pub struct GeolocationCoordinates {
	data CoordinatesData
}

pub fn GeolocationCoordinates.create(data CoordinatesData) &GeolocationCoordinates {
	return &GeolocationCoordinates{
		data: data
	}
}

pub fn (coordinates &GeolocationCoordinates) accuracy() f64 {
	return coordinates.data.accuracy
}

pub fn (coordinates &GeolocationCoordinates) latitude() f64 {
	return coordinates.data.latitude
}

pub fn (coordinates &GeolocationCoordinates) longitude() f64 {
	return coordinates.data.longitude
}

pub fn (coordinates &GeolocationCoordinates) altitude() ?f64 {
	return coordinates.data.altitude
}

pub fn (coordinates &GeolocationCoordinates) altitude_accuracy() ?f64 {
	return coordinates.data.altitude_accuracy
}

pub fn (coordinates &GeolocationCoordinates) heading() ?f64 {
	return coordinates.data.heading
}

pub fn (coordinates &GeolocationCoordinates) speed() ?f64 {
	return coordinates.data.speed
}

pub fn (coordinates &GeolocationCoordinates) to_json() CoordinatesData {
	return coordinates.data
}

// https://w3c.github.io/geolocation/#dom-geolocationposition
@[heap]
pub struct GeolocationPosition {
	coords_           &GeolocationCoordinates
	timestamp_        EpochTimeStamp
	is_high_accuracy_ bool
}

pub fn GeolocationPosition.create(coords &GeolocationCoordinates, timestamp EpochTimeStamp, is_high_accuracy bool) &GeolocationPosition {
	return &GeolocationPosition{
		coords_: coords
		timestamp_: timestamp
		is_high_accuracy_: is_high_accuracy
	}
}

pub fn GeolocationPosition.coords_offset() uint {
	return uint(__offsetof(GeolocationPosition, coords_))
}

pub fn (position &GeolocationPosition) coords() &GeolocationCoordinates {
	return position.coords_
}

pub fn (position &GeolocationPosition) timestamp() EpochTimeStamp {
	return position.timestamp_
}

// https://w3c.github.io/geolocation/#dfn-ishighaccuracy
pub fn (position &GeolocationPosition) is_high_accuracy() bool {
	return position.is_high_accuracy_
}

pub struct GeolocationPositionJSON {
pub:
	coords    CoordinatesData
	timestamp EpochTimeStamp
}

pub fn (position &GeolocationPosition) to_json() GeolocationPositionJSON {
	return GeolocationPositionJSON{
		coords: position.coords_.to_json()
		timestamp: position.timestamp_
	}
}

// https://w3c.github.io/geolocation/#dom-geolocationpositionerror
pub enum GeolocationPositionErrorCode as u16 {
	permission_denied    = 1
	position_unavailable = 2
	timeout              = 3
}

@[heap]
pub struct GeolocationPositionError {
	code_ GeolocationPositionErrorCode
}

pub fn GeolocationPositionError.create(code GeolocationPositionErrorCode) &GeolocationPositionError {
	return &GeolocationPositionError{
		code_: code
	}
}

pub fn (error &GeolocationPositionError) code() GeolocationPositionErrorCode {
	return error.code_
}

// A developer-friendly textual description of the code.
pub fn (error &GeolocationPositionError) message() string {
	return match error.code_ {
		.permission_denied { 'Permission denied' }
		.position_unavailable { 'Position unavailable' }
		.timeout { 'Timeout' }
	}
}
