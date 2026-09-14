<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:ext="com.deltaxml.xpath.result.print"
                exclude-result-prefixes="#all"
                expand-text="yes"
                version="3.0">
  
  <!--
       Renders a representative XDM value both ways: ANSI-coloured text to
       the console, and a browsable HTML page to disk.
       
       java -jar saxon.jar -xsl:demo.xsl -it
  -->
  
  <xsl:import href="../src/xdm-view.xsl"/>
  <xsl:output  method="html"/>
  
  <xsl:variable name="base-file" as="xs:string" select="
    let $filename := tokenize(base-uri(), '/')[last()]
    return replace($filename, '\.[^.]+$', '')"/>
  
  <xsl:variable name="out-file" as="xs:string" select="resolve-uri('out/' || $base-file || '.html', base-uri())"/>
  
  
  <xsl:template match="/">
    
    <xsl:result-document href="{$out-file}-view.html" method="html" indent="yes">
      <xsl:sequence select="xdm:persisted-to-html-view(.)"/>
    </xsl:result-document>
    
    <xsl:message>
      View saved to: {$out-file}
    </xsl:message>
    
  </xsl:template>
  
</xsl:stylesheet>
