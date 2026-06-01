# Clinix Report — PlantUML Diagram Sources

This folder contains the PlantUML source for every diagram referenced
in the Clinix BTech report, plus a few extras that strengthen the
methodology and implementation chapters.

## File index

| # | File                              | Diagram                                       | Used in       |
|---|-----------------------------------|-----------------------------------------------|---------------|
| 01 | `01_dfd_level0.puml`             | DFD Level 0 — Context Diagram                 | Fig 3.0       |
| 02 | `02_dfd_level1.puml`             | DFD Level 1                                   | Fig 3.1       |
| 03 | `03_usecase.puml`                | Use Case Diagram                              | Fig 3.2       |
| 04 | `04_activity_main.puml`          | Activity Diagram (main user flow)             | Fig 3.3       |
| 05 | `05_class_diagram.puml`          | Class Diagram                                 | Fig 3.4       |
| 06 | `06_sequence_consultation.puml`  | Sequence Diagram — patient consultation       | Fig 3.5       |
| 07 | `07_system_architecture.puml`    | System Architecture (3-tier component view)   | Fig 3.6       |
| 08 | `08_database_architecture.puml`  | Database Architecture                         | Fig 3.7       |
| 09 | `09_er_diagram.puml`             | Entity-Relationship Diagram                   | Fig 3.9       |
| 10 | `10_ai_provider_recommendation.puml` | AI Provider Recommendation Architecture   | Fig 3.10      |
| 11 | `11_state_appointment.puml`      | State Diagram — Appointment lifecycle         | (extra) Ch. 4 |
| 12 | `12_state_verification.puml`     | State Diagram — Provider verification         | (extra) Ch. 4 |
| 13 | `13_state_payment.puml`          | State Diagram — Payment lifecycle             | (extra) Ch. 4 |
| 14 | `14_deployment.puml`             | Deployment Diagram                            | (extra) Ch. 4 |
| 15 | `15_sequence_payment.puml`       | Sequence Diagram — CamPay payment             | (extra) Ch. 4 |
| 16 | `16_sequence_ai_scribe.puml`     | Sequence Diagram — AI scribe pipeline         | (extra) Ch. 4 |
| 17 | `17_activity_ai_consultation.puml`| Activity Diagram — AI consultation flow      | (extra) Ch. 4 |

Diagrams 11–17 are not yet referenced in the LaTeX. They are provided
because a BTech examiner usually expects state diagrams for important
lifecycles (appointment, verification, payment) and at least one
deployment diagram. To use any of them, render it to PNG and add an
`\includegraphics` + `\caption` block in Chapter 4 (or in a new
section in Chapter 3).

## How to render the `.puml` files to PNG/SVG

Pick **one** of the following options.

### Option 1 — VS Code (recommended for local work)

1. Install the **PlantUML** extension by jebbs in VS Code.
2. Install **Java 8+** (PlantUML needs it).
3. Optionally install **Graphviz** for the diagrams that need it
   (class, deployment). On Windows: download from
   <https://graphviz.org/download/> and add the `bin` folder to PATH.
4. Open any `.puml` file → press `Alt+D` to live-preview, or
   right-click → `Export Current Diagram` → choose PNG/SVG/PDF.

### Option 2 — Online (no install)

1. Open <https://www.plantuml.com/plantuml/uml> or
   <https://www.planttext.com>.
2. Paste the contents of the `.puml` file.
3. The page renders the PNG live; click **PNG / SVG** to download.

### Option 3 — Command line (for batch rendering)

Download `plantuml.jar` from <https://plantuml.com/download> and run:

```powershell
# PowerShell, from the report/figures/plantuml folder
java -jar plantuml.jar -tpng *.puml
# or for high-quality SVG:
java -jar plantuml.jar -tsvg *.puml
```

This produces one image per `.puml` file in the same folder.

### Option 4 — Overleaf (built-in)

Overleaf has a PlantUML compiler if you enable the `plantuml` package
in `main.tex`. The simpler route is still to render to PNG locally
and upload the PNGs.

## Embedding the rendered images in LaTeX

In each chapter, replace the existing placeholder

```latex
\fbox{\parbox{0.8\textwidth}{\centering \vspace{2cm}
  \textit{[Insert Figure 3.0: DFD Level 0 — Context Diagram]}
  \vspace{2cm}}}
```

with the actual image, for example:

```latex
\includegraphics[width=0.85\textwidth]{figures/dfd_level0.png}
```

Keep the `\caption{...}` and `\label{...}` lines that already wrap the
figure — that way every `\ref{fig:dfd0}` in the body keeps working.

## Suggested rendered-image filenames (to drop into `figures/`)

| Source `.puml` | Suggested rendered name        |
|----------------|--------------------------------|
| 01             | `figures/dfd_level0.png`       |
| 02             | `figures/dfd_level1.png`       |
| 03             | `figures/usecase.png`          |
| 04             | `figures/activity_main.png`    |
| 05             | `figures/class_diagram.png`    |
| 06             | `figures/sequence_consultation.png` |
| 07             | `figures/system_arch.png`      |
| 08             | `figures/db_arch.png`          |
| 09             | `figures/er_diagram.png`       |
| 10             | `figures/ai_provider_recommendation.png` |
| 11             | `figures/state_appointment.png` |
| 12             | `figures/state_verification.png` |
| 13             | `figures/state_payment.png`    |
| 14             | `figures/deployment.png`       |
| 15             | `figures/sequence_payment.png` |
| 16             | `figures/sequence_ai_scribe.png` |
| 17             | `figures/activity_ai_consultation.png` |

## Troubleshooting

- **"Graphviz not found"** — install Graphviz and add it to PATH.
  Only the class diagram and deployment diagram strictly need it.
- **Fonts look wrong** — the `.puml` files declare `Inter, Helvetica`.
  If neither is installed, PlantUML falls back to a serif font, which
  is fine for printing. To force a clean sans-serif look, install the
  free **Inter** font from <https://fonts.google.com/specimen/Inter>.
- **Diagram too big for one page** — switch to SVG, or split the
  diagram into two `.puml` files (e.g. patient-side and provider-side
  use cases).
- **Colours are too pale on a printed page** — open the rendered PNG
  and either bump the contrast in any image editor, or change the
  `BackgroundColor` lines in the `.puml` (e.g. `#EAF2F9` → `#D0DEEC`).
