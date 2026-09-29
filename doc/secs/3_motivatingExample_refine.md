# Motivating Example 修改稿及逐处说明

## 本轮修改依据

本轮以本文件上一版为基线，参考 `reference/tex_src/doc/secs/3_motivatingExample.tex` 的表达与组织方式，并遵循 `paper_readability_study/EXPRESSION_GUIDE.md`（EG）及 `paper_readability_study/READABILITY_GUIDE.md`（RG）。下面的连续稿和 R01–R08 说明替代此前版本及其修改备注。

附件使用常规的 Motivating Example 节标题，以研究问题命名段落，结合图中位置解释具体机制，再介绍本文方法如何处理。此次借鉴这种组织方式，不照搬附件中的类型推断任务、真实项目来源和基线失败原因，也不将这种写法视为唯一的“顶会格式”。

保留已确认的技术边界：本例说明需要保存的条件与更新关系，不证明 PSTC 是唯一可行的表示；union 可以支持潜在错误检测，其局限在于合并后可能丢失安全与错误调用之间的区别。版本、配置与复现位置仍待补充为 `xxx`，由评测设置或复现材料承接，不扩写为动机段中的实验说明。本轮不修改原 `.tex` 或图片。

## 连续修改稿

`% [Rxx]` 为编辑标记，转入论文时可删除。保留原图路径、节标签及图标签，以匹配现有正文引用。

```latex
% [R01]
\subsection{Motivating Example}
\label{sec:motivating-example}

% [R02]
Figure~\ref{fig:motivating-example} presents a message-processing
example that illustrates the need to track type-state changes across
function calls. The function \texttt{make\_line} calls
\texttt{encode\_message} to encode a message body before appending
a newline. The body is declared as \texttt{str | bytes}.
For a string body, \texttt{encode\_message} invokes the supplied
encoder and stores its result in the same message object.
\texttt{TextEncoder} returns the string unchanged, whereas
\texttt{Utf8Encoder} converts it to bytes.

% [R02a]
As shown in the figure, Mypy, Pyrefly, and Pyright do not report the
concatenation error, whereas PyTT detects it. Analyzing this example
reveals two related requirements for type-error detection. First,
the analyzer must propagate changes to the shared message body across
the call so that the subsequent operation is checked against its
updated type. Second, distinguishing the failing UTF-8 call from the
safe text-encoder call requires retaining the conditions under which
each update occurs. We examine these requirements below and explain
how PyTT addresses them through conditional type-state summaries.

\begin{figure}[!htbp]
\centering
\includegraphics[width=\linewidth]{motivatingExample.pdf}
% [R03]
\caption{Motivating example of interprocedural type-state changes
and type-error detection results.}
\Description{The caller make_line rejects a non-string message body,
then calls encode_message with Utf8Encoder and attempts to concatenate
msg.body with a newline string. For a string input, the helper writes
the encoder's result into the same message object. TextEncoder returns
a string, and Utf8Encoder returns bytes. Points 1, 2, and 3 mark the
string body before the call, the conditional field updates, and the
bytes body after the UTF-8 call returns normally. The concatenation
then raises TypeError. The result panel labels Mypy, Pyrefly, and
Pyright with No diagnostic and PyTT with Type error detected.}
\label{fig:motivating-example}
\end{figure}

% [R04]
\textbf{(1) Interprocedural Type-State Propagation.}
In \texttt{make\_line}, the guard raises \texttt{ValueError} when
\texttt{msg.body} is not a string. Thus, the body has type
\texttt{str} at point~1. The subsequent call passes \texttt{msg}
and a \texttt{Utf8Encoder} instance to \texttt{encode\_message},
which writes the encoding result into \texttt{msg.body}. Because
both functions access the same message object, the body has type
\texttt{bytes} at point~3 after the call returns normally.
The expression \texttt{msg.body + '\textbackslash n'} then raises
\texttt{TypeError} before \texttt{print} is invoked, and the exception
escapes \texttt{make\_line}.

% [R05]
Both the original string and the updated bytes satisfy the field's
union annotation, but the updated body does not support concatenation
with a string. Detecting this error requires propagating the field
update from \texttt{encode\_message} to its caller. The function's
return type, \texttt{None}, does not describe this update. If the
analyzer retains the string type established at point~1, it can miss
the error at point~3.

% [R06]
\textbf{(2) Conditional Type-State Modeling.}
Propagating a field update also requires determining which type the
call establishes. In this example, that type depends on the encoder
argument. Replacing \texttt{Utf8Encoder} with
\texttt{TextEncoder} leaves a string body and makes the concatenation
valid. An analyzer that assigns \texttt{str | bytes} to the body
after either call can flag the potential bytes/string conflict.
However, retaining the bytes alternative for \texttt{TextEncoder}
can also cause a false alarm. Distinguishing these calls therefore
requires preserving the relation between the encoder argument and the
resulting field type under the incoming string condition.

% [R07]
PyTT addresses these requirements using path-sensitive type contracts
(PSTCs), which record field updates together with their calling
conditions and propagate the applicable updates to callers. At point~2,
the contract for \texttt{encode\_message} records two cases for an
incoming string body. On normal return, the \texttt{TextEncoder}
case establishes a string body, and the \texttt{Utf8Encoder} case
establishes a bytes body. For a non-string input, the function leaves
the body unchanged.

% [R08]
At the illustrated call, PyTT uses the string type established by the
guard and the \texttt{Utf8Encoder} argument to select the second case.
It maps the callee's message parameter to the caller's object and
updates the type of \texttt{msg.body} accordingly. The subsequent
concatenation is therefore checked with a bytes body, revealing the
type error.
```

