#!/usr/bin/env python3
"""Table-driven tests for deny-master-push.py. Run: python3 .cursor/hooks/test_deny_master_push.py"""

from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HOOK = os.path.join(os.path.dirname(__file__), "deny-master-push.py")

spec = importlib.util.spec_from_file_location("deny_master_push", HOOK)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)

# command, should_deny, label
DENY_ON_FEATURE = [
    ("git push origin master", "master dest"),
    ("git push origin master --no-verify", "master dest flags after"),
    ("git push -u origin master", "upstream master"),
    ("git push origin HEAD:master", "HEAD:master"),
    ("git push origin feature/x:master", "refspec to master"),
    ("git push origin HEAD:refs/heads/master", "HEAD:refs/heads/master"),
    ("git push origin refs/heads/master", "refs dest"),
    ("git push origin HEAD master", "HEAD then master"),
    ("git push origin master HEAD", "master then HEAD"),
    ("git push --force origin feature/foo", "force feature"),
    ("git push -f origin feature/foo", "short force"),
    ("git push --force-with-lease origin feature/foo", "lease"),
    ("git push origin +master", "plus master"),
    ("git push origin +feature/foo", "plus feature is force"),
    ("git push --all", "all includes master"),
    ("gh pr merge 12", "gh pr merge"),
    ("gh pr merge 12 --squash", "gh pr merge flags"),
    (
        "gh api -X PUT repos/ifrit99/SmartPhoneSpecBattle/pulls/12/merge",
        "gh api PR merge",
    ),
    (
        "gh api -X PUT repos/ifrit99/SmartPhoneSpecBattle/pulls/12/merge?merge_method=squash",
        "gh api PR merge query",
    ),
    (
        "gh api --method POST repos/ifrit99/SmartPhoneSpecBattle/merges",
        "gh api repo merges",
    ),
    (
        "gh api graphql -f query='mutation { mergePullRequest(input: {}) { clientMutationId } }'",
        "gh api graphql mergePullRequest",
    ),
    ("git -C . push origin master", "git -C"),
    ("git -C /tmp/repo push origin HEAD:master", "git -C HEAD:master"),
    ("bash -c 'git push origin master'", "bash -c"),
    (
        "docker compose exec flutter-dev bash -c 'git push origin master'",
        "docker wrap",
    ),
    ("cd sub && git push origin master", "cd then push master"),
    ("cd /tmp && git push origin HEAD master", "cd then HEAD master"),
    ("git push origin feature/foo:refs/heads/master", "x:refs/heads/master"),
]

ALLOW_ON_FEATURE = [
    ("git push origin feature/a1-agent-master-gate-44a2", "feature with master substring"),
    ("git push -u origin feature/a1-agent-master-gate-44a2", "upstream feature"),
    ("git push origin HEAD", "HEAD on feature"),
    ("git push origin HEAD:feature/a1-agent-master-gate-44a2", "HEAD to feature"),
    ("git status", "status"),
    ("git push", "bare push on feature"),
    ("git push origin", "remote only on feature"),
    ("gh pr view 12", "gh view"),
    ("gh api repos/ifrit99/SmartPhoneSpecBattle/pulls/12", "gh api read PR"),
    ("git log --grep=push", "log grep push"),
    ("git -C . status", "git -C status"),
]

DENY_ON_MASTER = [
    ("git push", "bare push on master"),
    ("git push origin", "remote only on master"),
    ("git push origin HEAD", "HEAD on master"),
]


class DenyMasterPushTests(unittest.TestCase):
    def assert_denied(self, command: str, branch: str, label: str) -> None:
        with patch.object(mod, "current_branch", return_value=branch):
            reason = mod.decide(command, cwd=ROOT)
        self.assertIsNotNone(reason, f"{label}: expected deny for {command!r} on {branch}")

    def assert_allowed(self, command: str, branch: str, label: str) -> None:
        with patch.object(mod, "current_branch", return_value=branch):
            reason = mod.decide(command, cwd=ROOT)
        self.assertIsNone(
            reason, f"{label}: expected allow for {command!r} on {branch}, got {reason!r}"
        )

    def test_deny_on_feature(self) -> None:
        for command, label in DENY_ON_FEATURE:
            with self.subTest(label=label, command=command):
                self.assert_denied(command, "feature/a1-agent-master-gate-44a2", label)

    def test_allow_on_feature(self) -> None:
        for command, label in ALLOW_ON_FEATURE:
            with self.subTest(label=label, command=command):
                self.assert_allowed(command, "feature/a1-agent-master-gate-44a2", label)

    def test_deny_when_checked_out_master(self) -> None:
        for command, label in DENY_ON_MASTER:
            with self.subTest(label=label, command=command):
                self.assert_denied(command, "master", label)

    def test_stdin_json_deny_and_allow(self) -> None:
        def run_hook(command: str) -> dict:
            proc = subprocess.run(
                [sys.executable, HOOK],
                input=json.dumps({"command": command, "cwd": ROOT}),
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(proc.stdout.strip()[-1:], "}", proc.stderr)
            return json.loads(proc.stdout)

        self.assertEqual(run_hook("git push origin master")["permission"], "deny")
        self.assertEqual(
            run_hook("git push -u origin feature/a1-agent-master-gate-44a2")["permission"],
            "allow",
        )
        self.assertEqual(
            run_hook(
                "gh api -X PUT repos/ifrit99/SmartPhoneSpecBattle/pulls/1/merge"
            )["permission"],
            "deny",
        )

    def test_settings_deny_covers_review_gaps(self) -> None:
        settings_path = os.path.join(ROOT, ".claude", "settings.json")
        with open(settings_path, encoding="utf-8") as handle:
            settings = json.load(handle)
        deny = settings["permissions"]["deny"]
        required = [
            "Bash(git push *:master*)",
            "Bash(git push * refs/heads/master)",
            "Bash(git -C * push *)",
            "Bash(cd * && git push *)",
            "Bash(gh api *merge*)",
            "Bash(git push * HEAD master)",
        ]
        for pattern in required:
            self.assertIn(pattern, deny, f"missing deny pattern: {pattern}")

    def test_hook_matcher_includes_gh_api(self) -> None:
        hooks_path = os.path.join(ROOT, ".cursor", "hooks.json")
        with open(hooks_path, encoding="utf-8") as handle:
            hooks = json.load(handle)
        matcher = hooks["hooks"]["beforeShellExecution"][0]["matcher"]
        self.assertIn("gh\\s+api", matcher)
        self.assertIn("git(\\s+\\S+)*\\s+push", matcher)

    def test_invalid_json_is_denied(self) -> None:
        proc = subprocess.run(
            [sys.executable, HOOK],
            input="not-json",
            text=True,
            capture_output=True,
            check=False,
        )
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["permission"], "deny")


if __name__ == "__main__":
    unittest.main(verbosity=2)
