module svg

// Canonical names from AttributeNames.cpp and TagNames.cpp. Keeping these as
// data makes name coverage testable without coupling the translation to a DOM.
pub fn attribute_names() []string {
	return ['amplitude', 'attributeName', 'attributeType', 'baseFrequency', 'baseProfile', 'calcMode',
		'class', 'clipPathUnits', 'contentScriptType', 'contentStyleType', 'cx', 'cy', 'd',
		'diffuseConstant', 'dx', 'dy', 'edgeMode', 'fill', 'exponent', 'filterUnits', 'fr', 'fx',
		'fy', 'glyphRef', 'gradientTransform', 'gradientUnits', 'height', 'href', 'in', 'in2',
		'intercept', 'kernelMatrix', 'kernelUnitLength', 'k1', 'k2', 'k3', 'k4', 'keyPoints',
		'keySplines', 'keyTimes', 'lengthAdjust', 'limitingConeAngle', 'markerHeight', 'markerUnits',
		'markerWidth', 'maskContentUnits', 'maskUnits', 'mode', 'numOctaves', 'offset', 'opacity',
		'operator', 'pathLength', 'patternContentUnits', 'patternTransform', 'patternUnits', 'points',
		'pointsAtX', 'pointsAtY', 'pointsAtZ', 'preserveAlpha', 'preserveAspectRatio',
		'primitiveUnits', 'r', 'radius', 'refX', 'refY', 'repeatCount', 'repeatDur',
		'requiredExtensions', 'requiredFeatures', 'result', 'rotate', 'rx', 'ry', 'scale', 'seed',
		'slope', 'specularConstant', 'specularExponent', 'spreadMethod', 'startOffset', 'stdDeviation',
		'stitchTiles', 'stop-color', 'stop-opacity', 'surfaceScale', 'systemLanguage', 'tableValues',
		'targetX', 'targetY', 'textLength', 'type', 'values', 'version', 'viewBox', 'viewTarget',
		'width', 'x', 'x1', 'x2', 'xChannelSelector', 'xlink:href', 'xmlns', 'y', 'y1', 'y2',
		'yChannelSelector', 'zoomAndPan']
}

pub fn tag_names() []string {
	return ['a', 'circle', 'clipPath', 'defs', 'desc', 'ellipse', 'feBlend', 'feColorMatrix',
		'feComponentTransfer', 'feComposite', 'feDisplacementMap', 'feDropShadow', 'feFlood',
		'feFuncA', 'feFuncB', 'feFuncG', 'feFuncR', 'feGaussianBlur', 'feImage', 'feMerge',
		'feMergeNode', 'feMorphology', 'feOffset', 'feTurbulence', 'filter', 'foreignObject', 'g',
		'image', 'line', 'linearGradient', 'mask', 'metadata', 'path', 'pattern', 'polygon',
		'polyline', 'radialGradient', 'rect', 'script', 'stop', 'style', 'svg', 'symbol', 'text',
		'textPath', 'title', 'tspan', 'use', 'view']
}
