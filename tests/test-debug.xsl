<?xml version="1.1" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:zxd="http://deltaxignia.com/ns/xdm-persistence/internal"
                xmlns:array="http://www.w3.org/2005/xpath-functions/array"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Checks xdm:debug/xdm:debug-color and the machinery behind them:
       the grouping marker, text truncation, and node pruning.

       The grouping/label-order marker functions (zxd:is-group-start,
       zxd:debug-display-label) and the pruning functions
       (zxd:truncate-text, zxd:husk-node) are checked directly as pure
       functions first - they never touch a map, so they're fully
       deterministic regardless of Saxon version. The xdm:debug/
       xdm:debug-color end-to-end checks below that only assert things
       which hold regardless of $labels' rendering order (see the
       README's "XDM print debugging" section on why that order isn't
       guaranteed pre-XPath-4.0) - a single-entry map is used for the
       grouping check specifically, since with one entry there's no
       ordering ambiguity to work around.
  -->

  <xsl:import href="../src/xdm-view.xsl"/>

  <xsl:output method="text"/>

  <!-- zxd:is-group-start / zxd:debug-display-label -->

  <xsl:variable name="rawBook" as="element()">
    <book isbn="978-1">
      <title>Short<xsl:comment>n/a</xsl:comment><footnote>dropped</footnote></title>
      <author>Jane Austen</author>
      <blurb>This blurb text is deliberately longer than forty characters for sure</blurb>
      <empty-with-child><inner/></empty-with-child>
    </book>
  </xsl:variable>

  <xsl:variable name="prunedBook" as="element()" select="zxd:husk-node($rawBook)"/>

  <xsl:variable name="rawDoc" as="document-node()">
    <xsl:document><wrapper><child/></wrapper></xsl:document>
  </xsl:variable>

  <xsl:variable name="prunedDoc" as="document-node()" select="zxd:husk-node($rawDoc)"/>

  <!-- zxd:preserves-space / zxd:normalize-for-display -->

  <xsl:variable name="messy" as="element()">
    <messy>line one
      line two   with   spaces</messy>
  </xsl:variable>

  <xsl:variable name="preserved" as="element()">
    <pre xml:space="preserve">line one
line two</pre>
  </xsl:variable>

  <xsl:variable name="overridden" as="element()">
    <outer xml:space="preserve"><inner xml:space="default">line one
