<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:zxd="http://deltaxignia.com/ns/xdm-persistence/internal"
                xmlns:array="http://www.w3.org/2005/xpath-functions/array"
                exclude-result-prefixes="#all"
                version="4.0">

  <!--
       Checks xdm:debug's handling of XPath 4.0 JNodes: each one is shown
       with its path within its tree (from fn:path) above the value it
       wraps - at the top level, in a sequence, as a map entry's value and
       as an array member - while xdm:view-text shows just the value.

       An XSLT 4.0 stylesheet, so it's not run by tests/run.sh, whose
       test-*.xsl files are XSLT 3.0 and run with any Saxon edition. It
       needs Saxon-PE or Saxon-EE 13 (Saxon-HE 13 rejects XPath 4.0
       syntax), with XPath 4.0 syntax enabled by Saxon's
       allowSyntaxExtensions:on option - see the README's Tests section
       for the command line.
  -->

  <xsl:import href="../../src/xdm-view.xsl"/>

  <xsl:output method="text"/>

  <xsl:variable name="tree" select="jtree(map {
      'customer': map { 'name': 'Sam' },
      'first name': 'S',
      'lines': [map { 'sku': 'A' }, map { 'sku': 'B' }],
      'notes': ()
    })"/>

  <!-- one label per entry: with one entry there's no ordering ambiguity in the output -->
  <xsl:function name="zxd:debug-one" as="xs:string">
    <xsl:param name="value" as="item()*"/>
    <xsl:sequence select="xdm:debug('jnodes', map { 'v': $value })"/>
  </xsl:function>

  <xsl:variable name="lines" as="function(item()*) as xs:string*" select="function($value) { tokenize(zxd:debug-one($value), '&#10;') }"/>

  <xsl:variable name="customer" as="xs:string*" select="$lines($tree/customer)"/>
  <xsl:variable name="skus" as="xs:string*" select="$lines($tree/lines/*)"/>
  <xsl:variable name="root" as="xs:string*" select="$lines($tree)"/>
  <xsl:variable name="quoted" as="xs:string*" select="$lines($tree/get('first name'))"/>
  <xsl:variable name="notes" as="xs:string*" select="$lines($tree/notes)"/>
  <xsl:variable name="inMap" as="xs:string*" select="$lines(map { 'k': $tree/customer/name })"/>
  <xsl:variable name="inArray" as="xs:string*" select="$lines([$tree/customer])"/>

  <xsl:variable name="huskedMember" as="map(*)" select="array:get(zxd:husk-value([$tree/customer]), 1)"/>

  <xsl:variable name="checkLabels" as="xs:string*" select="(
    'is-jnode: a JNode',
    'is-jnode: not a map, array, node, atomic value or function',
    'jnode-path: a nested array member',
    'jnode-path: a key that is not an NCName',
    'debug: a JNode shows its path above its value',
    'debug: JNodes in a sequence each show their path',
    'debug: the root of a tree is /',
    'debug: a key that is not an NCName',
    'debug: a JNode for a JSON null shows its path and ()',
    'debug: a JNode as a map entry value',
    'debug: a JNode as an array member',
    'husk-value: an array member keeps its JNode path, as it is not passed through array:for-each',
    'view-text: a JNode shows just its value'
  )"/>

  <xsl:variable name="checkResults" as="xs:boolean*" select="(
    zxd:is-jnode($tree/customer),
    not(zxd:is-jnode(map {}) or zxd:is-jnode([]) or zxd:is-jnode(1) or zxd:is-jnode(concat#3)
        or zxd:is-jnode(parse-xml('&lt;a/&gt;'))),
    zxd:jnode-path($tree/lines/*[2]/sku) eq '/lines/*[2]/sku',
    zxd:jnode-path($tree/get('first name')) eq '/get(&quot;first name&quot;)',
    $customer = 'v: /customer' and $customer = '   {''name'': ''Sam''}',
    $skus = '     /lines/*[1]' and $skus = '     /lines/*[2]',
    $root = 'v: /',
    $quoted = 'v: /get(&quot;first name&quot;)' and $quoted = '   ''S''',
    $notes = 'v: /notes' and $notes = '   ()',
    some $line in $inMap satisfies $line eq '     ''k'': /customer/name',
    $inArray = '     /customer',
    $huskedMember($zxd:NODE-PATH-KEY) eq '/customer' and deep-equal($huskedMember($zxd:NODE-VALUE-KEY), map { 'name': 'Sam' }),
    contains(xdm:view-text($tree/customer), '''name''') and not(contains(xdm:view-text($tree/customer), '/customer'))
  )"/>

  <xsl:template name="xsl:initial-template">
    <xsl:variable name="failedLabels" as="xs:string*" select="
      for $i in 1 to count($checkResults) return if (not($checkResults[$i])) then $checkLabels[$i] else ()"/>
    <xsl:choose>
      <xsl:when test="empty($failedLabels)">
        <xsl:message select="'PASS: xdm:debug shows each JNode''s path above its value' || '&#10;'"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message select="'FAIL: ' || string-join($failedLabels, ' | ')"/>
        <xsl:message terminate="yes" select="'Test failed'"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
