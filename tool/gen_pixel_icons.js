/*
 * Generator: turns the Claude Design handoff "Bun Pixel Icons.dc.html" into a
 * Dart data file (lib/core/widgets/pixel_icons_data.dart).
 *
 * The design draws every icon on a 16x16 grid with a tiny drawing DSL. We reuse
 * that exact JS (extracted from the <script> in the HTML) so the Dart output is
 * pixel-identical to the mock — no hand-transcribing 100+ icons.
 *
 * Run:  node tool/gen_pixel_icons.js
 */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(__dirname, 'bun_pixel_icons.dc.html');
// NOTE: not named *.g.dart — that pattern is gitignored (build_runner output).
// This file is committed, so it must keep a plain .dart name.
const OUT = path.join(ROOT, 'lib/core/widgets/pixel_icons_data.dart');

const html = fs.readFileSync(SRC, 'utf8');
const m = html.match(/data-dc-script[^>]*>([\s\S]*?)<\/script>/);
if (!m) throw new Error('Could not find the <script type="text/x-dc"> block.');

// The class only needs the drawing primitives, the art* methods, defs(),
// encode() and toARGB(). It extends a framework base + references window in
// methods we never call; strip the base class and eval the rest. Method bodies
// that touch globals are never invoked, so parsing them is harmless.
let cls = m[1].replace('extends DCLogic', '');
const Klass = new Function('return (' + cls + ')')();
const c = new Klass();

function accentToHex(accent) {
  // accent is a pal() value like '#C77E5E' (6-hex RGB) -> 'FFC77E5E'.
  const h = String(accent).replace('#', '').toUpperCase();
  if (h.length === 6) return 'FF' + h;
  if (h.length === 8) return h; // already ARGB-ish
  return 'FF7A736B';
}

function colorLiteral(hex) {
  // hex is a palette entry like '#C77E5E' or '#00000000'.
  if (hex === '#00000000') return 'Color(0x00000000)';
  const argb = c.toARGB(hex); // returns '0xFFRRGGBB' / '0x00000000'
  return 'Color(' + argb + ')';
}

const defs = c.defs();
const glyphLines = [];
const catalogLines = [];

for (const d of defs) {
  const g = c.newG(16);
  c[d.art](g);
  const exp = c.encode(g); // { palette: ['#00000000', '#...', ...], data: [[idx,...] x16] }

  const palette = exp.palette.map(colorLiteral).join(', ');
  const rows = exp.data
    .map((r) => '      [' + r.join(',') + '],')
    .join('\n');

  glyphLines.push(
    "  '" + d.id + "': PixelGlyph(\n" +
    '    palette: [' + palette + '],\n' +
    '    pixels: [\n' + rows + '\n    ],\n' +
    '  ),'
  );

  const th = d.th.replace(/'/g, "\\'");
  const en = d.en.replace(/'/g, "\\'");
  catalogLines.push(
    "  PixelIconInfo(id: '" + d.id + "', nameTh: '" + th + "', nameEn: '" + en +
    "', colorHex: '" + accentToHex(d.accent) + "', income: " + (d.type === 'income') + '),'
  );
}

const out =
`// GENERATED FILE — do not edit by hand.
// Source: tool/bun_pixel_icons.dc.html (Claude Design handoff "Bun Pixel Icons").
// Regenerate: node tool/gen_pixel_icons.js
//
// ${defs.length} pixel-art glyphs (16x16). Each PixelGlyph holds an ARGB palette
// (index 0 is transparent) and a 16-row index grid; PixelIconPainter renders it.
import 'dart:ui' show Color;

import 'pixel_icon.dart';

/// 16x16 pixel-art glyphs keyed by icon id (used as a category's iconKey).
const Map<String, PixelGlyph> kPixelGlyphs = {
${glyphLines.join('\n')}
};

/// Full catalogue (name + accent colour + income flag) for the icon picker and
/// the category seed. Order matches the design's \`defs()\`.
const List<PixelIconInfo> kPixelIconCatalog = [
${catalogLines.join('\n')}
];
`;

fs.writeFileSync(OUT, out);
const expense = defs.filter((d) => d.type !== 'income').length;
const income = defs.length - expense;
console.log('Wrote ' + OUT);
console.log('Icons: ' + defs.length + ' total (' + expense + ' expense, ' + income + ' income)');
