/* @ds-bundle: {"format":4,"namespace":"AstryxDesignSystem_9884ce","components":[{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"Avatar","sourcePath":"components/data/Avatar.jsx"},{"name":"Divider","sourcePath":"components/data/Divider.jsx"},{"name":"Banner","sourcePath":"components/feedback/Banner.jsx"},{"name":"ProgressBar","sourcePath":"components/feedback/ProgressBar.jsx"},{"name":"Skeleton","sourcePath":"components/feedback/Skeleton.jsx"},{"name":"Spinner","sourcePath":"components/feedback/Spinner.jsx"},{"name":"StatusDot","sourcePath":"components/feedback/StatusDot.jsx"},{"name":"Toast","sourcePath":"components/feedback/Toast.jsx"},{"name":"Checkbox","sourcePath":"components/forms/Checkbox.jsx"},{"name":"RadioGroup","sourcePath":"components/forms/RadioGroup.jsx"},{"name":"SegmentedControl","sourcePath":"components/forms/SegmentedControl.jsx"},{"name":"Select","sourcePath":"components/forms/Select.jsx"},{"name":"Switch","sourcePath":"components/forms/Switch.jsx"},{"name":"TextArea","sourcePath":"components/forms/TextArea.jsx"},{"name":"TextInput","sourcePath":"components/forms/TextInput.jsx"},{"name":"Breadcrumbs","sourcePath":"components/navigation/Breadcrumbs.jsx"},{"name":"Tabs","sourcePath":"components/navigation/Tabs.jsx"}],"sourceHashes":{"components/core/Badge.jsx":"bfd74aca4d77","components/core/Button.jsx":"88dda8042ab6","components/core/Card.jsx":"60b67a1fb5e7","components/core/IconButton.jsx":"7882eb9c0a9d","components/data/Avatar.jsx":"af3acf30d01d","components/data/Divider.jsx":"0558b6bba3cb","components/feedback/Banner.jsx":"c375e6f001f8","components/feedback/ProgressBar.jsx":"636cf6582e95","components/feedback/Skeleton.jsx":"5ea3d3cf10ef","components/feedback/Spinner.jsx":"4f1e6d068d69","components/feedback/StatusDot.jsx":"0dc165acaadc","components/feedback/Toast.jsx":"fcef34d0ff86","components/forms/Checkbox.jsx":"3054b2845168","components/forms/RadioGroup.jsx":"86d0fbb6ba87","components/forms/SegmentedControl.jsx":"ec9ec72cfffc","components/forms/Select.jsx":"b667f14cc506","components/forms/Switch.jsx":"2ad02c0aa7fd","components/forms/TextArea.jsx":"0a73d1fabd9f","components/forms/TextInput.jsx":"aa81a8c9bedc","components/navigation/Breadcrumbs.jsx":"8eeac4b65f95","components/navigation/Tabs.jsx":"c91404f039e3","ui_kits/console/Screens.jsx":"34bff166bcb6","ui_kits/console/Shell.jsx":"0546f110f099","ui_kits/site/App.jsx":"d6751fca9111"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.AstryxDesignSystem_9884ce = window.AstryxDesignSystem_9884ce || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('badge', `
.astryx-badge{display:inline-flex;align-items:center;gap:var(--spacing-1);
  padding:2px var(--spacing-2);border-radius:var(--radius-full);
  font-family:var(--font-family-body);font-size:var(--font-size-sm);line-height:1.4;
  font-weight:var(--font-weight-medium);white-space:nowrap;}
.astryx-badge svg{width:12px;height:12px}
/* semantic — filled */
.astryx-badge[data-variant="neutral"]{background:var(--color-background-gray);color:var(--color-text-gray)}
.astryx-badge[data-variant="info"]{background:#0074e2;color:#fff}
.astryx-badge[data-variant="success"]{background:#198100;color:#fff}
.astryx-badge[data-variant="warning"]{background:#ffce2f;color:#171717}
.astryx-badge[data-variant="error"]{background:#e33f4a;color:#fff}
/* categorical — tinted */
.astryx-badge[data-variant="blue"]{background:var(--color-background-blue);color:var(--color-text-blue)}
.astryx-badge[data-variant="cyan"]{background:var(--color-background-cyan);color:var(--color-text-cyan)}
.astryx-badge[data-variant="green"]{background:var(--color-background-green);color:var(--color-text-green)}
.astryx-badge[data-variant="orange"]{background:var(--color-background-orange);color:var(--color-text-orange)}
.astryx-badge[data-variant="pink"]{background:var(--color-background-pink);color:var(--color-text-pink)}
.astryx-badge[data-variant="purple"]{background:var(--color-background-purple);color:var(--color-text-purple)}
.astryx-badge[data-variant="red"]{background:var(--color-background-red);color:var(--color-text-red)}
.astryx-badge[data-variant="teal"]{background:var(--color-background-teal);color:var(--color-text-teal)}
.astryx-badge[data-variant="yellow"]{background:var(--color-background-yellow);color:var(--color-text-yellow)}
.astryx-badge[data-variant="gray"]{background:var(--color-background-gray);color:var(--color-text-gray)}
`);

/**
 * Badge — highlights a status or category at a glance. Semantic variants use
 * solid fills; categorical color variants use tinted surfaces + colored text.
 */
function Badge({
  label,
  children,
  variant = 'neutral',
  icon,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("span", _extends({
    className: "astryx-badge",
    "data-variant": variant,
    style: style
  }, rest), icon, children ?? label);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
// Inject a component's scoped stylesheet once. Mirrors Astryx's real
// `astryx-*` class names so hover/active/focus states render faithfully.
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('button', `
.astryx-button{position:relative;display:inline-flex;align-items:center;justify-content:center;gap:var(--spacing-2);
  padding-block:var(--spacing-2);padding-inline:var(--spacing-3);border:0;border-radius:var(--radius-element);
  font-family:inherit;font-size:var(--text-label-size);line-height:var(--text-label-leading);font-weight:var(--font-weight-medium);
  white-space:nowrap;cursor:pointer;transition:background-color var(--duration-fast) var(--ease-standard),
  color var(--duration-fast) var(--ease-standard),opacity var(--duration-fast) var(--ease-standard),transform var(--duration-fast) var(--ease-standard);}
.astryx-button:active{transform:scale(0.98)}
.astryx-button[data-size="sm"]{height:var(--size-element-sm)}
.astryx-button[data-size="md"]{height:var(--size-element-md)}
.astryx-button[data-size="lg"]{height:var(--size-element-lg)}
.astryx-button[data-icon-only]{aspect-ratio:1/1;padding:0}
.astryx-button:focus-visible{outline:2px solid var(--color-accent);outline-offset:3px}
.astryx-button[data-variant="destructive"]:focus-visible{outline-color:var(--color-error)}
.astryx-button[data-variant="primary"]{background:var(--color-accent);color:var(--color-on-accent)}
.astryx-button[data-variant="primary"]:hover{background-image:linear-gradient(var(--color-overlay-hover),var(--color-overlay-hover))}
.astryx-button[data-variant="secondary"]{background:var(--color-neutral);color:var(--color-text-primary)}
.astryx-button[data-variant="secondary"]:hover{background-image:linear-gradient(var(--color-overlay-hover),var(--color-overlay-hover))}
.astryx-button[data-variant="ghost"]{background:transparent;color:var(--color-text-primary)}
.astryx-button[data-variant="ghost"]:hover{background-image:linear-gradient(var(--color-overlay-hover),var(--color-overlay-hover))}
.astryx-button[data-variant="destructive"]{background:var(--color-error);color:var(--color-on-error)}
.astryx-button[data-variant="destructive"]:hover{background-image:linear-gradient(var(--color-overlay-hover),var(--color-overlay-hover))}
.astryx-button:disabled,.astryx-button[aria-disabled="true"]{cursor:not-allowed;opacity:.5;background-image:none;transform:none}
.astryx-button__icon{display:inline-flex;align-items:center;justify-content:center;flex-shrink:0}
.astryx-button[data-size="lg"] .astryx-button__icon{width:20px;height:20px}
.astryx-button__icon{width:16px;height:16px}
.astryx-button__label{overflow:hidden;text-overflow:ellipsis;min-width:0}
.astryx-spin{animation:astryx-spin 0.7s linear infinite}
@keyframes astryx-spin{to{transform:rotate(360deg)}}
`);
function Spinner16() {
  return /*#__PURE__*/React.createElement("svg", {
    className: "astryx-spin",
    width: "16",
    height: "16",
    viewBox: "0 0 16 16",
    fill: "none",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "8",
    cy: "8",
    r: "6.5",
    stroke: "currentColor",
    strokeOpacity: "0.25",
    strokeWidth: "2"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M14.5 8a6.5 6.5 0 0 0-6.5-6.5",
    stroke: "currentColor",
    strokeWidth: "2",
    strokeLinecap: "round"
  }));
}

/**
 * Button — the primary action trigger. Four variants, three sizes,
 * leading icon, loading + disabled states, icon-only mode.
 */
function Button({
  label,
  children,
  variant = 'secondary',
  size = 'md',
  icon,
  endContent,
  isIconOnly = false,
  isLoading = false,
  isDisabled = false,
  type = 'button',
  href,
  onClick,
  style,
  ...rest
}) {
  const disabled = isDisabled || isLoading;
  const content = /*#__PURE__*/React.createElement(React.Fragment, null, isLoading && /*#__PURE__*/React.createElement("span", {
    className: "astryx-button__icon",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement(Spinner16, null)), !isLoading && icon && /*#__PURE__*/React.createElement("span", {
    className: "astryx-button__icon",
    "aria-hidden": "true"
  }, icon), !isIconOnly && /*#__PURE__*/React.createElement("span", {
    className: "astryx-button__label"
  }, children ?? label), !isIconOnly && endContent && /*#__PURE__*/React.createElement("span", {
    className: "astryx-button__icon",
    style: {
      width: 'auto',
      height: 'auto'
    }
  }, endContent));
  const shared = {
    className: 'astryx-button',
    'data-variant': variant,
    'data-size': size,
    'data-icon-only': isIconOnly ? '' : undefined,
    'aria-label': isIconOnly ? label : undefined,
    style,
    ...rest
  };
  if (href && !disabled) {
    return /*#__PURE__*/React.createElement("a", _extends({
      href: href,
      onClick: onClick
    }, shared), content);
  }
  return /*#__PURE__*/React.createElement("button", _extends({
    type: type,
    disabled: disabled,
    "aria-busy": isLoading || undefined,
    onClick: onClick
  }, shared), content);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('card', `
.astryx-card{border:var(--border-width) solid var(--color-border);border-radius:var(--radius-container);
  background:var(--color-background-card);box-shadow:var(--shadow-low);color:var(--color-text-primary);}
.astryx-card[data-variant="muted"]{background:var(--color-background-muted);box-shadow:none}
.astryx-card[data-variant="blue"]{background:var(--color-background-blue);border-color:var(--color-border-blue)}
.astryx-card[data-variant="green"]{background:var(--color-background-green);border-color:var(--color-border-green)}
.astryx-card[data-variant="purple"]{background:var(--color-background-purple);border-color:var(--color-border-purple)}
.astryx-card[data-variant="orange"]{background:var(--color-background-orange);border-color:var(--color-border-orange)}
.astryx-card[data-variant="teal"]{background:var(--color-background-teal);border-color:var(--color-border-teal)}
.astryx-card[data-variant="pink"]{background:var(--color-background-pink);border-color:var(--color-border-pink)}
.astryx-card[data-variant="red"]{background:var(--color-background-red);border-color:var(--color-border-red)}
.astryx-card[data-variant="yellow"]{background:var(--color-background-yellow);border-color:var(--color-border-yellow)}
.astryx-card[data-variant="cyan"]{background:var(--color-background-cyan);border-color:var(--color-border-cyan)}
.astryx-card[data-variant="gray"]{background:var(--color-background-gray);border-color:var(--color-border-gray)}
`);
const SPACING = {
  0: '0px',
  0.5: '2px',
  1: '4px',
  1.5: '6px',
  2: '8px',
  3: '12px',
  4: '16px',
  5: '20px',
  6: '24px',
  8: '32px',
  10: '40px'
};

/**
 * Card — a bordered, elevated container for discrete, self-contained items.
 * Not the default layout tool: reach for it only when items need clear
 * interaction boundaries or grid comparison.
 */
function Card({
  children,
  variant = 'default',
  padding = 3,
  width,
  height,
  maxWidth,
  minHeight,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    className: "astryx-card",
    "data-variant": variant,
    style: {
      padding: SPACING[padding] ?? padding,
      width,
      height,
      maxWidth,
      minHeight,
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * IconButton — a square, icon-only button. Wraps Button with isIconOnly.
 * Always pass an accessible `label`.
 */
function IconButton({
  label,
  icon,
  variant = 'ghost',
  size = 'md',
  ...rest
}) {
  return /*#__PURE__*/React.createElement(__ds_scope.Button, _extends({
    label: label,
    icon: icon,
    variant: variant,
    size: size,
    isIconOnly: true
  }, rest));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/data/Avatar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('avatar', `
.astryx-avatar{position:relative;display:inline-flex;align-items:center;justify-content:center;flex-shrink:0;
  border-radius:var(--radius-full);overflow:hidden;background:var(--color-background-gray);color:var(--color-text-gray);
  font-family:var(--font-family-body);font-weight:var(--font-weight-semibold);text-transform:uppercase;user-select:none}
.astryx-avatar[data-shape="square"]{border-radius:var(--radius-element)}
.astryx-avatar img{width:100%;height:100%;object-fit:cover;display:block}
.astryx-avatar__status{position:absolute;right:0;bottom:0;width:28%;height:28%;min-width:8px;min-height:8px;
  border-radius:var(--radius-full);border:2px solid var(--color-background-body)}
.astryx-avatar__status[data-tone="success"]{background:var(--color-vivid-green)}
.astryx-avatar__status[data-tone="warning"]{background:var(--color-vivid-yellow)}
.astryx-avatar__status[data-tone="error"]{background:var(--color-vivid-red)}
.astryx-avatar__status[data-tone="neutral"]{background:var(--color-icon-secondary)}
`);
const SIZES = {
  xs: 20,
  sm: 28,
  md: 36,
  lg: 48,
  xl: 64
};
function initials(name) {
  if (!name) return '';
  return name.trim().split(/\s+/).slice(0, 2).map(w => w[0]).join('');
}

/**
 * Avatar — a person or entity's image, falling back to initials.
 */
function Avatar({
  name,
  src,
  size = 'md',
  shape = 'circle',
  status,
  style,
  ...rest
}) {
  const px = SIZES[size] || size;
  const fontSize = Math.round(px * 0.4);
  return /*#__PURE__*/React.createElement("span", _extends({
    className: "astryx-avatar",
    "data-shape": shape,
    style: {
      width: px,
      height: px,
      fontSize,
      ...style
    },
    role: "img",
    "aria-label": name
  }, rest), src ? /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: name || ''
  }) : initials(name), status && /*#__PURE__*/React.createElement("span", {
    className: "astryx-avatar__status",
    "data-tone": status
  }));
}
Object.assign(__ds_scope, { Avatar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/Avatar.jsx", error: String((e && e.message) || e) }); }

// components/data/Divider.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('divider', `
.astryx-divider{border:0;background:var(--color-border);align-self:stretch}
.astryx-divider[data-orientation="horizontal"]{width:100%;height:var(--border-width);margin:var(--spacing-3) 0}
.astryx-divider[data-orientation="vertical"]{width:var(--border-width);min-height:1em;margin:0 var(--spacing-3)}
.astryx-divider-labelled{display:flex;align-items:center;gap:var(--spacing-3);margin:var(--spacing-3) 0}
.astryx-divider-labelled::before,.astryx-divider-labelled::after{content:"";flex:1;height:var(--border-width);background:var(--color-border)}
.astryx-divider-labelled__text{font-family:var(--font-family-body);font-size:var(--text-supporting-size);
  color:var(--color-text-secondary);white-space:nowrap}
`);

/**
 * Divider — a hairline separator between content. Optionally labelled (e.g. "OR").
 */
function Divider({
  orientation = 'horizontal',
  label,
  style,
  ...rest
}) {
  if (label) {
    return /*#__PURE__*/React.createElement("div", _extends({
      className: "astryx-divider-labelled",
      style: style
    }, rest), /*#__PURE__*/React.createElement("span", {
      className: "astryx-divider-labelled__text"
    }, label));
  }
  return /*#__PURE__*/React.createElement("hr", _extends({
    className: "astryx-divider",
    "data-orientation": orientation,
    style: style
  }, rest));
}
Object.assign(__ds_scope, { Divider });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/Divider.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Banner.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('banner', `
.astryx-banner{display:flex;align-items:flex-start;gap:var(--spacing-3);padding:var(--spacing-3);
  font-family:var(--font-family-body);border-radius:var(--radius-container)}
.astryx-banner[data-container="section"]{border-radius:0}
.astryx-banner[data-status="info"]{background:var(--color-background-blue);color:var(--color-text-blue)}
.astryx-banner[data-status="success"]{background:var(--color-success-muted);color:var(--color-text-green)}
.astryx-banner[data-status="warning"]{background:var(--color-warning-muted);color:var(--color-text-yellow)}
.astryx-banner[data-status="error"]{background:var(--color-error-muted);color:var(--color-text-red)}
.astryx-banner__icon{flex-shrink:0;display:flex;margin-top:1px}
.astryx-banner__icon svg{width:18px;height:18px}
.astryx-banner__body{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}
.astryx-banner__title{font-weight:var(--font-weight-semibold);font-size:var(--text-label-size)}
.astryx-banner__desc{font-size:var(--text-supporting-size);opacity:.9}
.astryx-banner__end{flex-shrink:0;display:flex;align-items:center;gap:var(--spacing-2)}
.astryx-banner__dismiss{display:flex;align-items:center;justify-content:center;width:22px;height:22px;border:0;padding:0;
  background:transparent;color:inherit;cursor:pointer;border-radius:var(--radius-inner);opacity:.7}
.astryx-banner__dismiss:hover{opacity:1;background:var(--color-overlay-hover)}
`);
const ICONS = {
  info: /*#__PURE__*/React.createElement("path", {
    d: "M12 16v-5M12 8h.01M12 3a9 9 0 100 18 9 9 0 000-18z",
    stroke: "currentColor",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    fill: "none"
  }),
  success: /*#__PURE__*/React.createElement("path", {
    d: "M20 7L10 17l-5-5",
    stroke: "currentColor",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    fill: "none"
  }),
  warning: /*#__PURE__*/React.createElement("path", {
    d: "M12 9v4M12 17h.01M10.3 4.3L2.5 18a1.9 1.9 0 001.7 2.9h15.6A1.9 1.9 0 0021.5 18L13.7 4.3a1.9 1.9 0 00-3.4 0z",
    stroke: "currentColor",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    fill: "none"
  }),
  error: /*#__PURE__*/React.createElement("path", {
    d: "M12 8v5M12 16h.01M12 3a9 9 0 100 18 9 9 0 000-18z",
    stroke: "currentColor",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    fill: "none"
  })
};
function XIcon() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 16 16",
    fill: "none",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M4 4l8 8M12 4l-8 8",
    stroke: "currentColor",
    strokeWidth: "1.5",
    strokeLinecap: "round"
  }));
}

/**
 * Banner — a persistent, status-colored message for errors, warnings, updates,
 * or confirmations. For short-lived auto-dismissing feedback, use Toast.
 */
function Banner({
  status = 'info',
  title,
  description,
  icon,
  endContent,
  isDismissable,
  onDismiss,
  container = 'card',
  style,
  ...rest
}) {
  const [hidden, setHidden] = React.useState(false);
  if (hidden) return null;
  return /*#__PURE__*/React.createElement("div", _extends({
    className: "astryx-banner",
    role: "status",
    "data-status": status,
    "data-container": container,
    style: style
  }, rest), /*#__PURE__*/React.createElement("span", {
    className: "astryx-banner__icon",
    "aria-hidden": "true"
  }, icon || /*#__PURE__*/React.createElement("svg", {
    viewBox: "0 0 24 24"
  }, ICONS[status])), /*#__PURE__*/React.createElement("div", {
    className: "astryx-banner__body"
  }, title && /*#__PURE__*/React.createElement("span", {
    className: "astryx-banner__title"
  }, title), description && /*#__PURE__*/React.createElement("span", {
    className: "astryx-banner__desc"
  }, description)), (endContent || isDismissable) && /*#__PURE__*/React.createElement("div", {
    className: "astryx-banner__end"
  }, endContent, isDismissable && /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: "astryx-banner__dismiss",
    "aria-label": "Dismiss",
    onClick: () => {
      setHidden(true);
      onDismiss && onDismiss();
    }
  }, /*#__PURE__*/React.createElement(XIcon, null))));
}
Object.assign(__ds_scope, { Banner });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Banner.jsx", error: String((e && e.message) || e) }); }

// components/feedback/ProgressBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('progress', `
.astryx-progress{width:100%;height:8px;border-radius:var(--radius-full);background:var(--color-border-emphasized);overflow:hidden}
.astryx-progress__fill{height:100%;border-radius:var(--radius-full);background:var(--color-accent);
  transition:width var(--duration-medium) var(--ease-standard)}
.astryx-progress[data-variant="accent"] .astryx-progress__fill{background:var(--color-vivid-blue)}
.astryx-progress[data-variant="success"] .astryx-progress__fill{background:var(--color-vivid-green)}
.astryx-progress[data-variant="warning"] .astryx-progress__fill{background:var(--color-vivid-yellow)}
.astryx-progress[data-variant="error"] .astryx-progress__fill{background:var(--color-vivid-red)}
`);

/**
 * ProgressBar — a determinate progress track (0–100).
 */
function ProgressBar({
  value = 0,
  max = 100,
  variant = 'default',
  style,
  ...rest
}) {
  const pct = Math.max(0, Math.min(100, value / max * 100));
  return /*#__PURE__*/React.createElement("div", _extends({
    className: "astryx-progress",
    "data-variant": variant,
    role: "progressbar",
    "aria-valuenow": value,
    "aria-valuemin": 0,
    "aria-valuemax": max,
    style: style
  }, rest), /*#__PURE__*/React.createElement("div", {
    className: "astryx-progress__fill",
    style: {
      width: pct + '%'
    }
  }));
}
Object.assign(__ds_scope, { ProgressBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/ProgressBar.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Skeleton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('skeleton', `
@keyframes astryx-pulse{0%,100%{opacity:1}50%{opacity:.45}}
.astryx-skeleton{display:block;background:var(--color-skeleton);border-radius:var(--radius-inner);
  animation:astryx-pulse 1.4s var(--ease-standard) infinite}
.astryx-skeleton[data-shape="circle"]{border-radius:var(--radius-full)}
.astryx-skeleton[data-shape="text"]{border-radius:var(--radius-full);height:.7em}
`);

/**
 * Skeleton — a shimmering placeholder shown while content loads, matching the
 * shape of what will appear.
 */
function Skeleton({
  shape = 'rect',
  width,
  height,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("span", _extends({
    className: "astryx-skeleton",
    "data-shape": shape,
    "aria-hidden": "true",
    style: {
      width,
      height,
      ...style
    }
  }, rest));
}
Object.assign(__ds_scope, { Skeleton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Skeleton.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Spinner.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('spinner', `
@keyframes astryx-spin{to{transform:rotate(360deg)}}
.astryx-spinner{display:inline-block;animation:astryx-spin .7s linear infinite;color:var(--color-icon-secondary)}
.astryx-spinner[data-shade="accent"]{color:var(--color-accent)}
.astryx-spinner[data-shade="inherit"]{color:inherit}
`);
const SIZES = {
  sm: 16,
  md: 20,
  lg: 24
};

/**
 * Spinner — an indeterminate loading indicator.
 */
function Spinner({
  size = 'md',
  shade = 'secondary',
  style,
  ...rest
}) {
  const s = SIZES[size] || size;
  return /*#__PURE__*/React.createElement("span", _extends({
    className: "astryx-spinner",
    "data-shade": shade,
    role: "status",
    "aria-label": "Loading",
    style: style
  }, rest), /*#__PURE__*/React.createElement("svg", {
    width: s,
    height: s,
    viewBox: "0 0 16 16",
    fill: "none",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "8",
    cy: "8",
    r: "6.5",
    stroke: "currentColor",
    strokeOpacity: "0.25",
    strokeWidth: "2"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M14.5 8a6.5 6.5 0 0 0-6.5-6.5",
    stroke: "currentColor",
    strokeWidth: "2",
    strokeLinecap: "round"
  })));
}
Object.assign(__ds_scope, { Spinner });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Spinner.jsx", error: String((e && e.message) || e) }); }

// components/feedback/StatusDot.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('status-dot', `
.astryx-status-dot{display:inline-flex;align-items:center;gap:var(--spacing-2);font-family:var(--font-family-body);
  font-size:var(--text-supporting-size);color:var(--color-text-secondary)}
.astryx-status-dot__dot{width:8px;height:8px;border-radius:var(--radius-full);flex-shrink:0}
.astryx-status-dot__dot[data-tone="neutral"]{background:var(--color-icon-secondary)}
.astryx-status-dot__dot[data-tone="success"]{background:var(--color-vivid-green)}
.astryx-status-dot__dot[data-tone="warning"]{background:var(--color-vivid-yellow)}
.astryx-status-dot__dot[data-tone="error"]{background:var(--color-vivid-red)}
.astryx-status-dot__dot[data-tone="info"]{background:var(--color-vivid-blue)}
`);

/**
 * StatusDot — a small colored dot (optionally labeled) for online/health/state.
 */
function StatusDot({
  tone = 'neutral',
  label,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("span", _extends({
    className: "astryx-status-dot",
    style: style
  }, rest), /*#__PURE__*/React.createElement("span", {
    className: "astryx-status-dot__dot",
    "data-tone": tone
  }), label);
}
Object.assign(__ds_scope, { StatusDot });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/StatusDot.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Toast.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('toast', `
.astryx-toast{display:flex;align-items:flex-start;gap:var(--spacing-2);min-width:280px;max-width:420px;
  padding:var(--spacing-3);font-family:var(--font-family-body);background:var(--color-background-inverted);
  color:var(--color-background-body);border-radius:var(--radius-element);box-shadow:var(--shadow-high)}
.astryx-toast__icon{flex-shrink:0;display:flex;margin-top:1px}
.astryx-toast__icon svg{width:18px;height:18px}
.astryx-toast[data-type="success"] .astryx-toast__icon{color:var(--color-vivid-green)}
.astryx-toast[data-type="error"] .astryx-toast__icon{color:var(--color-vivid-red)}
.astryx-toast[data-type="warning"] .astryx-toast__icon{color:var(--color-vivid-yellow)}
.astryx-toast[data-type="info"] .astryx-toast__icon{color:var(--color-vivid-blue)}
.astryx-toast__body{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px}
.astryx-toast__title{font-weight:var(--font-weight-semibold);font-size:var(--text-label-size)}
.astryx-toast__desc{font-size:var(--text-supporting-size);opacity:.8}
.astryx-toast__action{flex-shrink:0}
.astryx-toast__dismiss{display:flex;align-items:center;justify-content:center;width:22px;height:22px;border:0;padding:0;
  background:transparent;color:inherit;cursor:pointer;border-radius:var(--radius-inner);opacity:.6}
.astryx-toast__dismiss:hover{opacity:1}
`);
const ICONS = {
  success: /*#__PURE__*/React.createElement("path", {
    d: "M20 7L10 17l-5-5",
    stroke: "currentColor",
    strokeWidth: "2",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    fill: "none"
  }),
  error: /*#__PURE__*/React.createElement("path", {
    d: "M12 8v5M12 16h.01M12 3a9 9 0 100 18 9 9 0 000-18z",
    stroke: "currentColor",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    fill: "none"
  }),
  warning: /*#__PURE__*/React.createElement("path", {
    d: "M12 9v4M12 17h.01M10.3 4.3L2.5 18a1.9 1.9 0 001.7 2.9h15.6A1.9 1.9 0 0021.5 18L13.7 4.3a1.9 1.9 0 00-3.4 0z",
    stroke: "currentColor",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    fill: "none"
  }),
  info: /*#__PURE__*/React.createElement("path", {
    d: "M12 16v-5M12 8h.01M12 3a9 9 0 100 18 9 9 0 000-18z",
    stroke: "currentColor",
    strokeWidth: "1.8",
    strokeLinecap: "round",
    strokeLinejoin: "round",
    fill: "none"
  })
};
function XIcon() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "15",
    height: "15",
    viewBox: "0 0 16 16",
    fill: "none",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M4 4l8 8M12 4l-8 8",
    stroke: "currentColor",
    strokeWidth: "1.5",
    strokeLinecap: "round"
  }));
}

/**
 * Toast — a brief, auto-dismissing confirmation on a dark inverted surface.
 * This is the visual shell; wire timing/queueing in your app.
 */
function Toast({
  type = 'info',
  title,
  description,
  action,
  onDismiss,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    className: "astryx-toast",
    role: "status",
    "data-type": type,
    style: style
  }, rest), type && type !== 'plain' && /*#__PURE__*/React.createElement("span", {
    className: "astryx-toast__icon",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement("svg", {
    viewBox: "0 0 24 24"
  }, ICONS[type])), /*#__PURE__*/React.createElement("div", {
    className: "astryx-toast__body"
  }, title && /*#__PURE__*/React.createElement("span", {
    className: "astryx-toast__title"
  }, title), description && /*#__PURE__*/React.createElement("span", {
    className: "astryx-toast__desc"
  }, description)), action && /*#__PURE__*/React.createElement("span", {
    className: "astryx-toast__action"
  }, action), onDismiss && /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: "astryx-toast__dismiss",
    "aria-label": "Dismiss",
    onClick: onDismiss
  }, /*#__PURE__*/React.createElement(XIcon, null)));
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Toast.jsx", error: String((e && e.message) || e) }); }

// components/forms/Checkbox.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('checkbox', `
.astryx-check-field{display:inline-flex;align-items:flex-start;gap:var(--spacing-2);font-family:var(--font-family-body);cursor:pointer}
.astryx-check-field[data-disabled]{opacity:.5;cursor:not-allowed}
.astryx-check{position:relative;flex-shrink:0;width:18px;height:18px;margin-top:1px;border-radius:var(--radius-inner);
  border:var(--border-width) solid var(--color-border-emphasized);background:var(--color-background-surface);
  display:flex;align-items:center;justify-content:center;color:var(--color-on-accent);
  transition:background var(--duration-fast) var(--ease-standard),border-color var(--duration-fast) var(--ease-standard)}
.astryx-check[data-on]{background:var(--color-accent);border-color:var(--color-accent)}
.astryx-check svg{opacity:0}
.astryx-check[data-on] svg{opacity:1}
.astryx-check input{position:absolute;opacity:0;width:100%;height:100%;margin:0;cursor:inherit}
.astryx-check-field:focus-within .astryx-check{outline:2px solid var(--color-accent);outline-offset:2px}
.astryx-check-text{display:flex;flex-direction:column;gap:2px}
.astryx-check-label{font-size:var(--text-label-size);font-weight:var(--text-label-weight);color:var(--color-text-primary)}
.astryx-check-desc{font-size:var(--text-supporting-size);color:var(--color-text-secondary)}
`);
function Check() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "12",
    height: "12",
    viewBox: "0 0 16 16",
    fill: "none",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M3.5 8.5l3 3 6-7",
    stroke: "currentColor",
    strokeWidth: "2",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }));
}

/**
 * Checkbox — a single boolean choice, typically committed on form submit.
 */
function Checkbox({
  label,
  value = false,
  onChange,
  description,
  isDisabled,
  htmlName,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", {
    className: "astryx-check-field",
    "data-disabled": isDisabled ? '' : undefined,
    style: style
  }, /*#__PURE__*/React.createElement("span", {
    className: "astryx-check",
    "data-on": value ? '' : undefined
  }, /*#__PURE__*/React.createElement("input", _extends({
    type: "checkbox",
    checked: value,
    disabled: isDisabled,
    name: htmlName,
    "aria-label": !label ? undefined : label,
    onChange: e => onChange && onChange(e.target.checked, e)
  }, rest)), /*#__PURE__*/React.createElement(Check, null)), label && /*#__PURE__*/React.createElement("span", {
    className: "astryx-check-text"
  }, /*#__PURE__*/React.createElement("span", {
    className: "astryx-check-label"
  }, label), description && /*#__PURE__*/React.createElement("span", {
    className: "astryx-check-desc"
  }, description)));
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/forms/RadioGroup.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('radio', `
.astryx-radio-group{display:flex;flex-direction:column;gap:var(--spacing-2);font-family:var(--font-family-body)}
.astryx-radio-group__legend{font-size:var(--text-label-size);font-weight:var(--text-label-weight);color:var(--color-text-primary);margin-bottom:var(--spacing-1)}
.astryx-radio-field{display:inline-flex;align-items:flex-start;gap:var(--spacing-2);cursor:pointer}
.astryx-radio-field[data-disabled]{opacity:.5;cursor:not-allowed}
.astryx-radio{position:relative;flex-shrink:0;width:18px;height:18px;margin-top:1px;border-radius:var(--radius-full);
  border:var(--border-width) solid var(--color-border-emphasized);background:var(--color-background-surface);
  display:flex;align-items:center;justify-content:center;transition:border-color var(--duration-fast) var(--ease-standard)}
.astryx-radio[data-on]{border-color:var(--color-accent);border-width:5px}
.astryx-radio input{position:absolute;opacity:0;width:100%;height:100%;margin:0;cursor:inherit}
.astryx-radio-field:focus-within .astryx-radio{outline:2px solid var(--color-accent);outline-offset:2px}
.astryx-radio-text{display:flex;flex-direction:column;gap:2px}
.astryx-radio-label{font-size:var(--text-label-size);color:var(--color-text-primary)}
.astryx-radio-desc{font-size:var(--text-supporting-size);color:var(--color-text-secondary)}
`);

/**
 * RadioGroup — a single choice among a small set of mutually exclusive options.
 * Options are `{value, label, description?}`.
 */
function RadioGroup({
  label,
  options = [],
  value,
  onChange,
  name,
  isDisabled,
  style,
  ...rest
}) {
  const groupName = name || 'radio-' + Math.random().toString(36).slice(2, 8);
  return /*#__PURE__*/React.createElement("div", _extends({
    className: "astryx-radio-group",
    role: "radiogroup",
    "aria-label": label,
    style: style
  }, rest), label && /*#__PURE__*/React.createElement("div", {
    className: "astryx-radio-group__legend"
  }, label), options.map(opt => /*#__PURE__*/React.createElement("label", {
    key: opt.value,
    className: "astryx-radio-field",
    "data-disabled": isDisabled ? '' : undefined
  }, /*#__PURE__*/React.createElement("span", {
    className: "astryx-radio",
    "data-on": value === opt.value ? '' : undefined
  }, /*#__PURE__*/React.createElement("input", {
    type: "radio",
    name: groupName,
    value: opt.value,
    checked: value === opt.value,
    disabled: isDisabled,
    onChange: e => onChange && onChange(opt.value, e)
  })), /*#__PURE__*/React.createElement("span", {
    className: "astryx-radio-text"
  }, /*#__PURE__*/React.createElement("span", {
    className: "astryx-radio-label"
  }, opt.label), opt.description && /*#__PURE__*/React.createElement("span", {
    className: "astryx-radio-desc"
  }, opt.description)))));
}
Object.assign(__ds_scope, { RadioGroup });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/RadioGroup.jsx", error: String((e && e.message) || e) }); }

// components/forms/SegmentedControl.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('segmented', `
.astryx-segmented{display:inline-flex;padding:2px;gap:2px;background:var(--color-background-muted);
  border-radius:var(--radius-element);border:var(--border-width) solid var(--color-border)}
.astryx-segmented[data-size="sm"]{height:var(--size-element-sm)}
.astryx-segmented[data-size="md"]{height:var(--size-element-md)}
.astryx-segmented[data-size="lg"]{height:var(--size-element-lg)}
.astryx-segmented__opt{display:inline-flex;align-items:center;justify-content:center;gap:var(--spacing-1);
  padding:0 var(--spacing-3);border:0;background:transparent;border-radius:calc(var(--radius-element) - 2px);
  font-family:var(--font-family-body);font-size:var(--text-label-size);font-weight:var(--font-weight-medium);
  color:var(--color-text-secondary);cursor:pointer;white-space:nowrap;
  transition:background var(--duration-fast) var(--ease-standard),color var(--duration-fast) var(--ease-standard)}
.astryx-segmented__opt:hover{color:var(--color-text-primary)}
.astryx-segmented__opt[data-on]{background:var(--color-background-surface);color:var(--color-text-primary);box-shadow:var(--shadow-low)}
.astryx-segmented__opt:focus-visible{outline:2px solid var(--color-accent);outline-offset:2px}
.astryx-segmented__opt svg{width:16px;height:16px}
`);

/**
 * SegmentedControl — a compact single-select toggle among 2–5 options.
 * Options are `{value, label, icon?}`.
 */
function SegmentedControl({
  options = [],
  value,
  onChange,
  size = 'md',
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    className: "astryx-segmented",
    role: "tablist",
    "data-size": size,
    style: style
  }, rest), options.map(opt => /*#__PURE__*/React.createElement("button", {
    key: opt.value,
    type: "button",
    className: "astryx-segmented__opt",
    role: "tab",
    "aria-selected": value === opt.value,
    "data-on": value === opt.value ? '' : undefined,
    onClick: e => onChange && onChange(opt.value, e)
  }, opt.icon, opt.label)));
}
Object.assign(__ds_scope, { SegmentedControl });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/SegmentedControl.jsx", error: String((e && e.message) || e) }); }

// components/forms/Select.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('select', `
.astryx-select-wrap{position:relative;display:flex;align-items:center;background:var(--color-background-surface);
  border:var(--border-width) solid var(--color-border-emphasized);border-radius:var(--radius-element);
  transition:box-shadow var(--duration-fast) var(--ease-standard),border-color var(--duration-fast) var(--ease-standard)}
.astryx-select-wrap[data-size="sm"]{height:var(--size-element-sm)}
.astryx-select-wrap[data-size="md"]{height:var(--size-element-md)}
.astryx-select-wrap[data-size="lg"]{height:var(--size-element-lg)}
.astryx-select-wrap:focus-within{border-color:var(--color-vivid-blue);box-shadow:var(--shadow-inset-selected)}
.astryx-select-wrap[data-disabled]{opacity:.5}
.astryx-select{appearance:none;flex:1;min-width:0;height:100%;border:0;outline:0;background:transparent;
  padding:0 var(--spacing-8) 0 var(--spacing-3);font-family:inherit;font-size:var(--font-size-base);
  color:var(--color-text-primary);cursor:pointer}
.astryx-select-wrap__chev{position:absolute;right:var(--spacing-3);pointer-events:none;color:var(--color-icon-secondary);display:flex}
`);
function Chevron() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 16 16",
    fill: "none",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M4 6l4 4 4-4",
    stroke: "currentColor",
    strokeWidth: "1.5",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }));
}

/**
 * Select — a single choice from a longer list, backed by a native <select>.
 * Options are `{value, label}`.
 */
function Select({
  label,
  options = [],
  value,
  onChange,
  placeholder,
  size = 'md',
  description,
  isRequired,
  isOptional,
  isDisabled,
  isLabelHidden,
  htmlName,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", {
    className: "astryx-field",
    style: style
  }, !isLabelHidden && label && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__label"
  }, label, isOptional && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__opt"
  }, "Optional"), isRequired && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__req"
  }, "*")), description && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__desc"
  }, description), /*#__PURE__*/React.createElement("span", {
    className: "astryx-select-wrap",
    "data-size": size,
    "data-disabled": isDisabled ? '' : undefined
  }, /*#__PURE__*/React.createElement("select", _extends({
    className: "astryx-select",
    value: value ?? '',
    disabled: isDisabled,
    name: htmlName,
    "aria-label": isLabelHidden ? label : undefined,
    onChange: e => onChange && onChange(e.target.value, e)
  }, rest), placeholder && /*#__PURE__*/React.createElement("option", {
    value: "",
    disabled: true
  }, placeholder), options.map(opt => /*#__PURE__*/React.createElement("option", {
    key: opt.value,
    value: opt.value
  }, opt.label))), /*#__PURE__*/React.createElement("span", {
    className: "astryx-select-wrap__chev"
  }, /*#__PURE__*/React.createElement(Chevron, null))));
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// components/forms/Switch.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('switch', `
.astryx-switch-field{display:flex;align-items:center;gap:var(--spacing-2);font-family:var(--font-family-body);cursor:pointer}
.astryx-switch-field[data-spacing="spread"]{justify-content:space-between;width:100%}
.astryx-switch-field[data-pos="start"]{flex-direction:row-reverse}
.astryx-switch-field[data-disabled]{opacity:.5;cursor:not-allowed}
.astryx-switch-text{display:flex;flex-direction:column;gap:2px}
.astryx-switch-label{font-size:var(--text-label-size);font-weight:var(--text-label-weight);color:var(--color-text-primary)}
.astryx-switch-desc{font-size:var(--text-supporting-size);color:var(--color-text-secondary)}
.astryx-switch{position:relative;flex-shrink:0;width:36px;height:20px;border-radius:var(--radius-full);
  background:var(--color-border-emphasized);transition:background var(--duration-fast) var(--ease-standard)}
.astryx-switch[data-on]{background:var(--color-accent)}
.astryx-switch__thumb{position:absolute;top:2px;left:2px;width:16px;height:16px;border-radius:var(--radius-full);
  background:#fff;box-shadow:0 1px 2px rgba(0,0,0,.3);transition:transform var(--duration-fast) var(--ease-standard)}
.astryx-switch[data-on] .astryx-switch__thumb{transform:translateX(16px)}
.astryx-switch input{position:absolute;opacity:0;width:100%;height:100%;margin:0;cursor:inherit}
.astryx-switch-field:focus-within .astryx-switch{outline:2px solid var(--color-accent);outline-offset:2px}
`);

/**
 * Switch — a toggle for on/off settings that take effect immediately.
 */
function Switch({
  label,
  value = false,
  onChange,
  description,
  isDisabled,
  isLabelHidden,
  labelPosition = 'end',
  labelSpacing = 'hug',
  htmlName,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", {
    className: "astryx-switch-field",
    "data-pos": labelPosition,
    "data-spacing": labelSpacing,
    "data-disabled": isDisabled ? '' : undefined,
    style: style
  }, !isLabelHidden && /*#__PURE__*/React.createElement("span", {
    className: "astryx-switch-text"
  }, /*#__PURE__*/React.createElement("span", {
    className: "astryx-switch-label"
  }, label), description && /*#__PURE__*/React.createElement("span", {
    className: "astryx-switch-desc"
  }, description)), /*#__PURE__*/React.createElement("span", {
    className: "astryx-switch",
    "data-on": value ? '' : undefined
  }, /*#__PURE__*/React.createElement("input", _extends({
    type: "checkbox",
    role: "switch",
    checked: value,
    disabled: isDisabled,
    name: htmlName,
    "aria-label": isLabelHidden ? label : undefined,
    onChange: e => onChange && onChange(e.target.checked, e)
  }, rest)), /*#__PURE__*/React.createElement("span", {
    className: "astryx-switch__thumb"
  })));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// components/forms/TextArea.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('textarea', `
.astryx-textarea{width:100%;min-height:80px;resize:vertical;background:var(--color-background-surface);
  border:var(--border-width) solid var(--color-border-emphasized);border-radius:var(--radius-element);
  padding:var(--spacing-2) var(--spacing-3);font-family:inherit;font-size:var(--font-size-base);
  line-height:var(--text-body-leading);color:var(--color-text-primary);outline:0;
  transition:box-shadow var(--duration-fast) var(--ease-standard),border-color var(--duration-fast) var(--ease-standard)}
.astryx-textarea::placeholder{color:var(--color-text-secondary)}
.astryx-textarea:focus{border-color:var(--color-vivid-blue);box-shadow:var(--shadow-inset-selected)}
.astryx-textarea[data-status="error"]{border-color:var(--color-error)}
.astryx-textarea:disabled{opacity:.5;cursor:not-allowed}
`);

/**
 * TextArea — multi-line text entry for comments, descriptions, and notes.
 */
function TextArea({
  label,
  value = '',
  onChange,
  placeholder,
  rows = 3,
  description,
  isRequired,
  isOptional,
  isDisabled,
  isLabelHidden,
  status,
  htmlName,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", {
    className: "astryx-field",
    style: style
  }, !isLabelHidden && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__label"
  }, label, isOptional && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__opt"
  }, "Optional"), isRequired && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__req"
  }, "*")), description && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__desc"
  }, description), /*#__PURE__*/React.createElement("textarea", _extends({
    className: "astryx-textarea",
    "data-status": status?.type,
    rows: rows,
    value: value,
    name: htmlName,
    placeholder: placeholder,
    disabled: isDisabled,
    "aria-label": isLabelHidden ? label : undefined,
    "aria-invalid": status?.type === 'error' || undefined,
    onChange: e => onChange && onChange(e.target.value, e)
  }, rest)), status?.message && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__msg",
    "data-type": status.type
  }, status.message));
}
Object.assign(__ds_scope, { TextArea });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/TextArea.jsx", error: String((e && e.message) || e) }); }

// components/forms/TextInput.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('field', `
.astryx-field{display:flex;flex-direction:column;gap:var(--spacing-1);font-family:var(--font-family-body)}
.astryx-field__label{display:flex;align-items:center;gap:var(--spacing-1);font-size:var(--text-label-size);
  font-weight:var(--text-label-weight);line-height:var(--text-label-leading);color:var(--color-text-primary)}
.astryx-field__opt{font-weight:var(--font-weight-normal);color:var(--color-text-secondary)}
.astryx-field__req{color:var(--color-error)}
.astryx-field__desc{font-size:var(--text-supporting-size);color:var(--color-text-secondary);line-height:var(--text-supporting-leading)}
.astryx-field__msg{display:flex;align-items:center;gap:var(--spacing-1);font-size:var(--text-supporting-size);line-height:var(--text-supporting-leading)}
.astryx-field__msg[data-type="error"]{color:var(--color-error)}
.astryx-field__msg[data-type="warning"]{color:var(--color-warning)}
.astryx-field__msg[data-type="success"]{color:var(--color-success)}
`);
inject('text-input', `
.astryx-input-wrap{position:relative;display:flex;align-items:center;background:var(--color-background-surface);
  border:var(--border-width) solid var(--color-border-emphasized);border-radius:var(--radius-element);
  transition:box-shadow var(--duration-fast) var(--ease-standard),border-color var(--duration-fast) var(--ease-standard)}
.astryx-input-wrap[data-size="sm"]{height:var(--size-element-sm)}
.astryx-input-wrap[data-size="md"]{height:var(--size-element-md)}
.astryx-input-wrap[data-size="lg"]{height:var(--size-element-lg)}
.astryx-input-wrap:focus-within{border-color:var(--color-vivid-blue);box-shadow:var(--shadow-inset-selected)}
.astryx-input-wrap[data-status="error"]{border-color:var(--color-error)}
.astryx-input-wrap[data-status="warning"]{border-color:var(--color-warning)}
.astryx-input-wrap[data-status="success"]{border-color:var(--color-success)}
.astryx-input-wrap[data-disabled]{opacity:.5;cursor:not-allowed}
.astryx-input{flex:1;min-width:0;height:100%;border:0;outline:0;background:transparent;padding:0 var(--spacing-3);
  font-family:inherit;font-size:var(--font-size-base);color:var(--color-text-primary)}
.astryx-input::placeholder{color:var(--color-text-secondary)}
.astryx-input-wrap__icon{display:flex;align-items:center;color:var(--color-icon-secondary);padding-left:var(--spacing-3)}
.astryx-input-wrap__end{display:flex;align-items:center;color:var(--color-icon-secondary);padding-right:var(--spacing-2)}
.astryx-input-clear{display:flex;align-items:center;justify-content:center;width:20px;height:20px;border:0;padding:0;
  background:transparent;color:var(--color-icon-secondary);cursor:pointer;border-radius:var(--radius-full)}
.astryx-input-clear:hover{background:var(--color-overlay-hover);color:var(--color-icon-primary)}
`);
function XIcon() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "14",
    height: "14",
    viewBox: "0 0 16 16",
    fill: "none",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M4 4l8 8M12 4l-8 8",
    stroke: "currentColor",
    strokeWidth: "1.5",
    strokeLinecap: "round"
  }));
}

/**
 * TextInput — collects short single-line text with an always-rendered label,
 * optional description, validation status, and a clear button.
 */
function TextInput({
  label,
  value = '',
  onChange,
  type = 'text',
  size = 'md',
  placeholder,
  description,
  isRequired,
  isOptional,
  isDisabled,
  isLabelHidden,
  startIcon,
  hasClear,
  status,
  htmlName,
  style,
  ...rest
}) {
  const handle = e => onChange && onChange(e.target.value, e);
  return /*#__PURE__*/React.createElement("label", {
    className: "astryx-field",
    style: style
  }, !isLabelHidden && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__label"
  }, label, isOptional && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__opt"
  }, "Optional"), isRequired && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__req"
  }, "*")), description && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__desc"
  }, description), /*#__PURE__*/React.createElement("span", {
    className: "astryx-input-wrap",
    "data-size": size,
    "data-status": status?.type,
    "data-disabled": isDisabled ? '' : undefined
  }, startIcon && /*#__PURE__*/React.createElement("span", {
    className: "astryx-input-wrap__icon"
  }, startIcon), /*#__PURE__*/React.createElement("input", _extends({
    className: "astryx-input",
    type: type,
    value: value,
    name: htmlName,
    placeholder: placeholder,
    disabled: isDisabled,
    "aria-label": isLabelHidden ? label : undefined,
    "aria-invalid": status?.type === 'error' || undefined,
    onChange: handle
  }, rest)), hasClear && value && !isDisabled && /*#__PURE__*/React.createElement("span", {
    className: "astryx-input-wrap__end"
  }, /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: "astryx-input-clear",
    "aria-label": "Clear",
    onClick: e => onChange && onChange('', e)
  }, /*#__PURE__*/React.createElement(XIcon, null)))), status?.message && /*#__PURE__*/React.createElement("span", {
    className: "astryx-field__msg",
    "data-type": status.type
  }, status.message));
}
Object.assign(__ds_scope, { TextInput });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/TextInput.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Breadcrumbs.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('breadcrumbs', `
.astryx-crumbs{display:flex;align-items:center;gap:var(--spacing-1);font-family:var(--font-family-body);
  font-size:var(--text-supporting-size);color:var(--color-text-secondary);list-style:none;margin:0;padding:0}
.astryx-crumbs a{color:var(--color-text-secondary);text-decoration:none;border-radius:var(--radius-inner);padding:2px 4px}
.astryx-crumbs a:hover{color:var(--color-text-primary);background:var(--color-overlay-hover)}
.astryx-crumbs__sep{color:var(--color-icon-disabled);display:flex}
.astryx-crumbs__current{color:var(--color-text-primary);font-weight:var(--font-weight-medium);padding:2px 4px}
`);
function Sep() {
  return /*#__PURE__*/React.createElement("span", {
    className: "astryx-crumbs__sep",
    "aria-hidden": "true"
  }, /*#__PURE__*/React.createElement("svg", {
    width: "14",
    height: "14",
    viewBox: "0 0 16 16",
    fill: "none"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M6 3l4 5-4 5",
    stroke: "currentColor",
    strokeWidth: "1.5",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  })));
}

/**
 * Breadcrumbs — a compact trail showing the current page's place in a
 * hierarchy. Items are `{label, href?}`; the last item is the current page.
 */
function Breadcrumbs({
  items = [],
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("nav", _extends({
    "aria-label": "Breadcrumb",
    style: style
  }, rest), /*#__PURE__*/React.createElement("ol", {
    className: "astryx-crumbs"
  }, items.map((item, i) => {
    const last = i === items.length - 1;
    return /*#__PURE__*/React.createElement("li", {
      key: i,
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 'var(--spacing-1)'
      }
    }, last || !item.href ? /*#__PURE__*/React.createElement("span", {
      className: "astryx-crumbs__current",
      "aria-current": last ? 'page' : undefined
    }, item.label) : /*#__PURE__*/React.createElement("a", {
      href: item.href
    }, item.label), !last && /*#__PURE__*/React.createElement(Sep, null));
  })));
}
Object.assign(__ds_scope, { Breadcrumbs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Breadcrumbs.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Tabs.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const _seen = new Set();
function inject(id, css) {
  if (typeof document === 'undefined' || _seen.has(id)) return;
  _seen.add(id);
  const el = document.createElement('style');
  el.setAttribute('data-astryx', id);
  el.textContent = css;
  document.head.appendChild(el);
}
inject('tabs', `
.astryx-tabs{display:flex;gap:var(--spacing-4);border-bottom:var(--border-width) solid var(--color-border);font-family:var(--font-family-body)}
.astryx-tab{position:relative;display:inline-flex;align-items:center;gap:var(--spacing-2);padding:var(--spacing-2) 2px var(--spacing-3);
  border:0;background:transparent;font-family:inherit;font-size:var(--text-label-size);font-weight:var(--font-weight-medium);
  color:var(--color-text-secondary);cursor:pointer;white-space:nowrap;transition:color var(--duration-fast) var(--ease-standard)}
.astryx-tab:hover{color:var(--color-text-primary)}
.astryx-tab[data-on]{color:var(--color-text-primary)}
.astryx-tab[data-on]::after{content:"";position:absolute;left:0;right:0;bottom:-1px;height:2px;
  background:var(--color-accent);border-radius:var(--radius-full)}
.astryx-tab:focus-visible{outline:2px solid var(--color-accent);outline-offset:2px;border-radius:var(--radius-inner)}
.astryx-tab svg{width:16px;height:16px}
.astryx-tab__count{font-size:var(--font-size-sm);color:var(--color-text-secondary);
  background:var(--color-background-muted);border-radius:var(--radius-full);padding:0 6px}
`);

/**
 * Tabs — a horizontal underline tab bar for switching between peer views.
 * Options are `{value, label, icon?, count?}`.
 */
function Tabs({
  options = [],
  value,
  onChange,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    className: "astryx-tabs",
    role: "tablist",
    style: style
  }, rest), options.map(opt => /*#__PURE__*/React.createElement("button", {
    key: opt.value,
    type: "button",
    className: "astryx-tab",
    role: "tab",
    "aria-selected": value === opt.value,
    "data-on": value === opt.value ? '' : undefined,
    onClick: e => onChange && onChange(opt.value, e)
  }, opt.icon, opt.label, opt.count != null && /*#__PURE__*/React.createElement("span", {
    className: "astryx-tab__count"
  }, opt.count))));
}
Object.assign(__ds_scope, { Tabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Tabs.jsx", error: String((e && e.message) || e) }); }

// ui_kits/console/Screens.jsx
try { (() => {
// Dashboard + Settings screens for the Astryx Console kit.
const {
  Icon
} = window.CONSOLE;
const {
  Button,
  IconButton,
  Badge,
  Card,
  Avatar,
  Divider,
  TextInput,
  Select,
  Switch,
  RadioGroup,
  SegmentedControl,
  Banner,
  StatusDot,
  ProgressBar,
  Tabs
} = window.CONSOLE.NS;
const {
  useState
} = React;
const METRICS = [{
  label: 'Active projects',
  value: '48',
  delta: '+6',
  tone: 'success',
  icon: 'folder'
}, {
  label: 'Deployments today',
  value: '312',
  delta: '+18%',
  tone: 'success',
  icon: 'rocket'
}, {
  label: 'Error rate',
  value: '0.42%',
  delta: '-0.1%',
  tone: 'success',
  icon: 'alert-triangle'
}, {
  label: 'Open incidents',
  value: '3',
  delta: '+1',
  tone: 'error',
  icon: 'flame'
}];
const ROWS = [{
  name: 'web-frontend',
  owner: 'Ada Lovelace',
  status: 'Healthy',
  variant: 'success',
  progress: 92,
  env: 'prod'
}, {
  name: 'auth-service',
  owner: 'Alan Turing',
  status: 'Degraded',
  variant: 'warning',
  progress: 64,
  env: 'prod'
}, {
  name: 'billing-api',
  owner: 'Grace Hopper',
  status: 'Failed',
  variant: 'error',
  progress: 28,
  env: 'staging'
}, {
  name: 'docs-site',
  owner: 'Katherine J.',
  status: 'Healthy',
  variant: 'success',
  progress: 100,
  env: 'prod'
}];
function Metric({
  m
}) {
  return /*#__PURE__*/React.createElement(Card, {
    padding: 4,
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      color: 'var(--color-icon-secondary)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      color: 'var(--color-text-secondary)'
    }
  }, m.label), /*#__PURE__*/React.createElement(Icon, {
    name: m.icon,
    size: 16
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      gap: 8,
      marginTop: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 29,
      fontWeight: 700,
      letterSpacing: '-.01em'
    }
  }, m.value), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      fontWeight: 600,
      color: m.tone === 'error' ? 'var(--color-error)' : 'var(--color-success)'
    }
  }, m.delta)));
}
function Dashboard() {
  const [tab, setTab] = useState('all');
  const [view, setView] = useState('list');
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 'var(--spacing-5)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-end',
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("h1", {
    style: {
      margin: 0,
      fontSize: 24,
      fontWeight: 600
    }
  }, "Dashboard"), /*#__PURE__*/React.createElement("p", {
    style: {
      margin: '4px 0 0',
      color: 'var(--color-text-secondary)',
      fontSize: 14
    }
  }, "Fleet health across all environments.")), /*#__PURE__*/React.createElement(SegmentedControl, {
    value: view,
    onChange: setView,
    options: [{
      value: 'list',
      label: 'List'
    }, {
      value: 'grid',
      label: 'Grid'
    }]
  })), /*#__PURE__*/React.createElement(Banner, {
    status: "warning",
    title: "auth-service is degraded",
    description: "Elevated p95 latency in us-east-1 since 14:20 UTC.",
    endContent: /*#__PURE__*/React.createElement(Button, {
      label: "View incident",
      size: "sm"
    }),
    isDismissable: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 'var(--spacing-4)'
    }
  }, METRICS.map(m => /*#__PURE__*/React.createElement(Metric, {
    key: m.label,
    m: m
  }))), /*#__PURE__*/React.createElement(Card, {
    padding: 0
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '4px var(--spacing-4) 0'
    }
  }, /*#__PURE__*/React.createElement(Tabs, {
    value: tab,
    onChange: setTab,
    options: [{
      value: 'all',
      label: 'All services',
      count: 4
    }, {
      value: 'prod',
      label: 'Production'
    }, {
      value: 'staging',
      label: 'Staging'
    }]
  })), /*#__PURE__*/React.createElement("table", {
    style: {
      width: '100%',
      borderCollapse: 'collapse',
      fontSize: 14
    }
  }, /*#__PURE__*/React.createElement("thead", null, /*#__PURE__*/React.createElement("tr", {
    style: {
      textAlign: 'left',
      color: 'var(--color-text-secondary)',
      fontSize: 11,
      textTransform: 'uppercase',
      letterSpacing: '.04em'
    }
  }, /*#__PURE__*/React.createElement("th", {
    style: {
      padding: '12px 16px',
      fontWeight: 600
    }
  }, "Service"), /*#__PURE__*/React.createElement("th", {
    style: {
      padding: '12px 16px',
      fontWeight: 600
    }
  }, "Owner"), /*#__PURE__*/React.createElement("th", {
    style: {
      padding: '12px 16px',
      fontWeight: 600
    }
  }, "Status"), /*#__PURE__*/React.createElement("th", {
    style: {
      padding: '12px 16px',
      fontWeight: 600,
      width: 180
    }
  }, "Uptime"), /*#__PURE__*/React.createElement("th", {
    style: {
      padding: '12px 16px',
      fontWeight: 600
    }
  }, "Env"), /*#__PURE__*/React.createElement("th", {
    style: {
      padding: '12px 16px',
      width: 44
    }
  }))), /*#__PURE__*/React.createElement("tbody", null, ROWS.map(r => /*#__PURE__*/React.createElement("tr", {
    key: r.name,
    style: {
      borderTop: '1px solid var(--color-border)'
    }
  }, /*#__PURE__*/React.createElement("td", {
    style: {
      padding: '12px 16px',
      fontFamily: 'var(--font-family-code)',
      fontWeight: 500
    }
  }, r.name), /*#__PURE__*/React.createElement("td", {
    style: {
      padding: '12px 16px'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(Avatar, {
    name: r.owner,
    size: "xs"
  }), r.owner)), /*#__PURE__*/React.createElement("td", {
    style: {
      padding: '12px 16px'
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    label: r.status,
    variant: r.variant
  })), /*#__PURE__*/React.createElement("td", {
    style: {
      padding: '12px 16px'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 10,
      width: '100%'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement(ProgressBar, {
    value: r.progress,
    variant: r.variant === 'error' ? 'error' : r.variant === 'warning' ? 'warning' : 'success'
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: 'var(--color-text-secondary)',
      fontVariantNumeric: 'tabular-nums'
    }
  }, r.progress, "%"))), /*#__PURE__*/React.createElement("td", {
    style: {
      padding: '12px 16px'
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    label: r.env,
    variant: r.env === 'prod' ? 'purple' : 'gray'
  })), /*#__PURE__*/React.createElement("td", {
    style: {
      padding: '12px 16px'
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    label: "More",
    size: "sm",
    icon: /*#__PURE__*/React.createElement(Icon, {
      name: "more-horizontal",
      size: 16
    })
  }))))))));
}
function Settings() {
  const [name, setName] = useState('Astryx Platform');
  const [region, setRegion] = useState('us-east');
  const [visibility, setVisibility] = useState('team');
  const [deploys, setDeploys] = useState(true);
  const [alerts, setAlerts] = useState(true);
  const [saved, setSaved] = useState(false);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 'var(--spacing-5)',
      maxWidth: 640
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("h1", {
    style: {
      margin: 0,
      fontSize: 24,
      fontWeight: 600
    }
  }, "Settings"), /*#__PURE__*/React.createElement("p", {
    style: {
      margin: '4px 0 0',
      color: 'var(--color-text-secondary)',
      fontSize: 14
    }
  }, "Manage your workspace configuration.")), saved && /*#__PURE__*/React.createElement(Banner, {
    status: "success",
    title: "Settings saved",
    isDismissable: true
  }), /*#__PURE__*/React.createElement(Card, {
    padding: 5,
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 'var(--spacing-4)'
    }
  }, /*#__PURE__*/React.createElement(TextInput, {
    label: "Workspace name",
    value: name,
    onChange: setName,
    description: "Shown across the console and in invitations."
  }), /*#__PURE__*/React.createElement(Select, {
    label: "Primary region",
    value: region,
    onChange: setRegion,
    options: [{
      value: 'us-east',
      label: 'US East (N. Virginia)'
    }, {
      value: 'us-west',
      label: 'US West (Oregon)'
    }, {
      value: 'eu-west',
      label: 'EU West (Ireland)'
    }]
  }), /*#__PURE__*/React.createElement(RadioGroup, {
    label: "Default visibility",
    value: visibility,
    onChange: setVisibility,
    options: [{
      value: 'private',
      label: 'Private',
      description: 'Only you can access new projects.'
    }, {
      value: 'team',
      label: 'Team',
      description: 'Everyone in the workspace can access.'
    }]
  }), /*#__PURE__*/React.createElement(Divider, null), /*#__PURE__*/React.createElement(Switch, {
    label: "Auto-deploy on merge",
    description: "Deploy to staging when a PR merges to main.",
    value: deploys,
    onChange: setDeploys,
    labelSpacing: "spread"
  }), /*#__PURE__*/React.createElement(Switch, {
    label: "Incident alerts",
    description: "Notify on-call when error rate exceeds 1%.",
    value: alerts,
    onChange: setAlerts,
    labelSpacing: "spread"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      justifyContent: 'flex-end',
      marginTop: 4
    }
  }, /*#__PURE__*/React.createElement(Button, {
    label: "Cancel",
    variant: "ghost"
  }), /*#__PURE__*/React.createElement(Button, {
    label: "Save changes",
    variant: "primary",
    onClick: () => {
      setSaved(true);
    }
  }))));
}
window.CONSOLE.Dashboard = Dashboard;
window.CONSOLE.Settings = Settings;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/console/Screens.jsx", error: String((e && e.message) || e) }); }

// ui_kits/console/Shell.jsx
try { (() => {
// Astryx Console UI kit — an internal-tool product surface.
// Composes the design-system primitives from window.AstryxDesignSystem_9884ce
// with kit-specific layout (app shell, dashboard, settings).
const NS = window.AstryxDesignSystem_9884ce;
const {
  Button,
  IconButton,
  Badge,
  Card,
  Avatar,
  Divider,
  TextInput,
  Select,
  Switch,
  RadioGroup,
  SegmentedControl,
  Banner,
  StatusDot,
  ProgressBar,
  Tabs,
  Breadcrumbs
} = NS;
const {
  useState,
  useEffect,
  useRef
} = React;

// ---- Icon: renders a Lucide glyph (the Astryx neutral icon set) ----
function Icon({
  name,
  size = 18,
  color
}) {
  const ref = useRef(null);
  useEffect(() => {
    if (window.lucide && ref.current) {
      ref.current.innerHTML = '';
      const i = document.createElement('i');
      i.setAttribute('data-lucide', name);
      ref.current.appendChild(i);
      window.lucide.createIcons({
        attrs: {
          width: size,
          height: size,
          stroke: color || 'currentColor'
        }
      });
    }
  });
  return /*#__PURE__*/React.createElement("span", {
    ref: ref,
    style: {
      display: 'inline-flex',
      alignItems: 'center'
    },
    "aria-hidden": "true"
  });
}

// ---- Sidebar ----
const NAV = [{
  id: 'dashboard',
  label: 'Dashboard',
  icon: 'layout-dashboard'
}, {
  id: 'projects',
  label: 'Projects',
  icon: 'folder',
  badge: '8'
}, {
  id: 'members',
  label: 'Members',
  icon: 'users'
}, {
  id: 'activity',
  label: 'Activity',
  icon: 'activity'
}, {
  id: 'settings',
  label: 'Settings',
  icon: 'settings'
}];
function Sidebar({
  active,
  onNavigate
}) {
  return /*#__PURE__*/React.createElement("aside", {
    style: {
      width: 232,
      flexShrink: 0,
      background: 'var(--color-background-surface)',
      borderRight: '1px solid var(--color-border)',
      display: 'flex',
      flexDirection: 'column',
      padding: 'var(--spacing-3)',
      gap: 'var(--spacing-4)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      padding: '4px 6px'
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/brand-icon.svg",
    width: "26",
    height: "26",
    alt: ""
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 18,
      fontWeight: 700,
      letterSpacing: '-.01em'
    }
  }, "Astryx"), /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: 'auto'
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    label: "Beta",
    variant: "blue"
  }))), /*#__PURE__*/React.createElement("nav", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 2
    }
  }, NAV.map(n => {
    const on = active === n.id;
    return /*#__PURE__*/React.createElement("button", {
      key: n.id,
      onClick: () => onNavigate(n.id),
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        padding: '8px 10px',
        border: 0,
        borderRadius: 'var(--radius-element)',
        cursor: 'pointer',
        fontFamily: 'inherit',
        fontSize: 'var(--text-label-size)',
        fontWeight: 500,
        textAlign: 'left',
        width: '100%',
        background: on ? 'var(--color-neutral)' : 'transparent',
        color: on ? 'var(--color-text-primary)' : 'var(--color-text-secondary)'
      }
    }, /*#__PURE__*/React.createElement(Icon, {
      name: n.icon,
      size: 18
    }), n.label, n.badge && /*#__PURE__*/React.createElement("span", {
      style: {
        marginLeft: 'auto'
      }
    }, /*#__PURE__*/React.createElement(Badge, {
      label: n.badge,
      variant: "neutral"
    })));
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 'auto',
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      padding: '8px 6px',
      borderTop: '1px solid var(--color-border)'
    }
  }, /*#__PURE__*/React.createElement(Avatar, {
    name: "Ada Lovelace",
    src: "../../assets/avatar.png",
    size: "sm",
    status: "success"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      lineHeight: 1.2
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      fontWeight: 600
    }
  }, "Ada Lovelace"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: 'var(--color-text-secondary)'
    }
  }, "Owner"))));
}

// ---- Top bar ----
function Topbar({
  title,
  crumbs,
  dark,
  onToggleTheme
}) {
  const [q, setQ] = useState('');
  return /*#__PURE__*/React.createElement("header", {
    style: {
      height: 56,
      flexShrink: 0,
      display: 'flex',
      alignItems: 'center',
      gap: 'var(--spacing-4)',
      padding: '0 var(--spacing-5)',
      borderBottom: '1px solid var(--color-border)',
      background: 'var(--color-background-surface)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement(Breadcrumbs, {
    items: crumbs
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      marginLeft: 'auto',
      width: 260
    }
  }, /*#__PURE__*/React.createElement(TextInput, {
    label: "Search",
    isLabelHidden: true,
    placeholder: "Search\u2026",
    startIcon: /*#__PURE__*/React.createElement(Icon, {
      name: "search",
      size: 16
    }),
    hasClear: true,
    value: q,
    onChange: setQ,
    size: "sm"
  })), /*#__PURE__*/React.createElement(IconButton, {
    label: "Toggle theme",
    icon: /*#__PURE__*/React.createElement(Icon, {
      name: dark ? 'sun' : 'moon',
      size: 18
    }),
    onClick: onToggleTheme
  }), /*#__PURE__*/React.createElement(IconButton, {
    label: "Notifications",
    icon: /*#__PURE__*/React.createElement(Icon, {
      name: "bell",
      size: 18
    })
  }), /*#__PURE__*/React.createElement(Button, {
    label: "New project",
    variant: "primary",
    size: "sm",
    icon: /*#__PURE__*/React.createElement(Icon, {
      name: "plus",
      size: 16
    })
  }));
}
window.CONSOLE = {
  Icon,
  Sidebar,
  Topbar,
  NS: {
    Button,
    IconButton,
    Badge,
    Card,
    Avatar,
    Divider,
    TextInput,
    Select,
    Switch,
    RadioGroup,
    SegmentedControl,
    Banner,
    StatusDot,
    ProgressBar,
    Tabs
  }
};
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/console/Shell.jsx", error: String((e && e.message) || e) }); }

// ui_kits/site/App.jsx
try { (() => {
// Astryx marketing + docs site kit. Captures the product's brand voice and the
// component-doc page layout, composed from the design-system primitives.
const NS = window.AstryxDesignSystem_9884ce;
const {
  Button,
  Badge,
  Card,
  Tabs,
  TextInput,
  Divider
} = NS;
const {
  useState,
  useEffect,
  useRef
} = React;
function Icon({
  name,
  size = 18
}) {
  const ref = useRef(null);
  useEffect(() => {
    if (window.lucide && ref.current) {
      ref.current.innerHTML = '';
      const i = document.createElement('i');
      i.setAttribute('data-lucide', name);
      ref.current.appendChild(i);
      window.lucide.createIcons({
        attrs: {
          width: size,
          height: size
        }
      });
    }
  });
  return /*#__PURE__*/React.createElement("span", {
    ref: ref,
    style: {
      display: 'inline-flex',
      alignItems: 'center'
    },
    "aria-hidden": "true"
  });
}
function Nav({
  page,
  setPage
}) {
  return /*#__PURE__*/React.createElement("header", {
    style: {
      position: 'sticky',
      top: 0,
      zIndex: 10,
      height: 60,
      display: 'flex',
      alignItems: 'center',
      gap: 'var(--spacing-5)',
      padding: '0 var(--spacing-8)',
      background: 'color-mix(in srgb, var(--color-background-body) 85%, transparent)',
      backdropFilter: 'blur(8px)',
      borderBottom: '1px solid var(--color-border)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      cursor: 'pointer'
    },
    onClick: () => setPage('home')
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/brand-icon.svg",
    width: "26",
    height: "26",
    alt: ""
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 18,
      fontWeight: 700,
      letterSpacing: '-.01em'
    }
  }, "Astryx")), /*#__PURE__*/React.createElement("nav", {
    style: {
      display: 'flex',
      gap: 4,
      marginLeft: 'var(--spacing-4)'
    }
  }, [['home', 'Overview'], ['docs', 'Components'], ['home', 'Themes'], ['docs', 'Guides']].map(([p, l], i) => /*#__PURE__*/React.createElement("button", {
    key: i,
    onClick: () => setPage(p),
    style: {
      border: 0,
      background: 'transparent',
      cursor: 'pointer',
      fontFamily: 'inherit',
      fontSize: 14,
      fontWeight: 500,
      padding: '6px 10px',
      borderRadius: 'var(--radius-element)',
      color: 'var(--color-text-secondary)'
    }
  }, l))), /*#__PURE__*/React.createElement("div", {
    style: {
      marginLeft: 'auto',
      display: 'flex',
      alignItems: 'center',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Button, {
    label: "Star",
    variant: "ghost",
    size: "sm",
    icon: /*#__PURE__*/React.createElement(Icon, {
      name: "star",
      size: 16
    }),
    endContent: /*#__PURE__*/React.createElement(Badge, {
      label: "14.2k",
      variant: "neutral"
    })
  }), /*#__PURE__*/React.createElement(Button, {
    label: "GitHub",
    variant: "secondary",
    size: "sm",
    icon: /*#__PURE__*/React.createElement(Icon, {
      name: "github",
      size: 16
    })
  }), /*#__PURE__*/React.createElement(Button, {
    label: "Get started",
    variant: "primary",
    size: "sm"
  })));
}
const FEATURES = [{
  icon: 'blocks',
  title: 'Open internals',
  body: 'Components compose at any level. Swizzle ejects a component’s full source into your project to own.'
}, {
  icon: 'paintbrush',
  title: 'No styling lock-in',
  body: 'Authored in StyleX, invisible to you. Override with Tailwind, CSS modules, or plain CSS.'
}, {
  icon: 'palette',
  title: 'Customize without wrapping',
  body: 'A theme is a set of CSS custom-property overrides. Make Astryx unmistakably yours.'
}, {
  icon: 'bot',
  title: 'Built for people and agents',
  body: 'The API, docs, and CLI are designed together so a person and an AI build the same way.'
}, {
  icon: 'moon',
  title: 'Dark mode included',
  body: 'Every token carries a light and dark value via light-dark(). Flip a subtree with one attribute.'
}, {
  icon: 'accessibility',
  title: 'Accessible by default',
  body: '150+ components with keyboard, focus, and screen-reader support baked in.'
}];
function Home() {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("section", {
    style: {
      textAlign: 'center',
      padding: '96px var(--spacing-8) 72px',
      maxWidth: 820,
      margin: '0 auto'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-block',
      marginBottom: 24
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    label: "Now in Beta \xB7 v0.1",
    variant: "blue"
  })), /*#__PURE__*/React.createElement("h1", {
    style: {
      margin: 0,
      fontSize: 56,
      lineHeight: 1.05,
      fontWeight: 700,
      letterSpacing: '-.03em'
    }
  }, "The design system", /*#__PURE__*/React.createElement("br", null), "built for people ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--color-brand)'
    }
  }, "and agents")), /*#__PURE__*/React.createElement("p", {
    style: {
      margin: '20px auto 0',
      maxWidth: 600,
      fontSize: 18,
      lineHeight: 1.5,
      color: 'var(--color-text-secondary)'
    }
  }, "150+ accessible React components, brand-level theming, dark mode, and a CLI \u2014 as one cohesive system. Import pre-built CSS, use typed components. No build plugin."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12,
      justifyContent: 'center',
      marginTop: 32
    }
  }, /*#__PURE__*/React.createElement(Button, {
    label: "Get started",
    variant: "primary",
    size: "lg",
    icon: /*#__PURE__*/React.createElement(Icon, {
      name: "arrow-right",
      size: 18
    })
  }), /*#__PURE__*/React.createElement(Button, {
    label: "Browse components",
    variant: "secondary",
    size: "lg"
  })), /*#__PURE__*/React.createElement("code", {
    style: {
      display: 'inline-block',
      marginTop: 28,
      fontFamily: 'var(--font-family-code)',
      fontSize: 14,
      background: 'var(--color-background-surface)',
      border: '1px solid var(--color-border)',
      color: 'var(--color-text-secondary)',
      padding: '8px 16px',
      borderRadius: 'var(--radius-full)'
    }
  }, "npm install @astryxdesign/core @astryxdesign/theme-neutral")), /*#__PURE__*/React.createElement("section", {
    style: {
      padding: '0 var(--spacing-8) 96px',
      maxWidth: 1120,
      margin: '0 auto'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(3, 1fr)',
      gap: 'var(--spacing-4)'
    }
  }, FEATURES.map(f => /*#__PURE__*/React.createElement(Card, {
    key: f.title,
    padding: 5,
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      width: 40,
      height: 40,
      borderRadius: 'var(--radius-element)',
      alignItems: 'center',
      justifyContent: 'center',
      background: 'var(--color-accent-muted)',
      color: 'var(--color-text-primary)'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: f.icon,
    size: 20
  })), /*#__PURE__*/React.createElement("h3", {
    style: {
      margin: '4px 0 0',
      fontSize: 17,
      fontWeight: 700
    }
  }, f.title), /*#__PURE__*/React.createElement("p", {
    style: {
      margin: 0,
      fontSize: 14,
      lineHeight: 1.5,
      color: 'var(--color-text-secondary)'
    }
  }, f.body))))));
}
const PROPS = [['label', 'string', '—', 'Accessible label. Visible text by default.'], ['variant', "'primary' | 'secondary' | 'ghost' | 'destructive'", "'secondary'", 'Visual emphasis.'], ['size', "'sm' | 'md' | 'lg'", "'md'", 'Control height (28 / 32 / 36px).'], ['icon', 'ReactNode', '—', 'Leading icon element.'], ['isLoading', 'boolean', 'false', 'Show a spinner and block interaction.'], ['isDisabled', 'boolean', 'false', 'Disable the button.']];
function Docs() {
  const [tab, setTab] = useState('overview');
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      maxWidth: 1120,
      margin: '0 auto',
      gap: 'var(--spacing-8)',
      padding: 'var(--spacing-8)'
    }
  }, /*#__PURE__*/React.createElement("aside", {
    style: {
      width: 200,
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      textTransform: 'uppercase',
      letterSpacing: '.05em',
      color: 'var(--color-text-secondary)',
      marginBottom: 10,
      fontWeight: 600
    }
  }, "Action"), ['Button', 'IconButton', 'ButtonGroup', 'ToggleButton'].map((c, i) => /*#__PURE__*/React.createElement("div", {
    key: c,
    style: {
      padding: '6px 10px',
      borderRadius: 'var(--radius-element)',
      fontSize: 14,
      cursor: 'pointer',
      fontWeight: i === 0 ? 600 : 400,
      background: i === 0 ? 'var(--color-neutral)' : 'transparent',
      color: i === 0 ? 'var(--color-text-primary)' : 'var(--color-text-secondary)'
    }
  }, c))), /*#__PURE__*/React.createElement("article", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("h1", {
    style: {
      margin: 0,
      fontSize: 32,
      fontWeight: 700,
      letterSpacing: '-.02em'
    }
  }, "Button"), /*#__PURE__*/React.createElement(Badge, {
    label: "Action",
    variant: "purple"
  }), /*#__PURE__*/React.createElement(Badge, {
    label: "Stable",
    variant: "success"
  })), /*#__PURE__*/React.createElement("p", {
    style: {
      margin: '12px 0 0',
      fontSize: 17,
      lineHeight: 1.5,
      color: 'var(--color-text-secondary)',
      maxWidth: 620
    }
  }, "Button triggers an action when clicked. Use it for form submissions, confirmations, or any interaction that needs a clear call to action."), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: '24px 0'
    }
  }, /*#__PURE__*/React.createElement(Tabs, {
    value: tab,
    onChange: setTab,
    options: [{
      value: 'overview',
      label: 'Preview'
    }, {
      value: 'code',
      label: 'Code'
    }]
  })), tab === 'overview' ? /*#__PURE__*/React.createElement(Card, {
    padding: 6,
    style: {
      display: 'flex',
      gap: 12,
      alignItems: 'center',
      flexWrap: 'wrap'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    label: "Primary",
    variant: "primary"
  }), /*#__PURE__*/React.createElement(Button, {
    label: "Secondary"
  }), /*#__PURE__*/React.createElement(Button, {
    label: "Ghost",
    variant: "ghost"
  }), /*#__PURE__*/React.createElement(Button, {
    label: "Destructive",
    variant: "destructive"
  })) : /*#__PURE__*/React.createElement("pre", {
    style: {
      margin: 0,
      background: 'var(--color-background-inverted)',
      color: 'var(--color-background-body)',
      padding: 'var(--spacing-4)',
      borderRadius: 'var(--radius-container)',
      overflow: 'auto',
      fontFamily: 'var(--font-family-code)',
      fontSize: 13,
      lineHeight: 1.6
    }
  }, `import {Button} from '@astryxdesign/core/Button';

<Button label="Save changes" variant="primary" />
<Button label="Cancel" variant="ghost" />`), /*#__PURE__*/React.createElement("h2", {
    style: {
      fontSize: 20,
      fontWeight: 600,
      margin: '40px 0 12px'
    }
  }, "Props"), /*#__PURE__*/React.createElement("div", {
    style: {
      border: '1px solid var(--color-border)',
      borderRadius: 'var(--radius-container)',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement("table", {
    style: {
      width: '100%',
      borderCollapse: 'collapse',
      fontSize: 13
    }
  }, /*#__PURE__*/React.createElement("thead", null, /*#__PURE__*/React.createElement("tr", {
    style: {
      background: 'var(--color-background-muted)',
      textAlign: 'left',
      color: 'var(--color-text-secondary)'
    }
  }, /*#__PURE__*/React.createElement("th", {
    style: {
      padding: '10px 14px',
      fontWeight: 600
    }
  }, "Prop"), /*#__PURE__*/React.createElement("th", {
    style: {
      padding: '10px 14px',
      fontWeight: 600
    }
  }, "Type"), /*#__PURE__*/React.createElement("th", {
    style: {
      padding: '10px 14px',
      fontWeight: 600
    }
  }, "Default"), /*#__PURE__*/React.createElement("th", {
    style: {
      padding: '10px 14px',
      fontWeight: 600
    }
  }, "Description"))), /*#__PURE__*/React.createElement("tbody", null, PROPS.map(p => /*#__PURE__*/React.createElement("tr", {
    key: p[0],
    style: {
      borderTop: '1px solid var(--color-border)'
    }
  }, /*#__PURE__*/React.createElement("td", {
    style: {
      padding: '10px 14px',
      fontFamily: 'var(--font-family-code)',
      fontWeight: 600
    }
  }, p[0]), /*#__PURE__*/React.createElement("td", {
    style: {
      padding: '10px 14px',
      fontFamily: 'var(--font-family-code)',
      color: 'var(--color-text-purple)'
    }
  }, p[1]), /*#__PURE__*/React.createElement("td", {
    style: {
      padding: '10px 14px',
      fontFamily: 'var(--font-family-code)',
      color: 'var(--color-text-secondary)'
    }
  }, p[2]), /*#__PURE__*/React.createElement("td", {
    style: {
      padding: '10px 14px',
      color: 'var(--color-text-secondary)'
    }
  }, p[3]))))))));
}
function App() {
  const [page, setPage] = useState('home');
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Nav, {
    page: page,
    setPage: setPage
  }), page === 'docs' ? /*#__PURE__*/React.createElement(Docs, null) : /*#__PURE__*/React.createElement(Home, null));
}
ReactDOM.createRoot(document.getElementById('root')).render(/*#__PURE__*/React.createElement(App, null));
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/site/App.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Avatar = __ds_scope.Avatar;

__ds_ns.Divider = __ds_scope.Divider;

__ds_ns.Banner = __ds_scope.Banner;

__ds_ns.ProgressBar = __ds_scope.ProgressBar;

__ds_ns.Skeleton = __ds_scope.Skeleton;

__ds_ns.Spinner = __ds_scope.Spinner;

__ds_ns.StatusDot = __ds_scope.StatusDot;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.RadioGroup = __ds_scope.RadioGroup;

__ds_ns.SegmentedControl = __ds_scope.SegmentedControl;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.TextArea = __ds_scope.TextArea;

__ds_ns.TextInput = __ds_scope.TextInput;

__ds_ns.Breadcrumbs = __ds_scope.Breadcrumbs;

__ds_ns.Tabs = __ds_scope.Tabs;

})();
