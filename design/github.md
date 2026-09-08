repo: jonyardley/intrada
branch: main
path: design/, docs/, specs/, ios/Intrada/

## Last sync
date: 2026-09-07T22:32:03Z

### Updated in this project
- Designed `One Pass Create.dc.html`, the add-a-piece form carrying a chord chart and staged exercises in one save (#1390), against `specs/one-pass-create.md` and T21.
- Ruled the collapsed rows as nouns ("Chord chart", "Related exercises"), silent when collapsed; the tone doc's one caption is spent on expansion, matching the piece detail card's words.
- Staged chart shows the text verbatim (monospaced, three lines, fade), with no bar count or bar grid, since the chart is only parsed on Add.
- Error model: the scaffold's banner keeps the sentence, the offending row carries the pointer; one error slot means only one row is ever marked.
- Named for fold-in if it wins: FormSectionRow, StagedChartCard, DraftItemRow, DraftExerciseSheet; no new Theme.swift tokens (one candidate: `IntradaFont.chart`).

## Screen map
| Project screen | Repo source |
|---|---|
| One Pass Create.dc.html | specs/one-pass-create.md, docs/design-principles.md (T21, T18), ios/Intrada/Views/Screens/{ItemFormScaffold,ItemFormModel,LibraryAddScreen,LibraryDetailScreen}.swift, ios/Intrada/Views/Components/{ScanPageEntry,ChordChartEditSheet,LinkedItemPickerSheet,FormField,AddRowButton}.swift, ios/Intrada/DesignSystem/{Theme,FieldMark}.swift |
| Drill Loop.dc.html, A2/A3 | design/briefs/2026-08-coach-drill-loop.md, specs/intrada-practice-coach-design.md (v7, decisions 18 and 19) |
| Intrada Design System.dc.html | design/intrada-design-system.dc.html, ios/Intrada/DesignSystem/Theme.swift |

## Sync history
### 2026-08-04T07:00:03Z
- Rebuilt `Drill Loop.dc.html` A2/A3 around spec v7 / decision 18 (machine listening deferred): A3 uses the tap-verdict pattern; dropped the "unsure" variant; added the "no microphone yet" note; resolved the RepCounter/GateDots collision (cumulative gate counting per decision 17).