## 逐处修改与必要性

### R01 — 使用章节功能标题，以研究问题命名正文分项

**前版。** 节标题为 `Tracking Field Updates across Function Calls`，段标题包括 `How the call invalidates an earlier type fact`、`Why merging the possible field types loses precision` 和 `Preserving the condition for each field update`。

**修改。** 节标题改为附件采用的 `Motivating Example`。正文采用两个并列的加粗分项 `Interprocedural Type-State Propagation` 和 `Conditional Type-State Modeling`。

**必要性。** 前版标题按讲解步骤组织，读者首先看到的是“怎样发生”“为什么失去精度”等讲解提示。本版让节标题交代论文中的功能，让分项标题明确例子揭示的两个分析问题。两个分项分别回答“什么信息需要跨调用传播”和“传播时需要保留什么条件”，与正文职责对应。它们不是新增的两个独立创新点，也不强行套用引言中的全部三个挑战。

**依据。** 附件中的编号主题标题；EG §3.1 的阅读功能；RG §2 的定位功能与 §3.6 的章节职责。

### R02 — 从代码清单式介绍改为场景、机制和分析主题的导入

**前版。** 开头依次列出字段、两个方法、helper 返回值和后续拼接依赖，段末再次概括共享对象中的 body。

**修改。** 首句说明本例用于展示跨调用类型状态变化，随后围绕 `make_line` 调用 `encode_message` 展开消息处理过程，再介绍两种 encoder 的区别。将 helper 返回 `None` 的信息移至 R05。本轮将原先笼统的“两个分析方面”预告替换为独立的 R02a 整体分析引导段。

**必要性。** 第一段先让读者认识程序对象和调用任务，第二段再从这些对象提炼分析需求，避免代码背景与整体论证挤在一起。返回值的作用直到讨论“返回类型为什么不足以描述字段更新”时才出现，从而避免导入段提前罗列后面才会使用的信息。没有把例子写成真实项目缺陷。

**依据。** EG §3.1–3.2 的对象与动作；RG §3.1–3.2 的渐进展开与概括后解释。

### R02a — 增加整体分析引导，明确两项需求的关系

**前版。** 代码背景之后只用 `This example illustrates two aspects ...` 预告分项，读者尚不清楚两个方面各自解决什么问题，以及为什么需要同时讨论。

