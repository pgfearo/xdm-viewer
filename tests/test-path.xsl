<?xml version="1.1" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:ns="urn:example"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Checks xdm:path() across the node kinds and disambiguation rules
       it documents: an only child of its kind stays a bare step, a
       same-kind sibling forces a [N] predicate, non-element kinds
       (attribute/text/comment) get their own step form, every non-
       document path (document-rooted or standalone) gets a leading
       '/', and the bare document-node() case renders as
       '(whole document)'.

       Fully deterministic - xdm:path() walks real ancestor axes on a
       node directly, not a map, so none of this depends on the
       map-key-ordering caveats test-debug.xsl has to work around.
  -->

  <xsl:import href="../src/xdm-view.xsl"/>

  <xsl:output method="text"/>

  <xsl:variable name="doc" as="document-node()">
    <xsl:document>
      <books xmlns:ns="urn:example">
        <ns:book isbn="978-1"><title>A</title></ns:book>
        <ns:book isbn="978-2"><title>B</title></ns:book>
        <preface>intro<xsl:comment>note</xsl:comment></preface>
      </books>
    </xsl:document>
  </xsl:variable>

  <xsl:variable name="standalone" as="element()"><item/></xsl:variable>

  <xsl:variable name="checkLabels" as="xs:string*" select="(
    'root element, no [N] (only element of its kind)',
    'first of two same-name siblings gets [1]',
    'second sibling''s attribute',
    'only child of its kind stays bare (preface)',
    'text() step under an only-child title',
    'comment() step',
    'bare document-node() is (whole document)',
    'a node with no document ancestor still gets a leading /'
  )"/>

  <xsl:variable name="checkResults" as="xs:boolean*" select="(
    xdm:path($doc/*) eq '/books',
    xdm:path($doc//ns:book[1]) eq '/books/ns:book[1]',
    xdm:path($doc//ns:book[2]/@isbn) eq '/books/ns:book[2]/@isbn',
    xdm:path($doc//preface) eq '/books/preface',
    xdm:path($doc//ns:book[1]/title/text()) eq '/books/ns:book[1]/title/text()',
    xdm:path($doc//preface/comment()) eq '/books/preface/comment()',
    xdm:path($doc) eq '(whole document)',
    xdm:path($standalone) eq '/item'
  )"/>

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="failedLabels" as="xs:string*" select="
      for $i in 1 to count($checkResults) return if (not($checkResults[$i])) then $checkLabels[$i] else ()"/>
    <xsl:choose>
      <xsl:when test="empty($failedLabels)">
        <xsl:message select="'PASS: xdm:path renders location strings as documented' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="'FAIL: ' || string-join($failedLabels, ' | ')"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
