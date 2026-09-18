<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:people="http://example.com/people"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Renders a representative reference-preserving-mode value both ways:
       ANSI-coloured text to the console, and a browsable HTML page to
       disk - the companion to demo.xsl, using xdm:to-document-with-refs
       instead of xdm:to-document.

       $value is built to exercise every distinct thing the viewer shows
       for this mode: household/household-again reference the exact same
       node twice, so their location text comes out identical (letting
       the reader infer they're the same node, rather than the viewer
       asserting it); a-child disambiguates itself from its same-named
       sibling with a [1] predicate; visitor and visitor-bio are two
       independently-referenced nodes from the same second document, so
       their location text shares a prefix (revealing the ancestor
       relationship); and that second document shows as #2, distinct
       from the first document's #1.

       java -jar saxon.jar -xsl:demo-refs.xsl -it
  -->

  <xsl:import href="../src/xdm-view.xsl"/>
  <xsl:output method="text"/>

  <xsl:param name="html-file" as="xs:string" select="'out/view-demo-refs.html'"/>
  <xsl:param name="html-text-file" as="xs:string" select="'out/view-text-demo-refs.html'"/>

  <xsl:variable name="html-uri" as="xs:string" select="resolve-uri($html-file, static-base-uri())"/>
  <xsl:variable name="text-html-uri" as="xs:string" select="resolve-uri($html-text-file, static-base-uri())"/>

  <xsl:variable name="doc1" as="document-node()">
    <xsl:document>
      <people:family>
        <people:parent><people:child id="1"/></people:parent>
        <people:child id="2"/>
        <people:child id="3"/>
      </people:family>
    </xsl:document>
  </xsl:variable>

  <xsl:variable name="doc2" as="document-node()">
    <xsl:document>
      <people:person><people:bio>Second programmer.</people:bio></people:person>
    </xsl:document>
  </xsl:variable>

  <xsl:variable name="household" as="element()" select="$doc1/people:family"/>
  <xsl:variable name="aChild" as="element()" select="($doc1/people:family/people:child)[1]"/>

  <xsl:variable name="value" as="item()*" select="
    map {
      'name': 'Ada Lovelace',
      'household': $household,
      'household-again': $household,
      'a-child': $aChild,
      'visitor': $doc2/people:person,
      'visitor-bio': $doc2/people:person/people:bio
    }"/>

  <xsl:template name="xsl:initial-template">
    <!-- Primary output, not xsl:message - see demo.xsl's own comment on
         why: entity-encoding via xsl:message would mangle the ANSI
         escape codes. -->
    <xsl:sequence select="xdm:view-text-with-refs($value, true()) || '&#10;'"/>

    <xsl:result-document href="{$text-html-uri}" method="html" indent="yes">
      <html>
        <pre>
          <code>
            <xsl:sequence select="xdm:view-text-with-refs($value, false())"/>
          </code>
        </pre>
      </html>
    </xsl:result-document>

    <xsl:result-document href="{$html-uri}" method="html" indent="yes">
      <xsl:sequence select="xdm:view-html-with-refs($value)"/>
    </xsl:result-document>
    <xsl:message select="'Wrote ' || $html-uri"/>
  </xsl:template>

</xsl:stylesheet>
