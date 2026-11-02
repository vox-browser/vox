//US Privacy String API - required by the IAB to be a specific format
/** @function __uspapi
 *   @summary This function provides an api for vendors to access a user's us privacy string data
 *   @param {String} command - A command name
 *   @param {Number} version - The us privacy string version number
 *   @param {Function} callback - A callback function accepting usprivacy object as the first param, and success as the second
 *   @returns { Boolean } - a boolean of whether or not the privacy string exists, not required for iab
 *   @description A lengthy description of the purpose of this function
 *   @references https://iabtechlab.com
 *   @example
 *   __uspapi('getUSPData', 1, (data, success) =>{console.log(data, success) });
 *   > {version: 1, uspString: null}, false
 */
 (function () {
	var activeGroupsAreLoaded = false;
	window.__uspapi = function (command, version, callback) {

		function getCookie(name) {
			var cookieName = name + "=";
			//add '; ' so the first cookie will be recognized as well
			var theCookies = "; " + document.cookie;
			var cookieArray = theCookies.split(';');
			for (var i = 0; i < cookieArray.length; i++) {
				var cookie = cookieArray[i];
				while (cookie.charAt(0) === ' ') {
					cookie = cookie.substring(1, cookie.length);
					if (cookie.indexOf(cookieName) === 0) {
						return cookie.substring(cookieName.length, cookie.length);
					}
				}
			}
			return null;
		}

		var privacyCookieVal = getCookie('usprivacy');
		//Privacy object is a required value for the callback function
		var privacyObject = {
			"version": version,
			"uspString": privacyCookieVal
		};

		//Success state boolean is a required value for the callback function
		var validPrivacyString = false;
		if (privacyCookieVal !== null) {
			validPrivacyString = true;
		}

		//Private method for getUSPData
		function getUSPData() {
			callback(privacyObject, validPrivacyString);
		}

		//the command must match this string & case
		if (command.toLowerCase() === 'getuspdata') {
			getUSPData();
		}

		//return this value as well since it is the only command for now
		// return validPrivacyString;
	};
	function addUspapiFrame() {
		if (!window.frames['__uspapiLocator']) {
			if (document.body) {
				var body = document.body,
					iframe = document.createElement('iframe');
				iframe.style.display = 'none';
				iframe.setAttribute('style', 'display:none;height:0;opacity:0;visibility:hidden;border:0;width:0;height:0;');
				iframe.name = '__uspapiLocator';
				body.appendChild(iframe);
			} else {
				// if located in the head this injects the iframe more quickly than relying on DOMContentLoaded
				setTimeout(addUspapiFrame, 5);
			}
		}
	}

	addUspapiFrame();
	function optOutMsgHandler(event) {
		var msgIsString = typeof event.data === "string";
		var json;
		if (msgIsString) {
			json = event.data.indexOf("__uspapiCall") !== -1 ? JSON.parse(event.data) : {};
		} else {
			json = event.data;
		}
		if (json.__uspapiCall) {
			var i = json.__uspapiCall;
			window.__uspapi(i.command, i.version, function (retValue, success) {
				var returnMsg = {
					"__uspapiReturn": {
						"returnValue": retValue,
						"success": success,
						"callId": i.callId
					}
				};
				window.parent.console.log('received a request for uspapi');
				event.source.postMessage(msgIsString ?
					JSON.stringify(returnMsg) : returnMsg, '*');
			});
		}
	}

	if (window.addEventListener) {
		window.addEventListener('message', optOutMsgHandler, false);
	} else {
		window.attachEvent('onmessage', optOutMsgHandler);
	}

	/* non user customizable cookie settings can go here */
	window.usPrivacyCookie = (function () {
		var privacyCookieSettings = {
			cookie: {
				name: 'usprivacy',
				durationDays: 365
			},
		};
		/* TODO: Note - The setConsentVal, setNoticeVal, SetVersionVal methods create new cookies with expirations set a year from the created date
		- maybe they should preserve the initial cookie expiration?
		 */

		/* Some generic cookie helper functions */
		function createCookie(name, value, days, expiryDate) {
			var expireString = '; ',
				samesiteString = 'SameSite=Lax; ',
				secureString = '',
				pathString = 'path=/; ',
				nameString = name + '=' + (value || '') + '; ';

			var alertBoxClsdVal = getCookie('OptanonAlertBoxClosed');
			// Since the usprivacy cookie is synced on every page load 
			// we don't want the cookie to extended a year every time,
			// so setting the expiry same as optanon alert box closed
			if (alertBoxClsdVal) {
				expiryDate = new Date(alertBoxClsdVal);
			}
			if (days) {
				var date = expiryDate ? expiryDate : new Date();
				date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
				expireString = 'expires=' + date.toUTCString() + '; ';
			}
			var cookieString = nameString + expireString + samesiteString + secureString;
			cookieString += pathString;

			document.cookie = cookieString;
		}

		function getCookie(name) {
			var cookieName = name + "=";
			//add '; ' so the first cookie will be recognized as well
			var theCookies = "; " + document.cookie;
			var cookieArray = theCookies.split(';');
			for (var i = 0; i < cookieArray.length; i++) {
				var cookie = cookieArray[i];
				while (cookie.charAt(0) === ' ') {
					cookie = cookie.substring(1, cookie.length);
					if (cookie.indexOf(cookieName) === 0) {
						return cookie.substring(cookieName.length, cookie.length);
					}
				}
			}
			return null;
		}

		function eraseCookie(name) {
			document.cookie = name + '=; Max-Age=-99999999;';
		}

		function simpleSanitize(string) {
			var map = {
				'&': '&amp;',
				'<': '&lt;',
				'>': '&gt;',
				'"': '&quot;',
				"'": '&#x27;',
				"/": '&#x2F;',
			};
			var reg = /[&<>"'/]/ig;
			return string.replace(reg, function (match) {
				map[match];
			});
		}

		/* functions specific to the Us Privacy cookie */
		function getPrivacyCookie() {
			return getCookie(privacyCookieSettings.cookie.name);
		}

		/* The value of the cookie/usprivacy string should be a 3 character string
		 * char 1 {version} = 1
		 * char 2 {notice} = Y, N, -
		 * char 3 {consent} = Y, N, -
		 * char 4 {LSPA agreements} - Y, N, -
		 * More info: https://iabtechlab.com/standards/ccpa/
		 * Note: - is never valid unless values 2-4 are -
		 * ex 1--- === valid
		 * ex 1Y-N !== valid
		 * Note: values are now case insensitive, I wouldn't recommend mixing case though
		 * ex 1YNY == 1yny
		 */
		function createPrivacyCookie(val, expiryDate) {
			var cookieName = privacyCookieSettings.cookie.name,
				cookieDays = privacyCookieSettings.cookie.durationDays;
			createCookie(cookieName, val, cookieDays, expiryDate);
		}

		function getVersionVal() {
			var privacyStringValues = getPrivacyCookie();
			if (privacyStringValues !== null) {
				return privacyStringValues.substr(0, 1);
			} else {
				return null;
			}
		}

		function getNoticeVal() {
			var privacyStringValues = getPrivacyCookie();
			if (privacyStringValues !== null) {
				return privacyStringValues.substr(1, 1);
			} else {
				return null;
			}
		}

		function getOptOutVal() {
			var privacyStringValues = getPrivacyCookie();
			if (privacyStringValues !== null) {
				return privacyStringValues.substr(2, 1);
			} else {
				return null;
			}
		}

		function getLSPAVal() {
			var privacyStringValues = getPrivacyCookie();
			if (privacyStringValues !== null) {
				return privacyStringValues.substr(3, 1);
			} else {
				return null;
			}
		}

		function setVersionVal(newVal) {
			if (getPrivacyCookie() !== null) {
				var consentStringValues = newVal;
				consentStringValues += getNoticeVal();
				consentStringValues += getOptOutVal();
				createPrivacyCookie(consentStringValues);
				return true;
			} else {
				//cookie didn't exist in the first place
				return false;
			}
		}

		function setNoticeVal(newVal) {
			if (getPrivacyCookie() !== null) {
				var consentStringValues = getVersionVal();
				consentStringValues += newVal;
				consentStringValues += getOptOutVal();
				createPrivacyCookie(consentStringValues);
				return true;
			} else {
				//cookie didn't exist in the first place
				return false;
			}
		}

		function setConsentVal(newVal) {
			if (getPrivacyCookie() !== null) {
				var consentStringValues = getVersionVal();
				consentStringValues += getNoticeVal();
				consentStringValues += newVal;
				createPrivacyCookie(consentStringValues);
				return true;
			} else {
				//cookie didn't exist in the first place
				return false;
			}
		}

		function setLSPAVal(newVal) {
			if (getPrivacyCookie() !== null) {
				var consentStringValues = getVersionVal();
				consentStringValues += getNoticeVal();
				consentStringValues += getOptOutVal();
				consentStringValues += newVal;
				createPrivacyCookie(consentStringValues);
				return true;
			} else {
				//cookie didn't exist in the first place
				return false;
			}
		}

		/** @function usPrivacyCookie
		 *   @summary A module for interacting with the usprivacy string and cookie
		 *
		 *   @returns { Object} - Returns an object with methods that can be used to manipulate the privacy string data
		 *   @description A lengthy description of the purpose of this function
		 *   @requires <someModuleName>
		 *
		 *   @example
		 *   usPrivacyCookie.get();
		 *   > "1NN"
		 *
		 *   @example
		 *   usPrivacyCookie.set('1---');
		 *   > creates a usprivacy cookie with 1--- as the value
		 */
		return {
			get: getPrivacyCookie,
			create: createPrivacyCookie,
			getVersionVal: getVersionVal,
			getNoticeVal: getNoticeVal,
			getOptOutVal: getOptOutVal,
			getLSPAVal: getLSPAVal,
			setVersionVal: setVersionVal,
			setNoticeVal: setNoticeVal,
			setConsentVal: setConsentVal,
			setLSPAVal: setLSPAVal
		};
	})();

	/* OneTrust CCPA Opt Out  - Google Ad Manager Opt Out Cookie */
	window.gamoo = (function () {
		var gamooCookieSettings = {
			cookie: {
				name: 'OneTrustWPCCPAGoogleOptOut',
				durationDays: 365
			},
		};

		function createCookie(name, value, days) {
			var expireString = '; ',
				samesiteString = 'SameSite=Lax; ',
				secureString = '',
				pathString = 'path=/; ',
				nameString = name + '=' + (value || '') + '; ';

			if (days) {
				var date = new Date();
				date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
				expireString = 'expires=' + date.toUTCString() + '; ';
			}
			document.cookie = nameString + expireString + pathString + samesiteString + secureString;

		}

		function getCookie(name) {
			var cookieName = name + "=";
			//add '; ' so the first cookie will be recognized as well
			var theCookies = "; " + document.cookie;
			var cookieArray = theCookies.split(';');
			for (var i = 0; i < cookieArray.length; i++) {
				var cookie = cookieArray[i];
				while (cookie.charAt(0) === ' ') {
					cookie = cookie.substring(1, cookie.length);
					if (cookie.indexOf(cookieName) === 0) {
						return cookie.substring(cookieName.length, cookie.length);
					}
				}
			}
			return null;
		}

		function eraseCookie(name) {
			document.cookie = name + '=; Max-Age=-99999999;';
		}

		function simpleSanitize(string) {
			var map = {
				'&': '&amp;',
				'<': '&lt;',
				'>': '&gt;',
				'"': '&quot;',
				"'": '&#x27;',
				"/": '&#x2F;',
			};
			var reg = /[&<>"'/]/ig;
			return string.replace(reg, function (match) {
				map[match];
			});
		}

		/* functions specific to the Gamoo cookie */
		function getGamooCookie() {
			return getCookie(gamooCookieSettings.cookie.name);
		}

		//The value for this cookie should be true or false
		function createGamooCookie(val) {
			var cookieName = gamooCookieSettings.cookie.name,
				cookieDays = gamooCookieSettings.cookie.durationDays;
			createCookie(cookieName, val, cookieDays);
		}

		//Disable Google Ads Manager
		function disableGam() {
			if (typeof googletag !== "undefined" && googletag.apiReady) {
				googletag.pubads().disableInitialLoad();
				googletag.pubads().setPrivacySettings({ 'restrictDataProcessing': true });
				(adsbygoogle = window.adsbygoogle || []).requestNonPersonalizedAds = 1;
			} else {
			}
		}

		//Check the cookie & enable/disable accordingly
		function determineGamooStatus() {
			if (getGamooCookie() === 'true') {
				disableGam();
			} else {
				enableGam();
			}
		}


		//Enable Google ads Manager
		function enableGam() {

			if (typeof googletag !== "undefined" && googletag.apiReady) {
				googletag.pubads().disableInitialLoad();
				googletag.pubads().setPrivacySettings({ 'restrictDataProcessing': false });
				(adsbygoogle = window.adsbygoogle || []).requestNonPersonalizedAds = 0;
			} else {
			}
		}

		return {
			getCookie: getGamooCookie,
			createCookie: createGamooCookie,
			determine: determineGamooStatus,
			enable: enableGam,
			disable: disableGam
		};
	})();

	/* OneTrust CCPA Opt Out - Opt Out Dialogue Module */
	window.otCcpaOptOut = (function () {
		var retryCount = 0;

		/* High Level Functions to create/destroy */
		function init() {
			var userSettings = getCCPAOptOutIds();
			createBannerConnection();
			//Class for storing privacy string values
			function OptOutPrivacyObject() {
				// * char 1 {version} = 1
				// * char 2 {notice} = Y, N, -
				// * char 3 {optout} = Y, N, -
				// * char 4 {lspa} = Y, N, -
				var privacyStringValues = {
					version: '1',
					notice: 'N',
					optout: 'N',
					lspa: 'N'
				};
				if (isExplicitNoticeProvided()) {
					privacyStringValues.notice = 'Y';
				}
				if (isLspaAccepted()) {
					privacyStringValues.lspa = 'Y';
				}

				function returnValue() {
					return privacyStringValues.version + privacyStringValues.notice + privacyStringValues.optout + privacyStringValues.lspa;
				}

				function setValue(name, value) {
					privacyStringValues[name] = value;
				}

				return {
					set: setValue,
					value: returnValue
				};
			}

			/**
			 * Function in charge of wait of the population of OnetrustActiveGroups that is being made in the SDK. 
			 * Furthermore, the OnetrustActiveGroups rightfully could be ',,' in that case, the retryCount variable 
			 * when it reaches to the max number of retries it would lunch the normal flow calling  the groupsUpdated function
			 */
			function checkIfActiveGroupsExist() {
				if (window.OneTrust && OnetrustActiveGroups && (activeGroupsAreLoaded || OnetrustActiveGroups !== ',,' || retryCount > 10)) {
					retryCount = 0;
					groupsUpdated();
				} else {
					retryCount++;
					var checkOtApi = setInterval(function () {
						clearInterval(checkOtApi);
						checkIfActiveGroupsExist();
					}, 50);
				}
			}
			//check the location
			if (isLocationApplicable()) {

				//Write the privacy cookie only after OnetrustActiveGroups are available so we can calcuate
				// if CCPA opt out category is enabled or not
				function groupsUpdated() {
					// Insert the 'usprivacy' cookie if passed by mobile app to webview
					const consent = window.OTExternalConsent;
					if (consent && consent.USPrivacy && consent.consentedDate) {
						usPrivacyCookie.create(consent.USPrivacy, new Date(consent.consentedDate));
					} else {
						//Perform initial setup checks for the iab
						var initialPrivacyValues = new OptOutPrivacyObject();
						if (isExplicitNoticeProvided()) {
							initialPrivacyValues.set('notice', 'Y');
						} else {
							initialPrivacyValues.set('notice', 'N');
						}
						var isCCPAOptOutIdInActive = false;
						var activeGroupsArr = !OnetrustActiveGroups.slice(1, -1) ? [] : OnetrustActiveGroups.slice(1, -1).split(",");
						for (var i = 0, l = userSettings.ids.length; i < l; i++) {
							if (activeGroupsArr.indexOf(userSettings.ids[i]) == -1) {
								isCCPAOptOutIdInActive = true;
								break;
							}
						}
						if (isCCPAOptOutIdInActive) {
							initialPrivacyValues.set('optout', 'Y');
						} else {
							initialPrivacyValues.set('optout', 'N');
						}
						usPrivacyCookie.create(initialPrivacyValues.value());
					}
				};

				//Sync the usprivacy cookie once domaindata api is available
				checkIfActiveGroupsExist();

				//perform actions is google ads manager option is selected
				//TODO: Check to see if the gam cookie exists? if not add one with the default value of false
				gamoo.determine();

			} else {
				usPrivacyCookie.create('1---');
				gamoo.determine();

				//End everything now
				return false;
			}

			//gets attribute settings
			function getCCPAOptOutIds() {
				// initialize optOutIds variable to return
				var optOutIds = [];
				var geoValue = "";
				var userSettings = {};
				var lspaValue = "";
				// get all script tags on the DOM
				var scripts = document.getElementsByTagName('script');

				// loop through each script tag and identify the one that has the "ccpa-opt-out-ids" attribute
				for (var i = 0, l = scripts.length; i < l; i++) {
					var scriptHasCCPAOptOutIds = !!scripts[i].attributes.getNamedItem("ccpa-opt-out-ids");
					if (scriptHasCCPAOptOutIds) {
						// get the value of the "ccpa-out-out-ids" attribute
						var ccpaOptOutValue = scripts[i].attributes.getNamedItem("ccpa-opt-out-ids").value;
						geoValue = scripts[i].attributes.getNamedItem("ccpa-opt-out-geo").value;
						lspaValue = scripts[i].attributes.getNamedItem("ccpa-opt-out-lspa").value;
						// convert "ccpa-opt-out-ids" attribute value to an array when value is not falsey
						if (!!ccpaOptOutValue) {
							// split the comma separated values to support 1 or many opt out ids (OT cookie groups)
							optOutIds = ccpaOptOutValue.split(",");
						}
						break;
					}
				}
				userSettings = { ids: optOutIds, geo: geoValue, lspa: lspaValue };
				return userSettings;
			}

			function createBannerConnection() {
				window.addEventListener('consent.onetrust', function () {
					confirmSettings();
				}, false);

				//function that runs when confirmation button is clicked
				function confirmSettings() {
					var activeGroupsArr = !OnetrustActiveGroups.slice(1, -1) ? [] : OnetrustActiveGroups.slice(1, -1).split(",");

					// when "ccpa-opt-out-ids" attribute is empty, don't allow updating the usprivacy cookie"
					if (!userSettings.ids.length) {
						return;
					}
					//set values based on user settings
					var isCCPAOptOutIdInActive = false
					for (var i = 0, l = userSettings.ids.length; i < l; i++) {
						if (activeGroupsArr.indexOf(userSettings.ids[i]) == -1) {
							isCCPAOptOutIdInActive = true;
							break;
						};
					}
					if (isCCPAOptOutIdInActive) {
						if (isLocationApplicable()) {
							var updatedPrivacyValues = new OptOutPrivacyObject();
							updatedPrivacyValues.set('optout', 'Y');
							usPrivacyCookie.create(updatedPrivacyValues.value());
						}
						gamoo.createCookie('true');
						gamoo.determine();
					} else {
						if (isLocationApplicable()) {
							var updatedPrivacyValues = new OptOutPrivacyObject();
							updatedPrivacyValues.set('optout', 'N');
							usPrivacyCookie.create(updatedPrivacyValues.value());
						}
						gamoo.createCookie('false');
						gamoo.determine();
					}
				}
			}

			/* Return booleans based on certain conditions */
			function isExplicitNoticeProvided() {
				//The existence of a privacy policy is the criteria for explicit notice right now
				return true;
			}

			//need to add our own option
			function isLspaAccepted() {
				if (userSettings.lspa === "true") {
					return userSettings.lspa;
				} else {
					return false;
				}

			}

			function isLocationApplicable() {
				//need to add our own options
				var locationData = window.__otccpaooLocation,
					locationSetting = userSettings.geo.toLowerCase(); //valid values are 'all', 'us', and 'ca'
				var applicable = false;

				if (locationSetting === 'all') {
					applicable = true;
				} else if (locationSetting === 'us') {
					applicable = (locationData.country.toString().toLowerCase() === 'us');
				} else if (locationSetting === 'ca') {
					applicable = (locationData.state.toString().toLowerCase() === 'ca');
				} else {
					applicable = false;
				}

				return applicable;
			}
		}

		//call init
		//return public methods here
		return {
			init: init
		}
	})();

	(function otLocation() {
		//Set the global window function definition that will define what the geolocation script does
		window.dnsfeed = function (data) {
			//set this data to a global variable because why not?
			window.__otccpaooLocation = data;

			//This will check to see if the location data is on the page and then initialize the ccpa opt out module.
			kickStart();
		};

		//TODO: Should we use an xhr or some other method of accessing this endpoint instead of pulling the entire script onto the page?
		function addGeoScript() {
			//insert this script on the page
			var geoScript = document.createElement('script');
			geoScript.src = 'https://geolocation.onetrust.com/cookieconsentpub/v1/geo/location/dnsfeed';
			geoScript.async = true;
			geoScript.type = "text/javascript";
			var script1 = document.getElementsByTagName('script')[0];
			// var head = document.getElementsByTagName('head')[0];
			// head.appendChild(geoScript);
			script1.parentNode.insertBefore(geoScript, script1);
		}

		function kickStart() {
			//if the location data doesn't exist when this function is run, check it 10 more times in the next 5s
			if (window.__otccpaooLocation !== undefined) {
				//TODO: Check to see if user settings are defined before starting this?
				//otCcpaOptOut.init(); //change initial settings
				otCcpaOptOut.init();
			} else {
				var startOptOut = setInterval(function () {
					if (window.__otccpaooLocation !== undefined) {
						//pass a global object to the init function that should be provided by the user otherwise the default will be used
						otCcpaOptOut.init(); //initialized with default user settings
						clearInterval(startOptOut);
					} else {
					}
				}, 500);

				var optOutExpiration = setTimeout(function () {
					clearInterval(startOptOut);
				}, 5 * 1000);
			}
		}

		//Go ahead and load the geolocation script
		addGeoScript();
	})();

	window.addEventListener('OneTrustGroupsUpdated', function () {
		activeGroupsAreLoaded = true;
	});
})();