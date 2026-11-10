---
name: Misma app, dos resultados distintos
description: A PyCon Chile 2026 talk deck dressed as a Chilean supermarket package front, ALTO EN seals and a nutrition-facts table.
colors:
  ink: "#111111"
  paper: "#ffffff"
  loss: "#c8102e"
  panel: "#f1f1f1"
  ghost: "#c9c9c9"
  ghost-ink: "#767676"
typography:
  display:
    fontFamily: "'Archivo Variable', 'Arial Narrow', sans-serif"
    fontSize: "88px"
    fontWeight: 900
    lineHeight: 0.94
    letterSpacing: "-0.005em"
    fontVariation: "'wdth' 72"
  headline:
    fontFamily: "'Archivo Variable', 'Arial Narrow', sans-serif"
    fontSize: "64px"
    fontWeight: 900
    lineHeight: 0.94
    letterSpacing: "-0.005em"
    fontVariation: "'wdth' 72"
  title:
    fontFamily: "'Archivo Variable', 'Arial Narrow', sans-serif"
    fontSize: "34px"
    fontWeight: 900
    lineHeight: 1
    fontVariation: "'wdth' 75"
  lede:
    fontFamily: "'Archivo Variable', 'Helvetica Neue', sans-serif"
    fontSize: "26px"
    fontWeight: 600
    lineHeight: 1.35
  body:
    fontFamily: "'Archivo Variable', 'Helvetica Neue', sans-serif"
    fontSize: "24px"
    fontWeight: 450
    lineHeight: 1.35
  label:
    fontFamily: "'Archivo Variable', 'Helvetica Neue', sans-serif"
    fontSize: "15px"
    fontWeight: 800
    lineHeight: 1.3
  figure:
    fontFamily: "'JetBrains Mono Variable', ui-monospace, monospace"
    fontSize: "18px"
    fontWeight: 600
    lineHeight: 1.5
    fontFeature: "'tnum'"
rounded:
  none: "0px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "18px"
  lg: "28px"
  xl: "48px"
  slide-y: "52px"
  slide-x: "64px"
components:
  seal:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    size: "200px"
  seal-ghost:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ghost-ink}"
    size: "200px"
  tabla:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.none}"
    padding: "14px 18px 12px"
  tabla-value-loss:
    textColor: "{colors.loss}"
    typography: "{typography.figure}"
  origen:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.none}"
    padding: "3px 8px"
  code-panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.ink}"
    rounded: "{rounded.none}"
    padding: "14px 18px"
  code-inline:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.ink}"
    padding: "1px 6px"
  qr-slot:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.none}"
---

# Design System: Misma app, dos resultados distintos

## Overview

**Creative North Star: "The Package Front"**

Every slide is the front of a supermarket package under Chile's food-labeling law. The bad deployment earns heavy black ALTO EN octagons, each one triggered by a threshold stated on screen; the good deployment earns none. The nutrition-facts table, with its thick and thin black rules and tabular figures, carries the measurements. The world is white packaging stock, black ink, and one red that appears only where an order was lost or charged without confirmation.

Density is that of a label: condensed, heavy headlines set close; a short body line; numbers set in mono and aligned. Everything is square-cornered and flat. Hierarchy comes from rule weight and type width, not from color, shadow or boxes. The deck refuses the dark, code-forward tech deck with a title top-left and bullets: code appears, but on a pale panel inside a printed frame, as one more ingredient list.

Open item: the arena screens (`arena/static/*.html`) still carry an older, unrelated look and are to be restyled into this world. Nothing in this document describes their current appearance.

**Key Characteristics:**
- Black octagonal seals with a thin white keyline and condensed white caps.
- Nutrition-facts rules: 12px heavy bar, 4–6px medium rule, 1px hairline.
- One reserved red, used only for lost or charged orders.
- Archivo Variable on its condensed width axis for display; JetBrains Mono for code and measured values.
- Every figure carries a boxed source chip.
- Square corners everywhere; the octagon is the only non-rectangular silhouette.

## Colors

A printed two-ink label: black on white, with a single red held in reserve.

### Primary
- **Label Ink** (ink): every headline, seal body, table rule, frame, chart line and bar. The deck's only structural color.

### Secondary
- **Loss Red** (loss): a measured A value that represents lost or charged-without-confirmation orders, in the Tabla value column and nowhere else.

### Neutral
- **Packaging White** (paper): the slide ground, the seal keyline and seal lettering, the QR light modules.
- **Code Panel Grey** (panel): background of code blocks and inline code only.
- **Withdrawn Grey** (ghost): the dashed outline of a removed seal and chart gridlines.
- **Withdrawn Ink** (ghost-ink): the lettering of a removed seal.

### Named Rules
**The Reserved Red Rule.** Loss Red marks orders that were lost or charged without confirmation. It is never a warning, emphasis, link, or brand color.

**The Withdrawn Grey Rule.** Grey as a text or ink color means a seal has been removed. Ordinary de-emphasis is done with weight (a line drops to 500 from its 700), never with grey text.

## Typography

**Display Font:** Archivo Variable, condensed through the `wdth` axis (with Arial Narrow)
**Body Font:** Archivo Variable at normal width (with Helvetica Neue)
**Label/Mono Font:** JetBrains Mono Variable (with ui-monospace)

**Character:** One family pulled two ways: Archivo squeezed to 70–78% width at weight 900 reads like the seal and the label's product name; at full width and weight 450 it reads like the ingredient text. Mono is the scale's printout.

