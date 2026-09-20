<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Checks that xdm:view-tokens renders a map/array/sequence/node value
       as the expected <xdm:token>/<xdm:group> tree: correct token types
       and text, foldable computed the same way xdm-view-text.xsl's own
       layout decision would (true only for a container that would have
       gone multi-line as plain text), and each entry/member/item wrapped
       in its own kind="entry" group with a trailing comma exactly when
       it isn't the last one.
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

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="tokens" as="element()*" select="xdm:view-tokens($value)"/>
    <xsl:variable name="root" as="element(xdm:group)" select="$tokens[1]"/>

    <xsl:variable name="entries" as="element(xdm:group)*" select="$root/xdm:group[@kind = 'entry']"/>

    <xsl:variable name="nameToken" as="element(xdm:token)?" select="$root//xdm:token[@type = 'name' and . = '''name''']"/>
    <xsl:variable name="stringToken" as="element(xdm:token)?" select="$root//xdm:token[@type = 'string' and . = '''Ada''']"/>
    <xsl:variable name="booleanToken" as="element(xdm:token)?" select="$root//xdm:token[@type = 'boolean' and . = 'true()']"/>

    <xsl:variable name="scoresSeq" as="element(xdm:group)?" select="$root//xdm:group[@kind = 'sequence']"/>
    <xsl:variable name="scoresNumbers" as="xs:string*" select="$scoresSeq//xdm:token[@type = 'number']/string(.)"/>

    <xsl:variable name="tagsArray" as="element(xdm:group)?" select="$root//xdm:group[@kind = 'array']"/>
    <xsl:variable name="tagsStrings" as="xs:string*" select="$tagsArray//xdm:token[@type = 'string']/string(.)"/>

    <xsl:variable name="bioToken" as="element(xdm:token)?" select="$root//xdm:token[@type = 'value' and contains(., '&lt;p&gt;hello&lt;/p&gt;')]"/>
    <xsl:variable name="emptyToken" as="element(xdm:token)?" select="$root//xdm:token[@type = 'punct' and . = '()']"/>

    <!-- Every entry but the last ends with its own trailing ', ' punct
         token, so the comma lands inside the entry a consumer's CSS
         would put on one line - not as a separate sibling that would
         strand itself on a line of its own once entries go block. -->
    <xsl:variable name="nonLastEntriesHaveTrailingComma" as="xs:boolean" select="
      every $e in $entries[position() ne last()] satisfies ($e/*[last()][self::xdm:token][@type = 'punct'][. = ', '])"/>
    <xsl:variable name="lastEntryHasNoTrailingComma" as="xs:boolean" select="
      not($entries[last()]/*[last()][self::xdm:token][@type = 'punct'][. = ', '])"/>

    <xsl:variable name="checks" as="xs:boolean*" select="(
      $root/@kind = 'map',
      $root/@foldable = 'true',
      count($entries) = 6,
      every $e in $entries satisfies ($e/@kind = 'entry' and $e/@foldable = 'false'),
      $nonLastEntriesHaveTrailingComma,
      $lastEntryHasNoTrailingComma,
      exists($nameToken), exists($stringToken), exists($booleanToken),
      exists($scoresSeq), $scoresSeq/@foldable = 'false',
      $scoresNumbers = ('1', '2', '3'),
      exists($tagsArray), $tagsArray/@foldable = 'false',
      $tagsStrings = ('''a''', '''b'''),
      exists($bioToken),
      exists($emptyToken)
    )"/>

    <xsl:choose>
      <xsl:when test="every $c in $checks satisfies $c">
        <xsl:message select="'PASS: token view renders expected typed tokens/groups' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="'FAIL: checks = ' || string-join(for $c in $checks return string($c), ', ')"/>
        <xsl:message select="'serialized tree: ' || serialize($tokens, map{'method':'xml', 'indent': true()})"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
