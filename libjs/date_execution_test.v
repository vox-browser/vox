// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math
import os
import time

fn date_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'date.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 }) or {
		if is_throw_completion(err) {
			value := thrown_value(err)
			message := if value.is_object() {
				value.as_object().error_message() or { value.str() }
			} else {
				value.str()
			}
			return error('${source}: ${message}')
		}
		return err
	}
}

fn test_date_clock_intrinsic_graph_descriptors_and_brand_checks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	before := time.utc().unix_milli()
	observed := date_eval(mut vm, 'Date.now()')!.number
	assert observed >= before && observed <= time.utc().unix_milli()
	assert date_eval(mut vm, 'Date.length===7 && Date.now.length===0 && Date.parse.length===1 && Date.UTC.length===7 && Date.prototype.constructor===Date && Object.getPrototypeOf(Date)===Object.getPrototypeOf(Object) && Object.getPrototypeOf(Date.prototype)===Object.prototype && Object.prototype.toString.call(new Date(0))==="[object Date]" && Object.prototype.toString.call(Date.prototype)==="[object Object]"')!.as_bool()
	assert date_eval(mut vm, 'var descriptor=Object.getOwnPropertyDescriptor(Date.prototype,"getTime");descriptor.writable&&!descriptor.enumerable&&descriptor.configurable&&descriptor.value.name==="getTime"&&Date.prototype.toGMTString===Date.prototype.toUTCString')!.as_bool()
	assert date_eval(mut vm, 'var brands=0;try{Date.prototype.getTime.call(Date.prototype)}catch(e){if(e instanceof TypeError)brands++};try{Date.prototype.setTime.call({valueOf:function(){throw 1}},0)}catch(e){if(e instanceof TypeError)brands++};brands')!.number == 2
}

fn test_date_numeric_construction_copy_time_clip_and_conversion_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert date_eval(mut vm, 'new Date(-1.9).getTime()===-1 && Object.is(new Date(-0.5).getTime(),0) && new Date(null).getTime()===0 && isNaN(new Date(undefined).getTime()) && isNaN(new Date(Infinity).getTime()) && isNaN(new Date(8640000000000001).getTime())')!.as_bool()
	assert date_eval(mut vm, 'var original=new Date(42);original.valueOf=function(){throw "must not convert"};original[Symbol.toPrimitive]=function(){throw "must not convert"};var copy=new Date(original);copy!==original&&copy.getTime()===42')!.as_bool()
	assert date_eval(mut vm, 'var order="";var stamp=new Date({valueOf:function(){order+="v";return 123.9},toString:function(){order+="s";return "bad"}});stamp.getTime()+":"+order')!.as_string().str() == '123:v'
	assert date_eval(mut vm, 'var count=0;Date({toString:function(){count++;throw 1}});count')!.number == 0
}

fn test_date_utc_calendar_rollovers_leap_years_negative_and_extended_years() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert date_eval(mut vm, 'Date.UTC(1970,0,1)===0 && Date.UTC(99,0,1)===915148800000 && Date.UTC(2000,1,29)===951782400000 && Date.UTC(1900,1,29)===-2203891200000 && Date.UTC(1970,-1,32)===0 && Date.UTC(1970,0,1,0,0,-1,999)===-1 && isNaN(Date.UTC())')!.as_bool()
	assert date_eval(mut vm, 'new Date(-1).toISOString()')!.as_string().str() == '1969-12-31T23:59:59.999Z'
	assert date_eval(mut vm, 'new Date(-62167219200000).toISOString()')!.as_string().str() == '0000-01-01T00:00:00.000Z'
	assert date_eval(mut vm, 'new Date(-8640000000000000).toISOString()')!.as_string().str() == '-271821-04-20T00:00:00.000Z'
	assert date_eval(mut vm, 'new Date(8640000000000000).toISOString()')!.as_string().str() == '+275760-09-13T00:00:00.000Z'
	assert date_eval(mut vm, 'var d=new Date(-1);d.getUTCFullYear()+":"+d.getUTCMonth()+":"+d.getUTCDate()+":"+d.getUTCDay()+":"+d.getUTCHours()+":"+d.getUTCMinutes()+":"+d.getUTCSeconds()+":"+d.getUTCMilliseconds()')!.as_string().str() == '1969:11:31:3:23:59:59:999'
}

