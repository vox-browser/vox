// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn intl_number_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'intl-number-format.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200000})
}

fn test_intl_number_format_localized_grouping_digits_and_parts() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_number_eval(mut vm, 'var f=new Intl.NumberFormat("en-US");f.format(1234567.89)==="1,234,567.89"&&f.formatToParts(1234.5).map(x=>x.type+":"+x.value).join("|")==="integer:1|group:,|integer:234|decimal:.|fraction:5"&&new Intl.NumberFormat("en-IN").format(1234567)==="12,34,567"&&new Intl.NumberFormat("de-DE").format(1234.5)==="1.234,5"&&new Intl.NumberFormat("en-US-u-nu-arab").format(12)==="١٢"')!.as_bool()
}

fn test_intl_number_format_decimal_strings_and_large_bigints_keep_exact_digits() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_number_eval(mut vm, 'var f=new Intl.NumberFormat("en-US",{useGrouping:false,maximumFractionDigits:3});f.format("9007199254740993.125")==="9007199254740993.125"&&f.format(9007199254740993123456789n)==="9007199254740993123456789"&&f.format("0x20000000000001")==="9007199254740993"&&new Intl.NumberFormat("en-US",{minimumFractionDigits:2,maximumFractionDigits:2}).format(1.005)==="1.01"')!.as_bool()
}

fn test_intl_number_format_compact_github_options_and_rounding_promote_magnitude() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_number_eval(mut vm, 'var f=Intl.NumberFormat("en-US",{notation:"compact",maximumFractionDigits:1,maximumSignificantDigits:2});f.format(12345)==="12K"&&f.format(98765)==="99K"&&f.format(999500)==="1M"&&new Intl.NumberFormat("en-US",{notation:"compact"}).format(1234)==="1.2K"&&new Intl.NumberFormat("en-US",{notation:"compact",compactDisplay:"long"}).format(1200)==="1.2 thousand"&&f.formatToParts(1200).some(x=>x.type==="compact"&&x.value==="K")')!.as_bool()
}

fn test_intl_number_format_rounding_priority_significant_zeroes_and_increments() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_number_eval(mut vm, 'new Intl.NumberFormat("en-US",{minimumFractionDigits:2,maximumFractionDigits:2,roundingIncrement:25,roundingMode:"halfEven"}).format(1.375)==="1.50"&&new Intl.NumberFormat("en-US",{minimumSignificantDigits:4}).format(1)==="1.000"&&new Intl.NumberFormat("en-US",{minimumFractionDigits:2,trailingZeroDisplay:"stripIfInteger"}).format(1)==="1"&&new Intl.NumberFormat("en-US",{maximumFractionDigits:2,maximumSignificantDigits:2,roundingPriority:"morePrecision"}).format(1.234)==="1.23"&&new Intl.NumberFormat("en-US",{maximumFractionDigits:2,maximumSignificantDigits:2,roundingPriority:"lessPrecision"}).format(1.234)==="1.2"')!.as_bool()
}

fn test_intl_number_format_signs_zero_nonfinite_and_scientific_notation() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_number_eval(mut vm, 'new Intl.NumberFormat("en-US").format(-0)==="-0"&&new Intl.NumberFormat("en-US",{signDisplay:"negative"}).format(-0)==="0"&&new Intl.NumberFormat("en-US",{signDisplay:"always"}).format(0)==="+0"&&new Intl.NumberFormat("en-US",{signDisplay:"exceptZero",maximumFractionDigits:0}).format(-0.1)==="0"&&new Intl.NumberFormat("en-US").format(Infinity)==="∞"&&new Intl.NumberFormat("en-US").format(NaN)==="NaN"&&new Intl.NumberFormat("en-US",{notation:"scientific"}).format(12345)==="1.235E4"&&new Intl.NumberFormat("en-US",{notation:"engineering"}).format(0.000123)==="123E-6"')!.as_bool()
}

