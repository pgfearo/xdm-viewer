<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:people="http://example.com/people"
                xmlns:ext="com.deltaxml.xpath.result.print"
                exclude-result-prefixes="#all"
                version="3.0">
  
  <xsl:import href="../src/xdm-view.xsl"/>
  <xsl:output  method="text"/>
  
  <xsl:template match="/" mode="#default">
    <xsl:sequence select="xdm:persisted-to-text-view(., true())"/>
  </xsl:template>
  
</xsl:stylesheet>
