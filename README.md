# TypeCheck 论文源码

本仓库包含论文 **Detecting Python Type Errors through Interprocedural Type-State Analysis** 的 LaTeX 源码、参考文献、插图以及 ACM 模板。论文使用 ACM `acmsmall` 匿名评审版式，构建产物统一写入 `build/`。

## 目录结构

```text
.
├── doc/
│   ├── main.tex              # 论文入口，定义章节顺序和参考文献
│   ├── preamble.tex          # 宏、依赖包、代码样式和图片路径
│   ├── build.sh              # 一键构建脚本
│   ├── secs/                 # 各章节的 LaTeX 源文件
│   └── photos/               # 论文插图（PDF/PNG）
├── references.bib            # BibTeX 参考文献库
├── acmart-primary/           # 随仓库提供的 ACM `acmart` 模板源码
├── ACM-Reference-Format.bst  # ACM 参考文献样式
└── build/                    # 构建生成的 PDF、日志和辅助文件
```

各章节位于 `doc/secs/`：

| 文件 | 内容 |
| --- | --- |
| `1_abstract.tex` | 摘要 |
| `2_introduction.tex` | 引言 |
| `3_background.tex` | 背景知识 |
| `3_motivatingExample.tex` | 动机示例，由背景章节引入 |
| `4_method.tex` | 方法 |
| `5_evaluation.tex` | 实验评估 |
| `6_threats.tex` | 有效性威胁 |
| `6_relatedwork.tex` | 相关工作 |
| `7_conclusion.tex` | 总结 |

新增或调整章节后，需要在 `doc/main.tex` 中通过 `\input{...}` 确认其引用位置。图片放在 `doc/photos/` 后，可以直接使用文件名引用，因为图片搜索路径已在 `doc/preamble.tex` 中配置。

## 构建论文

### 环境要求

本地需要安装带有以下命令和 LaTeX 宏包的 TeX 发行版：

- `tex`
- `xelatex`
- `latexmk`
- `bibtex`
- `algorithm`、`algpseudocode`、`subcaption`、`tabularx`、`listings` 等宏包

完整安装的 TeX Live 通常已经包含这些依赖。

### 执行构建

在仓库根目录运行：

```bash
bash doc/build.sh
```

脚本会自动切换到仓库根目录，因此也可以从其他工作目录通过脚本路径调用。构建过程分为两步：

1. 如果 `build/acmart.cls` 不存在，或 `acmart-primary/acmart.dtx` 更新过，则从仓库内附带的 ACM 模板源码重新生成 class 文件。
2. 使用 `latexmk -xelatex` 编译 `doc/main.tex`，自动处理交叉引用和 BibTeX 参考文献。

最终生成的论文位于：

```text
build/main.pdf
```

编译日志和中间文件也保存在 `build/`，主要包括：

- `build/main.log`：XeLaTeX 日志；
- `build/main.blg`：BibTeX 日志；
- `build/main.aux`、`build/main.bbl` 等：LaTeX 中间文件；
- `build/class-generation.log`：首次生成或更新 `acmart.cls` 时产生的日志。

构建失败时，优先查看终端末尾的错误信息和 `build/main.log`。如果错误出现在 ACM class 生成阶段，再检查 `build/class-generation.log`。

## 常见编辑位置

- 修改论文标题、关键词、章节顺序或文档版式：`doc/main.tex`
- 增删宏包、公共命令或代码块样式：`doc/preamble.tex`
- 修改正文：`doc/secs/` 下对应章节
- 添加或替换图片：`doc/photos/`
- 添加参考文献：`references.bib`

`build/` 中的文件均为生成产物，不应在其中直接修改论文内容。
