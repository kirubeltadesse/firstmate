#!/usr/bin/env bash
# tests/fm-opencode-watch-arm-primary.test.sh - isPrimaryRoot contract for the
# OpenCode watch-arm plugin.
#
# Three behaviors, all hermetic over temp dirs with real node processes and no
# OpenCode installed:
#
#   SECONDMATE  - a valid secondmate home (.fm-secondmate-home marker present and
#                 well-formed) is accepted as a primary scope; the arm script runs.
#   PLAIN       - a plain primary checkout (git-dir == git-common-dir) is accepted;
#                 the arm script runs.
#   WORKTREE    - a git worktree (git-dir != git-common-dir) is NOT accepted; the
#                 arm script must not run.
#
# Each case drives a real node invocation of the plugin with a mock OpenCode
# client, seeds a task meta file so shouldArm passes, and verifies the arm
# script was or was not invoked by checking an output file the fixture arm writes.
#
# The live guard (fm-opencode-primary-live-e2e.test.sh) covers the full plugin
# end-to-end against a real OpenCode session.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# ROOT is exported by lib.sh

command -v node >/dev/null 2>&1 || { printf 'ok - SKIP (node not installed)\n'; exit 0; }

TMP_ROOT=$(fm_test_tmproot fm-opencode-watch-arm-primary)
fm_git_identity fmtest fmtest@example.invalid

PLUGIN="$ROOT/.opencode/plugins/fm-primary-watch-arm.js"

# Install a fixture arm script that records it was called into state/arm-ran.
install_arm_fixture() {  # <dir>
  mkdir -p "$1/bin"
  cat > "$1/bin/fm-watch-arm.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$$" >> "${FM_HOME:-$FM_ROOT_OVERRIDE}/state/arm-ran"
printf 'watcher: FAILED - fixture sentinel\n'
exit 1
SH
  chmod +x "$1/bin/fm-watch-arm.sh"
}

# Install the minimum firstmate skeleton into <dir> without calling git init.
install_skeleton() {  # <dir>
  mkdir -p "$1/bin" "$1/state" "$1/config"
  printf '' > "$1/AGENTS.md"
  install_arm_fixture "$1"
}

# Fire one session.idle event through FmPrimaryWatchArm and wait up to 5 s for
# state/arm-ran to appear.  FM_HOME and FM_ROOT_OVERRIDE are passed as env vars.
run_plugin_session_idle() {  # <fm-root> <fm-home>
  local fm_root=$1 fm_home=$2
  FM_HOME="$fm_home" FM_ROOT_OVERRIDE="$fm_root" \
    node --input-type=module <<NODEEOF
import { FmPrimaryWatchArm } from "${PLUGIN}";
import { writeFileSync, mkdirSync } from "node:fs";

const root  = process.env.FM_ROOT_OVERRIDE;
const home  = process.env.FM_HOME;
const state = home + "/state";
mkdirSync(state, { recursive: true });

// Seed a task meta so shouldArm returns true.
writeFileSync(state + "/fixture.meta", "project=test\n");

// Claim the session lock (write our own pid).
writeFileSync(state + "/.lock", String(process.pid) + "\n");

const mockClient = { session: { promptAsync: async () => {} } };

const plugin = await FmPrimaryWatchArm({
  client: mockClient,
  directory: root,
  worktree: null,
});

// Fire session.idle — the plugin arms and returns; the arm runs in background.
await plugin.event({
  event: {
    type: "session.idle",
    properties: { sessionID: "fixture-session" },
  },
});

// Allow up to 5 s for the arm child to write its marker.
const fs = await import("node:fs");
for (let i = 0; i < 100; i++) {
  if (fs.existsSync(state + "/arm-ran")) break;
  await new Promise(r => setTimeout(r, 50));
}
NODEEOF
}

# ---- SECONDMATE: valid marker on home -> arm must run ----------------------