fn test_date_iso_parser_offsets_default_fields_invalid_inputs_and_native_roundtrips() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert date_eval(mut vm, 'Date.parse("1970")===0&&Date.parse("1970-01")===0&&Date.parse("1970-01-01T00:00:00.000Z")===0&&Date.parse("1970-01-01T01:30+01:30")===0&&Date.parse("1969-12-31T24:00Z")===0&&new Date("2000-02-29T12:34:56.789Z").toISOString()==="2000-02-29T12:34:56.789Z"')!.as_bool()
	for source in ['', '-000000-01-01', '1970-13-01', '1970-00-01', '1970-01-32', '1970-01-01T24:01Z',
		'1970-01-01T00:00:60Z', '1970-01-01T00:00+24:00', '1970-01-01T00:00:00.00Z',
		'1970-01-01T00:00Zjunk'] {
		assert math.is_nan(parse_date_string(utf16_string(source))), source
	}
	assert date_eval(mut vm, 'var d=new Date(-2203891200000);Date.parse(d.toString())===d.getTime()&&Date.parse(d.toUTCString())===d.getTime()&&Date.parse(d.toISOString())===d.getTime()')!.as_bool()
	assert date_eval(mut vm, 'var seen="";Date.parse({toString:function(){seen+="s";return "1970-01-01"},valueOf:function(){throw 1}});seen')!.as_string().str() == 's'
}

fn test_date_setters_capture_old_time_convert_in_order_and_recover_invalid_dates() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert date_eval(mut vm, 'var d=new Date(0);d.setUTCFullYear(2000,1,29);d.setUTCHours(12,34,56,789);d.toISOString()')!.as_string().str() == '2000-02-29T12:34:56.789Z'
	assert date_eval(mut vm, 'd.setUTCMonth(12);d.setUTCDate(0);d.setUTCMinutes(60);d.setUTCSeconds(-1,999);d.toISOString()')!.as_string().str() == '2000-12-31T12:59:59.999Z'
	assert date_eval(mut vm, 'var d=new Date(0);var order="";d.setUTCHours({valueOf:function(){order+="h";d.setTime(999999);return 1}},{valueOf:function(){order+="m";return 2}});d.getTime()+":"+order')!.as_string().str() == '3720000:hm'
	assert date_eval(mut vm, 'var d=new Date(NaN);var converted=0;d.setUTCHours(1,{valueOf:function(){converted++;return 2}});isNaN(d.getTime())&&converted===1&&d.setUTCFullYear(2000)===946684800000')!.as_bool()
	assert date_eval(mut vm, 'var d=new Date(42);var sentinel={};try{d.setUTCMinutes(1,{valueOf:function(){throw sentinel}})}catch(e){if(e!==sentinel)throw 1};d.getTime()')!.number == 42
}

fn test_date_json_and_primitive_conversion_are_generic_and_preserve_exceptions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert date_eval(mut vm, 'new Date(0).toJSON()==="1970-01-01T00:00:00.000Z"&&new Date(NaN).toJSON()===null&&new Date(NaN).toString()==="Invalid Date"&&typeof Date()==="string"')!.as_bool()
	assert date_eval(mut vm, 'var reads="";var object={valueOf:function(){reads+="v";return 1},toISOString:function(){reads+="i";return this}};Date.prototype.toJSON.call(object)===object&&reads==="vi"')!.as_bool()
	assert date_eval(mut vm, 'var object={valueOf:function(){return 42},toString:function(){return "string"}};var convert=Date.prototype[Symbol.toPrimitive];convert.call(object,"default")==="string"&&convert.call(object,"number")===42&&new Date(0)+""===new Date(0).toString()&&+new Date(42)===42')!.as_bool()
	assert date_eval(mut vm, 'var errors=0;try{new Date(NaN).toISOString()}catch(e){if(e instanceof RangeError)errors++};try{convert.call(object,{toString:function(){return "number"}})}catch(e){if(e instanceof TypeError)errors++};errors')!.number == 2
}

fn test_date_local_construction_getters_setters_and_dst_disambiguation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert date_eval(mut vm, 'var d=new Date(2000,1,29,12,34,56,789);d.getFullYear()===2000&&d.getMonth()===1&&d.getDate()===29&&d.getHours()===12&&d.getMinutes()===34&&d.getSeconds()===56&&d.getMilliseconds()===789&&d.getDay()===2&&d.getYear()===100')!.as_bool()
	assert date_eval(mut vm, 'd.setFullYear(2001,0,1);d.setHours(1,2,3,4);d.setMonth(1);d.setDate(2);d.setMinutes(4);d.setSeconds(5);d.setMilliseconds(6);d.getFullYear()+":"+d.getMonth()+":"+d.getDate()+":"+d.getHours()+":"+d.getMinutes()+":"+d.getSeconds()+":"+d.getMilliseconds()')!.as_string().str() == '2001:1:2:1:4:5:6'
	if os.getenv('TZ') == 'America/New_York' {
		gap := date_eval(mut vm, 'new Date(2024,2,10,2,30).toISOString()')!.as_string().str()
		assert gap == '2024-03-10T07:30:00.000Z'
		assert date_eval(mut vm, 'new Date(2024,10,3,1,30).toISOString()')!.as_string().str() == '2024-11-03T05:30:00.000Z'
		assert date_eval(mut vm, 'Date.parse("2024-03-10T02:30:00")')!.number == 1710055800000
		assert date_eval(mut vm, 'new Date("2024-01-01T00:00Z").getTimezoneOffset()===300&&new Date("2024-07-01T00:00Z").getTimezoneOffset()===240')!.as_bool()
	}
}
