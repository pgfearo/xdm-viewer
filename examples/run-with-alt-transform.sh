#!/usr/bin/env bash
# Runs a stylesheet through the DeltaXML AltTransform wrapper (the class
# the xslt-xpath VS Code extension uses for xsl:message) against a chosen
# Saxon jar and a chosen build of alt-saxon-xslt-cli - for testing
# xdm-viewer's ANSI text output against different Saxon versions without
# going through the VS Code extension/task.
#
# Usage:
#   SAXON_JAR=/path/to/saxon-he-13.0.jar \
#   ALT_CLASSES=/path/to/alt-saxon-xslt-cli/target/classes \
#     examples/run-with-alt-transform.sh [stylesheet.xsl]
#
# stylesheet.xsl defaults to examples/demo.xsl.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XSL="${1:-$SCRIPT_DIR/demo.xsl}"

: "${SAXON_JAR:?Set SAXON_JAR to the Saxon jar to test against, e.g. SAXON_JAR=/path/to/saxon-he-13.0.jar}"
: "${ALT_CLASSES:?Set ALT_CLASSES to the alt-saxon-xslt-cli compiled classes dir, e.g. ALT_CLASSES=/path/to/alt-saxon-xslt-cli/target/classes}"

OUT_DIR="$SCRIPT_DIR/out"
mkdir -p "$OUT_DIR"

java -cp "$ALT_CLASSES:$SAXON_JAR" \
  com.deltaxml.saxon.perf.AltTransform \
  -xsl:"$XSL" \
  -s:"$XSL" \
  -it \
  -o:"$OUT_DIR/empty.xml" \
  --allowSyntaxExtensions:off