fn test_intl_number_format_currency_percent_units_and_accounting() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_number_eval(mut vm, 'new Intl.NumberFormat("en-US",{style:"currency",currency:"usd"}).format(12)==="$12.00"&&new Intl.NumberFormat("en-US",{style:"currency",currency:"USD",currencyDisplay:"code"}).format(12)==="USD\u00a012.00"&&new Intl.NumberFormat("en-US",{style:"currency",currency:"USD",currencySign:"accounting"}).format(-12)==="($12.00)"&&new Intl.NumberFormat("en-US",{style:"currency",currency:"JPY"}).format(12.5)==="¥13"&&new Intl.NumberFormat("en-US",{style:"percent"}).format(0.125)==="13%"&&new Intl.NumberFormat("en-US",{style:"unit",unit:"liter",unitDisplay:"long"}).format(2)==="2 liters"&&new Intl.NumberFormat("en-US",{style:"unit",unit:"kilometer-per-hour",unitDisplay:"long"}).format(2)==="2 kilometers per hour"')!.as_bool()
}

fn test_intl_number_format_preserves_brand_and_effect_order() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_number_eval(mut vm, 'var order=[],o={get minimumFractionDigits(){order.push("minf");return 0},get maximumFractionDigits(){order.push("maxf");return 1},get minimumSignificantDigits(){order.push("mins");return 1},get maximumSignificantDigits(){order.push("maxs");return 2},get roundingIncrement(){order.push("inc");return 1},get roundingMode(){order.push("mode");return "halfExpand"}};new Intl.NumberFormat("en-US",o);order.join(",")==="minf,maxf,mins,maxs,inc,mode"&&Object.prototype.toString.call(new Intl.NumberFormat())==="[object Intl.NumberFormat]"')!.as_bool()
	assert intl_number_eval(mut vm, 'var f=new Intl.NumberFormat("en-US"),g=f.format,bad=false,reads=0;try{Object.getOwnPropertyDescriptor(Intl.NumberFormat.prototype,"format").get.call({})}catch(e){bad=e instanceof TypeError}bad&&g===f.format&&g.name===""&&g.length===1&&!("prototype" in g)&&g.call(null,1234)==="1,234"&&(function(){try{Intl.NumberFormat.prototype.formatToParts.call({}, {valueOf(){reads++;return 1}})}catch(e){return e instanceof TypeError&&reads===0}})()')!.as_bool()
}

fn test_number_to_locale_string_retains_intrinsic_and_checks_receiver_first() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_number_eval(mut vm, 'var nf=Intl.NumberFormat;Intl.NumberFormat=function(){throw 1};var good=(1234.5).toLocaleString("de-DE")==="1.234,5",reads=0,bad=false;try{Number.prototype.toLocaleString.call({}, {get length(){reads++;throw 2}})}catch(e){bad=e instanceof TypeError}Intl.NumberFormat=nf;good&&bad&&reads===0&&Number.prototype.toLocaleString.length===0')!.as_bool()
}

fn test_intl_number_format_rejects_invalid_currency_units_and_digit_options() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_number_eval(mut vm, '[{currency:"ıaa"},{currency:"ßa"},{unit:"meter-per-meter-per-second"},{roundingIncrement:3},{minimumFractionDigits:4,maximumFractionDigits:2},{roundingIncrement:5,minimumFractionDigits:0,maximumFractionDigits:1}].every(o=>{try{new Intl.NumberFormat("en-US",o);return false}catch(e){return e instanceof RangeError}})&&(function(){try{new Intl.NumberFormat("en-US",{maximumSignificantDigits:2,roundingIncrement:5});return false}catch(e){return e instanceof TypeError}})()')!.as_bool()
}

fn test_cached_intl_number_formatter_uses_native_entries_without_recompiling() {
	directory := os.join_path(os.temp_dir(), 'vox-intl-number-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert intl_number_eval(mut vm, 'function count(n){return Intl.NumberFormat("en-US",{notation:"compact",maximumFractionDigits:1,maximumSignificantDigits:2}).format(n)}count(12345)==="12K"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
