<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:people="http://example.com/people"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Renders a representative XDM value both ways: ANSI-coloured text to
       the console, and a browsable HTML page to disk.

         java -jar saxon.jar -xsl:demo.xsl -it
  -->

  <xsl:import href="../src/xdm-view.xsl"/>

  <xsl:param name="html-file" as="xs:string" select="'out/view-demo.html'"/>

  <xsl:output method="text"/>

  <xsl:variable name="html-uri" as="xs:string" select="resolve-uri($html-file, static-base-uri())"/>

  <xsl:variable name="profile" as="element()">
    <people:person><people:bio>First programmer.</people:bio></people:person>
  </xsl:variable>

  <xsl:variable name="value" as="item()*" select="
    map {
      'name': 'Ada Lovelace',
      'born': xs:date('1815-12-10'),
      'tags': array { 'mathematician', 'writer' },
      'scores': (7, 9, 10),
      'profile': $profile,
      'active': true(),
      'note': ()
    }"/>

  <xsl:template name="xsl:initial-template">
    <xsl:sequence select="xdm:view-text($value, true()) || '&#10;'"/>

    <xsl:result-document href="{$html-uri}" method="html" indent="yes">
      <xsl:sequence select="xdm:view-html($value)"/>
    </xsl:result-document>
    <xsl:sequence select="'Wrote ' || $html-uri || '&#10;'"/>
  </xsl:template>

</xsl:stylesheet>
