# References — Standards Governing color-mojo

> **Version:** 0.1.0 | **Updated:** 2026-07-02

Vendored and linked specifications for every byte this library emits or parses, with the design consequences drawn from each.

---

| #   | Section                                             |
| --- | --------------------------------------------------- |
| 1   | [Overview](#overview)                               |
| 2   | [Vendored RFCs](#vendored-rfcs)                     |
| 3   | [External Specifications](#external-specifications) |
| 4   | [Design Consequences](#design-consequences)         |
| 5   | [Provenance](#provenance)                           |

---

## Overview

This folder holds the primary sources behind color-mojo's design decisions.

| Source class            | Policy               | Rationale                                        |
| ----------------------- | -------------------- | ------------------------------------------------ |
| IETF RFC texts          | Vendored verbatim    | Small, immutable, license permits redistribution |
| Non-IETF specifications | Linked, not vendored | Heavyweight PDFs, murkier redistribution terms   |

Cite entries from this index in module headers rather than restating spec text.

---

## Vendored RFCs

| File          | Specification                           | Status        | Governs in color-mojo                                                          |
| ------------- | --------------------------------------- | ------------- | ------------------------------------------------------------------------------ |
| `rfc20.txt`   | ASCII Format for Network Interchange    | STD 80        | `ESC` (`0x1B`), `BEL` (`0x07`), and the full byte alphabet of SGR sequences    |
| `rfc1091.txt` | Telnet Terminal-Type Option             | Proposed Std  | Lineage and registry culture of terminal identities that appear in `TERM`      |
| `rfc1468.txt` | ISO-2022-JP Japanese Character Encoding | Informational | Real-world three-byte `ESC` sequences (`ESC ( B`, `ESC $ B`) `strip` must skip |
| `rfc1572.txt` | Telnet Environment Option               | Proposed Std  | Standard propagation of `TERM` across connections; precedence philosophy       |
| `rfc3629.txt` | UTF-8, a Transformation Format          | STD 63        | Octet structure behind `visible_width` and the escape scanner's safety         |
| `rfc5198.txt` | Unicode Format for Network Interchange  | Proposed Std  | C0/C1 rules for interchange text; basis for capability gating                  |

---

## External Specifications

| Specification             | Authority          | Governs                                                                                                                                | Link                                                                           |
| ------------------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| ECMA-48, 5th edition      | Ecma International | CSI grammar (params `0x30`–`0x3F`, intermediates `0x20`–`0x2F`, final `0x40`–`0x7E`); core SGR codes; §5.6 command strings ending at ST | <https://ecma-international.org/publications-and-standards/standards/ecma-48/> |
| ITU-T T.416 / ISO 8613-6  | ITU-T              | Extended color model behind `38;5;n` / `38;2;r;g;b` — strict T.416 spells them with colon sub-parameters; semicolons are the de-facto encoding | <https://www.itu.int/rec/T-REC-T.416>                                          |
| XTerm Control Sequences   | Thomas E. Dickey   | De-facto 256-color palette layout; OSC termination by `BEL` or `ST`; aixterm bright codes 90–97 / 100–107; semicolon extended-color forms | <https://invisible-island.net/xterm/ctlseqs/ctlseqs.html>                      |
| NO_COLOR                  | Community          | `NO_COLOR` present and non-empty means no color, highest precedence                                                                    | <https://no-color.org>                                                         |
| CLICOLOR / CLICOLOR_FORCE | Community          | `CLICOLOR=0` disables; `CLICOLOR_FORCE` forces — honored alongside `FORCE_COLOR` (`0`/`false` disable; `1`/`2`/`3` floor the tier)     | <https://bixense.com/clicolors/>                                               |
| UAX #11 East Asian Width  | Unicode Consortium | Wide-glyph column width — a declared non-goal for this library                                                                         | <https://www.unicode.org/reports/tr11/>                                        |
| PNG (RFC 2083, Historic)  | IETF               | RGB/RGBA/gamma context; cited but not vendored (102 pages)                                                                             | <https://www.rfc-editor.org/rfc/rfc2083.txt>                                   |

---

## Design Consequences

| #   | Finding                                                                    | Source                | Consequence in color-mojo                                                                                      |
| --- | -------------------------------------------------------------------------- | --------------------- | -------------------------------------------------------------------------------------------------------------- |
| 1   | ASCII octet values never occur inside UTF-8 multi-byte sequences           | RFC 3629 §1           | Byte-wise scan for `0x1B` cannot false-positive; the SIMD scanner is sound                                     |
| 2   | Continuation octets match `10xxxxxx` (`0x80`–`0xBF`)                       | RFC 3629 §3           | `visible_width` counts code points via bytes where `(b & 0xC0) != 0x80`                                        |
| 3   | C1 controls (`0x80`–`0x9F`) MUST NOT appear in network text                | RFC 5198 §2           | Emit 7-bit `ESC [` forms only; `strip` deliberately ignores single-byte CSI `0x9B`                             |
| 4   | C0 controls SHOULD be avoided in interchange text                          | RFC 5198 §2           | Capability gating is spec compliance: no escapes to non-terminal destinations                                  |
| 5   | `ESC` prefixes "a limited number of contiguously following characters"     | RFC 20 §5.2           | `strip` implements the general ESC-sequence grammar, not a CSI-only special case                               |
| 6   | Charset shifts use `ESC` + intermediate + final; escapes occupy no columns | RFC 1468              | Three-byte sequences are real-world input; escapes are zero-width by precedent                                 |
| 7   | Terminal color carries `r;g;b` only; alpha exists only in file formats     | ITU-T T.416, RFC 2083 | `Color` has no alpha field; RGBA input must be pre-composited by the caller                                    |
| 8   | Faithful color reproduction requires gamma and chromaticity management     | RFC 2083              | Quantization is nearest-match in nominal sRGB space — a heuristic, not colorimetry                             |
| 9   | `TERM` is the conveyed terminal identity; better signals may override it   | RFC 1091, RFC 1572 §6 | Pure resolution ladder (`ColorLevel.resolve`, signals supplied by the application — the library never reads the environment): `no_color` > `force_color` `0`/`false` disable > force flags > `clicolor=0` > TTY > `term=dumb` veto > numeric `force_color` floors > `colorterm` > `term` |
| 10  | Command strings (OSC, DCS, SOS, PM, APC) run to ST; only OSC ends at BEL   | ECMA-48 §5.6; ctlseqs | `strip_escapes` consumes string payloads exactly as a terminal does; BEL stays payload outside OSC             |

---

## Provenance

| Item       | Detail                                           |
| ---------- | ------------------------------------------------ |
| Source     | RFC Editor's canonical plain-text archive        |
| Downloaded | 2026-07-02                                       |
| License    | IETF Trust license permits verbatim reproduction |

Re-fetch at any time:

```bash
for n in 20 1091 1468 1572 3629 5198; do
    curl -fsSL "https://www.rfc-editor.org/rfc/rfc${n}.txt" -o "rfc${n}.txt"
done
```
