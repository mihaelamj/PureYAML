# Validation Rules

Rules for writing PureYAML validators and validation tests.

## Core Rule

A validator is a diagnostic contract, not just a throwing function. Every new
validation rule must make these parts explicit:

- **Subject**: the YAML value shape the rule inspects.
- **Predicate**: the condition under which the rule runs. Use `when` for
  optional or context-specific checks instead of hiding that logic in the issue
  body.
- **Context**: use `root`, `subject`, and `path` deliberately. If a rule needs
  document-wide knowledge, read it from `root`; if it only needs the current
  node, read it from `subject`.
- **Issue contract**: return path-aware `Issue` values with exact severity,
  reason, and path. Do not report anonymous failures.
- **Default status**: state whether the rule belongs in
  `Validation.Validator.defaultRules` or must be opt-in.

## Test Contract

Every validator change must include Swift Testing coverage for:

- a document that succeeds and returns no issues;
- a document that fails with exact issue values;
- a case where the predicate prevents the rule from running;
- required presence and required absence checks, so false positives are caught;
- exact traversal order when multiple issues are possible;
- strict and non-strict behavior when the rule can emit warnings;
- exact thrown `Issue.Collection` contents for failure cases.

## Implementation Rules

- Keep rules as immutable values under `PureYAML.Validation.Rule`.
- Prefer a `when` predicate over early-returning inside the rule body when the
  rule only applies to a subset of nodes.
- Keep built-in rules deterministic and allocation-conscious. Use sets or maps
  for membership checks instead of repeated linear scans.
- Do not add external dependencies, Foundation, C shims, or platform-specific
  code to validation.
- Do not make validation mutate parsed values. Validation observes and reports.
