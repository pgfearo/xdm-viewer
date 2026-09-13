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
  <xsl:param name="html-text-file" as="xs:string" select="'out/view--text-demo.html'"/>
  
  <xsl:variable name="html-uri" as="xs:string" select="resolve-uri($html-file, static-base-uri())"/>
  <xsl:variable name="text-html-uri" as="xs:string" select="resolve-uri($html-text-file, static-base-uri())"/>
  
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
    <!-- xsl:message rather than the primary output: it isn't subject to a
         task runner's resultPath redirection, and (with the DeltaXML XSLT
         extension's Saxon wrapper) is emitted without XML-entity-encoding
         the ANSI escape codes. -->
    <xsl:message select="xdm:view-text($value, true())"/>
    
    <xsl:result-document href="{$text-html-uri}" method="html" indent="yes">
      <html>
        <pre>
          <code>
            <xsl:sequence select="xdm:view-text($value, false())"/>
          </code>
        </pre>
      </html>
    </xsl:result-document>
    
    <xsl:result-document href="{$html-uri}" method="html" indent="yes">
      <xsl:sequence select="xdm:view-html($value)"/>
    </xsl:result-document>
    <xsl:message select="'Wrote ' || $html-uri"/>
  </xsl:template>
  
</xsl:stylesheet>
