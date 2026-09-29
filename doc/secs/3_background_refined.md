# Background 修订稿：保留渐进展开与解释性重述

修订日期：2026-09-27。本轮以最近确认的 Markdown 正文为基线，依据 [可读性经验文档](C:/Users/hejl/Desktop/921Version/921Version/paper_readability_study/READABILITY_GUIDE.md) 和 [行文表达经验](C:/Users/hejl/Desktop/921Version/921Version/paper_readability_study/EXPRESSION_GUIDE.md) 调整表达。原始 [3_background.tex](C:/Users/hejl/Desktop/921Version/921Version/TypeCheck/doc/secs/3_background.tex) 仅用于对照阅读功能和历史修改位置。

正文保留原文“总述—展开—回扣”的阅读顺序，修正语义和草稿问题。下方先给出完整 LaTeX 正文，再逐处说明修改必要性及原有阅读功能的保留方式。正文中的 % [M1] 等为备注索引，不显示在编译后的论文中；正式使用时可删除。这些编号对应本版备注，不沿用旧稿的编号。

本轮重点是写清对象、动作与条件，采用已确认的 `a detector must examine` 表达必要的检查要求。`must` 用于完成相应分析所需的工作，`can` 用于表达能力或可采用的方式，`may` 用于可能发生的行为，不进行统一替换。

本次仅更新本 Markdown 文件。原章节标题、小节标题、标签、公式标签和 motivating example 的引入语句均保留；背景正文不提前引用该例子，不展开 PSTC 的具体设计。独立例子文件中的工具版本、配置等 xxx 仍留待补充。

## 新版正文

~~~latex
\section{Background and Motivating Example}
\label{sec:background}

% [M1]
In this section, we explain how dynamic typing and duck typing in Python
affect type-error detection. We then introduce Hoare triples and explain
how their preconditions and postconditions can summarize function behavior.

\subsection{Dynamic Typing and Duck Typing in Python}

% [M2]
A type-error detector must determine which types an operation's operands
can have and check whether the operation supports those
types~\cite{oh2024pyinder}. Python's dynamic typing and duck typing
complicate these tasks. With dynamic typing, the values used by an
operation may have different types on different executions.
Under duck typing, objects of different classes can support the same
operation. To check compatibility, a detector must examine whether the
operands meet the requirements of the methods or protocols used by that
operation. Moreover, the same operation may invoke different
implementations for different operand types. These implementations may
return values of different types, affecting the types used by subsequent
operations.

% [M3]
More specifically, \textbf{dynamic typing} allows both local and global
variables in Python to be bound to objects of different
types during program execution~\cite{pythonExecutionModel,pythonDataModel}.
Consequently, an operand's type depends on the assignments and updates
along the execution path to the operation.
% [M4]
Function calls can also change the values that a caller uses. A caller may
assign a function's return value to a variable. A callee may also update a
global variable or an attribute of an object shared with its caller.
When the caller next reads the updated variable or attribute, it may
obtain a value of a different type, even if the callee did not return that
value. To determine the types used by subsequent operations, a detector
must therefore track assignments and updates both within functions and
across calls.

% [M5]
In Python, code written in the \textbf{duck typing} style uses objects
through the methods and attributes they support, without requiring them
to belong to a particular class~\cite{pythonGlossary}.
For an operation that calls a method on an operand, a detector must check
that the object supports that method and that the call satisfies the
method's requirements.
% [M6]
Beyond checking whether an operation accepts its operands, a detector
must account for what its implementation returns or updates. Python's
dispatch rules may select different implementations for different operand
types. These implementations may return values of different types or
update state that subsequent operations read. The detector must track
these effects because later operations use the resulting values and
updated state.

