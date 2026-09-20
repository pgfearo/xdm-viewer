<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:xdm="http://deltaxignia.com/ns/xdm-persistence"
                xmlns:people="http://example.com/people"
                exclude-result-prefixes="#all"
                version="3.0">

  <!--
       Renders demo.xsl's own representative value as a standalone,
       self-contained HTML page using xdm:view-tokens() - the colorized,
       foldable "code view", as an alternative to xdm:view-html's
       collapsible-list rendering, for refining/reviewing outside of any
       particular VS Code webview.

       xdm-view-tokens.css/xdm-view-tokens.js are inlined into the
       generated page (via unparsed-text(), at build time) rather than
       linked - the demo page then has no external resource loads at
       all, so it's guaranteed to render the same way whether it's
       double-clicked and opened via file:// or served from a real
       webserver. Edit those two files directly and re-run this
       stylesheet to refresh the generated page; they're also the exact
       assets a real VS Code notebook renderer would bundle later - see
       xdm-view-tokens.css's own header comment for why the same file
       works unmodified in both places.

       java -jar saxon.jar -xsl:demo-tokens.xsl -it
  -->

  <xsl:import href="../src/xdm-view.xsl"/>
  <xsl:output method="html" indent="no"/>

  <xsl:param name="html-file" as="xs:string" select="'out/view-tokens-demo.html'"/>
  <xsl:variable name="html-uri" as="xs:string" select="resolve-uri($html-file, static-base-uri())"/>

  <xsl:variable name="css-text" as="xs:string" select="unparsed-text('xdm-view-tokens.css')"/>
  <xsl:variable name="js-text" as="xs:string" select="unparsed-text('xdm-view-tokens.js')"/>

  <!-- Same representative value as demo.xsl, so the token/code view can
       be compared directly against the existing text/HTML views of the
       exact same data. -->
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
      'profile2': $profile[last()]/*,
      'active': true(),
      'note': ()
    }"/>

  <xsl:variable name="tokens" as="element()*" select="xdm:view-tokens($value)"/>

  <!-- Not HTML-entity-escaped, since fn:serialize()'s own xml output
       already produces well-formed markup text - only the '</script>'
       substring would be unsafe to embed literally in a real <script>
       body (none of this fixed sample data contains it; a real value
       from user data might, and this demo doesn't attempt to guard
       against that). -->
  <xsl:variable name="tokens-xml" as="xs:string" select="serialize($tokens, map{'method':'xml'})"/>

  <xsl:template name="xsl:initial-template">
    <xsl:result-document href="{$html-uri}" method="html" indent="no">
      <html>
        <head>
          <meta charset="UTF-8"/>
          <title>xdm-viewer - token/code view</title>
          <style><xsl:sequence select="$css-text"/></style>
        </head>
        <body>
          <div class="xdm-tokens-root" id="xdm-tokens-container">Loading&#8230;</div>

          <script type="application/xdm+xml" id="xdm-tokens-data"><xsl:sequence select="$tokens-xml"/></script>

          <!-- One module scope: xdm-view-tokens.js's own content
               (defining renderXdmTokens), followed directly by the call
               to it - no import needed, since nothing here is loaded
               from a separate file. -->
          <script type="module">
            <xsl:sequence select="$js-text"/>
            <xsl:text>
const xml = document.getElementById('xdm-tokens-data').textContent;
renderXdmTokens(xml, document.getElementById('xdm-tokens-container'));
</xsl:text>
          </script>
        </body>
      </html>
    </xsl:result-document>
    <xsl:message select="'Wrote ' || $html-uri"/>
  </xsl:template>

</xsl:stylesheet>