### Hierarchy
- **Display** (900, 88px, 0.94, wdth 72): cover and close titles, balanced over two lines.
- **Headline** (900, 64px, 0.94, wdth 72): the one headline per content slide.
- **Title** (900, 34px, 1, wdth 75): table captions, rule-list terms, step counters, ingredient-list headings (set in caps there, 26–30px).
- **Lede** (600, 26px): the subtitle under a display title and the main consequence lines beside evidence.
- **Body** (450, 24px, 1.35): running text, max 34em, `text-wrap: pretty`. Bold is 800.
- **Label** (800, 15px): table column heads, table unit line. Source text (chips, table origin line) uses the Label role at weight 600.
- **Figure** (mono 600, 18px, tabular): table values and code. Inline measured numbers in prose use mono 700 tabular.

### Named Rules
**The Measured-In-Mono Rule.** A number that is a measurement is set in JetBrains Mono with tabular figures. Headline numbers and display figures may stay in condensed Archivo.

**The Width-Is-Weight Rule.** Display hierarchy is made with the width axis and weight 900, not with size jumps alone: wider and lighter is text, narrower and heavier is the label's voice.

## Layout

A 1280×720 canvas with 52px top/bottom and 64px side margins. Two recurring frames:

- **Package front** (cover and close): a two-column grid, flexible left and a fixed 410px right column with a 48px gutter. Left stacks title, seal row and an event line; the right column holds the Tabla with the QR beneath it where a barcode would go.
- **Bands** (content slides): three rows, headline, evidence, footer, with a 28px gap. The evidence row is a flex row with a 40px gap, usually two equal halves; the footer holds source chips.
- **Demo** slides put a 380px QR beside a 104px headline.

Spacing steps cluster at 8, 12, 18, 28 and 48px; seals in a row sit 16–22px apart.

## Elevation & Depth

None. The system is completely flat: no shadows, no tonal layering beyond the code panel's grey. Depth and grouping come from printed rules and frames, as on a package.

### Named Rules
**The Printed-Flat Rule.** If it could not be printed in one pass of black ink on carton, it doesn't belong.

## Shapes

Square corners throughout (0px). Frames are solid ink strokes: 3px around the Tabla and the QR, 2px around code panels, 1.5px around source chips. Inside tables and lists the nutrition-facts rule vocabulary applies: a 12px bar opens a block, 4–6px rules close a block or separate the head, 1px hairlines separate rows. The octagon (a regular eight-sided figure, flat top) is reserved for seals and for version A's data points in charts.

## Components

### Seal (signature)
The ALTO EN octagon. Ink body, a 3px paper keyline inset 8 units in a 200-unit box, three stacked lines in paper caps at wdth 72: "ALTO EN" (800, 1.5em), the word (900, 1.9em, shrinks for words over seven letters), and a small foot naming where it was measured (600, 0.6em, min 10px, letter-spacing .08em). Type scales with the seal: the base em is size ÷ 10. Sizes in use: 120–190px.
- **Ghost (withdrawn):** paper body with a 3px dashed Withdrawn Grey outline, no keyline, Withdrawn Ink lettering, the word struck through with a 3px line.
- **Stamp motion:** when revealed, a seal presses down from scale 1.45 and −7° to rest in 280ms on `cubic-bezier(.16, 1, .3, 1)`; opacity fades in over 120ms. Other reveals are a plain 220ms opacity fade.

### Tabla (nutrition facts)
A 3px ink frame on paper, 14px 18px 12px padding. Title in the Title role, a 15px unit line, a 12px bar, a 4px rule under the A/B column heads, 1px row hairlines, a 4px closing rule, then a small source line. Row labels are Archivo 700 18px left; values are mono 600 18px right, tabular. Sub-rows indent 16px at weight 500. A loss value turns Loss Red.

### Source chip (Origen)
A 1.5px ink box with 3px 8px padding and one line of 600-weight small text naming where a number came from. Sits in the slide footer; one chip per source.

### QR barcode slot
The QR drawn as crisp ink modules on paper inside a 3px ink outline, with an optional condensed-caps caption (Title family, 24px) and the URL in small mono.

### Code panel
Code blocks sit on Code Panel Grey inside a 2px ink frame, 14px 18px padding, mono 18px/1.5. Inline code is the same grey with 1px 6px padding; inside headings, ingredient lists and the summary table it drops the panel and goes bold.

### Rule list, ingredient list, preparation steps
Label-section patterns built from the rule vocabulary. Rule lists (`dl`) put a condensed caps term in a 300px column beside its definition, 6px rules top and bottom, 1px between. Ingredient lists open with a 12px bar and a condensed caps heading. Preparation steps open with a 12px bar, close with 4px, and number each step with a 34px condensed counter.

### Ramp chart
Ink lines on paper, 1px Withdrawn Grey gridlines. Version A is dashed with filled octagon markers; version B is solid with open circles. A dotted ink diagonal marks "what was requested". Series are labeled directly at their ends in condensed 900, no legend.

## Do's and Don'ts

### Do:
- **Do** give every on-screen measurement a source chip in the footer.
- **Do** state the threshold that earns a seal on the same screen as the seal.
- **Do** separate and group with the nutrition-facts rules (12px, 4–6px, 1px) instead of boxes, fills or space alone.
- **Do** set measured values in mono with tabular figures, right-aligned in tables.
- **Do** mark version A with octagons and version B with plain or open forms when both appear in one figure.

### Don't:
- **Don't** use Loss Red for anything other than lost or charged orders.
- **Don't** use grey text to de-emphasize; use weight 500.
- **Don't** round corners or add shadows.
- **Don't** use the octagon for anything but seals and version A's data.
- **Don't** put kickers or eyebrow labels above headlines; small caps live inside seals and tables, never as a headline's preface.
- **Don't** build the dark, code-forward tech deck: no dark slides, no bulleted lists; lists are ruled, and numbered when sequential.