% [M7]
To check subsequent operations precisely, a detector can relate the types
and state before each operation to its result and the state after it.
For a function call, this relation connects the argument types and the
types of shared values before the call to the return type and the types
of updated values after it. The shared values include global variables
and object attributes that the function reads or updates.
The same function may return or update values of different types under
different calling conditions or along different execution paths. If the
detector records only the possible resulting types, it loses the
conditions under which each type arises. It may then consider types that
cannot occur in the current calling context when checking a later
operation. Keeping each result associated with its conditions allows the
detector to use the type information relevant to that call.

\subsection{Hoare Triples as Function Summaries}
\label{sec:hoare-background}

% [M8]
To check operations after a call, a detector must account for the values
returned or updated by the callee. A function summary describes the
callee's relevant behavior so that the detector can reuse it at call
sites. For type-error detection, a summary can relate conditions on the
arguments and shared state before the call to type facts that hold after
it returns normally. Hoare triples provide a standard way to express
this relationship between conditions before and after execution.

Hoare logic describes how executing a program changes its
state~\cite{hoare1969axiomatic,softwareFoundationsHoare}. A Hoare triple has
the form
\begin{equation}
\{P\}\ C\ \{Q\},
\label{eq:hoare-triple}
\end{equation}
% [M9]
where $C$ is a command, and $P$ and $Q$ are assertions over program states,
called the precondition and postcondition, respectively. An assertion
describes a property of a state, such as the type of a value held in a
variable.
% [M10]
We use a partial-correctness interpretation that describes what holds on
normal termination. A valid triple states that if $P$ holds before $C$
executes and $C$ terminates normally, then $Q$ holds afterward. In other
words, $P$ gives the assumptions under which executing $C$ establishes $Q$
on normal termination. Under this interpretation, the triple does not
guarantee that $C$ terminates or executes without raising a
\texttt{TypeError}.

% [M11]
When a Hoare triple is used as a function summary, its precondition can
express assumptions about the arguments and shared state, while its
postcondition can describe the return value and properties of the shared
state after the call.
% [M12]
To apply the summary at a call site, the detector matches the callee's
parameters with the caller's arguments and interprets references to
shared objects in the caller's state. This step instantiates the summary
for the call. If the calling state satisfies the instantiated
precondition, the postcondition gives facts that hold when the call
returns normally. The detector can use these facts to check subsequent
operations. If the calling state does not satisfy the precondition, the
detector cannot rely on this guarantee. That alone does not establish a
type error. To determine whether an error occurs, the detector must
examine the relevant operations and their exceptional behavior.

% [M13]
Hoare triples also support sequential composition. If
$\{P\}\ C_1\ \{R\}$ and $\{R\}\ C_2\ \{Q\}$ are valid, then
$\{P\}\ C_1; C_2\ \{Q\}$ is valid. Here, $R$ is an intermediate assertion.
Starting from a state satisfying $P$, $C_1$ establishes $R$ on normal
termination. This assertion then serves as the precondition for the
second triple. Thus, the properties established by
one command provide the assumptions for reasoning about the next command.

% [M14]
For Python type-error detection, a detector can use a function summary to
update the type facts it uses after a call. If a function updates an
attribute of a shared object, its postcondition can describe the type of
the value held in that attribute on normal return. The caller still
accesses the same object, but the attribute now holds the updated value.
A type fact about its previous contents may therefore no longer apply.
The detector must check subsequent operations using type facts that
account for the update. When the calling state satisfies the summary's
precondition, its postcondition can provide these facts.

\input{doc/secs/3_motivatingExample}
~~~

## 逐处修改备注

以下“对应原文”行号沿用原始 3_background.tex，便于追溯；本轮修改以最近确认的 refined 正文为基线。备注说明各处累积修正和本轮表达调整，M9、M11、M13 经核对后保留上一轮正文，不计作本轮新增修改。

### M1：明确导语的内容，保留导航作用

