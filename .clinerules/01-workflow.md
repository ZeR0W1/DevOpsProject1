# Project workflow rules

## Gather context before acting

- Treat the files in `/home/geeta/Project1/.clinerules/` as the authoritative
  project instructions and rolling status.
- Read `/home/geeta/Project1/misc/DevOps_on_AWS_-_-_k8s__Docker.pdf` before making
  implementation or final-compliance decisions about the assignment. Do not rely
  only on summaries of its requirements.
- Read every file relevant to the next edit immediately before editing it.
- Inspect relevant Git status and diffs before changing tracked work.
- Gather enough context to follow existing conventions. Do not assume a user
  handoff supersedes the repository, assignment, or current project rules.
- If current external state matters, reverify it read-only rather than assuming a
  dated status entry is still true.

## Prefer integrated workspace tools

- Prefer dedicated workspace tools over shell equivalents whenever possible:
  use file-reading tools for file content, code-search tools for discovery, and
  patch tools for edits.
- Use terminal commands only when the operation genuinely requires a command,
  such as Git inspection, Terraform validation, builds, or tests.
- Do not use inline Python, shell heredocs, or compound multi-line shell programs.
  For longer logic, create a readable script through the editor as a separate
  project-file edit, then invoke it with a short command.
- If execution completes but output capture fails, treat the command as completed
  but do not claim or infer output that was not captured.

## Edit and validate safely

- Edit one workspace file per editor/patch tool call. This is a workaround for
  the legacy Cline multi-file approval UI bug, not a prohibition on concise,
  explicitly approved batch filesystem operations. After the exact paths and
  ownership boundary are verified, one short shell command may move or delete
  multiple approved files.
- Use exact, unique patch context; never rely on fuzzy patching.
- Never issue a file or directory deletion action without first asking the user
  and receiving explicit approval. This includes editor delete operations,
  delete-and-recreate rewrites, shell deletion, cleanup, and removal of untracked
  artifacts, even when the tool or UI would not normally pause for approval.
- Normalize line endings only when needed and one project-owned file at a time.
- Verify every edited or created file and run the relevant validation or tests.
- Do not modify imported Ansible roles unless the user explicitly changes that
  boundary.
- Use absolute paths when referring to workspace files in task communication.
- Compensate for legacy Cline bundle limitations with one-file patches, explicit
  post-edit reads, short commands, Git inspection, and concise status updates. Do
  not rely on checkpoints as the sole safety mechanism.
- Avoid sequential multi-file editor/patch approval operations because legacy
  approval buttons can become stuck. Tasks created under the `next` bundle may be
  hidden in legacy, but workspace files remain authoritative.

## Preserve the mixed workspace

- Assume the workspace can contain unrelated pre-existing staged, modified,
  deleted, and untracked work.
- Never broadly stage, revert, delete, clean, or attribute all current differences
  to the active task.
- Never use `git add .`; if staging is requested, stage explicit paths only.
- Do not revert unrelated changes or remove untracked files without explicit
  approval after establishing their ownership and purpose.
- Do not commit or push unless the user asks for it.
- Never expose credentials, tokens, private keys, secret values, ignored variable
  files, or sensitive command output. Inspect only specifically required,
  non-secret values.

## Keep status useful

- Maintain `90-current-project-status.md` as the rolling recovery/status record.
- Preserve provenance: distinguish newly completed work from pre-existing changes.
- Label dated inventories and milestones clearly. When a newer verification
  supersedes an older one, retain only useful history and identify the current
  boundary unambiguously.
- At the end of every work session, including partial or interrupted sessions,
  update `90-current-project-status.md` with completed work, validation performed,
  the current safety/ownership boundary, unfinished work, and the exact resume
  point. Keep task-local progress checklists consistent with that durable record.