**修改。** 参考附件“例子与工具表现—整体分析—分项展开”的顺序，将原结尾的简短工具对比移到引导段开头。随后明确两项需求：跨调用传播共享字段更新，使后续操作使用当前类型；保留更新条件，使分析能够区分错误调用与安全调用。段末说明后文将展开这些需求及 PyTT 的摘要处理方式。

**必要性。** 这段为读者提供完整的论证路线，而非只列标题。第一项解决旧事实继续被使用的问题，第二项进一步解决更新被合并后丢失精度的问题。两者因此是递进的分析需求，不是从单个例子推导出的两个独立创新点。工具结果只移动、不重复；也不根据未报警直接断言基线缺少哪一种内部机制。

**后续承接。** R04–R05 展开字段更新如何传播及遗漏传播的后果；R06 以“传播时需要确定调用究竟建立哪种类型”承接，再展开条件区分；R07 明确 PSTC 同时记录条件与更新并传播适用更新；R08 用一次实际调用展示两项需求如何共同得到处理。

**依据。** 附件导入中的整体分析功能；RG §2、§3.1–3.2 的定位、渐进解释与概括后展开；EG §3.2–3.3 的具体关系与因果承接。

### R03 — 图注负责标识主题，编号推理留在正文

**前版。** 图注逐一解释三个编号点，正文随后又按编号推导错误。

**修改。** 图注改为 `Motivating example of interprocedural type-state changes and type-error detection results`。保留完整的 `\Description`，以文字描述图中程序、编号及结果标签。

**必要性。** 参考附件的主题式图注，避免在图注与紧邻正文中重复整条执行链。具体推理没有被删除，而由 R04 和 R07–R08 承担。无障碍描述仍需自足，因此继续保留输入条件、正常返回条件和异常发生位置，不以压缩可见文字为理由删掉这些信息。

**依据。** RG §2 的功能分工与 §4 的有益重述判断；EG §3.7 的必要条件。

### R04 — 将执行过程组织为跨函数传播的证据链

**前版。** 以“旧事实失效”为题描述 caller guard、helper guard、编码成功、字段写入和正常返回；异常分析在下一段继续。

**修改。** 在跨函数传播标题下连贯说明 point 1 的字符串类型、传入的 encoder、callee 字段写入、共享对象关系、point 3 的 bytes 类型和拼接失败。保留异常先于 `print` 发生以及逃逸当前函数的结论。

**必要性。** 每句围绕同一字段在三个位置的变化推进，图中编号成为分析证据的索引。省去对两个 guard 和编码成功的重复叙述，但仍以“输入已经是字符串”和“调用正常返回”限定后置结论。共享对象关系保留为独立的因果说明，因为没有这一步，读者就需要自行解释 callee 的赋值为何影响 caller。

**依据。** 附件按依赖编号展开具体机制的方式；EG §3.3 的真实因果、§3.6 的稳定对象；RG §3.1 的保留中间推理。

### R05 — 用一个需求段连接程序错误与分析缺口

**前版。** 注解合法性、旧事实失效和返回类型不足分散在运行分析与 union 比较两部分。

**修改。** 紧接执行链，先指出合法的字段赋值仍会使后续拼接失败，再提出需要传播字段更新，最后解释返回 `None` 不描述该更新以及保留旧字符串事实的漏报风险。

**必要性。** 这一段将“程序做了什么”转换为“检测器需要处理什么”，模仿附件从例中依赖推出分析需求的表达方式。比较对象明确限定为此字段的注解和此函数的返回类型，不泛化成类型注解无法表示任何条件关系。`can miss` 表示一种分析策略的后果，不据此推测三个基线的内部实现。

**依据。** EG §3.2–3.4 的关系对象、因果与公平比较；RG §2 的因果连接与 §3.7 的机制映射。

### R06 — 以安全调用引出条件建模，保留 union 的实际能力

**前版。** TextEncoder 的安全结果先在错误段出现，union 比较时再次出现；段末又单独引入一般函数摘要。

