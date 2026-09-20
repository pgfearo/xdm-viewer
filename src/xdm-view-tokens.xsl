<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:zxd="http://deltaxignia.com/ns/xdm-persistence/internal"
                exclude-result-prefixes="xsl zxd"
                version="3.0">

  <!--
       (c) DeltaXignia ltd. 2026
       Renders an XPath 3.1 Data Model value as a sequence of <xdm:token>/
       <xdm:group> elements - the same shape xdm-view-text.xsl renders as a
       plain string, just with every fragment's semantic kind (string,
       number, boolean, map key, or plain punctuation) already classified
       on it, rather than left for a consumer to re-parse out of text. A
       consumer that wants to color this the way a source-code editor
       would no longer has to lex it back apart first - and can't
       misclassify a string value's own content as if it were punctuation,
       a real risk when re-parsing xdm:view-text's own output (e.g. an
       unescaped quote character inside a string value).

       <xdm:token type="string|number|boolean|name|value|punct">text</xdm:token>
       is a leaf - exactly one fragment of display text, already tagged
       with its kind. The type names are deliberately the same ones VS
       Code's own `debugTokenExpression.*` theme colors use (string,
       number, boolean, name, value), so a consumer can map type directly
       to the matching CSS variable with no translation table
       of its own; punct (brackets, commas, colons) has no VS Code
       equivalent and is meant to stay in the default foreground, same as
       the Debug Console leaves its own punctuation uncolored. A node's
       markup (an element or document value, which has no compact
       tokenizable form of its own) is one "value" token carrying its
       already-truncated/pretty-printed text as-is, embedded newlines and
       all - unlike every other punct/token boundary here, that text is
       not something a consumer is expected to re-lay-out.

       <xdm:group kind="map|array|sequence|node-ref|attribute|namespace"
       foldable="true|false">...</xdm:group> is a container - its children
       are its own opening/closing punct tokens plus whatever it holds, in
       document order, with no further nesting for fold purposes (an
       entry's key, colon, and value all sit as direct children, not in
       their own sub-group) - nothing here asks to fold at any finer grain
       than one whole map/array/sequence. foldable is true exactly when
       xdm-view-text.xsl's own layout would have spread this container
       over multiple lines rather than inlining it on one - the same
       zxd:is-simple-item-seq decision, reused rather than re-derived, so
       the tokenized and plain-text renderings never disagree about which
       containers are "big enough to matter". Punctuation and layout
       (indentation, line breaks between a foldable container's children)
       are deliberately not baked into any token's text - that's a
       consumer/CSS concern, the same way it would be for any other
       structured-data renderer.
  -->

  <xsl:function name="xdm:view-tokens" as="element()*">
    <xsl:param name="value" as="item()*"/>
    <xsl:sequence select="xdm:persisted-to-token-view(xdm:to-document($value))"/>
  </xsl:function>

  <!-- For a value already persisted via xdm-persistence's xdm:to-document()
       (e.g. read back with doc()) - renders the tree directly, same
       precedent as xdm:persisted-to-text-view/xdm:persisted-to-html-view. -->
  <xsl:function name="xdm:persisted-to-token-view" as="element()*">
    <xsl:param name="doc" as="document-node()"/>
    <xsl:variable name="items" as="element(xdm:item)*" select="
      if (xdm:is-refs-format($doc)) then $doc/xdm:context/xdm:sequence/xdm:item else $doc/xdm:sequence/xdm:item"/>
    <xsl:sequence select="zxd:render-item-seq-tokens($items)"/>
  </xsl:function>

  <!-- Value-level entry point for the reference-preserving mode, mirroring
       xdm:view-text-with-refs/xdm:view-html-fragment-with-refs the same
       way they mirror xdm:to-document-with-refs. -->
  <xsl:function name="xdm:view-tokens-with-refs" as="element()*">
    <xsl:param name="value" as="item()*"/>
    <xsl:sequence select="xdm:persisted-to-token-view(xdm:to-document-with-refs($value))"/>
  </xsl:function>

  <xsl:function name="zxd:token" as="element(xdm:token)">
    <xsl:param name="type" as="xs:string"/>
    <xsl:param name="text" as="xs:string"/>
    <xdm:token type="{$type}"><xsl:value-of select="$text"/></xdm:token>
  </xsl:function>

  <xsl:function name="zxd:punct" as="element(xdm:token)">
    <xsl:param name="text" as="xs:string"/>
    <xsl:sequence select="zxd:token('punct', $text)"/>
  </xsl:function>

  <!-- Renders a sequence of xdm:item elements the way xdm-view-text.xsl's
       zxd:render-item-seq-text does: 0 items -> a single '()' punct token,
       1 item -> just that item's own tokens (no wrapping group), 2+ items
       -> a foldable "sequence" group, parenthesized and comma-separated. -->
  <xsl:function name="zxd:render-item-seq-tokens" as="element()*">
    <xsl:param name="items" as="element(xdm:item)*"/>
    <xsl:choose>
      <xsl:when test="count($items) = 0">
        <xsl:sequence select="zxd:punct('()')"/>
      </xsl:when>
      <xsl:when test="count($items) = 1">
        <xsl:sequence select="zxd:render-payload-tokens($items[1]/*[1])"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="foldable" as="xs:boolean" select="
          some $i in $items satisfies not($i/*[1]/self::xdm:atomic)"/>
        <xdm:group kind="sequence" foldable="{$foldable}">
          <xsl:sequence select="zxd:punct('(')"/>
          <xsl:for-each select="$items">
            <xsl:if test="position() gt 1"><xsl:sequence select="zxd:punct(', ')"/></xsl:if>
            <xsl:sequence select="zxd:render-payload-tokens(./*[1])"/>
          </xsl:for-each>
          <xsl:sequence select="zxd:punct(')')"/>
        </xdm:group>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="zxd:render-payload-tokens" as="element()*">
    <xsl:param name="payload" as="element()"/>
    <xsl:choose>
      <xsl:when test="$payload/self::xdm:atomic">
        <xsl:sequence select="zxd:render-atomic-tokens($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:map">
        <xsl:sequence select="zxd:render-map-tokens($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:array">
        <xsl:sequence select="zxd:render-array-tokens($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:node-ref">
        <xsl:sequence select="zxd:render-node-ref-tokens($payload)"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:text">
        <xsl:sequence select="zxd:token('string', '&quot;' || string($payload) || '&quot;')"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:comment">
        <xsl:sequence select="zxd:token('value', '&lt;!--' || string($payload) || '--&gt;')"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:pi">
        <xsl:sequence select="zxd:token('value', '&lt;?' || string($payload/@name) || ' ' || string($payload) || '?&gt;')"/>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:attribute">
        <xdm:group kind="attribute" foldable="false">
          <xsl:sequence select="zxd:token('name', '@' || string($payload/@name))"/>
          <xsl:sequence select="zxd:punct('=')"/>
          <xsl:sequence select="zxd:token('string', '&quot;' || string($payload) || '&quot;')"/>
        </xdm:group>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:namespace">
        <xdm:group kind="namespace" foldable="false">
          <xsl:sequence select="
            zxd:token('name', 'xmlns' || (if (string-length($payload/@prefix) gt 0) then ':' || string($payload/@prefix) else ''))"/>
          <xsl:sequence select="zxd:punct('=')"/>
          <xsl:sequence select="zxd:token('string', '&quot;' || string($payload/@uri) || '&quot;')"/>
        </xdm:group>
      </xsl:when>
      <xsl:when test="$payload/self::xdm:document">
        <xsl:sequence select="zxd:render-node-tokens($payload/node())"/>
      </xsl:when>
      <xsl:otherwise> <!-- a plain copied element node -->
        <xsl:sequence select="zxd:render-node-tokens($payload)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="zxd:render-atomic-tokens" as="element(xdm:token)">
    <xsl:param name="el" as="element(xdm:atomic)"/>
    <xsl:variable name="type" as="xs:string" select="$el/@type"/>
    <xsl:variable name="lexical" as="xs:string" select="string($el)"/>
    <xsl:choose>
      <xsl:when test="$type eq 'xs:string'">
        <xsl:sequence select="zxd:token('string', '''' || $lexical || '''')"/>
      </xsl:when>
      <xsl:when test="$type eq 'xs:boolean'">
        <xsl:sequence select="zxd:token('boolean', $lexical || '()')"/>
      </xsl:when>
      <xsl:when test="$type = $zxd:NUMERIC-TYPES">
        <xsl:sequence select="zxd:token('number', $lexical)"/>
      </xsl:when>
      <xsl:when test="$type eq 'xs:QName'">
        <xsl:variable name="uri" as="xs:string?" select="$el/@uri"/>
        <xsl:sequence select="
          zxd:token('value', (if (string-length($uri) gt 0) then 'Q{' || $uri || '}' else '') || $lexical)"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- Unlike zxd:render-atomic-text (which colors the lexical value
             and leaves the '(type)' annotation in the default color as a
             quieter aside), a token can only carry one type - the whole
             "lexical (type)" text is a single 'value' token here. -->
        <xsl:sequence select="zxd:token('value', $lexical || ' (' || $type || ')')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:function name="zxd:render-map-tokens" as="element(xdm:group)">
    <xsl:param name="mapEl" as="element(xdm:map)"/>
    <xsl:variable name="entryEls" as="element(xdm:entry)*" select="$mapEl/xdm:entry"/>
    <xsl:variable name="foldable" as="xs:boolean" select="
      exists($entryEls) and (some $e in $entryEls satisfies not(zxd:is-simple-item-seq($e/xdm:item)))"/>
    <xdm:group kind="map" foldable="{$foldable}">
      <xsl:sequence select="zxd:punct('{')"/>
      <xsl:for-each select="$entryEls">
        <xsl:if test="position() gt 1"><xsl:sequence select="zxd:punct(', ')"/></xsl:if>
        <xsl:sequence select="zxd:render-entry-tokens(.)"/>
      </xsl:for-each>
      <xsl:sequence select="zxd:punct('}')"/>
    </xdm:group>
  </xsl:function>

  <xsl:function name="zxd:render-entry-tokens" as="element()*">
    <xsl:param name="entry" as="element(xdm:entry)"/>
    <xsl:variable name="keyType" as="xs:string" select="$entry/@key-type"/>
    <xsl:variable name="keyText" as="xs:string" select="
      if ($keyType eq 'xs:string') then '''' || string($entry/@key) || '''' else string($entry/@key)"/>
    <xsl:sequence select="zxd:token('name', $keyText)"/>
    <xsl:sequence select="zxd:punct(': ')"/>
    <xsl:sequence select="zxd:render-item-seq-tokens($entry/xdm:item)"/>
  </xsl:function>

  <xsl:function name="zxd:render-array-tokens" as="element(xdm:group)">
    <xsl:param name="arrayEl" as="element(xdm:array)"/>
    <xsl:variable name="memberEls" as="element(xdm:member)*" select="$arrayEl/xdm:member"/>
    <xsl:variable name="foldable" as="xs:boolean" select="
      exists($memberEls) and (some $m in $memberEls satisfies not(zxd:is-simple-item-seq($m/xdm:item)))"/>
    <xdm:group kind="array" foldable="{$foldable}">
      <xsl:sequence select="zxd:punct('[')"/>
      <xsl:for-each select="$memberEls">
        <xsl:if test="position() gt 1"><xsl:sequence select="zxd:punct(', ')"/></xsl:if>
        <xsl:sequence select="zxd:render-item-seq-tokens(./xdm:item)"/>
      </xsl:for-each>
      <xsl:sequence select="zxd:punct(']')"/>
    </xdm:group>
  </xsl:function>

  <!-- A real node's markup, as a single 'value' token - reuses
       zxd:render-node-text (from xdm-view-text.xsl) with useColor=false so
       it never emits ANSI escapes, rather than re-implementing its
       truncation/pretty-print/cross-Saxon-version whitespace handling a
       second time. Always called at level 0: the surrounding indentation
       zxd:render-node-text would otherwise add for a non-zero level is a
       layout concern for whoever positions this token, not something to
       bake into the token's own text - only the leading newline the
       multi-line branch unconditionally adds (regardless of level) is
       stripped here, the same "don't stack a leading blank line" fix
       zxd:render-node-ref-text/zxd:render-path-wrapped-text already apply
       for their own callers. -->
  <xsl:function name="zxd:render-node-tokens" as="element(xdm:token)">
    <xsl:param name="node" as="node()*"/>
    <xsl:variable name="rendered" as="xs:string" select="zxd:render-node-text($node, false(), 0)"/>
    <xsl:variable name="text" as="xs:string" select="
      if (starts-with($rendered, '&#10;')) then substring($rendered, 2) else $rendered"/>
    <xsl:sequence select="zxd:token('value', $text)"/>
  </xsl:function>

  <!-- The resolved node's own tokens (zxd:render-node-tokens), with the
       location line (zxd:render-node-ref-path-text, from
       xdm-view-common.xsl) as a leading 'value' token - not foldable
       itself (see this file's header comment for why fold support stops
       at map/array/sequence for now). -->
  <xsl:function name="zxd:render-node-ref-tokens" as="element(xdm:group)">
    <xsl:param name="ref" as="element(xdm:node-ref)"/>
    <xsl:variable name="resolved" as="node()" select="zxd:resolve-node-ref($ref)"/>
    <xdm:group kind="node-ref" foldable="false">
      <xsl:sequence select="zxd:token('value', zxd:render-node-ref-path-text($ref))"/>
      <xsl:sequence select="zxd:render-node-tokens($resolved)"/>
    </xdm:group>
  </xsl:function>

</xsl:stylesheet>
