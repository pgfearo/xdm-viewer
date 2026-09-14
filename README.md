# xdm-viewer

Renders an XPath 3.1 Data Model value — nodes, maps, arrays, and atomic
values, in any combination or nesting — as legible output for a human:
JSON-like text (`{'a': 1, 'b': (2, 3)}`), optionally ANSI-coloured, or a
browsable HTML page with collapsible maps/arrays.

## Background

This is the spiritual successor to [xpath-result-serializer](https://github.com/pgfearo/xpath-result-serializer),
an older debug-only pretty-printer for XPath results. Rather than
reimplementing its value-classification logic a second time, this project
builds directly on [xdm-persistence](https://github.com/pgfearo/xdm-persistence):
it walks the already-classified `xdm:` tree that `xdm-persistence`'s
`xdm:serialize()` produces (exact atomic types, map/array structure, node
kinds all already resolved) and just renders it, in two different ways.

Implemented with [Claude](https://claude.com/claude-code).

## Requires xdm-persistence as a sibling checkout

This repo depends on `xdm-persistence` via a relative `xsl:import` and does
not vendor or submodule it. Clone both under the same parent directory:

```
github/
├── xdm-persistence/
└── xdm-viewer/
```

## Files

| File | Purpose |
|---|---|
| `src/xdm-view-text.xsl` | `xdm:view-text($value)`, `xdm:view-text($value, $useColor)` |
| `src/xdm-view-html.xsl` | `xdm:view-html($value)` |
| `src/xdm-view-common.xsl` | Shared helper used by both renderers |
| `src/xdm-view.xsl` | Single entry point — imports all three of the above |

Import `xdm-view.xsl` rather than the individual renderer files, for the same
reason `xdm-persistence.xsl` is the recommended entry point in the sibling
project.

## Usage

```xml
<xsl:import href="src/xdm-view.xsl"/>

<xsl:variable name="value" as="item()*" select="map { 'a': 1, 'b': (2, 3) }"/>

<xsl:sequence select="xdm:view-text($value)"/>
<!-- {'a': 1, 'b': (2, 3)} -->

<xsl:sequence select="xdm:view-text($value, true())"/>
<!-- same, with ANSI color codes -->

<xsl:sequence select="xdm:view-html($value)"/>
<!-- a full HTML document-node(), ready for xsl:result-document -->
```

## How it works

Both renderers walk the same tree `xdm:serialize($value)` produces (see
`xdm-persistence`'s README for its shape) rather than re-classifying the
original value:

- `xdm:map`/`xdm:entry` render as `{ 'key': value, ... }` (or nested
  `<details>` sections in HTML); an entry's value is rendered using XPath
  sequence syntax when it holds more than one item (`(1, 2, 3)`), or none
  (`()`).
- `xdm:array`/`xdm:member` render the same way as `[ ... ]`.
- `xdm:atomic` renders using its recorded type: quoted for strings,
  `true()`/`false()` for booleans, plain for numerics, `Q{uri}local` for a
  namespaced `xs:QName`.
- A real element or document node has no compact literal form, so it's
  shown as its own (re-)serialized markup — truncated in the text view,
  in a `<pre>` in the HTML view. Namespaces the node inherited only from
  the `xdm:` wrapper tree (not from the original document) are stripped
  first, so they don't clutter the display.

## Example

```sh
java -jar saxon.jar -xsl:examples/demo.xsl -it
```

Prints a plain-text view via `xsl:message` and writes two HTML files:
`examples/out/view-demo.html` (the collapsible `xdm:view-html` output) and
`examples/out/view--text-demo.html` (the same text view as the message,
in a `<pre><code>`).

## Color output

`xdm:view-text($value, true())` produces real ANSI escape codes, but
XSLT processors like Saxon cannot always process them when the result goes through `xsl:message`: Saxon's
default `MessageListener` (and most XSLT tooling built on it) XML-entity-encodes
message content, turning `ESC[0;31m` into the literal text `&#x1b;[0;31m`.
This isn't specific to any one tool - it's the default behavior of Saxon's
own message delivery.

Two ways around it:

- **Primary output** (`xsl:output method="text"`, writing to stdout or a
  file rather than `xsl:message`) is not affected - it writes the escape
  codes through untouched with plain Saxon, no extra tooling needed.
- **Driving Saxon via its Java API**, install your own `MessageListener`/
  `MessageListener2` on the transformer that writes the message's string
  value out directly (e.g. `System.err.println(content.getStringValue())`)
  instead of using Saxon's default one, which is what avoids the
  entity-encoding.

## Tests

```sh
SAXON_JAR=/path/to/saxon-he-12.jar tests/run.sh
```

Since rendered output has no natural "correct answer" to `deep-equal`
against (unlike `xdm-persistence`'s round-trip tests), these check that a
representative value's rendering contains the expected fragments
(`{`, `'name'`, `true()`, ...) rather than an exact string match — map
key iteration order isn't guaranteed, so an exact expected string would be
fragile.

## Requirements

Same as `xdm-persistence`: an XSLT 3.0 / XPath 3.1 processor with maps,
arrays and higher-order functions — e.g. Saxon Home Edition or above, 9.8+.
