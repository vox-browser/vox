// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import platform
import rand

fn intl_date_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'intl-date-time-format.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 300000})
}

fn test_intl_date_time_format_github_patterns_use_real_cldr_data_and_utc_dates() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'var f=Intl.DateTimeFormat("en-US",{month:"short",day:"numeric",year:"numeric",timeZone:"UTC"});f.format(0)==="Jan 1, 1970"&&f instanceof Intl.DateTimeFormat&&Intl.DateTimeFormat.length===0&&Object.prototype.toString.call(f)==="[object Intl.DateTimeFormat]"')!.as_bool()
	assert intl_date_eval(mut vm, 'var f=new Intl.DateTimeFormat("en-US",{dateStyle:"long",timeZone:"UTC"}),r=f.resolvedOptions();f.format(0)==="January 1, 1970"&&r.dateStyle==="long"&&r.year===undefined&&r.month===undefined&&r.locale==="en-US"&&r.calendar==="gregory"&&r.numberingSystem==="latn"&&r.timeZone==="UTC"')!.as_bool()
	assert intl_date_eval(mut vm, 'new Intl.DateTimeFormat("en-US",{timeZone:"UTC"}).format(0)==="1/1/1970"&&new Intl.DateTimeFormat("en-GB",{timeZone:"UTC"}).format(0)==="01/01/1970"&&new Intl.DateTimeFormat("en-US",{year:"2-digit",month:"2-digit",day:"2-digit",timeZone:"UTC"}).format(0)==="01/01/70"')!.as_bool()
}

fn test_intl_date_time_format_uses_locale_contexts_and_non_latin_digits() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'var month=new Intl.DateTimeFormat("ru-RU",{month:"long",timeZone:"UTC"}),date=new Intl.DateTimeFormat("ru-RU",{month:"long",day:"numeric",timeZone:"UTC"});month.format(0)==="январь"&&date.format(0)==="1 января"')!.as_bool()
	assert intl_date_eval(mut vm, 'var f=new Intl.DateTimeFormat("en-US-u-nu-arab",{year:"numeric",month:"short",day:"numeric",timeZone:"UTC"});f.format(0)==="Jan ١, ١٩٧٠"&&f.resolvedOptions().numberingSystem==="arab"&&f.resolvedOptions().locale==="en-US-u-nu-arab"')!.as_bool()
}

fn test_intl_date_time_format_hour_cycles_fractional_seconds_and_day_periods() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'var a=new Intl.DateTimeFormat("en-US",{hour:"numeric",minute:"numeric",timeZone:"UTC"}),b=new Intl.DateTimeFormat("en-US",{hour:"numeric",minute:"numeric",second:"numeric",fractionalSecondDigits:3,hourCycle:"h23",timeZone:"UTC"});a.format(0)==="12:00 AM"&&a.resolvedOptions().hour12&&a.resolvedOptions().dayPeriod===undefined&&b.format(123.9)==="00:00:00.123"&&b.resolvedOptions().fractionalSecondDigits===3&&!b.resolvedOptions().hour12')!.as_bool()
	assert intl_date_eval(mut vm, 'var a=new Intl.DateTimeFormat("en-US-u-hc-h24",{hour:"numeric",hour12:false,timeZone:"UTC"}),b=new Intl.DateTimeFormat("en-US",{hour:"numeric",hourCycle:"h24",timeZone:"UTC"});a.format(0)==="00"&&a.resolvedOptions().hourCycle==="h23"&&b.format(0)==="24"&&b.resolvedOptions().hourCycle==="h24"')!.as_bool()
}

fn test_intl_date_time_format_parts_and_bound_format_keep_identity_and_brand_checks() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'var f=new Intl.DateTimeFormat("en-US",{year:"numeric",month:"short",day:"numeric",timeZone:"UTC"}),bound=f.format,p=f.formatToParts(0);bound===f.format&&bound.call({},0)==="Jan 1, 1970"&&p.map(x=>x.value).join("")===bound(0)&&p.map(x=>x.type).join()==="month,literal,day,literal,year"&&bound.length===1&&Object.getPrototypeOf(bound)===Function.prototype&&Function.prototype.toString.call(bound).includes("[native code]")&&!Object.hasOwn(bound,"prototype")&&Object.getPrototypeOf(p[0])===Object.prototype')!.as_bool()
	assert intl_date_eval(mut vm, 'var errors=0;for(var f of [()=>Intl.DateTimeFormat.prototype.formatToParts.call({},0),()=>Intl.DateTimeFormat.prototype.resolvedOptions.call({}),()=>Object.getOwnPropertyDescriptor(Intl.DateTimeFormat.prototype,"format").get.call({})])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===3')!.as_bool()
}

