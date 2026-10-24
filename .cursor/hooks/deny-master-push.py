#!/usr/bin/env python3
"""Deny agent git push to master, force-push, and gh pr merge.

Cursor Cloud Agents load project hooks from .cursor/hooks.json.
This is a supplement to GitHub rulesets, not a replacement.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys

DENY_MERGE = "Agents must not merge pull requests. A human merges."
DENY_FORCE = "Force-push is forbidden. Push a feature/ branch without --force."
DENY_MASTER = (
    "Pushing to master is forbidden. Push a feature/ branch and open a PR. "
    "A human merges."
)
DENY_INPUT = "Invalid hook input; refusing the matching shell command."

MASTER_DESTS = {"master", "refs/heads/master", "origin/master"}


def allow() -> None:
    print(json.dumps({"permission": "allow"}))
    sys.exit(0)


def deny(message: str) -> None:
    print(
        json.dumps(
            {
                "permission": "deny",
                "user_message": message,
                "agent_message": message,
            }
        )
    )
    sys.exit(0)


def tokenize(command: str) -> list[str]:
    try:
        return shlex.split(command, posix=True)
    except ValueError:
        return command.split()


def current_branch(cwd: str) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            timeout=2,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def dest_is_master(token: str) -> bool:
    value = token.lstrip("+")
    if value in MASTER_DESTS:
        return True
    if ":" not in value:
        return False
    dest = value.rsplit(":", 1)[1].lstrip("+")
    return dest in MASTER_DESTS


def looks_like_gh_merge(command: str) -> bool:
    if re.search(r"\bgh\b", command) is None:
        return False
    if re.search(r"\bpr\s+merge\b", command):
        return True
    if re.search(r"\bapi\b", command) is None:
        return False
    return (
        re.search(r"/merges?(?:\b|$|\?)", command) is not None
        or re.search(r"mergePullRequest", command) is not None
    )


def extract_git_push_args(tokens: list[str]) -> list[str] | None:
    """Return argv after `push`, or None if this is not a git push."""
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token in {"git", "git.exe"} or token.endswith("/git"):
            i += 1
            while i < len(tokens):
                option = tokens[i]
                if option == "push":
                    return tokens[i + 1 :]
                if option in {"-C", "--git-dir", "--work-tree"}:
                    i += 2
                    continue
                if option.startswith("--git-dir=") or option.startswith(
                    "--work-tree="
                ):
                    i += 1
                    continue
                if option == "-c":
                    i += 2
                    continue
                if option.startswith("-"):
                    i += 1
                    continue
                break
        elif token in {"-c", "--command"} and i + 1 < len(tokens):
            nested = extract_git_push_args(tokenize(tokens[i + 1]))
            if nested is not None:
                return nested
            i += 2
        else:
            i += 1
    return None


def is_force_push(push_args: list[str]) -> bool:
    for token in push_args:
        if token in {"--force", "-f", "--force-with-lease"}:
            return True
        if token.startswith("--force-with-lease="):
            return True
        if token.startswith("+") and dest_is_master(token):
            return True
        if token.startswith("+"):
            return True
    return False


def skip_push_option(args: list[str], index: int) -> int:
    token = args[index]
    takes_value = {
        "--repo",
        "--receive-pack",
        "--exec",
        "--push-option",
        "-o",
    }
    if token in takes_value and index + 1 < len(args):
        return index + 2
    if token.startswith("--repo=") or token.startswith("--signed="):
        return index + 1
    return index + 1


def positional_push_args(push_args: list[str]) -> list[str]:
    positional: list[str] = []
    i = 0
    while i < len(push_args):
        token = push_args[i]
        if token == "--":
            positional.extend(push_args[i + 1 :])
            break
        if token.startswith("-"):
            i = skip_push_option(push_args, i)
            continue
        positional.append(token)
        i += 1
    return positional


def push_targets_master(push_args: list[str], cwd: str) -> bool:
    if any(token in {"--all", "--mirror"} for token in push_args):
        return True
    positional = positional_push_args(push_args)
    if not positional:
        return current_branch(cwd) == "master"
    if len(positional) == 1:
        only = positional[0]
        dests = [only]
        if (
            not dest_is_master(only)
            and ":" not in only
            and only not in {"HEAD", "@"}
            and "/" not in only
        ):
            return current_branch(cwd) == "master"
    else:
        dests = positional[1:]
    saw_head = False
    for token in dests:
        if dest_is_master(token):
            return True
        if token in {"HEAD", "@"}:
            saw_head = True
    if saw_head:
        return current_branch(cwd) == "master"
    return False


def inner_commands(command: str) -> list[str]:
    found = [command]
    for match in re.finditer(r"""(?:bash|sh|zsh)\s+(?:-c|--command)\s+(.*)""", command):
        found.append(match.group(1))
    return found


def decide(command: str, cwd: str) -> str | None:
    for candidate in inner_commands(command):
        if looks_like_gh_merge(candidate):
            return DENY_MERGE
        tokens = tokenize(candidate)
        push_args = extract_git_push_args(tokens)
        if push_args is None:
            if re.search(r"\bgit\b", candidate) and re.search(r"\bpush\b", candidate):
                if re.search(r"(?:^|\s)(--force|--force-with-lease|-f)(?:\s|$)", candidate):
                    return DENY_FORCE
                for token in tokenize(candidate):
                    if dest_is_master(token):
                        return DENY_MASTER
            continue
        if is_force_push(push_args):
            return DENY_FORCE
        if push_targets_master(push_args, cwd):
            return DENY_MASTER
    return None


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        deny(DENY_INPUT)
    if not isinstance(data, dict):
        deny(DENY_INPUT)
    command = data.get("command") or ""
    if not isinstance(command, str):
        deny(DENY_INPUT)
    cwd = data.get("cwd") or os.getcwd()
    if not isinstance(cwd, str) or not cwd:
        cwd = os.getcwd()
    reason = decide(command, cwd)
    if reason:
        deny(reason)
    allow()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        deny(DENY_INPUT)