> **对应原文：第 4–7 行。**
>
> **原句的作用：** 在进入小节前告诉读者本章将介绍什么。
>
> **修改与必要性：** 保留 dynamic typing、duck typing 和 Hoare triples 三项导航内容。本轮将“介绍与检测相关的语言特性”改为“解释它们怎样影响类型错误检测”，再说明前后条件怎样概括函数行为，使导语直接交代读者将理解的关系。继续保留此前对 these calls 模糊指代的修正，不提前引用 motivating example。
>
> **阅读功能如何保留：** 仍用两句完整导语交代两个小节及其顺序，没有为了减少重复而直接从小节标题跳进技术细节。
>
> **句式调整说明：** 两句分别围绕 explain how 和 introduce ... and explain how 展开，以实际说明任务代替“相关概念”的笼统列表。

### M2：先说明语言现象，再明确检测器必须检查什么

> **对应原文：第 11–20 行。**
>
> **原句的作用：** 给读者一张阅读地图：确定类型、判断兼容性，以及操作结果对后续类型信息的影响。
>
> **修改与必要性：** 本轮用 detector 作主语，直接写出确定操作数可能类型和检查操作支持情况两项任务，不规定二者严格分步执行。采用已确认的两句表达，先说明不同类的对象可以支持同一操作，再用 “a detector must examine” 指明必须检查相关方法或协议的要求。去掉没有充分铺垫的 Even when 及 types 与 class names 之间的比较，使读者直接看到判断对象。
>
> **阅读功能如何保留：** 仍依次交代两项任务、动态类型、duck typing、不同实现及其对后续操作的影响。最后两句由 operation 调用实现、实现返回值来描述执行过程，避免让 operand types 看起来像执行调用的主体。整段导航功能和后文展开均保留。
>
> **情态词说明：** must examine 表达完成兼容性判断所需的检查；can support 和 may invoke / return 表达支持能力与可能行为，不将它们改为必然发生。

### M3：清理动态类型定义，同时保留从定义到程序点的推理

> **对应原文：第 22–25 行前半部分。**
>
> **原句的作用：** 从动态类型的通用概念，逐步解释操作数在具体程序点为什么会具有不同类型。
>
> **修改与必要性：** 本轮将插入说明改为 both local and global variables，让定义的对象直接进入主句。随后用 an operand's type 指明依赖 assignments and updates 的对象，保留沿执行路径确定类型的含义。
>
> **阅读功能如何保留：** 保留 “More specifically” 引导的展开，以及 “Consequently” 引出的分析后果。定义之后仍解释它对操作数类型意味着什么，而不是只给定义。这里没有声称同一个对象本身会因变量重新赋值而改变类型。

### M4：修正返回值与共享状态变化的关系，并补足调用后的观察过程

> **对应原文：第 25–28 行。**
>
> **原句的作用：** 将局部类型变化推进到跨函数变化，并归纳为什么需要跨调用跟踪。
>
> **修改与必要性：** 本轮直接以“函数调用可以改变调用者使用的值”进入跨调用影响。分别说明 caller 赋值、callee 更新共享值、caller 再次读取，明确每个动作的主体；把“观察到不同类型”具体化为“读到不同类型的值”。最后写明 detector must track 的分析要求。继续保留返回值产生与调用者赋值的区别。
>
> **阅读功能如何保留：** 保留“调用影响—两类变化途径—再次读取—分析需求”的顺序。即使 callee 不返回被更新的值，caller 仍能观察到更新，这个让步有前文的返回值说明作依据，因而保留。段尾用 therefore 收束实际建立的因果链。
>
> **句式调整说明：** 用相邻完整句区分 caller 和 callee 的动作，不用一个 while 同时承载两种变化途径，也不把真实执行与检测器的推理混为同一个动作。

### M5：保留 duck typing 的定义和兼容性解释，修正过强的充分条件暗示

