// Renders an <xdm:token>/<xdm:group> tree - the output of
// xdm:view-tokens()/xdm:persisted-to-token-view() (see
// src/xdm-view-tokens.xsl) - into a live, foldable DOM.
//
// The elements are inserted as-is, still in their original xdm:
// namespace - never converted to <span>/<div>. xdm-view-tokens.css's
// selectors (`token[type=...]`, `group.xdm-collapsed`, ...) match them
// by local name regardless of namespace, so no HTML-element translation
// step is needed at all; this module's only job is parsing the XML text,
// putting the result in the page, and wiring up fold toggles.

export function renderXdmTokens(xmlText, container) {
  const parsed = new DOMParser().parseFromString(xmlText, 'application/xml');
  const parseError = parsed.querySelector('parsererror');
  if (parseError) {
    container.textContent = 'Failed to parse token XML: ' + parseError.textContent;
    return;
  }

  const root = document.adoptNode(parsed.documentElement);
  addFoldToggles(root);

  container.replaceChildren(root);
}

// Adds a fold toggle + collapse/expand behavior to every foldable="true"
// group (map/array/sequence - see xdm-view-tokens.xsl), including root
// itself when it's one - querySelectorAll only ever searches an
// element's descendants, never the element it's called on, so root has
// to be checked separately or its own top-level entries would silently
// never get wrapped/foldable at all.
function addFoldToggles(root) {
  const groups = root.matches('[foldable="true"]') ? [root] : [];
  groups.push(...root.querySelectorAll('[foldable="true"]'));
  groups.forEach(wireFoldToggle);
}

// Each foldable group's own children are exactly [open-punct-token,
// ...body..., close-punct-token] - the body is moved into one wrapper
// element so collapsing is a single display:none toggle on that
// wrapper, not a positional CSS selector that would have to keep
// working as the toggle and ellipsis elements below are inserted
// alongside the real content.
function wireFoldToggle(group) {
  const children = Array.from(group.children);
  if (children.length < 2) {
    return; // no open/close pair to fold around - shouldn't happen, but nothing to do
  }

  const openToken = children[0];
  const bodyChildren = children.slice(1, -1);

  const bodyWrap = document.createElement('span');
  bodyWrap.className = 'xdm-fold-body';
  bodyChildren.forEach((node) => bodyWrap.appendChild(node)); // moves, doesn't copy

  const ellipsis = document.createElement('span');
  ellipsis.className = 'xdm-ellipsis';
  ellipsis.textContent = '…';

  const toggle = document.createElement('span');
  toggle.className = 'xdm-fold-toggle';
  toggle.setAttribute('role', 'button');
  toggle.setAttribute('tabindex', '0');
  toggle.setAttribute('aria-expanded', 'true');

  group.insertBefore(toggle, openToken);
  openToken.insertAdjacentElement('afterend', bodyWrap);
  bodyWrap.insertAdjacentElement('afterend', ellipsis);
  // Final order: toggle, openToken, bodyWrap, ellipsis, closeToken.

  // Collapse state lives on `group` (an xdm: namespaced element) as a
  // real attribute, not a class - see xdm-view-tokens.css's own comment
  // on why a class selector silently never matches here.
  const isCollapsed = () => group.getAttribute('collapsed') === 'true';
  const setCollapsed = (collapsed) => {
    group.setAttribute('collapsed', String(collapsed));
    toggle.setAttribute('aria-expanded', String(!collapsed));
  };
  setCollapsed(false);

  toggle.addEventListener('click', () => setCollapsed(!isCollapsed()));
  toggle.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      setCollapsed(!isCollapsed());
    }
  });
}
