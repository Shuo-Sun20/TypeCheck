# Method 修订稿：由需求和未解决的问题逐步引出方案

修订日期：2026-09-28。本轮以本文件上一版为修改基线，重写章节的论述推进。正文中的 `% [R01]`—`% [R35]` 与末尾修改说明逐项对应，替代上一版 M01—M37 标记及备注。本轮修改此 Markdown；现有 `4_method_refined.tex` 和 PDF 尚未同步本轮内容。

参考 [4_method_V3.tex](C:/Users/hejl/Desktop/921Version/921Version/reference/tex_src/doc/secs/4_method_V3.tex) 的需求驱动论述方式，并继续采用 [READABILITY_GUIDE.md](C:/Users/hejl/Desktop/921Version/921Version/paper_readability_study/READABILITY_GUIDE.md) 和 [EXPRESSION_GUIDE.md](C:/Users/hejl/Desktop/921Version/921Version/paper_readability_study/EXPRESSION_GUIDE.md) 的渐进解释原则。V3 的技术机制与能力主张不移植到本文。

## 本轮修正的核心问题

上一版主要按照“组件叫什么—输入是什么—执行什么—有什么边界”介绍方法。这能列全技术内容，却没有充分解释组件之间为什么需要彼此。部分段首虽写了目的，但紧接着就进入符号、版本、对象身份和异常规则，读者尚未理解核心方案，就要处理实现细节。

V3 的 Phase I 提供了更清楚的推进示范：为了复用依赖对象的类型，需要按依赖顺序分析；相互依赖使这个顺序无法直接建立，因此引出聚合；聚合后仍有上下文大小约束，再引出进一步处理。值得借鉴的是每一步都承接前一步留下的具体问题，而不只是使用相同的小节标题。

本稿据此建立下面的论述链。它是编辑说明，不放入论文正文。

| 前面已经建立什么 | 仍需解决什么 | 由此引出的方案 |
| --- | --- | --- |
| 检查调用后的操作，需要知道调用产生的类型变化 | 返回类型没有描述共享字段变化，合并的结果类型又不能区分调用条件 | PSTC 同时记录入口条件、执行路径和出口事实 |
| PSTC 明确了需要提取的信息 | 按不同条件和路径反复分析整段代码会重复计算 | Phase I 先分析类型行为与未知入口状态无关的部分 |
| 已得到可复用的局部事实 | 剩余代码的结果仍取决于条件和路径 | Phase II 提取显式路径，分别保留条件与更新 |
| 已知道经过哪些源代码操作 | 同一源操作在不同类型下可能调用不同实现 | 推断隐式路径，再组合入口条件、检查与更新 |
| 已构造 callee PSTC | 契约使用形参和共享位置，尚未对应本次调用的对象与状态 | 实例化契约、筛选相关案例、传播更新并检查后续操作 |
| 已得到类型冲突 | 冲突可能来自程序，也可能来自抽取契约的误差 | Phase III 回到相关源路径，在调用条件下分析冲突 |
| 已修正某个契约 | 使用旧契约的调用者结果仍可能错误 | 失效依赖结果、重分析调用者，再说明复用与预算 |

模型部分先解释各组成部分为什么需要，再给形式定义。阶段部分先承接前一部分的产物与剩余问题，再展开解决步骤。实例身份、强弱更新、缓存匹配等细节保留在相应需求已经明确的位置，不以删除技术边界换取顺畅。

## 新版正文

~~~latex
\section{Approach}
\label{sec:method}

% [R01]
This section presents how PyTT detects Python type errors by tracking
conditional type-state changes across function calls. We first explain
the overall workflow and the function contracts used to represent these
changes. We then describe how PyTT extracts the contracts from code,
uses them to check operations, and investigates the resulting conflicts.

\subsection{Overview}

