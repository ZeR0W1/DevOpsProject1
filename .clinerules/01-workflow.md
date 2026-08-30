# Project workflow rules

## Gather context before acting

- Treat the files in `/home/geeta/Project1/.clinerules/` as the authoritative
  project instructions and current rolling status.
- Read `/home/geeta/Project1/misc/DevOps_on_AWS_-_-_k8s__Docker.pdf` when a
  fresh task requires assignment interpretation, compliance decisions, or work
  not already grounded by the current project rules/status. Do not reread it
  routinely for implementation steps whose requirements are already established.
- Gather only the context needed for the current task. Prefer targeted reads and
  searches over broad repository rereads.
- Do not assume a user handoff supersedes the repository, assignment, or current
  project rules.
- If current external state materially affects a decision, reverify only the
  relevant state read-only rather than relying on dated status/history.

## Prefer integrated workspace tools

- Prefer dedicated workspace tools over shell equivalents when they are more
  precise or reduce unnecessary output: use file-reading tools for file content,
  code-search tools for discovery, and patch tools for edits.
- Shell commands, including `rm`, are allowed when appropriate, but all deletion
  approval and ownership rules still apply.
- Never include the shell `exit` builtin in commands executed through workspace
  tools. It can close the integrated terminal without returning a usable result
  to the output-capture tool, even though the command itself completes as
  intended; preserve status with command chaining, bounded `timeout`, or a
  separate check instead.
- Do not use inline Python, shell heredocs, compound multi-line shell programs,
  or long compound one-liners that combine setup, background-process lifecycle,
  secret retrieval, validation, cleanup, and status propagation. For longer
  logic, create a readable script through the editor as a separate project-file
  edit, then invoke it with a short command.
- Keep command output scoped to what is needed for the current decision. Avoid
  broad listings, dumps, or recursive output when a narrower query is sufficient.
- If execution completes but output capture fails, treat the command as completed
  but do not claim or infer output that was not captured.

## Edit and validate safely

- Edit one workspace file per editor/patch tool call. This is a workaround for
  the legacy Cline multi-file approval UI bug, not a prohibition on concise,
  explicitly approved batch filesystem operations.
- After exact paths and ownership are verified, one short shell command may move
  or delete multiple explicitly approved files.
- Use exact, unique patch context; never rely on fuzzy patching.
- Never delete a file or directory without first receiving explicit user
  approval. This includes editor deletion, delete-and-recreate rewrites, shell
  deletion, cleanup, and removal of untracked artifacts.
- Normalize line endings only when needed and only for project-owned files.
- Verify edited or created files to the extent needed for the change. Run the
  smallest relevant validation or test set first; broaden validation only when
  the change, failure, or dependency surface justifies it.
- Do not modify imported Ansible roles unless the user explicitly changes that
  boundary.
- Use absolute paths when referring to workspace files in task communication.
- Compensate for legacy Cline bundle limitations with one-file patches, short
  commands, focused Git inspection, and concise status updates. Do not rely on
  checkpoints as the sole safety mechanism.

## Preserve repository ownership

- Before broad Git operations, check current status and preserve unrelated work.
- Do not commit or push unless the user asks for it.
- Follow `03-cloud-and-terraform-safety.md`; if unintended secret exposure is
  suspected, stop exposing further output and alert the user.

## Keep current status and history separate

- Maintain `90-current-project-status.md` as the authoritative compact current
  state and resume record. Follow its own maintenance rules when updating it.
- Store completed milestones, dated evidence, superseded states, validation
  history, and recovery provenance in
  `/home/geeta/Project1/misc/recovery/PROJECT_HISTORY.md`.
- Do not routinely read the full history file. Consult only the relevant
  historical section when provenance, an earlier decision, or recovery context
  is needed.
- At the end of a work session, update the current-status file only when current
  truth, blockers, active work, or the resume point materially changed. Add to
  `PROJECT_HISTORY.md` only for durable milestones or useful provenance.
- Keep task-local progress checklists consistent with the current-status file,
  but do not copy full task transcripts or tool output into either recovery file.