**修改。** 以“传播更新时需要确定调用建立的类型”承接第一分项，再将安全调用集中放在本分项开头。解释 encoder 参数改变会使拼接有效，随后讨论同一 union 用于两个调用时的潜在报警和误报，最后得出保留条件与结果关联的需求。一般摘要的桥接句由 R07 的具体方法回应承接。

**必要性。** 读者先看到需要区分的两种调用，再理解合并为何损失精度，比较具有明确对象。保留“union 可以报告潜在错误”，避免借助不公平的反面对比突出本文。这里需要保留的是信息关联，不是某一种唯一表示；后文介绍 PyTT 如何表达它，不声称其他上下文敏感分析无法做到。

**依据。** EG §3.3–3.4 的有依据的转折和比较；RG §3.1 的从已知走向需求。

### R07 — 将一般摘要讲解改为直接的方法回应

**前版。** 单独一段解释一般 summary 的两个 case，另一段解释一般 analyzer 的应用方式，结尾再介绍 PyTT 使用 PSTC。

**修改。** 采用附件“需求之后直接介绍本文处理方式”的衔接，以 `PyTT addresses these requirements ...` 引入 PSTC，说明其记录条件与字段更新，并向 caller 传播适用更新，再给出两个输入为字符串的条件化更新。保留正常返回条件和非字符串不更新的说明。

**必要性。** 前版的“一般摘要—一般分析器—PyTT 摘要”形成了不必要的再次映射。本版让读者一次建立 PSTC 与例中两条更新关系的对应。两条具体 case 仍需保留，因为它们解释 contract 中究竟记录什么。PSTC 的形式定义以及与 Hoare triple 的具体关系留在方法章节，不在此重复背景或提出替代关系。

**依据。** 附件方法回应段的组织方式；EG §3.1、§3.6 的施事与概念映射；RG §3.6–3.7 的章节职责。

### R08 — 通过一次调用点应用收束，与引导段形成回应

**前版。** 一般分析器的选择和映射之后，结尾再次用 PyTT 的 contract 解释输入字符串、UTF-8 encoder 和输出 bytes。

**修改。** 只用 PyTT 作为当前分析过程的主体，依次说明根据 guard 和 encoder 选择 case、绑定同一对象、更新字段类型以及检查拼接。工具对比已移到 R02a；本段以检查 bytes 类型的字段并发现冲突收束，不再重复基线结果或增加版本配置段。

**必要性。** 本段回答“上述 contract 如何用在图中的调用上”，与 R07 的“contract 记录什么”形成递进。选择 case 对应引导段的条件区分需求，映射并更新 caller 字段对应跨调用传播需求；最终操作检查将二者连接到检测结果。无需再列一遍工具表现，也不新增 TextEncoder 的 PyTT 实测结果。

**依据。** EG §3.1–3.2 的动作及对象连续性；RG §3.2、§3.7 的应用与回扣。工具结果的简短表达延续用户已确认的范围。

## 保留的技术与材料边界

- 当前图中工具结果仍待复现确认。工具版本、配置和复现位置为 `xxx`；本轮没有修改评测章节，也未产生运行证据。
- 正文仅说三个基线未报告目标拼接错误。若实际存在其他诊断，图中 `No diagnostic` 及对应 `\Description` 应在定稿时同步收紧。
- 条件化摘要的输入字符串与正常返回限制均保留。非字符串输入不更新单独交代，未将相关两条 case 写成 helper 的全部行为。
- 未把编号的两个分析方面写成完整方法的全部挑战，未引入本例无法展示的 LLM 推断或冲突修正流程。
- 没有把方法优越性归因于唯一表示能力。PSTC 的构建、复用与相对收益需要方法和实验支撑。
- 图路径及现有标签保持一致。聊天中出现的简写 `\ref{fig}` 未替换文件中的实际标签 `fig:motivating-example`，以免造成无法解析的引用。
- 本轮交付为 Markdown 中的论文修订稿，原 `.tex` 和图片保持不变；未编译论文。