> **对应原文：第 30–36 行。**
>
> **原句的作用：** 先解释 duck typing，再说明检测器怎样判断操作是否适用。
>
> **修改与必要性：** 本轮让 code 作主语，用“通过对象支持的方法和属性使用对象”解释 duck typing，并将不要求特定类的范围限定在这种编程风格中。随后具体到操作调用某个方法时，检测器必须确认对象支持该方法、调用满足其要求。这样把 behavior 落到可识别的对象和动作，同时避免把“存在同名方法”当作充分条件。
>
> **阅读功能如何保留：** M2 负责总述“不同类的对象可以支持同一操作”；本段负责定义，并把检查要求具体化为方法调用。没有原样再讲一遍总述，也没有删去定义。实现选择及其效果仍由 M6 接续。
>
> **概念边界：** 本段说明 duck typing 的使用原则和兼容性检查，不把实现分派及副作用归因于 duck typing 本身。

### M6：把“当前操作兼容”与“后续类型信息”分开解释，再联系起来

> **对应原文：第 33–38 行中关于实现选择及其结果的内容。**
>
> **原句的作用：** 说明 duck typing 相关的操作行为不仅影响当前检查，也影响后续分析。
>
> **修改与必要性：** 将“考虑选中实现的行为”具体化为“考虑实现返回或更新了什么”。接着明确 Python 分派规则选择实现、实现返回值或更新状态、后续操作使用这些结果。最后由 detector must track 写出必要的分析动作。
>
> **阅读功能如何保留：** 从当前操作是否接受操作数，走到实现的结果，再走到后续操作使用这些结果，保留 compatibility checking 与 type tracking 的衔接。此前“当前操作兼容不保证后续兼容”的解释功能，由正面说明后续操作实际使用哪些值和状态来承担。
>
> **句式调整说明：** 用 because 连接跟踪要求与后续操作的实际读取行为，避免只宣布“这些效果必须被跟踪”却不说明谁跟踪、为何跟踪。

### M7：移除不准确的注解对比，保留“前后对应关系”的主题展开

> **对应原文：第 39–43 行，独立为本小节的收束段。**
>
> **原句的作用：** 将具体语言特性归纳为分析需要保留的输入与输出关系。
>
> **修改与必要性：** 本轮用 detector can relate 写出保留关系的分析方式，并明确关系两端是调用前的参数与共享值类型、调用后的返回值与更新值类型。随后说明同一函数在不同条件或路径下产生不同类型结果，以及只记录可能类型会丢失哪些条件。继续保留此前移除不准确类型注解对比的决定。
>
> **阅读功能如何保留：** 本段没有仅用“需要条件化的状态关系”一句收尾，而是说明关系的两端是什么、涉及哪些对象、对后续检查有什么用途。独立成段是为了让读者先完成对 duck typing 的理解，再接受跨调用分析所需信息的归纳。
>
> **情态词说明：** 这里保留 can，描述一种支持精确检查的关系表示方式，不将所有检测器都必须显式保存该关系作为前提。保留“条件丢失—纳入当前调用不会出现的类型—按条件使用结果”的完整推理。
>
> **范围：** 只移除正文中的这一次引用，不删除参考文献条目，不提前介绍 PSTC 或 motivating example。

### M8：保留从调用影响到函数摘要、再到 Hoare 形式的桥接

> **对应原文：第 49–56 行。**
>
> **原句的作用：** 回扣上一小节，将“需要跨调用传播信息”连接到“摘要如何表达这些信息”。
>
> **修改与必要性：** 本轮直接说明检测器检查调用后操作时必须考虑 callee 返回或更新的值，再介绍摘要供检测器在调用点复用。把“前后关系”明确为调用前参数和共享状态的条件与正常返回后的类型事实，然后引出 Hoare triples。
>
> **阅读功能如何保留：** 保留“调用产生影响—检测器复用摘要—前后条件表达”三个台阶。开头回扣上一小节，随后才进入形式定义；同时明确复用摘要的是检测器，避免把分析行为写成调用者程序的运行行为。

### M9：明确状态与断言的区别，给术语一层直观解释