fn test_intl_date_time_format_named_zones_offsets_dst_and_canonical_aliases() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'var f=new Intl.DateTimeFormat("en-US",{year:"numeric",month:"short",day:"numeric",hour:"numeric",minute:"numeric",timeZoneName:"short",timeZone:"america/new_york"});f.resolvedOptions().timeZone==="America/New_York"&&f.format(0)==="Dec 31, 1969, 7:00 PM EST"&&f.format(Date.UTC(2024,6,1)).endsWith("EDT")')!.as_bool()
	assert intl_date_eval(mut vm, 'var f=new Intl.DateTimeFormat("en-US",{hour:"numeric",minute:"numeric",timeZoneName:"shortOffset",timeZone:"+0330"});f.format(0)==="3:30 AM GMT+3:30"&&f.resolvedOptions().timeZone==="+03:30"&&new Intl.DateTimeFormat("en-US",{timeZone:"gmt"}).resolvedOptions().timeZone==="UTC"')!.as_bool()
}

fn test_intl_date_time_format_validates_options_and_reads_them_in_spec_order() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'var seen="",options=new Proxy({timeZone:"UTC"},{get(t,k,r){seen+=k+",";return Reflect.get(t,k,r)}});new Intl.DateTimeFormat("en-US",options);seen==="localeMatcher,calendar,numberingSystem,hour12,hourCycle,timeZone,weekday,era,year,month,day,dayPeriod,hour,minute,second,fractionalSecondDigits,timeZoneName,formatMatcher,dateStyle,timeStyle,"')!.as_bool()
	assert intl_date_eval(mut vm, 'var errors=0;for(var options of [null,{month:"invalid"},{calendar:"bad_calendar"},{timeZone:"../etc/passwd"},{timeZone:"+24:00"},{timeZone:"+00:60"},{fractionalSecondDigits:0},{fractionalSecondDigits:4},{fractionalSecondDigits:NaN},{dateStyle:"long",year:"numeric"}])try{new Intl.DateTimeFormat("en-US",options)}catch(e){if(e instanceof Error)errors++}errors===10')!.as_bool()
	assert intl_date_eval(mut vm, 'var marker={},same=false;try{new Intl.DateTimeFormat({get length(){throw marker}})}catch(e){same=e===marker}same')!.as_bool()
}

fn test_intl_date_time_format_supported_locales_extensions_and_subclass_prototypes() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'Intl.DateTimeFormat.supportedLocalesOf(["en-us","zz-ZZ","de-de"]).join()==="en-US,de-DE"&&Intl.DateTimeFormat.supportedLocalesOf.length===1')!.as_bool()
	assert intl_date_eval(mut vm, 'class D extends Intl.DateTimeFormat{}var f=new D("en-US-u-ca-iso8601-hc-h23-nu-arab",{timeZone:"UTC"}),r=f.resolvedOptions();f instanceof D&&r.calendar==="iso8601"&&r.numberingSystem==="arab"&&r.locale==="en-US-u-ca-iso8601-hc-h23-nu-arab"')!.as_bool()
}

fn test_intl_date_time_format_date_conversion_preserves_abrupt_values_and_rejects_invalid_time() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'var f=new Intl.DateTimeFormat("en-US",{timeZone:"UTC"}),errors=0;for(var value of [NaN,Infinity,-Infinity,8640000000000001,1n,Symbol()])try{f.format(value)}catch(e){if(e instanceof Error)errors++}var marker={},same=false;try{f.format({valueOf(){throw marker}})}catch(e){same=e===marker}errors===6&&same&&typeof f.format()==="string"')!.as_bool()
}

fn test_intl_date_time_format_cached_data_and_bound_functions_survive_temporary_storage() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut arena := platform.new_arena('native Intl date constructor')
	entry := arena.enter()
	intl_date_eval(mut vm, 'var formatter=new Intl.DateTimeFormat("en-US",{year:"numeric",month:"short",day:"numeric",timeZone:"UTC"}),bound=formatter.format')!
	arena.leave(entry)
	value := vm.global_object().get(mut vm, PropertyName.from_str('formatter'))!
	assert !arena.contains(value.as_object()) && !arena.contains(value.as_object().intl_date_time_format?)
	arena.reset(); arena.release()
	assert intl_date_eval(mut vm, 'bound(0)==="Jan 1, 1970"&&formatter.format===bound')!.as_bool()
}

fn test_cached_github_intl_date_pattern_executes_native_code_on_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-intl-date-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert intl_date_eval(mut vm, 'function label(value){return Intl.DateTimeFormat("en-US",{month:"short",day:"numeric",year:"numeric",timeZone:"UTC"}).format(value)}label(0)==="Jan 1, 1970"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
