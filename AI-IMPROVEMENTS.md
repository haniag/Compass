# Task: improve how Compass uses Apple Intelligence

Compass writes two kinds of text with the on-device model (Foundation Models):
Pulse's two-sentence briefing (`Compass/Insights/BriefingWriter.swift`) and the
Insights digest cards and "Ask about your numbers" chat
(`Compass/Insights/InsightWriter.swift`). Swift computes every number, the model
only words them, and `InsightCheck`, `BriefingCheck` and `FigureCheck` reject any
draft that breaks the copy rules before it reaches the screen. That design stays
as it is. A review found the improvements below; do them in this order, one per
commit, and build and run the unit tests before each commit.

The owner is not a professional developer. After each step, explain in plain
language what changed and why. If a step turns out to need a decision that isn't
covered here, stop and ask rather than guessing.

Check every Foundation Models API name against the iOS 27 SDK before using it.
The names below are from memory and may be wrong or have changed.

## 1. Save the briefing with the numbers

Today `PulseViewModel.writeBriefing()` keeps the briefing only in memory
(`briefing`, `briefingFacts`), so every launch runs the model again even when the
numbers are unchanged. Pulse already saves its facts through `SavedNumbers.save`
in the refresh code just above `writeBriefing`.

Save the checked briefing text together with the facts it was written from, per
period. When Pulse opens and the saved facts equal the current facts, show the
saved briefing at once and skip the model. Only save text that passed
`BriefingCheck`. Make sure Disconnect removes it along with the other saved
numbers. Add unit tests for "same facts reuse the text" and "changed facts don't".

## 2. Warm up the model while the numbers load

When Pulse appears, Apple Intelligence is available, and there is no saved
briefing for the current facts, prewarm a session (`LanguageModelSession.prewarm`)
so the model is loading while the EN fetch runs. Don't prewarm when the model
won't be used.

## 3. Rename the `getWeeklyNumbers` tool

The period can be yesterday, 7 days, 30 days or last month, so the name tells the
model something false. Rename it to `getNumbers`: the `Tool` struct and its
`name` in `InsightWriter.swift`, the sentence added to the chat instructions in
`NumbersChat.init`, any tests, and the mention in `CLAUDE.md`.

## 4. Handle model errors by type

Two cases get their own handling; everything else keeps today's behaviour.

- Chat context full: in `InsightsViewModel`'s ask method, any error drops the
  chat and fails the answer. When the error is the context-window one, start a
  new `NumbersChat` and ask the same question once more automatically.
- Model still downloading: `InsightWriter.status` folds "model not ready" into
  `.unavailable`. Add a separate status for it, and where the UI explains why AI
  is off, say Apple Intelligence is still getting ready. Templates are shown
  meanwhile, as now.

## 5. Measure pass rates in PromptLab

Before changing any prompt, make it possible to measure. Look at how `PromptLab/`
is set up first. Add a run that takes a few sets of fixture facts (fake data: a
good period, a bad one, a mixed one, for at least two `Fact.Period` values),
generates the briefing and the digest drafts about 20 times each with the app's
real instructions, and reports how often each passes `BriefingCheck` and
`InsightCheck`, plus the most common rejection reasons. Write the report to
`PromptLab/Results/`. If PromptLab can't share the app's prompt and check code
without a large restructuring, stop and describe the options.

Record the baseline numbers. Steps 6 and 7 are judged against them.

## 6. Tell the model what it got wrong on a retry

`BriefingWriter.briefing(from:)` and `InsightWriter.drafts(about:)` retry a
rejected draft up to 3 times with a new session and the identical prompt, so the
model has no idea what to fix. `NumbersChat.answer` already does the better
thing: it stays in the session and says what to change.

- Give `FigureCheck` a way to report why text failed (for example: used "last
  week", quoted 45% which isn't a figure of this fact, wrote "we"). Keep the
  existing true/false function working on top of it so current tests still pass.
- On a rejected draft, stay in the same session and send one short correction
  naming the problem and asking for the text again. Keep the limit of 3 tries.
- Put the reason in the existing `AI` log lines. Never log tokens or personal data.
- The final text must still pass the same checks; nothing is loosened.

Rerun the PromptLab measurement and report before and after.

## 7. Reword the briefing's opening line

The briefing instructions open with "You are a data analyst for a nonprofit.
Summarize these metrics…". Earlier experiments (see "Tested limits" in
`CLAUDE.md`) found analyst framing pushes this model to analyse. Reword the
opening along the digest's lines: the app has already worked out the numbers and
the model only puts them into words. Keep the rules and the worked example.
Keep the change only if the PromptLab pass rate is no worse; report both numbers.

## 8. Show digest cards as each one finishes

`InsightsViewModel.update(facts:)` waits for every fact's draft (up to 9 model
calls) before showing anything. Show the template insights straight away, then
replace each card as its draft passes the check. The final order and content
must match what `InsightCheck.filling` produces today. Insights is on hold, so
do this last and skip it if it turns into a large change.

## Not in scope

- Streaming generated text to the screen: it would show unchecked words.
- Adding AI to the Email or Giving tabs.
- Any new dependency, any network call, any change to what the checks allow.

## Verifying

Use the build and test commands in `CLAUDE.md`. The model only runs in the
simulator when this Mac has Apple Intelligence on; otherwise you will see the
template fallback. For each step, say plainly what you saw working and what you
could not check (for example "built and unit tests pass, but the model path was
not exercised").
