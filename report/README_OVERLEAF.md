# Clinix BTech Project Report — Overleaf Setup

This folder contains a complete multi-file LaTeX project for the
**Clinix: A Mobile Health Care Platform** BTech report, following the
University of Buea, College of Technology template.

## Folder layout

```
report/
├── main.tex                       # Entry point — compile this
├── refs.bib                       # Bibliography (BibTeX)
├── README_OVERLEAF.md              # This file
├── chapters/
│   ├── front_matter.tex            # Title page, certification, attestation, dedication, acknowledgements
│   ├── abstract.tex                # Abstract + keywords
│   ├── abbreviations.tex           # List of abbreviations
│   ├── chapter1_introduction.tex   # CHAPTER I — General Introduction
│   ├── chapter2_literature.tex     # CHAPTER II — Literature Review
│   ├── chapter3_methodology.tex    # CHAPTER III — Materials & Methods
│   ├── chapter4_implementation.tex # CHAPTER IV — Implementation, Results & Testing
│   └── chapter5_conclusion.tex     # CHAPTER V — Conclusion & Future Work
└── figures/                        # Drop your diagrams and screenshots here
```

## Uploading to Overleaf

1. **Zip the folder.** On Windows, right-click `report/` → *Send to* →
   *Compressed (zipped) folder*. Make sure `main.tex` is in the **root**
   of the zip, not inside an extra folder.
2. Open <https://www.overleaf.com>, log in, click **New Project →
   Upload Project**, and drop in the zip.
3. In the Overleaf project, open **Menu (top-left) → Settings** and set:
   - **Compiler:** `pdfLaTeX`
   - **Main document:** `main.tex`
   - **TeX Live version:** the latest available
4. Click **Recompile**. The first compile may take ~30 seconds because
   Overleaf builds the table of contents and runs BibTeX.

## Adding the figures

Chapter 3 references 10+ diagrams using `\fbox{...}` placeholders that
say *"[Insert Figure 3.x: ...]"*. To replace each placeholder with a
real figure:

1. Export each diagram to PNG or PDF.
2. Upload it into the `figures/` folder in Overleaf (drag-and-drop).
3. In the relevant chapter, replace this block:
   ```latex
   \fbox{\parbox{0.8\textwidth}{\centering \vspace{2cm} \textit{[Insert Figure 3.0: ...]} \vspace{2cm}}}
   ```
   with:
   ```latex
   \includegraphics[width=0.8\textwidth]{figures/dfd_level0.png}
   ```

### Recommended figure names

| Figure                          | Suggested filename               |
|---------------------------------|----------------------------------|
| DFD Level 0                     | `figures/dfd_level0.png`         |
| DFD Level 1                     | `figures/dfd_level1.png`         |
| Use Case Diagram                | `figures/usecase.png`            |
| Activity Diagram                | `figures/activity.png`           |
| Class Diagram                   | `figures/class_diagram.png`      |
| Sequence Diagram                | `figures/sequence_diagram.png`   |
| System Architecture             | `figures/system_arch.png`        |
| Database Architecture           | `figures/db_arch.png`            |
| Mobile App Design 1             | `figures/mobile_ui_1.png`        |
| Mobile App Design 2             | `figures/mobile_ui_2.png`        |
| ER Diagram                      | `figures/er_diagram.png`         |
| AI Provider Recommendation     | `figures/ai_provider_recommendation.png` |

You can keep the same `\label{...}` keys (`fig:dfd0`, `fig:dfd1`, etc.)
so cross-references continue to resolve.

## Adding the university logos

The title page in `chapters/front_matter.tex` has two commented lines:

```latex
% \includegraphics[width=0.18\textwidth]{figures/ub_logo.png}\hspace{2cm}
% \includegraphics[width=0.18\textwidth]{figures/cot_logo.png}
```

Uncomment them once you have uploaded `ub_logo.png` (University of Buea)
and `cot_logo.png` (College of Technology) into `figures/`.

## Filling in the dedication

`chapters/front_matter.tex` has a one-line placeholder dedication
inside `\textit{...}`. Replace it with your personal dedication.

## Filling in signature dates

The certification page leaves `Date: ___` blank for both supervisors;
attestation does the same for the candidate. Fill these manually before
printing.

## Citing references

The bibliography in `refs.bib` already contains entries for Django, DRF,
Channels, Celery, Flutter, Riverpod, Agora, Firebase, Gemini, CamPay,
PostgreSQL, Redis, React, Vite, TanStack Query, the WHO mHealth report,
the Cameroon cybersecurity law, the Scrum Guide, Nielsen's heuristics,
and the OWASP Top Ten. Cite any of them in the body with `\cite{key}`,
for example:

```latex
The backend follows the Django REST Framework conventions
\cite{drf_docs}.
```

Run **Recompile** after adding a citation so BibTeX rebuilds the
reference list.

## Troubleshooting

- **Bibliography is empty.** Make sure you have at least one `\cite{...}`
  in the body, then recompile twice.
- **`mathptmx` not found.** This package is included in standard TeX
  Live and ships with Overleaf by default.
- **Special characters look broken.** Save all files as UTF-8 (Overleaf
  does this by default).
- **`\input{}` cannot find a chapter.** Confirm the file is inside
  `chapters/` and the name matches exactly (Overleaf is case-sensitive
  on the server).
