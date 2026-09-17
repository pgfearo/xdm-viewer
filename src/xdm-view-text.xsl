<?xml version="1.1" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="xsl"
                version="3.0">

  <!--
       (c) DeltaXignia ltd. 2026
       Renders an XPath 3.1 Data Model value as indented, JSON-like text
       ({...}, [...], 'string', true()/false(), ...), optionally with
       ANSI color. Works by walking the xdm: tree that
       xdm-persistence's xdm:serialize() produces - the value's shape and
       every atomic value's exact type are already classified there, so
       this only has to render, not re-classify.
  -->

  <xsl:variable name="xdm:RESET" as="xs:string" select="'&#x1B;[0m'"/>
  <xsl:variable name="xdm:RED" as="xs:string" select="'&#x1B;[0;31m'"/>
  <xsl:variable name="xdm:GREEN" as="xs:string" select="'&#x1B;[0;32m'"/>
  <!-- Normal intensity, unlike any of $xdm:BRACKET-COLORS below (all
       bright variants of the same 5 hues) - the one base hue not
       already claimed as a role color elsewhere, used for xdm:debug's
       labels specifically so they read as distinct from real map keys
       (xdm:RED) without clashing with anything else in the palette. -->
  <xsl:variable name="xdm:YELLOW" as="xs:string" select="'&#x1B;[0;33m'"/>
  <xsl:variable name="xdm:BLUE" as="xs:string" select="'&#x1B;[0;34m'"/>
  <xsl:variable name="xdm:MAGENTA" as="xs:string" select="'&#x1B;[0;35m'"/>
  <xsl:variable name="xdm:CYAN" as="xs:string" select="'&#x1B;[0;36m'"/>
  <xsl:variable name="xdm:BRACKET-COLORS" as="xs:string*" select="(
    '&#x1B;[0;91m', '&#x1B;[0;92m', '&#x1B;[0;93m', '&#x1B;[0;95m', '&#x1B;[0;96m'
  )"/>

  <xsl:variable name="xdm:NUMERIC-TYPES" as="xs:string*" select="(
    'xs:integer', 'xs:decimal', 'xs:double', 'xs:float',
    'xs:byte', 'xs:short', 'xs:int', 'xs:long',
    'xs:nonNegativeInteger', 'xs:nonPositiveInteger', 'xs:positiveInteger', 'xs:negativeInteger',
    'xs:unsignedByte', 'xs:unsignedShort', 'xs:unsignedInt', 'xs:unsignedLong'
  )"/>

  <xsl:function name="xdm:colorize" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="color" as="xs:string"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:sequence select="if ($useColor) then $color || $text || $xdm:RESET else $text"/>
  </xsl:function>

  <xsl:function name="xdm:bracket-color" as="xs:string">
    <xsl:param name="level" as="xs:integer"/>
    <xsl:variable name="n" as="xs:integer" select="count($xdm:BRACKET-COLORS)"/>
    <!-- level mod n, not (level - 1) mod n: the latter goes negative (and
         so out of range for indexing $xdm:BRACKET-COLORS) for level 0,
         which the root value's brackets are now rendered at. -->
    <xsl:variable name="idx" as="xs:integer" select="($level mod $n) + 1"/>
    <xsl:sequence select="$xdm:BRACKET-COLORS[$idx]"/>
  </xsl:function>

  <xsl:function name="xdm:indent" as="xs:string">
    <xsl:param name="level" as="xs:integer"/>
    <xsl:sequence select="string-join(for $n in 1 to $level return '  ', '')"/>
  </xsl:function>

  <!-- A map entry's or array member's value stays on the same line as its
       key/preceding siblings only if it's a single atomic value (or empty) -
       anything else (a nested map/array/node, or a multi-item sequence)
       forces its whole container onto multiple lines, one child per line. -->
  <xsl:function name="xdm:is-simple-item-seq" as="xs:boolean">
    <xsl:param name="items" as="element(xdm:item)*"/>
    <xsl:sequence select="
      count($items) le 1 and (empty($items) or $items[1]/*[1]/self::xdm:atomic)"/>
  </xsl:function>

  <xsl:function name="xdm:view-text" as="xs:string">
    <xsl:param name="value" as="item()*"/>
    <xsl:sequence select="xdm:view-text($value, false())"/>
  </xsl:function>

  <xsl:function name="xdm:view-text" as="xs:string">
    <xsl:param name="value" as="item()*"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:sequence select="xdm:persisted-to-text-view(xdm:serialize($value), $useColor)"/>
  </xsl:function>

  <!-- For a value already persisted via xdm-persistence's xdm:serialize()
       (e.g. read back with doc()) - renders the tree directly rather than
       parsing it into a value and immediately re-serializing it, and
       doesn't need xdm-persistence's xdm:parse() at all. -->
  <xsl:function name="xdm:persisted-to-text-view" as="xs:string">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:sequence select="xdm:persisted-to-text-view($doc, false())"/>
  </xsl:function>

  <xsl:function name="xdm:persisted-to-text-view" as="xs:string">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <!-- Level 0: nothing precedes the very first character, so the root
         value's own opening bracket has no indent - matching xdm:indent(0),
         which is what its closing bracket needs to align with.
         Everything below xdm:render-item-seq-text is shared between the
         two persisted formats unchanged - the reference-preserving
         format's xdm:context wraps the same xdm:sequence/xdm:item shape,
         just one level deeper, and introduces exactly one new payload
         kind (xdm:node-ref) that the default format never produces, so
         only the root's own location needs to differ per format. -->
    <xsl:variable name="items" as="element(xdm:item)*" select="
      if (xdm:is-refs-format($doc)) then $doc/xdm:context/xdm:sequence/xdm:item else $doc/xdm:sequence/xdm:item"/>
    <xsl:sequence select="xdm:render-item-seq-text($items, $useColor, 0)"/>
  </xsl:function>

  <!-- Value-level entry point for the reference-preserving mode, mirroring
       xdm:view-text/xdm:serialize-with-refs the same way xdm:view-text
       mirrors xdm:serialize. -->
  <xsl:function name="xdm:view-text-with-refs" as="xs:string">
    <xsl:param name="value" as="item()*"/>
    <xsl:sequence select="xdm:view-text-with-refs($value, false())"/>
  </xsl:function>

  <xsl:function name="xdm:view-text-with-refs" as="xs:string">
    <xsl:param name="value" as="item()*"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:sequence select="xdm:persisted-to-text-view(xdm:serialize-with-refs($value), $useColor)"/>
  </xsl:function>

  <!-- A dedicated debug-dump helper for the common pattern of wrapping
       several named variables in a map purely to label them for one
       xsl:message call - $labels' keys are read as plain, unquoted
       labels, not rendered as a real map value in its own right (no
       {}/quoted-key styling), so the wrapper itself doesn't show up as
       noise in the output. Every labeled value is serialized together
       in one xdm:serialize-with-refs call, so identity/pool-document
       numbering (#1, #2, ...) stays consistent across them exactly as
       it would for a single ordinary value - e.g. two labels pointing
       at the same document still show matching #N text.

       Each label's ': ' follows its own text immediately - the padding
       needed to line every value up in a common column goes after the
       colon instead, not between the label and the colon - colored
       xdm:YELLOW (distinct from xdm:RED, used for real map keys, so a
       label never reads as though it were one). Each value then starts
       on the same line as its label, rendered exactly as
       xdm:view-text-with-refs would render it standalone, except every
       line after its first is then re-indented (a plain string
       post-process - tokenize on newline, prepend spaces, rejoin -
       rather than threading an extra indent through the whole render
       call chain) so the whole value lines up under where it started,
       not just its first line.

       $title is a required leading parameter, not folded into $labels
       as a reserved key - a "magic" key name would risk colliding with
       a real label and silently misbehaving if mistyped, and would
       break $labels' otherwise-uniform "every entry is a plain label"
       contract. It's also why $title can't instead be an optional
       trailing parameter the way $useColor is: xdm:debug($labels,
       $useColor) and xdm:debug($title, $labels) would both be 2-arg
       overloads of the same name, and XSLT/XPath resolves functions by
       (name, arity) only, never by parameter type - the two can't
       coexist. Given a title is meant to mark practically every
       scattered xsl:message call, not be an occasional extra, it's
       made a required first parameter outright rather than adding a
       differently-named variant. -->
  <xsl:function name="xdm:debug" as="xs:string">
    <xsl:param name="title" as="xs:string"/>
    <xsl:param name="labels" as="map(xs:string, item()*)"/>
    <xsl:sequence select="xdm:debug($title, $labels, false())"/>
  </xsl:function>

  <xsl:function name="xdm:debug" as="xs:string">
    <xsl:param name="title" as="xs:string"/>
    <xsl:param name="labels" as="map(xs:string, item()*)"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:variable name="banner" as="xs:string" select="xdm:debug-banner($title)"/>
    <xsl:variable name="serialized" as="document-node()" select="xdm:serialize-with-refs($labels)"/>
    <xsl:variable name="entries" as="element(xdm:entry)*" select="$serialized/xdm:context/xdm:sequence/xdm:item/xdm:map/xdm:entry"/>
    <xsl:variable name="labelWidth" as="xs:integer" select="max((0, for $e in $entries return string-length(string($e/@key))))"/>
    <xsl:variable name="prefixWidth" as="xs:integer" select="$labelWidth + 2"/> <!-- + ': ' -->
    <xsl:variable name="continuationPad" as="xs:string" select="xdm:pad-right('', $prefixWidth)"/>
    <xsl:variable name="lines" as="xs:string*" select="
      for $e in $entries return
        xdm:debug-label-prefix(string($e/@key), $labelWidth, $useColor) ||
        xdm:indent-continuation-lines(xdm:render-item-seq-text($e/xdm:item, $useColor, 0), $continuationPad)"/>
    <xsl:sequence select="$banner || '&#10;' || string-join($lines, '&#10;')"/>
  </xsl:function>

  <xsl:variable name="xdm:DEBUG-BANNER-CHAR" as="xs:string" select="'&#x2500;'"/>
  <xsl:variable name="xdm:DEBUG-BANNER-WIDTH" as="xs:integer" select="70"/>

  <!-- A horizontal rule with $title centered in it, marking the start
       of one xsl:debug call clearly when scrolling past many scattered
       ones. A title too long to leave any room for the rule (rare) is
       shown in full with no rule at all, rather than truncated - a
       debug title should never be the thing that gets cut off. -->
  <xsl:function name="xdm:debug-banner" as="xs:string">
    <xsl:param name="title" as="xs:string"/>
    <xsl:variable name="titleText" as="xs:string" select="' ' || $title || ' '"/>
    <xsl:variable name="fillTotal" as="xs:integer" select="max((0, $xdm:DEBUG-BANNER-WIDTH - string-length($titleText)))"/>
    <xsl:variable name="fillLeft" as="xs:integer" select="$fillTotal idiv 2"/>
    <xsl:variable name="fillRight" as="xs:integer" select="$fillTotal - $fillLeft"/>
    <xsl:sequence select="
      xdm:repeat-char($xdm:DEBUG-BANNER-CHAR, $fillLeft) || $titleText || xdm:repeat-char($xdm:DEBUG-BANNER-CHAR, $fillRight)"/>
  </xsl:function>

  <xsl:function name="xdm:repeat-char" as="xs:string">
    <xsl:param name="ch" as="xs:string"/>
    <xsl:param name="n" as="xs:integer"/>
    <xsl:sequence select="string-join(for $i in 1 to $n return $ch, '')"/>
  </xsl:function>

  <!-- $rawLabel's own ': ' immediately follows its text, then enough
       trailing spaces to reach $labelWidth + 2 overall - the colorize
       call wraps only the label text itself, not the padding, so the
       padding's own width is computed from $rawLabel's plain length
       (colorizing first would count the embedded ANSI codes as part of
       the string length and throw the alignment off). -->
  <xsl:function name="xdm:debug-label-prefix" as="xs:string">
    <xsl:param name="rawLabel" as="xs:string"/>
    <xsl:param name="labelWidth" as="xs:integer"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:variable name="pad" as="xs:string" select="xdm:pad-right('', $labelWidth - string-length($rawLabel))"/>
    <xsl:sequence select="xdm:colorize($rawLabel, $xdm:YELLOW, $useColor) || ': ' || $pad"/>
  </xsl:function>

  <xsl:function name="xdm:pad-right" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="width" as="xs:integer"/>
    <xsl:sequence select="$text || string-join(for $i in 1 to ($width - string-length($text)) return ' ', '')"/>
  </xsl:function>

  <!-- Prepends $padding to every line of $text after the first (a
       multi-line value's own first line already follows its label
       directly, so only its later lines need the extra indent). -->
  <xsl:function name="xdm:indent-continuation-lines" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:param name="padding" as="xs:string"/>
    <xsl:variable name="lines" as="xs:string*" select="tokenize($text, '&#10;')"/>
    <xsl:sequence select="
      string-join(for $i in 1 to count($lines) return
        if ($i = 1) then $lines[$i] else $padding || $lines[$i], '&#10;')"/>
  </xsl:function>

  <!-- Renders a sequence of xdm:item elements the way XPath itself would
       write that sequence: 0 items -> '()', 1 item -> just that item (no
       parens), 2+ items -> a parenthesized, comma-separated list. -->
  <xsl:function name="xdm:render-item-seq-text" as="xs:string">
    <xsl:param name="items" as="element(xdm:item)*"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:param name="level" as="xs:integer"/>
    <xsl:variable name="bc" as="xs:string" select="xdm:bracket-color($level)"/>
    <xsl:choose>
      <xsl:when test="count($items) = 0">
        <xsl:sequence select="xdm:colorize('()', $bc, $useColor)"/>
      </xsl:when>
      <xsl:when test="count($items) = 1">
        <xsl:sequence select="xdm:render-payload-text($items[1]/*[1], $useColor, $level)"/>
      </xsl:when>
      <xsl:when test="some $i in $items satisfies not($i/*[1]/self::xdm:atomic)">
        <xsl:variable name="childIndent" as="xs:string" select="xdm:indent($level + 1)"/>
        <xsl:variable name="closeIndent" as="xs:string" select="xdm:indent($level)"/>
        <xsl:variable name="rendered" as="xs:string*" select="
          for $i in $items return xdm:render-payload-text($i/*[1], $useColor, $level + 1)"/>
        <xsl:sequence select="
          xdm:colorize('(', $bc, $useColor) || '&#10;' || $childIndent ||
          string-join($rendered, ',&#10;' || $childIndent) ||
          '&#10;' || $closeIndent || xdm:colorize(')', $bc, $useColor)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="rendered" as="xs:string*" select="
          for $i in $items return xdm:render-payload-text($i/*[1], $useColor, $level)"/>
        <xsl:sequence select="
          xdm:colorize('(', $bc, $useColor) || string-join($rendered, ', ') || xdm:colorize(')', $bc, $useColor)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="xdm:render-payload-text" as="xs:string">
    <xsl:param name="payload" as="element()"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:param name="level" as="xs:integer"/>
    <xsl:choose>
      <xsl:when test="$payload/self::xdm:atomic">
        <xsl:sequence select="xdm:render-atomic-text($payload, $useColor)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:map">
        <xsl:sequence select="xdm:render-map-text($payload, $useColor, $level)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:array">
        <xsl:sequence select="xdm:render-array-text($payload, $useColor, $level)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:node-ref">
        <xsl:sequence select="xdm:render-node-ref-text($payload, $useColor, $level)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:text">
        <xsl:sequence select="xdm:colorize('&quot;' || string($payload) || '&quot;', $xdm:CYAN, $useColor)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:comment">
        <xsl:sequence select="xdm:colorize('&lt;!--' || string($payload) || '--&gt;', $xdm:MAGENTA, $useColor)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:pi">
        <xsl:sequence select="xdm:colorize('&lt;?' || string($payload/@name) || ' ' || string($payload) || '?&gt;', $xdm:MAGENTA, $useColor)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:attribute">
        <xsl:sequence select="xdm:colorize('@' || string($payload/@name) || '=&quot;' || string($payload) || '&quot;', $xdm:GREEN, $useColor)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:namespace">
        <xsl:sequence select="
          xdm:colorize('xmlns' || (if (string-length($payload/@prefix) gt 0) then ':' || string($payload/@prefix) else '') ||
                        '=&quot;' || string($payload/@uri) || '&quot;', $xdm:GREEN, $useColor)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:document">
        <xsl:sequence select="xdm:render-node-text($payload/node(), $useColor, $level)"/>
      </xsl:when>
      <xsl:otherwise> <!-- a plain copied element node -->
        <xsl:sequence select="xdm:render-node-text($payload, $useColor, $level)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="xdm:render-atomic-text" as="xs:string">
    <xsl:param name="el" as="element(xdm:atomic)"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:variable name="type" as="xs:string" select="$el/@type"/>
    <xsl:variable name="lexical" as="xs:string" select="string($el)"/>
    <xsl:choose>
      <xsl:when test="$type eq 'xs:string'">
        <xsl:sequence select="xdm:colorize('''' || $lexical || '''', $xdm:BLUE, $useColor)"/>
      </xsl:when>
      <xsl:when test="$type eq 'xs:boolean'">
        <xsl:sequence select="xdm:colorize($lexical || '()', $xdm:GREEN, $useColor)"/>
      </xsl:when>
      <xsl:when test="$type = $xdm:NUMERIC-TYPES">
        <xsl:sequence select="xdm:colorize($lexical, $xdm:MAGENTA, $useColor)"/>
      </xsl:when>
      <xsl:when test="$type eq 'xs:QName'">
        <xsl:variable name="uri" as="xs:string?" select="$el/@uri"/>
        <xsl:sequence select="
          xdm:colorize((if (string-length($uri) gt 0) then 'Q{' || $uri || '}' else '') || $lexical, $xdm:CYAN, $useColor)"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- The value is colorized; the '(type)' annotation is left in the
             terminal's default color so it reads as a quieter aside, not
             part of the value itself. -->
        <xsl:sequence select="xdm:colorize($lexical, $xdm:CYAN, $useColor) || ' (' || $type || ')'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="xdm:render-map-text" as="xs:string">
    <xsl:param name="mapEl" as="element(xdm:map)"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:param name="level" as="xs:integer"/>
    <xsl:variable name="bc" as="xs:string" select="xdm:bracket-color($level)"/>
    <xsl:variable name="entryEls" as="element(xdm:entry)*" select="$mapEl/xdm:entry"/>
    <xsl:choose>
      <xsl:when test="empty($entryEls)">
        <xsl:sequence select="xdm:colorize('{', $bc, $useColor) || xdm:colorize('}', $bc, $useColor)"/>
      </xsl:when>
      <xsl:when test="some $e in $entryEls satisfies not(xdm:is-simple-item-seq($e/xdm:item))">
        <xsl:variable name="childIndent" as="xs:string" select="xdm:indent($level + 1)"/>
        <xsl:variable name="closeIndent" as="xs:string" select="xdm:indent($level)"/>
        <xsl:variable name="entries" as="xs:string*" select="
          for $e in $entryEls return xdm:render-entry-text($e, $useColor, $level + 1)"/>
        <xsl:sequence select="
          xdm:colorize('{', $bc, $useColor) || '&#10;' || $childIndent ||
          string-join($entries, ',&#10;' || $childIndent) ||
          '&#10;' || $closeIndent || xdm:colorize('}', $bc, $useColor)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="entries" as="xs:string*" select="
          for $e in $entryEls return xdm:render-entry-text($e, $useColor, $level + 1)"/>
        <xsl:sequence select="
          xdm:colorize('{', $bc, $useColor) || string-join($entries, ', ') || xdm:colorize('}', $bc, $useColor)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="xdm:render-entry-text" as="xs:string">
    <xsl:param name="entry" as="element(xdm:entry)"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:param name="level" as="xs:integer"/>
    <xsl:variable name="keyType" as="xs:string" select="$entry/@key-type"/>
    <xsl:variable name="keyText" as="xs:string" select="
      if ($keyType eq 'xs:string') then '''' || string($entry/@key) || '''' else string($entry/@key)"/>
    <xsl:sequence select="
      xdm:colorize($keyText, $xdm:RED, $useColor) || ': ' ||
      xdm:render-item-seq-text($entry/xdm:item, $useColor, $level)"/>
  </xsl:function>

  <xsl:function name="xdm:render-array-text" as="xs:string">
    <xsl:param name="arrayEl" as="element(xdm:array)"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:param name="level" as="xs:integer"/>
    <xsl:variable name="bc" as="xs:string" select="xdm:bracket-color($level)"/>
    <xsl:variable name="memberEls" as="element(xdm:member)*" select="$arrayEl/xdm:member"/>
    <xsl:choose>
      <xsl:when test="empty($memberEls)">
        <xsl:sequence select="xdm:colorize('[', $bc, $useColor) || xdm:colorize(']', $bc, $useColor)"/>
      </xsl:when>
      <xsl:when test="some $m in $memberEls satisfies not(xdm:is-simple-item-seq($m/xdm:item))">
        <xsl:variable name="childIndent" as="xs:string" select="xdm:indent($level + 1)"/>
        <xsl:variable name="closeIndent" as="xs:string" select="xdm:indent($level)"/>
        <xsl:variable name="members" as="xs:string*" select="
          for $m in $memberEls return xdm:render-item-seq-text($m/xdm:item, $useColor, $level + 1)"/>
        <xsl:sequence select="
          xdm:colorize('[', $bc, $useColor) || '&#10;' || $childIndent ||
          string-join($members, ',&#10;' || $childIndent) ||
          '&#10;' || $closeIndent || xdm:colorize(']', $bc, $useColor)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="members" as="xs:string*" select="
          for $m in $memberEls return xdm:render-item-seq-text($m/xdm:item, $useColor, $level + 1)"/>
        <xsl:sequence select="
          xdm:colorize('[', $bc, $useColor) || string-join($members, ', ') || xdm:colorize(']', $bc, $useColor)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- The resolved node's own rendering (exactly as xdm:render-node-text
       would render it inline), with the location line
       (xdm:render-node-ref-path-text) prepended on its own line above,
       in the terminal's default color - not colorized like the node
       body itself, so it reads as a quiet annotation rather than part
       of the value. Always puts the node's rendering on its own line(s)
       below the location, even when it would otherwise be short enough
       to stay inline after a 'key: ' prefix. -->
  <xsl:function name="xdm:render-node-ref-text" as="xs:string">
    <xsl:param name="ref" as="element(xdm:node-ref)"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:param name="level" as="xs:integer"/>
    <xsl:variable name="resolved" as="node()" select="xdm:resolve-node-ref($ref)"/>
    <xsl:variable name="pathLine" as="xs:string" select="xdm:render-node-ref-path-text($ref)"/>
    <xsl:variable name="rendered" as="xs:string" select="xdm:render-node-text($resolved, $useColor, $level)"/>
    <xsl:variable name="prefix" as="xs:string" select="'&#10;' || xdm:indent($level)"/>
    <!-- xdm:render-node-text already starts its own output with $prefix
         when the resolved node has descendant elements (its multi-line
         branch) - stripped here so the two don't stack into a blank-
         looking double newline; the single-line (leaf) branch has no
         such prefix, so nothing is stripped and $prefix supplies the
         line break the path line needs either way. -->
    <xsl:variable name="renderedBody" as="xs:string" select="
      if (starts-with($rendered, $prefix)) then substring($rendered, string-length($prefix) + 1) else $rendered"/>
    <xsl:sequence select="$pathLine || $prefix || $renderedBody"/>
  </xsl:function>

  <!-- A real (element/document) node has no compact XPath-literal form. A
       leaf-like node (no descendant elements) is shown as truncated,
       single-line markup; one with descendant elements is pretty-printed
       with conventional XML indentation instead, aligned to the current
       nesting level - truncating nested markup to a fixed length would
       just cut it apart awkwardly. -->
  <xsl:function name="xdm:render-node-text" as="xs:string">
    <xsl:param name="node" as="node()*"/>
    <xsl:param name="useColor" as="xs:boolean"/>
    <xsl:param name="level" as="xs:integer"/>
    <xsl:variable name="clean" as="node()*" select="xdm:strip-unused-namespaces($node)"/>
    <xsl:choose>
      <xsl:when test="exists($clean/descendant::*)">
        <xsl:variable name="indent" as="xs:string" select="xdm:indent($level)"/>
        <xsl:variable name="raw" as="xs:string" select="
          string-join(for $n in $clean return serialize($n, map{'method':'xml', 'indent': true()}), '&#10;')"/>
        <!-- Whether serialize() surrounds a lone element's indented markup
             with a leading/trailing newline is implementation-defined (the
             exact whitespace under indent="yes" isn't part of the spec,
             and does vary between Saxon versions) - so any such leading or
             trailing newline is stripped explicitly here, rather than
             assuming a fixed one is (or isn't) present and dropping a
             token by position, which silently ate the real opening tag on
             Saxon versions that don't add the leading newline.
             The (always-added, by us) leading newline is emitted as plain
             text BEFORE the color escape (rather than joined into the
             colorized text) - some terminals/log sinks swallow a bare
             newline that immediately follows a color-start code with
             nothing in between, which otherwise merges the element's start
             tag back onto the 'key: ' line. -->
        <xsl:variable name="withoutLeadingNewline" as="xs:string" select="
          if (starts-with($raw, '&#10;')) then substring($raw, 2) else $raw"/>
        <xsl:variable name="trimmed" as="xs:string" select="
          if (ends-with($withoutLeadingNewline, '&#10;'))
          then substring($withoutLeadingNewline, 1, string-length($withoutLeadingNewline) - 1)
          else $withoutLeadingNewline"/>
        <xsl:variable name="body" as="xs:string" select="
          string-join(tokenize($trimmed, '&#10;'), '&#10;' || $indent)"/>
        <xsl:sequence select="'&#10;' || $indent || xdm:colorize($body, $xdm:BLUE, $useColor)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="maxLength" as="xs:integer" select="80"/>
        <xsl:variable name="raw" as="xs:string" select="
          string-join(for $n in $clean return serialize($n, map{'method':'xml', 'indent': false()}), '')"/>
        <xsl:variable name="text" as="xs:string" select="
          if (string-length($raw) gt $maxLength) then substring($raw, 1, $maxLength - 3) || '...' else $raw"/>
        <xsl:sequence select="xdm:colorize($text, $xdm:BLUE, $useColor)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

</xsl:stylesheet>