> **对应原文：第 65 行，并承接第 58–64 行原样保留的公式介绍。**
>
> **原句的作用：** 解释公式中三个组成部分。
>
> **修改与必要性：** 明确 C 是命令，P 和 Q 是关于程序状态的断言；随后用“描述状态的性质，例如变量中值的类型”解释 assertion。这样避免把 precondition、postcondition 或后文 R 当成具体状态。
>
> **阅读功能如何保留：** 不仅列出符号名称，也告诉读者断言究竟描述什么。没有额外引入状态空间、谓词语义或新符号系统，让基础概念解释保持在当前章节所需的层次。

### M10：准确表达部分正确性，同时保留公式后的自然语言重述

> **对应原文：第 66–67 行及第 70–71 行中的保证说明。**
>
> **原句的作用：** 将三元组形式转成执行前后关系。
>
> **修改与必要性：** 明确本节采用只约束正常终止结果的部分正确性解释，并保留有效三元组及正常终止的条件。随后用一句话说明前置条件是后置保证所依赖的假设；最后指出在此解释下三元组本身既不保证终止，也不保证执行中没有 TypeError。这一区分避免读者把正常返回后的类型事实误读为无类型错误的保证，也不将该解释泛化到所有带错误语义的 Hoare 逻辑。
>
> **本轮表达调整：** 将 normal-termination partial-correctness interpretation 这一连续修饰结构展开成“采用部分正确性解释，并说明正常终止时成立什么”。随后用 P、C、Q 对应假设、执行和保证，保留公式后的自然语言重述及全部语义边界。
>
> **阅读功能如何保留：** 仍然有“形式含义—换一种说法解释—必要边界”的顺序。相比上一版，没有继续追加对所有可能入口状态的抽象讨论；重要边界由 assumptions 与正常终止条件直接表达，避免限制性说明压过正面解释。

### M11：将前后条件映射到函数摘要，并接替原编码例子的解释职责

> **对应原文：第 67–76 行。**
>
> **原句的作用：** 原来的编码例子将三元组具体化；后面的函数摘要说明把前后条件与调用联系起来。
>
> **修改与必要性：** 删除依赖 msg.body 的编码例子，因为未指定编码实现就推出 bytes 不充分，也提前借用了后文场景。将“前置条件记录调用时必须满足的内容、后置条件记录返回值与所有可见变化”改为 can express assumptions 和 can describe properties，避免把摘要写成必然完整的状态记录。
>
> **阅读功能如何保留：** 例子原来承担的解释工作由三处接替：M9 用变量中值的类型解释断言；本处逐项说明参数、共享状态和返回值怎样对应前后条件；M14 再说明更新共享属性后调用者如何使用这些信息。没有删掉例子之后只留下数学定义，也没有为增加篇幅而另造一段代码。

### M12：逐步说明摘要在调用点如何使用，补齐保证适用的条件

> **对应原文：第 76–78 行。**
>
> **原句的作用：** 解释形式参数如何连接调用者，并将摘要结果用于后续操作。
>
> **修改与必要性：** 本轮明确由 detector 匹配参数与实参、解释共享对象引用、使用后置事实检查后续操作。原来的 “The caller can then use these facts” 容易将程序执行与分析器推理混淆，现统一为检测器的动作。调用状态满足实例化前置条件、调用正常返回两个条件仍保留。
>
> **阅读功能如何保留：** 采用“对象如何对应—这一步叫什么—何时能使用保证—保证用于什么”的顺序，避免一句 instantiated assertions 让读者自行补全过程。此处只介绍摘要应用的原则，不提前展开别名分析或 PSTC 的实现算法。
>
> **保证边界与情态词：** 不满足前置条件时，检测器不能依赖该保证，但这不单独证明存在类型错误。用 detector must examine 表达错误判定所需的操作与异常行为检查；用 can use 表达满足条件后可使用后置事实的能力，不混用两种语气。

