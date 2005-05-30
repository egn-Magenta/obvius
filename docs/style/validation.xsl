<?xml version="1.0" encoding="iso-8859-1"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">

  <xsl:output method="html"/>

  <xsl:template match="/">
    <html>
      <head>
        <title>Validation results</title>
        <style type="text/css">
          body { font-family: sans-serif; color: black; background-color: #aaa; }
          div.all { color: black; background-color: white; padding: 0.5em 1em; }
          h1 { font-size: large; margin-top: 0.5em; }
          label { display: block; font-size: small; font-weight: bold; }
          div { margin-bottom: 1em; }
          div.errors div { margin-bottom: 0.1em; font-family: monospace; }
        </style>
      </head>
      <body>
        <div class="all">
          <h1>W3C XHTML 1.0 markup validation results</h1>
          <xsl:apply-templates select="/validation/status"/>
          <xsl:if test="number(/validation/errorcount) != 0">
            <xsl:apply-templates select="/validation/errorcount"/>
            <div class="errors">
              <label>Errors:</label>
              <xsl:for-each select="/validation/w3ccheckoutput/result/messages/msg">
                <div>
                  Line: <xsl:value-of select="format-number(@line, '###')"/>,
                  Column: <xsl:value-of select="format-number(@col, '###')"/>:
                  <xsl:value-of select="."/>
                </div>
              </xsl:for-each>
            </div>
          </xsl:if>
          <div><button onclick="javascript:window.close()">Close window</button></div>
        </div>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="/validation/status">
    <div>
      <label>Result:</label>
      <xsl:value-of select="."/>
    </div>
  </xsl:template>

  <xsl:template match="/validation/errorcount">
    <div>
      <label>Number of errors found:</label>
      <xsl:value-of select="."/>
    </div>
  </xsl:template>

</xsl:stylesheet>
