<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="xsl"
                version="3.0">

  <!--
       (c) DeltaXignia ltd. 2026
       Small helpers shared by xdm-view-text.xsl and xdm-view-html.xsl.
  -->

  <!-- A real element/document node embedded in the xdm: tree inherits
       xmlns:xdm/xmlns:xs from its ancestors (that's just how XML namespace
       scoping works), even though it never uses either. Serializing it in
       isolation for display would otherwise carry that noise along, so it
       is stripped down to only the namespaces its own names actually use. -->
  <xsl:mode name="xdm:strip-ns" on-no-match="shallow-copy"/>

  <xsl:template match="*" mode="xdm:strip-ns">
    <xsl:copy copy-namespaces="no">
      <xsl:apply-templates select="@*, node()" mode="xdm:strip-ns"/>
    </xsl:copy>
  </xsl:template>

  <xsl:function name="xdm:strip-unused-namespaces" as="node()*">
    <xsl:param name="node" as="node()*"/>
    <xsl:apply-templates select="$node" mode="xdm:strip-ns"/>
  </xsl:function>

  <!-- Whether every item in a sequence (a map entry's or array member's
       value, or the top-level value) is a plain atomic value. A sequence
       that's all-atomic is short enough to lay out compactly on one line;
       one holding even a single node, map or array reads better with each
       item on its own line - nodes and attributes in particular tend to
       be too verbose to cram inline. -->
  <xsl:function name="xdm:all-atomic" as="xs:boolean">
    <xsl:param name="items" as="element(xdm:item)*"/>
    <xsl:sequence select="every $i in $items satisfies $i/*[1]/self::xdm:atomic"/>
  </xsl:function>

</xsl:stylesheet>
