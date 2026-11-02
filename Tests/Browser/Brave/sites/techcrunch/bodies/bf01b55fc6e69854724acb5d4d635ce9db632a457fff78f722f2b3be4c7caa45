/**
 * Convert a string to title case.
 *
 * @param {*} str
 * @returns {string}
 */
function toTitleCase(str) {
	return str.replace(/\w\S*/g, function (txt) {
		return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
	});
}

/**
 * Send the event to Google Tag Manager.
 *
 * @param {HTMLElement} element The element that was clicked.
 */
function sendGTMEvent(element) {
	const attributeList = window.tenupDataLayer.trackingAttrs || [];

	const data = attributeList.reduce((acc, attribute) => {
		const value = element.getAttribute(attribute);
		if (value) {
			const key = attribute.replace('data-', '');

			// Force proper case.
			acc[key] = toTitleCase(value);
		}
		return acc;
	}, {});

	/**
	 * If the ctaText is not set, use the innerText of the element.
	 * WP_HTML_Tag_Processor is limited in what it can do, so we can't
	 * assign the data-ctaText attribute.
	 */
	if (!data.ctaText) {
		data.ctaText = element.innerText.trim();
	}

	window.dataLayer = window.dataLayer || [];
	window.dataLayer.push(data);
}

/**
 * Add event listeners to the document.
 */
document.addEventListener('DOMContentLoaded', () => {
	// Add event listeners to all elements with a data-event attribute.
	document.addEventListener('click', function (event) {
		const clickedElement = event.target;
		const eventElement   = clickedElement.closest('[data-event]');

		// Bail if we can't find an element with a data-event attribute.
		if (!eventElement) {
			return;
		}

		// Send the event to Google Tag Manager.
		const dataEvent = eventElement.getAttribute('data-event');
		if (dataEvent) {
			sendGTMEvent(eventElement);
		}
	});

	// Add event listeners to all internal links without a data-event attribute.
	const hyperLinks = document.querySelectorAll('a:not([data-event])'); // Select only links without data-event attribute.
	hyperLinks.forEach((link) => {
		// Check if it's an internal link.
		if (link.host === window.location.host) {
			link.addEventListener('click', () => {
				const ctaText = link.innerText;
				const destinationLink = link.href;

				window.dataLayer = window.dataLayer || [];
				window.dataLayer.push({
					event: 'recirculation',
					module: 'hyperlink',
					ctaText,
					destinationLink,
				});
			});
		}
	});
});
