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
       gone multi-line as plain text), each entry/member/item wrapped in
       its own kind="entry" group with a trailing comma exactly when it
       isn't the last one, every node value (here, 'bio') wrapped in a
       kind="node-path" group showing its xdm:path() location, and (via
       'rich') that $minimize=true shrinks a node value the same way
       xdm:debug's own pruning does (zxd:prune-node, reused directly),
       while $minimize=false (the default) leaves it in full, and (via
       'born') that a fallback atomic's '(type)' annotation is its own
       trailing 'punct' token, not merged into the value's own token.
  -->

  <xsl:import href="../src/xdm-view.xsl"/>

  <xsl:output method="text"/>

  <xsl:variable name="bio" as="element()"><p>hello</p></xsl:variable>

  <!-- Deep enough (a grandchild) and long enough (over 40 chars of
       text) to make zxd:prune-node's shrink visible: minimized, the
       <detail> grandchild and the full <name> text should both be
       gone, replaced by a '…' marker; unminimized, both survive. -->
  <xsl:variable name="rich" as="element()">
    <item sku="A1">
      <name>Widget with a really quite long descriptive name</name>
      <description><detail>deeply nested detail text</detail></description>
    </item>
  </xsl:variable>

  <xsl:variable name="value" as="item()*" select="
    map {
      'name': 'Ada',
      'active': true(),
      'scores': (1, 2, 3),
      'tags': array { 'a', 'b' },
      'bio': $bio,
      'rich': $rich,
      'born': xs:date('1815-12-10'),
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

    <!-- The fallback-atomic branch (xs:date has no dedicated type of its
         own) splits into two separate tokens - 'value' for the lexical
         value, 'punct' for the '(type)' annotation - rather than one
         merged token, so a consumer's CSS can leave the annotation
         uncolored while the value itself is colored. -->
    <xsl:variable name="dateValueToken" as="element(xdm:token)?" select="$root//xdm:token[@type = 'value' and . = '1815-12-10']"/>
    <xsl:variable name="dateTypeToken" as="element(xdm:token)?" select="$root//xdm:token[@type = 'punct' and . = ' (xs:date)']"/>

    <!-- $bio is a parentless element (declared standalone, not read from
         a document), so xdm:path() on it is just its own step label -
         see xdm-view-common.xsl's xdm:path. -->
    <xsl:variable name="bioPathGroup" as="element(xdm:group)?" select="
      $root//xdm:group[@kind = 'node-path'][xdm:token[1] = '/p']"/>
    <xsl:variable name="bioPathToken" as="element(xdm:token)?" select="$bioPathGroup/xdm:token[1][@type = 'punct' and . = '/p']"/>

    <!-- Every entry but the last ends with its own trailing ', ' punct
         token, so the comma lands inside the entry a consumer's CSS
         would put on one line - not as a separate sibling that would
         strand itself on a line of its own once entries go block. -->
    <xsl:variable name="nonLastEntriesHaveTrailingComma" as="xs:boolean" select="
      every $e in $entries[position() ne last()] satisfies ($e/*[last()][self::xdm:token][@type = 'punct'][. = ', '])"/>
    <xsl:variable name="lastEntryHasNoTrailingComma" as="xs:boolean" select="
      not($entries[last()]/*[last()][self::xdm:token][@type = 'punct'][. = ', '])"/>

    <!-- $minimize=true should reuse zxd:prune-node exactly like
         xdm:debug does: the <detail> grandchild and the full <name>
         text both disappear, a '…' marker shows up in their place, and
         (unaffected by $minimize either way) 'rich' still gets its own
         kind="node-path" location. -->
    <xsl:variable name="minimizedTokens" as="element()*" select="xdm:view-tokens($value, true())"/>
    <xsl:variable name="minimizedRoot" as="element(xdm:group)" select="$minimizedTokens[1]"/>

    <xsl:variable name="checks" as="xs:boolean*" select="(
      $root/@kind = 'map',
      $root/@foldable = 'true',
      count($entries) = 8,
      every $e in $entries satisfies ($e/@kind = 'entry' and $e/@foldable = 'false'),
      $nonLastEntriesHaveTrailingComma,
      $lastEntryHasNoTrailingComma,
      exists($nameToken), exists($stringToken), exists($booleanToken),
      exists($scoresSeq), $scoresSeq/@foldable = 'false',
      $scoresNumbers = ('1', '2', '3'),
      exists($tagsArray), $tagsArray/@foldable = 'false',
      $tagsStrings = ('''a''', '''b'''),
      exists($bioToken),
      exists($bioPathGroup), $bioPathGroup/@foldable = 'false',
      exists($bioPathToken),
      exists($bioPathGroup/xdm:token[2][@type = 'value' and contains(., '&lt;p&gt;hello&lt;/p&gt;')]),
      exists($emptyToken),
      exists($dateValueToken), exists($dateTypeToken),
      $dateTypeToken/preceding-sibling::*[1] is $dateValueToken,
      exists($root//xdm:token[@type = 'value' and contains(., 'deeply nested detail text')]),
      not(exists($minimizedRoot//xdm:token[@type = 'value' and contains(., 'deeply nested detail')])),
      exists($minimizedRoot//xdm:token[@type = 'value' and contains(., '&#x2026;')]),
      exists($minimizedRoot//xdm:group[@kind = 'node-path']/xdm:token[1][@type = 'punct' and . = '/item'])
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
