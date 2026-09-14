<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:people="http://example.com/people"
                xmlns:ext="com.deltaxml.xpath.result.print"
                exclude-result-prefixes="#all"
                version="3.0">
  
  <!--
       Renders a representative XDM value both ways: ANSI-coloured text to
       the console, and a browsable HTML page to disk.
       
       java -jar saxon.jar -xsl:demo.xsl -it
  -->
  
	<xsl:import href="../src/xdm-view.xsl"/>
  <xsl:output  method="text"/>
  
  <xsl:param name="html-file" as="xs:string" select="'out/view-demo.html'"/>
  <xsl:param name="html-text-file" as="xs:string" select="'out/view--text-demo.html'"/>
  
  <xsl:variable name="html-uri" as="xs:string" select="resolve-uri($html-file, static-base-uri())"/>
  <xsl:variable name="text-html-uri" as="xs:string" select="resolve-uri($html-text-file, static-base-uri())"/>
  
  <xsl:variable name="anyURI" as="xs:anyURI" select="xs:anyURI('http://deltaxignia.com/demo')"/>
  
  <xsl:variable name="profile" as="item()*">
    <xsl:processing-instruction name="type" select="'anything &lt;good&gt;'"/>
    <xsl:attribute name="class" select="'bold'"/>
    <xsl:sequence select="node-name(doc('')/*)"/>
    <xsl:sequence select="$anyURI"/>
    <xsl:text>text-node here</xsl:text>
    <p> the <b>quick</b> brown </p>
    <people:person><people:bio>First programmer.</people:bio></people:person>
  </xsl:variable>
  
  <xsl:variable name="value" as="item()*" select="
    map {
      'name': 'Ada Lovelace',
      'born': xs:date('1815-12-10'),
      'tags': [ 'mathematician', 'writer', (1,2,3), (4,5,6), [10,9,[1,2]] ],
      'scores': (7, 9, 10),
      'profile': $profile,
      'active': true(),
      'note': ()
    }"/>
  
  
  <xsl:template name="xsl:initial-template">
    <!-- Primary output, not xsl:message: most tools (Saxon's own default
         MessageListener included) XML-entity-encode xsl:message content,
         which mangles ANSI escape codes into literal '&#x1b;[...m' text.
         Primary output isn't affected, so this is the one place in the
         demo that actually shows color. Anyone who does want color through
         xsl:message needs to drive Saxon via its Java API and install
         their own MessageListener that writes the message's string value
         out unescaped - see the README. -->
    <xsl:sequence select="xdm:view-text($value, true())"/>
    
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
