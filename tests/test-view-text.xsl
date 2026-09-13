<?xml version="1.1" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Checks that xdm:view-text renders the expected XPath-like fragments
       for a representative value, and that ANSI escapes appear only when
       color is requested. Uses substring checks rather than an exact
       string match, since map key iteration order is not guaranteed.
  -->

  <xsl:import href="../src/xdm-view.xsl"/>

  <xsl:output method="text"/>

  <xsl:variable name="bio" as="element()"><p>hello</p></xsl:variable>

  <xsl:variable name="value" as="item()*" select="
    map {
      'name': 'Ada',
      'active': true(),
      'scores': (1, 2, 3),
      'tags': array { 'a', 'b' },
      'bio': $bio,
      'empty': ()
    }"/>

  <xsl:variable name="expectedFragments" as="xs:string*" select="(
    'map{', '}',
    '''name''', '''Ada''',
    '''active''', 'true()',
    '(1, 2, 3)',
    'array{', '''a''', '''b''',
    '&lt;p&gt;hello&lt;/p&gt;',
    '()'
  )"/>

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="plain" as="xs:string" select="xdm:view-text($value)"/>
    <xsl:variable name="colored" as="xs:string" select="xdm:view-text($value, true())"/>

    <xsl:variable name="missing" as="xs:string*" select="$expectedFragments[not(contains($plain, .))]"/>
    <xsl:variable name="hasEscInPlain" as="xs:boolean" select="contains($plain, '&#x1B;')"/>
    <xsl:variable name="hasEscInColored" as="xs:boolean" select="contains($colored, '&#x1B;')"/>

    <xsl:variable name="passed" as="xs:boolean" select="
      empty($missing) and not($hasEscInPlain) and $hasEscInColored"/>

    <xsl:choose>
      <xsl:when test="$passed">
        <xsl:message select="'PASS: text view renders expected fragments, color only when requested' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="'FAIL: missing fragments: ' || string-join($missing, ' | ')"/>
        <xsl:message select="'plain has ESC: ' || $hasEscInPlain || ', colored has ESC: ' || $hasEscInColored"/>
        <xsl:message select="'plain output: ' || $plain"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