### M13：修正组合规则，同时保留它为什么能连接前后执行的解释

> **对应原文：第 79–80 行；拆成独立段落。**
>
> **原句的作用：** 说明一个命令建立的性质如何支持下一个命令的分析。
>
> **修改与必要性：** 显式给出组合后的三元组，并将 “the state R” 改为 intermediate assertion。说明从满足 P 的状态出发，C1 正常结束后 R 成立，并作为第二个三元组的前置条件，避免将断言与状态混淆，也保留保证所依赖的入口条件。
>
> **阅读功能如何保留：** 写出规则后仍用一句自然语言归纳其操作含义。该句在逻辑上重述规则，但能帮助读者理解组合的用途，应当保留。独立成段则让读者先读完调用点实例化，再理解顺序组合，不在一个长段内切换两项概念。
>
> **句式调整说明：** 先用完整句子说明 R 是中间断言，再解释它在执行中的作用，避免用冒号将术语与解释挤在同一句中。

### M14：保留面向 Python 类型分析的收束，删除签名对比而非删除解释

> **对应原文：第 82–89 行。**
>
> **原句的作用：** 将通用 Hoare 形式重新落到 Python 类型分析，让读者理解它为何与本章相关。
>
> **修改与必要性：** 本轮用 detector can use a function summary 说明摘要用途；保留调用者仍访问同一对象、属性内容已更新、旧事实可能失效的解释。结尾明确检测器必须依据考虑了更新的类型事实检查后续操作，并把调用状态满足前置条件放在使用后置事实之前。继续保留此前删除签名能力对比、不重复罗列摘要覆盖对象的决定。
>
> **阅读功能如何保留：** 保留从通用摘要到 Python 类型分析的映射，但以“同一对象的属性已保存新值”为中心，逐步解释旧事实为什么可能失效、新事实怎样用于检查。M11 负责说明摘要覆盖的信息，本段负责说明更新对既有类型事实的影响，二者职责更清楚。
>
> **PSTC 定位：** 正文只说明通用形式能承载类型信息，不声称 Hoare triples 缺少某种表达能力，也不提前介绍 PSTC。其具体内容与用途留给方法章节，符合已经确认的定位。

## 本版有意保留的表达与结构

下面列的是保留决定，不计为新的修改。

- 第一小节的总述仍然较完整；总述帮助定位，后续段落帮助理解，职责不同。
- 动态类型段落仍从定义慢慢走到局部更新、跨调用更新和分析后果，没有用一个专业术语概括整个过程。
- 仍先解释 duck typing 下的兼容性判断，再衔接实现分派及其对后续类型跟踪的影响，不只留下 requirements 和 effects 两个标签。
- Hoare 公式后仍保留自然语言解释；摘要应用与顺序组合也各有解释后的回扣。
- M9 的断言解释、M11 的摘要映射和 M13 的顺序组合已经清楚，经核对后保留，不为统一句型而改写。
- 结尾仍回到 Python 类型分析，帮助读者将通用概念与本章主题联系起来。
- 原始标题、标签及输入例子的语句保留。例子正文及其中待补充的实验 xxx 不在此次修改范围。

这些取舍依据经验文档中对“定位、直观解释、因果连接、具体化、归纳回扣”的区分。相关观察可查 [逐篇阅读笔记](C:/Users/hejl/Desktop/921Version/921Version/paper_readability_study/READING_NOTES.md)：P1 的因果展开，P3 的概念映射与跨节回扣，P7 的公式解释，以及 P8 的总结性重述。本版借鉴这些表达功能，不照搬样本论文的句式、篇幅或技术主张。

本轮句子表达的依据另见 [表达精读笔记](C:/Users/hejl/Desktop/921Version/921Version/paper_readability_study/EXPRESSION_READING_NOTES.md)。重点检查连接词是否有依据、关系两端是否明确，以及程序执行与检测器分析是否由正确的主语承担。