\begin{figure}[!htbp]
\centering
\includegraphics[width=\linewidth]{methodOverview.pdf}
\caption{Overview of PyTT's workflow}
\label{fig:method-overview}
\end{figure}

% [R02]
To check an operation after a function call, PyTT needs the types
established by that call under the current calling conditions. It records
this information in a \emph{path-sensitive type contract} (PSTC), which
relates a function's entry conditions to its return value and shared-state
updates along different paths. A caller can use the relevant contract
cases to update its type-state and check subsequent operations.

Figure~\ref{fig:method-overview} shows how PyTT constructs and uses these
contracts for a Python repository. PyTT builds a call graph and gives
priority to analyzing callees, whose contracts then provide information
for analyzing callers. For each function, it performs three phases.

% [R03]
\textbf{(1) Context-free Code Simplification.}
Analyzing a function under different calling conditions can repeat work
on computations whose type behavior is already determined. PyTT first
identifies and checks these computations using static analysis. It then
reuses their type facts when analyzing the remaining code, reducing the
work needed to consider different paths.

% [R04]
\textbf{(2) PSTC Generation.}
The remaining code can produce different types under different entry
conditions. PyTT extracts these conditional transitions by identifying
explicit paths with static analysis and inferring implicit paths with an
LLM. It combines the requirements and effects along each path with the
facts from Phase~I and available callee contracts. The resulting PSTC
records the transitions used to check operations in callers.

% [R05]
\textbf{(3) Type Conflict Analysis.}
A conflict found using an inferred contract may reflect either a program
error or an inaccuracy in that contract. To distinguish them, PyTT traces
the conflicting type facts to the relevant caller and callee paths and
analyzes those paths under the calling conditions. It reports errors
supported by this analysis and corrects contracts responsible for false
alarms. Cases with insufficient evidence remain unresolved.

% [R06]
These phases are connected through the contracts they construct and
revise. A callee contract is used to analyze its callers; a correction to
that contract can therefore change their analysis results. PyTT repeats
the affected analyses until no pending work remains or the configured
budget is reached. It then reports confirmed type errors and records
undecided cases as unresolved. The PSTC model addresses Challenge~1 in
the introduction, its extraction in Phases~I and II addresses
Challenge~2, and conflict analysis in Phase~III addresses Challenge~3.

\subsection{Design of Path-Sensitive Type Contracts}
\label{sec:state-model}

% [R07]
The motivating example establishes two requirements for a function
summary. It must describe changes to values shared with the caller, and
it must retain the conditions under which each change occurs. For
\texttt{encode\_message}, knowing that the function returns
\texttt{None} does not tell the caller what happened to the message body.
Recording that the body can become either a string or bytes still leaves
the caller unable to determine which result applies to its encoder.
PyTT therefore needs a summary that connects the incoming type-state and
execution conditions to the types established by the call.

\subsubsection{Representing Calling Conditions and Updates}

% [R08]
To express changes beyond the return value, the summary must refer to the
variables and attributes read or updated by the function. PyTT represents
their type information at a program point as a \emph{type-state}
\[
    S:L\rightarrow\mathcal{T},
\]
where $L$ contains the tracked locations and $\mathcal{T}$ is the domain
of type information, including sets of possible types. A location can be
a parameter, a local or global variable, or a class or instance
attribute. A distinguished result location records the return value on
normal exit. Thus, $S(\ell)$ describes the type information for the value
held at location $\ell$. An assignment to an attribute changes the facts
for that attribute's contents. If the caller and callee refer to the
same object, this update also changes the facts used when the caller
next reads the attribute.

% [R09]
The summary must also specify when these post-call facts apply. PyTT
expresses this information using \emph{state assertions}, which describe
sets of states through type facts, branch conditions, and relevant
object-identity constraints. An entry assertion can require a string
message body and a \texttt{Utf8Encoder} argument, while an exit assertion
can state that the body holds bytes after normal return. Associating
these assertions keeps the resulting field type connected to the
calling condition that establishes it. Branch conditions remain relevant
because identical entry types need not imply identical execution paths.

\subsubsection{Connecting Assertions through Execution Paths}

% [R10]
Entry and exit assertions describe the conditional change needed by a
caller. To check that change and investigate a conflict, PyTT also needs
to retain the operations that produce it. For example, an exit assertion
that the message body holds bytes does not show which call produced the
bytes or which assignment stored them. PyTT therefore associates each
pair of assertions with a path description. This description records
guards, operation requirements, calls, and updates in execution order.
It includes explicit branch choices and implicit choices of behavior
that depend on operand types.

% [R11]
These three components form a path contract $(p,m,q)$, where $p$ is the
entry assertion, $m$ is the path description, and $q$ is the exit
assertion. A function can have several such cases, collected in its PSTC
\[
    \mathit{PSTC}(f)\subseteq
    \mathcal{A}\times\mathcal{M}_f\times\mathcal{A},
\]
where $\mathcal{A}$ is the set of state assertions and
$\mathcal{M}_f$ is the set of path descriptions for $f$. Each case keeps
a particular path associated with its entry conditions and post-call
facts. The PSTC thus represents the information required to transfer
type facts across a call while retaining the behavior behind those facts.

% [R12]
A path contract specializes the Hoare-triple structure introduced in the
background. A correct case states that if execution starts in a state
satisfying $p$, follows $m$, and returns normally, then $q$ holds
afterward. The caller can use these facts under the corresponding
conditions. This partial-correctness interpretation describes normal
returns; it does not guarantee that execution reaches one without a type
error. PyTT checks the operations along the path and tracks their
exceptional continuations separately. Moreover, the cases extracted by
the analysis may contain inaccuracies, which Phase~III investigates when
conflicts arise.

% [R13]
For \texttt{encode\_message}, one case starts with a string body and a
\texttt{TextEncoder} argument. Its path calls the encoder and assigns the
returned string to the body, establishing a string body on normal return.
A second case associates a \texttt{Utf8Encoder} argument with a path that
writes bytes to the body. Both cases return \texttt{None}, while the
non-string path leaves the body unchanged. These cases show what the
contract must preserve. The next two phases explain how PyTT obtains
this information from the function's code without repeating the same
analysis for every calling condition.

\subsection{Phase I: Context-free Code Simplification}
\label{sec:extraction}

% [R14]
Constructing the contract defined above requires examining behavior under
different entry conditions and execution paths. When a path contains
calls, its analysis also depends on the relevant paths of the callees,
increasing the number of combinations to consider. Reanalyzing the entire
function for each combination would repeat computations whose type
behavior does not depend on the unknown entry state. PyTT first separates
these computations and analyzes them once, so that subsequent path
analysis can reuse their results.

\subsubsection{Identifying Computations for Shared Analysis}

% [R15]
The first step is to determine which computations can be analyzed in
this way. We call a computation \emph{context-free} when local semantics
and available callee PSTCs determine its type behavior without resolving
the unknown entry type-state. PyTT checks this dependence by following
the values, shared locations, and guards used by the computation, as
well as its callees' requirements and updates. It places such
computations in $C_I$ and the remaining computations in $C_D$, the
\emph{Context-sensitive Code Snippet} in the workflow figure.

For \texttt{f(a)} in Figure~\ref{fig:method-overview}, the assignment
\texttt{c = 1} provides a known integer argument to \texttt{g}. Together
with the depicted PSTC of \texttt{g}, this determines that the result
\texttt{v} is an integer without knowing the type of \texttt{a}. The
computation can therefore be analyzed in $C_I$. The call
\texttt{h(v, a)} still depends on \texttt{a} and remains in $C_D$.
This classification also considers shared-state dependencies of a call;
known argument types alone do not establish that a call is context-free.

\subsubsection{Supplying Type Facts to the Remaining Code}

% [R16]
Separating $C_I$ is useful only if its results remain available where
the rest of the function uses them. PyTT checks $C_I$ using local
operation semantics and callee PSTCs, and supplies the inferred type
facts to their subsequent uses in $C_D$. In the figure, each analysis of
\texttt{h(v, a)} can start with the known integer type of \texttt{v}; it
does not need to infer \texttt{g(c)} again for each possible type of
\texttt{a}. A conflict encountered while checking $C_I$ is passed to
Phase~III, just as a conflict in the remaining code would be.

% [R17]
These facts must remain tied to the execution that establishes them.
A fact produced by an operation applies after that operation succeeds,
and an intervening write can change the contents of the location it
describes. PyTT therefore retains each fact's condition, value or
location version, and supporting source or contract. It also preserves
the source positions and control dependencies of $C_I$ and $C_D$, so
that their checks and updates can later be assembled in execution order.
Branches, shared-state writes, and exceptional continuations in $C_I$
remain part of the summarized behavior. Phase~I thus provides reusable
facts for path analysis without discarding the conditions of their use.

\subsection{Phase II: PSTC Generation}
\label{sec:pstc-generation}

% [R18]
Phase~I determines the type facts that can be shared across calling
conditions. It does not yet determine the behavior of $C_D$, such as the
result of \texttt{h(v, a)} for different types of \texttt{a}. To construct
a PSTC, PyTT must now associate the remaining behavior with the conditions
under which it occurs. It does this in two steps. Static analysis first
identifies the explicit paths through the source code. The LLM then
infers the type-dependent behavior within those paths, allowing PyTT to
construct their entry and exit assertions.

\subsubsection{Separating Explicit Execution Paths}

% [R19]
Different branches can perform different updates, so combining their
results before recording their conditions would lose information needed
by the contract. PyTT uses static analysis to extract explicit paths
through $C_D$ within the configured bounds. Each path retains its guards
and operations in source order, along with the facts from Phase~I
available at each use. These are the initial \emph{Type Paths} in
Figure~\ref{fig:method-overview}.

In \texttt{encode\_message}, the body test separates the path that calls
the encoder and assigns its result from the path that leaves the body
unchanged. This separation identifies where an update occurs and the
body condition under which it occurs. It does not yet determine the
type of the value returned by the encoder on the updating path.

\subsubsection{Resolving Implicit Paths}

% [R20]
The remaining uncertainty arises because a source operation can select
different behavior for different operand types. The encoder call uses
the implementation provided by its argument; similarly,
\texttt{x + y} can perform arithmetic, concatenate strings, or invoke a
user-defined method. Enumerating source branches alone does not separate
these implicit paths. Their requirements and effects must be determined
to obtain the type-state changes along an explicit path.

PyTT uses an LLM to infer these paths from the source operations and
their type context. The context includes the facts established in
Phase~I, relevant repository type information, and available callee
PSTCs. It supplies both the operations requiring analysis and the known
types and function behavior on which that analysis can build. The LLM
proposes the entry conditions, operation requirements, and resulting type
facts for the implicit paths.

% [R21]
PyTT combines these results with the ordered checks and updates from
$C_I$ and $C_D$ to form cases $(p,m,q)$. For the updating path of
\texttt{encode\_message}, the return type of each encoder determines the
type stored by the subsequent assignment. Keeping the encoder condition
with that assignment yields a string-body case for \texttt{TextEncoder}
and a bytes-body case for \texttt{Utf8Encoder}. Together with the
unchanged-body path, these cases form the helper's PSTC. Each case
retains its source locations, inference context, and supporting
dependencies, so that the analysis can revisit how its facts were
obtained if they later cause a conflict.

\subsubsection{Applying Contracts to Check Caller Operations}
\label{sec:composition}

% [R22]
The constructed PSTC describes the callee in terms of its parameters and
the shared locations it accesses. To use it for a particular call, PyTT
must first relate those references to the caller's values and objects.
After evaluating the call target and arguments in source order and
checking argument binding, PyTT constructs a substitution $\theta$ for
this correspondence. For example, the helper's message parameter is
mapped to the message object passed by \texttt{make\_line}.
This instantiation allows an update expressed through the callee's
parameter to affect the same field that the caller later reads.

If two arguments refer to the same object, the substitution preserves
their shared identity. Internal symbols and newly allocated objects are
fresh for each call. These rules keep shared locations connected without
merging objects that belong to different invocations. The same
composition procedure is used when constructing caller contracts and
when analyzing calls under given entry conditions.

% [R23]
After mapping the references, PyTT determines which cases are relevant
to the call. Let $A$ be the caller's abstract state and
$\operatorname{Facts}(A)$ its type facts and path conditions. For a case
$(p_i,m_i,q_i)$, PyTT considers
\begin{equation}
    \operatorname{Facts}(A)\land\theta(p_i).
    \label{eq:applicability}
\end{equation}
The conjunction restricts the calling states to those satisfying the
case's entry assertion. An inconsistent case is excluded. A case that
remains is analyzed under the combined condition, which is retained
with its results. Several cases may apply to different parts of the
calling state; consistency does not show that one case covers every
possible execution. If the available cases leave states uncovered, PyTT
requests further analysis or records those states as unresolved. Lack
of a matching case alone does not establish a type error.

% [R24]
For each relevant case, PyTT follows the instantiated path in execution
order to determine the state used by subsequent operations. Guards
restrict the current condition, reads use the facts for the current
location contents, and writes update those facts. On normal return,
the exit assertion describes the resulting return value and shared
state; it records the effects already processed along the path without
applying them a second time.

A shared-state update must reflect which object is written. If the
write definitely targets one location of a single object, PyTT replaces
its previous type fact with the new one, a \emph{strong update}. If
several targets are possible, a \emph{weak update} retains the possible
old and new contents. Facts about locations known to be unaffected
remain available. An unknown write invalidates precise facts for the
region it may affect. These rules ensure that later checks use facts
that account for the call's possible writes.

% [R25]
As PyTT processes each operation, it checks the values used by that
operation against the state established by the preceding steps. For an
operation with requirement $R$ and current facts $F$, it examines the
success condition $F\land R$
and failure condition $F\land\neg R$. These describe the states in which
the operands satisfy or violate the operation's requirement. A supported
failure case becomes a candidate conflict and retains the source
location and facts supporting the check. Indeterminate conditions remain
unresolved. Normal continuation uses the success facts, while
exceptional continuation carries the state established up to the
failed operation.

% [R26]
At the motivating call, the caller's guard establishes a string body
and the encoder argument is a \texttt{Utf8Encoder} instance. These facts
select the case that writes bytes to the shared body. The following
concatenation is consequently checked with a bytes operand and produces
a bytes/string conflict. Replacing the encoder with
\texttt{TextEncoder} selects the string-body case and satisfies the same
operation requirement. The contract now provides the conditional update
needed to distinguish the calls. Since that contract was inferred,
however, a conflict obtained from it still requires the investigation
described next.

\subsection{Phase III: Type Conflict Analysis}
\label{sec:conflict-analysis}

% [R27]
The preceding phases check operations using type facts propagated from
inferred contracts. If a contract loses a condition or assigns the wrong
type to an update, a caller can receive an inaccurate fact and appear
to perform an invalid operation. Inspecting only the operation cannot
determine whether the program produces the conflicting value or the
contract merely predicts it. PyTT therefore returns to the source
behavior that established the disputed fact and analyzes it under the
calling conditions. This phase first constructs a conflict trace and
then uses that trace to decide whether to report an error or revise a
contract.

\subsubsection{Constructing a Conflict Trace}

% [R28]
Reexamining every callee body would repeat analysis unrelated to the
conflict. The path descriptions and supporting dependencies retained in
the PSTCs allow PyTT to select the relevant behavior. Starting from the
conflicting operation or annotation check, PyTT follows the conditions,
values, and shared-object references that support its type facts. It
uses the contributing callee cases to identify which paths need to be
expanded in the call graph.

PyTT connects those callee paths to the caller fragments leading to the
conflict. The resulting \emph{conflict trace} retains guards, operation
requirements, writes, and exceptional control flow, together with the
call-site bindings established during composition. A write through a
callee parameter can thus be followed to a later read through the
caller's reference. The trace provides the source operations and calling
conditions needed to reassess the disputed transition.

\subsubsection{Distinguishing Errors from Contract Inaccuracies}

% [R29]
Using the expanded trace, PyTT re-infers the type-state changes and
checks the operation or annotation that produced the conflict. For the
motivating example, the trace connects the string guard to the encoder
call, the field assignment, and the final concatenation. With
\texttt{Utf8Encoder}, the encoder returns bytes and the helper stores
them in the body. The concatenation then raises \texttt{TypeError}, which
escapes \texttt{make\_line}. The trace supports a runtime type-error
report because it explains both how the bytes value arises and why the
operation fails under that calling condition.

Suppose instead that an inaccurate contract predicts a bytes update for
a \texttt{TextEncoder} call. Expanding the encoder's behavior reveals
that it returns the string unchanged. The conflicting bytes fact is
then unsupported by the source behavior. PyTT corrects the contract
under the text-encoder condition and dismisses the resulting false
alarm. If the expanded analysis cannot establish an error or justify a
correction, the candidate remains unresolved.

% [R30]
The correction must be recorded in the contract so that subsequent
callers receive the revised transition. PyTT adds or revises the
relevant case, corresponding to the \emph{Missing Path Contract} in
Figure~\ref{fig:method-overview}. Depending on the inaccuracy, this can
restore a condition associated with an update, correct a type
combination, distinguish object-identity cases, or supplement an
uncovered entry case. A correction retains the calling conditions
under which it was established. Other functions may already have used
the previous case, so updating this contract also requires revisiting
their dependent results, as described in Section~\ref{sec:reuse}.

\subsubsection{Determining What to Report}

% [R31]
The trace must support the kind of error being reported. For a
\emph{runtime type error}, it must reach an operation with incompatible
operand types or unmet protocol requirements and show that the resulting
type-related exception escapes the analyzed entry. For a repository
entry, the trace includes the initialization and calls establishing that
state. For an open entry, the report records the symbolic arguments and
state assumptions under which the failure occurs. If a handler consumes
the exception, PyTT records a handled failure. A corrected contract that
removes the conflict leads to dismissal, while insufficient evidence
leaves the candidate unresolved. Reports retain the trace, re-inference
context and result, and exception disposition.

% [R32]
An \emph{annotation-contract error} concerns whether a declaration agrees
with the behavior of the code. PyTT checks whether declared input types
meet the requirements of the operations using them, and whether returned
or stored values satisfy their declared types. A conflict undergoes the
same tracing and contextual re-inference as an operation conflict. A
confirmed report identifies the declaration, the incompatible case, and
the supporting behavior. Because the claim concerns the declaration's
agreement with the code, it does not require a repository call that
raises an exception. This separates the evidence needed for annotation
conflicts from the runtime failures described above.

\subsection{Interprocedural Refinement and Reuse}
\label{sec:reuse}

% [R33]
Phase~III can correct a callee contract, but that correction alone does
not update results already computed for its callers. PyTT records the
contract dependencies of those results so that it can identify which
analyses need to be repeated. When a PSTC changes, PyTT assigns it a new
version, invalidates results that used its previous version, and
re-enqueues the affected caller entries. Reanalysis can in turn change
their contracts and propagate the correction to further callers.
Algorithm~\ref{alg:analysis} summarizes this feedback through a worklist
of functions and their calling states.

\begin{algorithm}[t]
\caption{PSTC propagation and conflict-driven refinement}
\label{alg:analysis}
\begin{algorithmic}[1]
\Require Repository $P$, fixed call graph $G$, entries $E$, budgets $B$
\Ensure Runtime reports, annotation-contract reports, and unresolved cases
\State Initialize PSTCs and a callee-first worklist $W$ from $G,E$
\While{$W\neq\emptyset$ and analysis budget remains}
  \State Remove a function entry $(f,A)$ from $W$
  \State Infer entry-independent facts and extract explicit and implicit paths
  \State Construct or supplement $\mathit{PSTC}(f)$ using these results
  \State Apply PSTCs under $A$ and collect operation and annotation conflicts
  \For{each candidate conflict $c$}
    \State Trace supporting conditions, values, object identities, and callee cases
    \State Expand relevant paths and re-infer behavior in the calling context
    \If{a supporting PSTC changes}
      \State Revise the PSTC and invalidate dependent results
      \State Enqueue affected caller entries in $W$
    \EndIf
    \State Classify $c$ using its error category and current evidence
  \EndFor
\EndWhile
\State Retain uncovered states and undecided candidates as unresolved
\end{algorithmic}
\end{algorithm}

% [R34]
Repeated analysis also creates opportunities to reuse work that remains
applicable. The facts from Phase~I, common path prefixes, and callee
PSTCs can serve multiple cases and callers. Reusing a PSTC still requires
instantiating its references and refreshing internal symbols for the
current call. Reusing an already computed call result additionally
requires matching its relevant entry state, object identities, call
targets, analysis assumptions and settings, exploration bounds, and
supporting contract versions. These conditions tie reuse to the facts
on which the result depends. The check includes dependencies of reads,
checks, and updates; instances with unknown read or write locations are
recomputed. A cached failure is reconsidered under the current entry's
reachability and exception handling.

% [R35]
Reuse reduces repeated work but does not remove the growth in path
combinations. PyTT bounds path exploration, loop and recursive expansion,
and conflict refinement. Refinement of a candidate stops when its
outcome is established, no new evidence is obtained, or its budget is
exhausted. Unexamined continuations, uncovered states, and undecided
conflicts remain unresolved. The complete cost includes shared fact
inference, path construction, call-site composition, trace expansion,
contextual re-inference, and dependency maintenance, including caller
reanalysis after corrections. Section~\ref{sec:rq2} evaluates this cost
and examines reuse in comparison with direct function-body analysis.
~~~

## 逐处修改说明

以下以前一版 Markdown 的 M 编号定位原内容；R 编号是本轮正文标记。备注关注“原先跳过了哪一步推理、现在在哪里补上”，不再只解释措辞变化。

### 从检测需求进入总览

**R01｜原 M01，保留导航、降低入口负担。** 章节开头介绍要解释的检测过程。契约为何必要由 R02 接着说明，保证读者先知道本节要解决什么，再了解完整机制。

**R02｜原 M02，先说明为何使用契约。** 原首段从构建调用图和调度函数开始，读者还不清楚为何要先分析 callee。新版先建立“调用后检查需要调用建立的类型—PSTC 记录这种信息—caller 使用契约”的关系，再引出 callee 优先的调度。此时调度顺序有了已知的信息依赖依据，借鉴 V3 在迭代步骤之前先解释 EDG 的用途。

**R03｜原 M03，先引出重复工作再提出简化。** 原总览直接说 identify context-free computations，是从方案起笔。新版先说明同一计算会随不同调用条件反复分析，再介绍识别、检查与复用。将 `g(c)` 细节留给 R15–R16，避免总览尚未建立三阶段关系就进入局部执行过程。

**R04｜原 M04，明确承接简化后的剩余任务。** 新版以 remaining code 开始，说明 Phase I 的事实并未确定条件相关行为，再介绍显式/隐式路径如何形成契约。读者能看出 Phase II 是完成尚未解决的工作，而非与 Phase I 并列的另一项工具能力。

**R05｜原 M05，保留冲突分析的必要性。** 原段已区分真实错误和契约不准确，新版将其紧接在“生成的契约用于检查”之后，强调冲突依据来自推断，因此需要调查。总览保留判错、修正和 unresolved 三种结果，具体证据规则在 R31–R32 展开。

**R06｜原 M06，说明阶段如何相互影响。** 保留契约由 callee 流向 caller 的关系，并由此解释为什么契约修正会触发下一轮。版本失效和工作队列细节移至 R33，在读者理解修正过程后再出现；挑战对应仍保留，但不再用编号替代因果解释。

### 由表示需求引出 PSTC 的组成

**R07｜原 M07、M12，先提出摘要需要解决的两个缺口。** 原稿很快宣布 PSTC 具体化 Hoare triple，随后进入映射定义。新版先回接 motivating example 的共享更新与条件保留需求，分别说明 `None` 返回和合并字段类型缺少哪项信息，再提出需要条件摘要。这里的例子承担需求定位，R13 才用同一场景解释定义后的契约组成。

**R08｜原 M08，先解释为何要有 locations。** 在写映射公式之前补上摘要必须指向 callee 读写的变量和属性这一需求。公式后的解释保留，并将共享对象更新与 caller 后续读取联系起来，使映射成为表达状态变化的手段，而不是突然出现的数学对象。

**R09｜原 M09，先解释为何需要 assertions。** 从“已经能描述更新，但还需说明更新何时适用”引出状态断言。再用入口条件与出口事实解释断言之间的关联。保留 branch conditions 和 object identity 的范围，不在此处提前展开身份匹配规则。

**R10｜原 M10 中的路径说明，独立补足设计理由。** 原稿直接列出路径里有什么，没有解释为什么已有 `(p,q)` 还要存 `m`。新版说明入口—出口关系用于传递类型事实，而检查和追查这些事实还需要知道产生它们的操作。由这个具体需求引出有序路径，为 Phase III 的展开选择提供先前依据。

**R11｜原 M10，推迟完整形式定义。** 现在读者已经分别知道入口/出口断言与路径为什么必要，再将三部分组成 `(p,m,q)` 并给出 PSTC 集合定义。公式不承担首次介绍全部对象的任务；后面仍保留一句执行用途解释，避免只给符号释义。

**R12｜原 M11，在模型用途明确后限定保证。** 保留部分正确性、正常返回条件、异常继续路径和推断误差。限定围绕“caller 可以使用哪些事实”展开，不恢复保证终止或单一入口决定路径的错误含义，也不以严格性为由提前列出所有实现边界。

**R13｜原 M12，实例后明确转入构造问题。** 例子按入口—路径—出口解释两种 encoder，保留非字符串路径不变这一情况。段末承认目前只定义了应记录什么，接下来还要解释如何从代码取得这些信息及避免重复分析，直接引出 Phase I。

### 由构造成本引出简化，再说明简化能提供什么

**R14｜原 M13，补出跨调用路径组合到重复分析的中间环节。** 原稿概括“不同条件和路径导致重复”。新版明确路径中的调用还要考虑 callee 路径，若每种组合都重分析整段函数，入口无关计算也被重复处理。共享分析由这个成本来源引出，不声称消除路径爆炸。

**R15｜原 M14–M15，围绕是否能共享分析组织定义。** 先承接上段的问题“哪些计算可这样处理”，再定义 context-free、检查依赖并区分 `C_I/C_D`，最后用图中例子解释一次划分。共享状态依赖的限定放在例子之后，纠正“参数已知就足够”的误读，同时不打断定义入口。

**R16｜原 M16，说明划分为什么还需要结果传播。** 原文从“检查 `C_I`”继续列动作。新版先指出仅分离代码还没有让剩余分析获益，必须把结果提供到使用位置，再描述检查与传播。图中的 `v:int` 此时用于解释共享怎样减少重复工作，职责区别于 R15 的分类示例。

**R17｜原 M17，先提出事实失效风险再解释元信息。** 原稿较早枚举 version/source/control 信息。新版先说明事实只能在生产操作成功后使用且会被后续写入改变，因此需要条件、位置版本和执行顺序。这些细节有了保障结果适用性的理由，原分支、更新和异常语义全部保留。

### 由简化的局限引出条件行为提取

**R18｜原 M18，明确 Phase I 尚未完成什么。** 原入口说“using facts ... next constructs”，只有时间先后。新版具体指出共享事实没有决定 `h(v,a)` 随 `a` 改变的行为，因此还必须将剩余行为与条件关联。随后才引出显式路径与隐式路径两步，建立分析依赖而非流程清单。

**R19｜原 M19 和 M21 的显式分支说明，先说明为何分路径。** 新版先指出不同分支更新若提前合并会丢失条件，再提出静态路径提取。`encode_message` 例子说明该步已经区分“会不会更新”，但尚未确定“更新为什么类型”，由一个具体剩余问题引出下节。

**R20｜原 M20 和 M19 的隐式行为说明，先说明显式路径为何不够。** 新版承接 encoder 返回类型尚未确定，解释行为取决于所选实现；列出加法作为通用机制的补充后，再提出 LLM 推断和所需上下文。没有把“枚举源分支不够”扩大成“静态分析无法处理类型相关行为”的泛化主张。

**R21｜原 M20–M21，解释隐式推断如何完成最初的契约定义。** 先把推断结果与有序操作组合为 `(p,m,q)`，再逐步连接 encoder return 与 body assignment，回到 R13 中需要构造的案例。源位置、上下文和依赖的保留紧接其用途——冲突时能追查事实来源——而不是独立列存储字段。

### 由契约与本次调用之间的距离引出组合检查

**R22｜原 M22，明确为何先要实例化。** 以 callee 的形参与 caller 的实际对象不同为入口，先解释 `θ` 如何让字段更新作用到 caller 随后读取的对象，再给共享身份与 fresh identities 规则。读者先理解“对应到同一个对象”这一核心操作，才处理多个参数或多次调用的细节。

**R23｜原 M23，将筛选案例写成映射之后的下一项需求。** 映射完成只解决位置对应，仍需判断当前调用涉及哪些契约案例。因此引出合取公式，再解释一致性、条件保留和覆盖边界。把原 M21 提前出现的未覆盖输入处理集中到此处，因为此时读者已理解什么叫匹配和覆盖。

**R24｜原 M24–M25，把强弱更新放在传播更新的需求之后。** 先解释按路径得到后续操作使用的当前状态，再说明必须确定写入目标才能正确更新事实。强更新、弱更新、未知写入规则均保留。原 `a.prefix/b.prefix` 独立例子删除，其“共享身份决定哪些读受影响”的功能已由 R08、R22 和本段目标位置规则连续承担，避免主线中途再学习一套对象。

**R25｜原 M26，把操作检查接在状态传播的说明之后。** 新段首说明每个操作使用的是前序步骤建立的状态，再给成功/失败条件；这解释传播和检查的关系，不暗示先执行完整条路径的更新再统一检查。保留候选证据及正常、异常继续路径。循环和递归预算移到 R35，与全章探索边界一起解释，避免在操作检查规则中突然转入成本控制。

**R26｜原 M27，以示例回扣传播再自然引出核查。** 保留 guard、encoder、字段更新、拼接的执行链及两个 encoder 的区别。段尾指出契约来自推断，所以冲突仍需调查。由这一未解决问题进入 Phase III，而不靠一个新标题重新宣告研究挑战。

### 由候选冲突的证据不足引出 trace 和修正

**R27｜原 M28，明确为什么查看报错操作本身不够。** 原段说推断可能不准，所以要展开；新版进一步指出局部操作不能区分“程序真的生成冲突值”和“契约预测了这个值”。因此需要回到产生该事实的源行为。这一步解释 trace 必须跨调用边界的原因。

**R28｜原 M29，由全量重分析的成本引出选择性展开。** 新版先说明无差别重看所有 callee 会重做无关工作，再回接 R10、R21 已保留的路径与依赖，使读者理解此前记录的信息现在如何发挥作用。随后才展开从事实到案例、从案例到 caller/callee trace 的操作步骤。

**R29｜原 M30，围绕同一条证据链说明两种判定。** UTF-8 例子解释冲突值如何实际产生以及操作为何失败；假设的 TextEncoder 误报解释哪个事实不被源行为支持。后一种情形继续用 Suppose 标为假设，未冒充工具实验结果。无法得到支持错误或修正的证据时保留 unresolved。

**R30｜原 M31，将“修正当前判断”推进到“修正可复用契约”。** 新段首先说明只判断这个候选还不能让后续 caller 获益，因此要把修正写回契约。保留各种修正类型及调用条件，再指出已有 caller 仍使用旧结果，把跨函数失效与重分析的完整解释留到 R33。局部修正与全局反馈不再挤在同一段。

**R31｜原 M32，将报告标准作为 trace 分析后的证据要求。** 段首说明证据随报告类别不同，再保留 runtime 的可达、异常逃逸、repository/open entry、handled/dismissed/unresolved 要求。这部分仍在基本调查过程之后，读者先理解如何得到证据，再理解何种证据足以报告。

**R32｜原 M33，解释注解报告为何需要另一套判定边界。** 先建立 declaration 与 behavior 的关系，再解释输入与返回/存储类型的检查以及相同 trace 流程，最后说明不要求实际调用抛异常的原因。这里的差异对应 introduction 已区分的错误类别，不扩张检测任务。

### 由跨函数修正引出迭代，再深入复用条件与成本

**R33｜原 M31 的依赖传播、M34 的算法，重组。** 最后一节改为 Interprocedural Refinement and Reuse。先说明改 callee 契约并不会自动改已算好的 caller 结果，再引出依赖记录、版本失效、重新入队和进一步传播。算法放在这些机制之后归纳流程，原标签保留；工作队列此时对应一个已经说明的实际需求。

**R34｜原 M35–M36，复用细节在重分析需求之后出现。** 原稿单列 Reuse and Cost，较像追加实现清单。新版从重复分析中仍有可继续使用的工作引出复用，再说明“复用契约”与“复用算好的调用结果”的条件不同。原 entry state、alias、target、配置、预算、依赖版本、读写范围和异常上下文条件均保留，但先有为何复用、为何检查适用性的理由。

**R35｜原 M31 的停止条件、M26 的扩展边界及 M37 的成本，集中收束。** 在复用解释后承认路径组合仍可能增长，因此需要预算；再说明何时停止、哪些结果 unresolved、评估计入哪些成本。保留无新证据终止、loop/recursion bounds 和 caller reanalysis 口径，未暗示预算终止代表分析完整或无错。

## 结构与技术边界核对

- 保留 introduction 的三个挑战及其对应关系；总览不承担完整机制证明。
- 保留背景中的正常返回语义，区分状态与断言；PSTC 是 Hoare 结构的具体化。
- `p`、`m`、`q` 分别由适用条件、追查源行为和调用后事实的需求引出，再一起形式化。
- Phase I 结尾提供可复用事实；Phase II 明确还需确定条件相关行为；Phase III 明确还需判断冲突来源。
- 共享对象映射、更新语义、未覆盖输入、异常处理、依赖版本、预算和 unresolved 均保留，调整其进入叙述的位置。
- 示例各有职责：模型说明记录什么，Phase I 图示说明哪些工作可共享，Phase II 说明如何构造和应用，Phase III 说明如何核查来源。
- 原章节与图、公式、算法标签保留；`sec:reuse` 对应的新标题涵盖迭代修正和复用，不新增机制或实验结果。
- 本轮不以缩短为目标，也不要求每段机械套用“however/therefore”。已清楚的定义和操作说明直接保留必要展开，只有真实存在的剩余问题才引出下一方案。