test_secondmate_home_is_accepted_as_primary_scope() {
  local root home
  root="$TMP_ROOT/sm-root"
  home="$TMP_ROOT/sm-home"

  fm_git_init_commit "$root"
  install_skeleton "$root"
  install_skeleton "$home"

  # Valid secondmate-home marker in home (non-symlink, alphanumeric id).
  printf 'secondmate-test-id\n' > "$home/.fm-secondmate-home"

  run_plugin_session_idle "$root" "$home" 2>/dev/null

  [ -f "$home/state/arm-ran" ] \
    || fail "secondmate home with a valid marker must be accepted as primary scope; arm did not run"
  pass "fm-primary-watch-arm: valid secondmate home is accepted as a primary scope"
}

# ---- SECONDMATE: symlink marker -> falls through to git check -> rejected --

test_secondmate_home_symlink_marker_is_rejected() {
  local base wt home target
  base="$TMP_ROOT/sm-sym-base"
  wt="$TMP_ROOT/sm-sym-wt"
  home="$TMP_ROOT/sm-sym-home"

  # Create a worktree so git-dir != git-common-dir for root.
  fm_git_worktree "$base" "$wt" fm/sm-sym-wt
  install_skeleton "$wt"
  install_skeleton "$home"

  # Symlink marker: fm_root_is_secondmate_home returns 1 for symlinks.
  target="$TMP_ROOT/sm-sym-target"
  printf 'symlink-id\n' > "$target"
  ln -s "$target" "$home/.fm-secondmate-home"

  run_plugin_session_idle "$wt" "$home" 2>/dev/null

  [ ! -f "$home/state/arm-ran" ] \
    || fail "a secondmate marker that is a symlink must NOT accept the home; arm must not run"
  pass "fm-primary-watch-arm: symlink secondmate-home marker is not a valid secondmate; worktree rejected"
}

# ---- PLAIN CHECKOUT: arm must run ------------------------------------------

test_plain_checkout_is_accepted_as_primary_scope() {
  local dir
  dir="$TMP_ROOT/plain"
  fm_git_init_commit "$dir"
  install_skeleton "$dir"

  run_plugin_session_idle "$dir" "$dir" 2>/dev/null

  [ -f "$dir/state/arm-ran" ] \
    || fail "a plain primary checkout must be accepted as primary scope; arm did not run"
  pass "fm-primary-watch-arm: plain primary checkout is accepted as a primary scope"
}

# ---- WORKTREE: arm must NOT run --------------------------------------------

test_git_worktree_is_rejected_as_primary_scope() {
  local base wt
  base="$TMP_ROOT/wt-base"
  wt="$TMP_ROOT/wt-child"

  fm_git_worktree "$base" "$wt" fm/watch-arm-wt-child
  install_skeleton "$wt"

  run_plugin_session_idle "$wt" "$wt" 2>/dev/null

  [ ! -f "$wt/state/arm-ran" ] \
    || fail "a git worktree must NOT be accepted as primary scope; arm must not run"
  pass "fm-primary-watch-arm: git worktree is rejected as a primary scope"
}

# ---- SECONDMATE: valid marker on root itself qualifies even in a worktree --

test_secondmate_root_marker_accepted_in_worktree() {
  local base wt
  base="$TMP_ROOT/sm-root-wt-base"
  wt="$TMP_ROOT/sm-root-wt"

  fm_git_worktree "$base" "$wt" fm/sm-root-wt
  install_skeleton "$wt"

  # Valid secondmate-home marker on root itself.
  printf 'sm-root-id\n' > "$wt/.fm-secondmate-home"

  run_plugin_session_idle "$wt" "$wt" 2>/dev/null

  [ -f "$wt/state/arm-ran" ] \
    || fail "a worktree root with a valid secondmate marker must be accepted as primary scope"
  pass "fm-primary-watch-arm: secondmate marker on root itself qualifies even in a worktree"
}

# ---- run -------------------------------------------------------------------

test_secondmate_home_is_accepted_as_primary_scope
test_secondmate_home_symlink_marker_is_rejected
test_plain_checkout_is_accepted_as_primary_scope
test_git_worktree_is_rejected_as_primary_scope
test_secondmate_root_marker_accepted_in_worktree
