"""Rebalance the JTM manuscript after adding BRCA and CHOL coverage.

This is a text-only edit of the current submission draft. It leaves the
analyses, figures, tables and numerical estimates unchanged.
"""

from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH


FOLDER = Path("/Users/stefano/Desktop/JTM")
MAIN_IN = FOLDER / "manuscript_JTM.docx"
MAIN_OUT = FOLDER / "manuscript_JTM_balanced.docx"
COVER_IN = FOLDER / "cover_letter_JTM.docx"
COVER_OUT = FOLDER / "cover_letter_JTM_balanced.docx"


def find(document, beginning):
    matches = [p for p in document.paragraphs if p.text.startswith(beginning)]
    if len(matches) != 1:
        raise ValueError(f"Expected one paragraph beginning {beginning!r}; found {len(matches)}")
    return matches[0]


def replace(document, beginning, new_text):
    paragraph = find(document, beginning)
    if len(paragraph.runs) == 1:
        paragraph.runs[0].text = new_text
    else:
        paragraph.text = new_text


main = Document(MAIN_IN)
replace(
    main,
    "Background. Haematoxylin",
    "Background. Haematoxylin-and-eosin (H&E) slides show tissue patterns "
    "associated with tumour genetics and immune activity. We examined which "
    "cancer-specific features can be estimated from published slide "
    "representations and whether TITAN, Giga-SSL and Prov-GigaPath capture "
    "the same associations.",
)
replace(
    main,
    "Methods. We analysed",
    "Methods. We compared the three slide representations on identical slides "
    "from 8,241 patients, testing 3,389 cancer-feature combinations in 30 "
    "TCGA cancers. We also analysed two cancers that could not enter the "
    "matched three-way comparison, bringing the atlas to 32 cancers. Separate "
    "models were trained for each feature within each cancer. Patient-level "
    "nested cross-validation measured continuous outcomes by held-out Q² and "
    "binary outcomes by area under the receiver operating characteristic "
    "curve (AUROC).",
)
replace(
    main,
    "Results. At least one available",
    "Results. The slide representations captured signals for driver mutations, "
    "microsatellite instability, called gene fusions, genome doubling and "
    "selected RNA- and methylation-derived immune phenotypes. In the matched "
    "cohort, at least one representation reached AUROC 0.60 in 157 of 243 "
    "eligible mutation or fusion analyses; all three did so in 60. Strong "
    "shared examples included GTF2I mutation in thymoma (AUROC 0.875 to "
    "0.911), strict microsatellite instability in colon cancer (0.846 to "
    "0.909) and the RNA-derived TGF-beta response score in testicular "
    "germ-cell tumours (Q² 0.575 to 0.681). TITAN most often gave the highest "
    "internal estimate, but the leading representation depended on the "
    "feature, and some associations weakened when TCGA tissue-source-site "
    "codes were held apart. PathoFMPred, the accompanying R package, "
    "organizes and applies compatible fitted research models.",
)
replace(
    main,
    "Conclusions. The atlas identifies",
    "Conclusions. Pathology slide representations revealed cancer-specific "
    "associations with genomic alterations and derived immune-related "
    "phenotypes. The atlas can guide independent testing of these "
    "associations, but the TCGA results do not establish clinical validity.",
)
replace(
    main,
    "We built a cancer-specific atlas",
    "We examined which genomic and immune-related features could be estimated "
    "from H&E slide representations within each cancer. A cancer-feature "
    "combination defines one separate prediction analysis. We compared "
    "TITAN, Giga-SSL and Prov-GigaPath on identical slides, outcomes and "
    "validation folds wherever all three were available, and retained other "
    "cancers in the atlas when fewer representations or a small-cohort "
    "analysis were possible. The PathoFMPred R package provides a common "
    "interface for the resulting research models.",
)
replace(
    main,
    "The three-way comparison included",
    "The matched comparison comprised 8,241 patients and 3,389 "
    "cancer-feature analyses across 30 cancers (Figure 1). It included "
    "2,963 continuous and 426 binary analyses, with the same 10,165 slides, "
    "outcomes, folds and tuning rules for each representation. Breast "
    "cancer was analysed with TITAN and Giga-SSL because the Prov-GigaPath "
    "release lacked its slides. Cholangiocarcinoma was examined separately "
    "under the small-cohort exception. These additions brought the "
    "cancer-specific atlas to 32 cancers without entering the matched "
    "three-way comparison.",
)
replace(
    main,
    "Across the 32-cancer atlas",
    "We evaluated 3,637 cancer-feature combinations across the full atlas. "
    "Of these, 1,084 reached the descriptive held-out threshold of Q² 0.20 "
    "or AUROC 0.60 with at least one available representation (Figure 2; "
    "Supplementary Table S5). This counts a feature separately in each "
    "cancer where it was tested; it does not represent 1,084 independent "
    "biomarkers. Twelve combinations used an H&E-derived TIL reference. "
    "The other 1,072 compared the slide with independently derived genomic, "
    "transcriptomic or immune-related reference phenotypes. Supplementary "
    "Table S6 separates the matched results by reference-phenotype source.",
)
replace(
    main,
    "In breast cancer, TITAN or Giga-SSL",
    "The breast-cancer extension yielded 21 binary and 51 continuous "
    "threshold crossings, including CDH1 and TP53 mutation signals with "
    "both available representations. The exploratory cholangiocarcinoma "
    "analysis yielded eight pathway or immune-related associations and "
    "no eligible mutation model (Supplementary Table S5).",
)
chol = find(main, "In the 38-patient CHOL slide intersection")
chol._element.getparent().remove(chol._element)
discussion = find(main, "Representation choice depended on the target")
if len(discussion.runs) != 3:
    raise ValueError("Unexpected discussion run structure")
for run in discussion.runs[1:]:
    run._element.getparent().remove(run._element)
for paragraph in main.paragraphs:
    if paragraph.style.name == "Normal":
        paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
main.save(MAIN_OUT)

cover = Document(COVER_IN)
replace(
    cover,
    "We are pleased to submit",
    "We are pleased to submit this manuscript as a Research Article for "
    "consideration in Journal of Translational Medicine. Using published "
    "TITAN, Giga-SSL and Prov-GigaPath slide representations, we examined "
    "which genomic and immune-related features can be estimated from "
    "haematoxylin-and-eosin images in individual TCGA cancers. The matched "
    "comparison used identical patients, slides, outcomes and validation "
    "folds across the three representations. The wider cancer-specific "
    "atlas also includes breast cancer and an exploratory analysis of "
    "cholangiocarcinoma.",
)
for paragraph in cover.paragraphs:
    if paragraph.text.strip():
        paragraph.alignment = WD_ALIGN_PARAGRAPH.LEFT
cover.save(COVER_OUT)
print(MAIN_OUT)
print(COVER_OUT)
