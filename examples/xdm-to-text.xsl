<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                version="3.0">
  
  <xsl:import href="../src/xdm-view.xsl"/>
  <xsl:output  method="text"/>
  
  <xsl:template match="/" mode="#default">
    <xsl:text expand-text="yes">
File: {tokenize(base-uri(*), '/')[last()]}
===========================

{xdm:persisted-to-text-view(., true())}

</xsl:text>
  </xsl:template>
  
</xsl:stylesheet>
