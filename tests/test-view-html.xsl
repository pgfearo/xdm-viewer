<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Checks that xdm:view-html renders the expected HTML fragments for a
       representative value. Uses substring checks rather than parsing the
       result back as XML, since HTML output (e.g. <meta ...> with no
       closing tag) is not required to be well-formed XML.
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
    'class=&quot;xdm-map&quot;', 'map{6 entries}',
    'class=&quot;xdm-string&quot;', '''Ada''',
    'class=&quot;xdm-boolean&quot;', 'true()',
    'class=&quot;xdm-number&quot;',
    'class=&quot;xdm-array&quot;', 'array{2 members}',
    'class=&quot;xdm-node&quot;', 'hello'
  )"/>

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="html" as="xs:string" select="serialize(xdm:view-html($value), map{'method':'html', 'indent': true()})"/>
    <xsl:variable name="missing" as="xs:string*" select="$expectedFragments[not(contains($html, .))]"/>

    <xsl:choose>
      <xsl:when test="empty($missing)">
        <xsl:message select="'PASS: html view renders expected fragments' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="'FAIL: missing fragments: ' || string-join($missing, ' | ')"/>
        <xsl:message select="'html output:' || '&#10;' || $html"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
