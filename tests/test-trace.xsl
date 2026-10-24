<?xml version="1.1" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:zxd="http://deltaxignia.com/ns/xdm-persistence/internal"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Checks xdm:trace: that each form returns its value unchanged, as
       fn:trace does - so it can wrap any expression - and, through
       zxd:trace-text (what it writes with xsl:message), the label prefix,
       the multi-line layout with continuation lines indented under the
       value, a node's path, and color only when asked for.

       The traces themselves are written as messages while this runs; the
       checks don't depend on whether NO_COLOR is set, as they pass the
       color flag explicitly or only check the returned value.
  -->

  <xsl:import href="../src/xdm-view.xsl"/>

  <xsl:output method="text"/>

  <xsl:variable name="book" as="element()">
    <book isbn="978-1"><title>Short</title></book>
  </xsl:variable>

  <xsl:variable name="m" as="map(*)" select="map { 'name': 'Ada', 'langs': ['xslt', 'xpath'] }"/>

  <xsl:variable name="numbers" as="xs:string" select="zxd:trace-text((1, 2, 3), 'ns', false())"/>
  <xsl:variable name="mapText" as="xs:string" select="zxd:trace-text($m, 'm', false())"/>
  <xsl:variable name="unlabelled" as="xs:string" select="zxd:trace-text('x', (), false())"/>
  <xsl:variable name="nodeText" as="xs:string" select="zxd:trace-text($book, 'book', false())"/>
  <xsl:variable name="colored" as="xs:string" select="zxd:trace-text($m, 'm', true())"/>

  <xsl:variable name="checkLabels" as="xs:string*" select="(
    'returns a sequence unchanged',
    'returns a map unchanged',
    'returns the same node, not a copy',
    'returns the empty sequence',
    'the 1- and 3-argument forms return the value too',
    'a value on one line follows its label',
    'a map is written over several lines',
    'continuation lines start under the value',
    'without a label, only the value',
    'a node shows its path',
    'color codes only when asked for'
  )"/>

  <xsl:variable name="checkResults" as="xs:boolean*" select="(
    deep-equal(xdm:trace((1, 2, 3), 'test: sequence'), (1, 2, 3)),
    deep-equal(xdm:trace($m, 'test: map'), $m),
    xdm:trace($book, 'test: node') is $book,
    empty(xdm:trace((), 'test: empty')),
    deep-equal(xdm:trace(42), 42) and deep-equal(xdm:trace(42, 'test: no color', false()), 42),
    $numbers eq 'ns: (1, 2, 3)',
    count(tokenize($mapText, '&#10;')) gt 1 and contains($mapText, '''name'': ''Ada'''),
    every $line in tail(tokenize($mapText, '&#10;')) satisfies starts-with($line, '   '),
    $unlabelled eq '''x''',
    contains($nodeText, xdm:path($book)),
    contains($colored, '&#x1B;[') and not(contains($mapText, '&#x1B;['))
  )"/>

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="failedLabels" as="xs:string*" select="
      for $i in 1 to count($checkResults) return if (not($checkResults[$i])) then $checkLabels[$i] else ()"/>
    <xsl:choose>
      <xsl:when test="empty($failedLabels)">
        <xsl:message select="'PASS: xdm:trace returns its value and writes it as documented' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="'FAIL: ' || string-join($failedLabels, ' | ')"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
