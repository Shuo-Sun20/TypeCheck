# Manuscript

The English manuscript follows `../../common/introduction.md`. Its entry point is
`main.tex`; section sources are in `secs/`. Experimental values and unspecified
experimental settings use `xxx` placeholders.

From `tex_src/`, build with:

```sh
bash doc/build.sh
```

The script uses XeLaTeX, BibTeX, and latexmk. It generates the ACM class from the
bundled publisher source and places the PDF and auxiliary files in `build/`.
The rendered manuscript is `build/main.pdf`. The manuscript retains the existing
ACM `acmsmall` anonymous review layout.

Expression-level review and separate research questions are recorded in
`../../reviews/writing-review.md` and `../../reviews/research-concerns.md`.