line two</inner></outer>
  </xsl:variable>

  <xsl:variable name="fortyXs" as="xs:string" select="string-join(for $i in 1 to 40 return 'x', '')"/>
  <xsl:variable name="fortyOneXs" as="xs:string" select="$fortyXs || 'x'"/>

  <xsl:variable name="plainResult" as="xs:string" select="xdm:debug('my title', map { 'a': 1, 'b': 'text' })"/>
  <xsl:variable name="colorResult" as="xs:string" select="xdm:debug-color('same', map { 'a': 1 })"/>
  <xsl:variable name="level2Result" as="xs:string" select="xdm:debug('lvl', map { 'x': 1 }, 2)"/>
  <xsl:variable name="soloUnderscoreResult" as="xs:string" select="xdm:debug('grp', map { '_only': 42 })"/>
  <xsl:variable name="nodeResult" as="xs:string" select="xdm:debug('node', map { 'n': $rawBook })"/>

  <xsl:variable name="checkLabels" as="xs:string*" select="(
    'is-group-start: leading underscore',
    'is-group-start: no underscore',
    'is-group-start: underscore not at start is ignored',
    'display-label: strips a leading underscore',
    'display-label: unchanged without one',
    'display-label: bare underscore becomes empty string',
    'truncate-text: short text unchanged',
    'truncate-text: exactly at the limit is unchanged',
    'truncate-text: one over the limit is cut with a single ellipsis',
    'husk-node: keeps the root''s own attribute',
    'husk-node: zxd:path matches xdm:path on the original node',
    'husk-node: child with a dropped grandchild keeps its own text plus a marker',
    'husk-node: comment() alongside real content is silently dropped too',
    'husk-node: dropped grandchild element itself is gone',
    'husk-node: child with nothing more gets no marker',
    'husk-node: long child text is truncated, not double-marked',
    'husk-node: content-only child with no text gets the marker alone',
    'husk-node: document-node() recurses into its root element',
    'preserves-space: false with no xml:space in scope',
    'preserves-space: true under xml:space=preserve',
    'preserves-space: nearest wins - an inner xml:space=default overrides an outer preserve',
    'normalize-for-display: collapses line breaks and runs of spaces to one each, and trims',
    'normalize-for-display: left verbatim under xml:space=preserve',
    'husk-node end-to-end: a messy text node is normalized in the pruned output',
    'husk-node end-to-end: a preserve-marked text node keeps its line breaks in the pruned output',
    'husk-value: a bare text() item (not embedded in an element) is normalized and truncated too',
    'husk-value: a bare text() item under xml:space=preserve is kept verbatim',
    'husk-value: bare text() husking also applies inside an array member',
    'debug: title appears in the banner',
    'debug: an atomic label renders as label colon value',
    'debug: a string label is quoted',
    'debug: plain xdm:debug has no ANSI escapes',
    'debug-color: xdm:debug-color does have ANSI escapes',
    'debug: every call opens with a blank line',
    'debug: $level indents every line, including label lines, by (level-1)*5',
    'debug: a lone group-marked label gets no blank line (nothing precedes it)',
    'debug: the underscore is stripped from the lone label''s display',
    'debug: a node value shows its xdm:path() location',
    'debug: a node value is pruned (dropped grandchild is not shown)'
  )"/>

  <xsl:variable name="checkResults" as="xs:boolean*" select="(
    zxd:is-group-start('_foo'),
    not(zxd:is-group-start('foo')),
    not(zxd:is-group-start('foo_bar')),
    zxd:debug-display-label('_foo') eq 'foo',
    zxd:debug-display-label('foo') eq 'foo',
    zxd:debug-display-label('_') eq '',
    zxd:truncate-text('short', 40) eq 'short',
    zxd:truncate-text($fortyXs, 40) eq $fortyXs,
    zxd:truncate-text($fortyOneXs, 40) eq ($fortyXs || '&#x2026;'),
    $prunedBook/@isbn eq '978-1',
    $prunedBook/@zxd:path eq xdm:path($rawBook),
    $prunedBook/title/text() eq ('Short' || '&#x2026;'),
    empty($prunedBook/title/comment()),
    empty($prunedBook//footnote),
    $prunedBook/author/text() eq 'Jane Austen',
    string-length($prunedBook/blurb/text()) eq 41 and ends-with($prunedBook/blurb/text(), '&#x2026;')
      and not(contains($prunedBook/blurb/text(), '&#x2026;&#x2026;')),
    $prunedBook/*[local-name() eq 'empty-with-child']/text() eq '&#x2026;',
    $prunedDoc/*/@zxd:path eq xdm:path($rawDoc/*),
    not(zxd:preserves-space($messy/text())),
    zxd:preserves-space($preserved/text()),
    not(zxd:preserves-space($overridden/inner/text())),
    zxd:normalize-for-display($messy/text()) eq 'line one line two with spaces',
    zxd:normalize-for-display($preserved/text()) eq ('line one' || '&#10;' || 'line two'),
    zxd:husk-node($messy)/text() eq 'line one line two with spaces',
    zxd:husk-node($preserved)/text() eq ('line one' || '&#10;' || 'line two'),
    zxd:husk-value($messy/text())[1] eq 'line one line two with spaces',
    zxd:husk-value($preserved/text())[1] eq ('line one' || '&#10;' || 'line two'),
    array:get(zxd:husk-value([$messy/text()])[1], 1) eq 'line one line two with spaces',
    contains($plainResult, 'my title'),
    contains($plainResult, 'a: 1'),
    contains($plainResult, '''text'''),
    not(contains($plainResult, '&#x1B;')),
    contains($colorResult, '&#x1B;'),
    starts-with($plainResult, '&#10;'),
    some $line in tokenize($level2Result, '&#10;') satisfies $line eq '     x: 1',
    count(tokenize($soloUnderscoreResult, '&#10;')) eq 3,
    contains($soloUnderscoreResult, 'only: 42') and not(contains($soloUnderscoreResult, '_only')),
    contains($nodeResult, xdm:path($rawBook)),
    contains($nodeResult, 'Short&#x2026;') and not(contains($nodeResult, 'footnote'))
  )"/>

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="failedLabels" as="xs:string*" select="
      for $i in 1 to count($checkResults) return if (not($checkResults[$i])) then $checkLabels[$i] else ()"/>
    <xsl:choose>
      <xsl:when test="empty($failedLabels)">
        <xsl:message select="'PASS: xdm:debug, grouping, and pruning all behave as documented' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="'FAIL: ' || string-join($failedLabels, ' | ')"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
