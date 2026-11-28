// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_date_locale_strings_use_intrinsic_cldr_formatting_with_date_time_and_all_defaults() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'var d=new Date(0);d.toLocaleDateString("en-US",{month:"short",day:"numeric",year:"numeric",timeZone:"UTC"})==="Jan 1, 1970"&&d.toLocaleDateString("en-GB",{timeZone:"UTC"})==="01/01/1970"&&d.toLocaleTimeString("en-US",{timeZone:"UTC"})==="12:00:00 AM"&&d.toLocaleString("en-US",{timeZone:"UTC"})==="1/1/1970, 12:00:00 AM"')!.as_bool()
}

fn test_date_locale_strings_preserve_brand_invalid_dates_and_style_restrictions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'var n=0,reads=0,options={get timeZone(){reads++;return "UTC"}};for(var name of ["toLocaleString","toLocaleDateString","toLocaleTimeString"]){try{Date.prototype[name].call({},[],options)}catch(e){if(e instanceof TypeError)n++}if(new Date(NaN)[name]({get length(){throw 1}},options)==="Invalid Date")n++}try{new Date(0).toLocaleDateString("en",{timeStyle:"short"})}catch(e){if(e instanceof TypeError)n++}try{new Date(0).toLocaleTimeString("en",{dateStyle:"short"})}catch(e){if(e instanceof TypeError)n++}n===8&&reads===0&&Date.prototype.toLocaleDateString.length===0')!.as_bool()
}

fn test_date_locale_string_captures_time_before_options_reenter_and_ignores_public_formatter_replacement() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert intl_date_eval(mut vm, 'var d=new Date(0),old=Intl.DateTimeFormat;Intl.DateTimeFormat=function(){throw 1};var value=d.toLocaleDateString("en-US",{get timeZone(){d.setTime(86400000);return "UTC"}});Intl.DateTimeFormat=old;value==="1/1/1970"&&d.getTime()===86400000')!.as_bool()
}
