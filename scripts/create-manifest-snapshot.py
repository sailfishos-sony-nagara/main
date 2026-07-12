#!/usr/bin/env python3

import argparse
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path


DEFAULT_OUTPUT_DIR = "manifest-snapshot"


class CommandError(RuntimeError):
    pass


def run_command(command, cwd, check=True):
    result = subprocess.run(
        command,
        cwd=str(cwd),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and result.returncode != 0:
        raise CommandError(
            "Command failed: {}\n{}".format(" ".join(command), result.stderr.strip())
        )
    return result


def run_git(project_dir, args, check=True):
    return run_command(["git"] + args, project_dir, check=check)


def resolve_android_root():
    android_root = os.environ.get("ANDROID_ROOT")
    if android_root:
        root = Path(android_root).expanduser().resolve()
        if not (root / ".repo").is_dir():
            raise CommandError("ANDROID_ROOT does not contain .repo: {}".format(root))
        return root

    root = Path.cwd().resolve()
    if (root / ".repo").is_dir():
        return root

    raise CommandError(
        "ANDROID_ROOT is not set and current directory is not an Android repo root"
    )


def write_repo_status(android_root, output_dir):
    status_path = output_dir / "repo-status.log"
    with status_path.open("w", encoding="utf-8") as status_log:
        status_log.write("# cd {}\n".format(android_root))
        status_log.write("# repo status\n\n")
        result = subprocess.run(
            ["repo", "status"],
            cwd=str(android_root),
            text=True,
            stdout=status_log,
            stderr=subprocess.PIPE,
        )
    if result.returncode != 0:
        raise CommandError("repo status failed:\n{}".format(result.stderr.strip()))
    return status_path


def write_raw_manifest(android_root, raw_manifest_path):
    result = subprocess.run(
        ["repo", "manifest", "-r", "-o", str(raw_manifest_path)],
        cwd=str(android_root),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise CommandError("repo manifest failed:\n{}".format(result.stderr.strip()))


def project_checkout_path(project):
    return project.get("path") or project.get("name")


def is_git_checkout(project_dir):
    result = run_git(project_dir, ["rev-parse", "--git-dir"], check=False)
    return result.returncode == 0


def local_first_parent_info(project_dir):
    result = run_git(
        project_dir,
        ["rev-list", "--first-parent", "--boundary", "HEAD", "--not", "--remotes"],
        check=True,
    )
    local_commits = []
    boundary_commits = []
    for line in result.stdout.splitlines():
        if not line:
            continue
        if line.startswith("-"):
            boundary_commits.append(line[1:])
        else:
            local_commits.append(line)
    return local_commits, boundary_commits


def local_commit_summaries(project_dir, local_commits):
    summaries = []
    for commit in reversed(local_commits):
        result = run_git(
            project_dir,
            ["show", "--no-patch", "--format=%h %an: %s", commit],
            check=True,
        )
        summaries.append(result.stdout.strip())
    return summaries


def write_project_log(log, project_dir, checkout_path, local_commits, details):
    log.write("{}: {} local commits:\n".format(checkout_path, len(local_commits)))
    for summary in local_commit_summaries(project_dir, local_commits):
        log.write("  {}\n".format(summary))
    for detail in details:
        log.write("  {}\n".format(detail))
    log.write("\n")


def remote_refs(project_dir):
    result = run_git(
        project_dir,
        ["for-each-ref", "--format=%(refname)", "refs/remotes"],
        check=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def is_reachable_from_remote(project_dir, revision):
    refs = remote_refs(project_dir)
    for ref in refs:
        result = run_git(
            project_dir,
            ["merge-base", "--is-ancestor", revision, ref],
            check=False,
        )
        if result.returncode == 0:
            return True
    return False


def indent_xml(element, level=0):
    indent = "\n" + level * "  "
    child_indent = "\n" + (level + 1) * "  "
    children = list(element)

    if children:
        if not element.text or not element.text.strip():
            element.text = child_indent
        for child in children:
            indent_xml(child, level + 1)
        if not element.tail or not element.tail.strip():
            element.tail = indent
    else:
        if level and (not element.tail or not element.tail.strip()):
            element.tail = indent


def process_manifest(android_root, raw_manifest_path, snapshot_path, log_path):
    tree = ET.parse(raw_manifest_path)
    root = tree.getroot()

    projects = root.findall("project")
    processed = 0
    rewound = 0
    warnings = 0

    with log_path.open("w", encoding="utf-8") as log:
        log.write("# Created: {}\n".format(datetime.now().isoformat(sep=" ", timespec="seconds")))
        log.write("# Android root: {}\n".format(android_root))
        log.write("\n")

        for project in projects:
            name = project.get("name", "<unnamed>")
            checkout_path = project_checkout_path(project)
            if not checkout_path:
                warnings += 1
                log.write("{}: WARNING: project has no name or path\n".format(name))
                continue

            project_dir = android_root / checkout_path
            if not project_dir.exists():
                warnings += 1
                log.write("{}: WARNING: checkout path does not exist: {}\n".format(name, checkout_path))
                continue

            if not is_git_checkout(project_dir):
                warnings += 1
                log.write("{}: WARNING: not a git checkout: {}\n".format(name, checkout_path))
                continue

            processed += 1
            original_revision = project.get("revision", "")
            local_commits, boundary_commits = local_first_parent_info(project_dir)

            if not local_commits:
                continue

            if not boundary_commits:
                warnings += 1
                write_project_log(
                    log,
                    project_dir,
                    checkout_path,
                    local_commits,
                    [
                        "WARNING: no remote boundary commit was found; keeping {}".format(
                            original_revision
                        )
                    ],
                )
                continue

            candidate_sha = boundary_commits[0]
            if not is_reachable_from_remote(project_dir, candidate_sha):
                warnings += 1
                write_project_log(
                    log,
                    project_dir,
                    checkout_path,
                    local_commits,
                    [
                        "WARNING: candidate {} is not reachable from remotes; keeping {}".format(
                            candidate_sha, original_revision
                        )
                    ],
                )
                continue

            project.set("revision", candidate_sha)
            rewound += 1
            write_project_log(
                log,
                project_dir,
                checkout_path,
                local_commits,
                ["rewound from {} to {}".format(original_revision, candidate_sha)],
            )

    indent_xml(root)
    tree.write(snapshot_path, encoding="UTF-8", xml_declaration=True)
    return processed, rewound, warnings


def parse_args():
    parser = argparse.ArgumentParser(
        description="Create an Android repo manifest snapshot without local patch commits"
    )
    parser.add_argument(
        "-o",
        "--output",
        default=DEFAULT_OUTPUT_DIR,
        help="Output directory for snapshot files (default: ./manifest-snapshot)",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    try:
        android_root = resolve_android_root()
        output_dir = Path(args.output).expanduser().resolve()
        output_dir.mkdir(parents=True, exist_ok=True)

        snapshot_path = output_dir / "snapshot.xml"
        processing_log_path = output_dir / "snapshot-processing.log"

        print("Android root: {}".format(android_root))
        print("Output directory: {}".format(output_dir))

        status_path = write_repo_status(android_root, output_dir)

        with tempfile.NamedTemporaryFile(
            prefix="repo-manifest-", suffix=".xml", delete=False
        ) as raw_manifest:
            raw_manifest_path = Path(raw_manifest.name)

        try:
            write_raw_manifest(android_root, raw_manifest_path)
            processed, rewound, warnings = process_manifest(
                android_root, raw_manifest_path, snapshot_path, processing_log_path
            )
        finally:
            raw_manifest_path.unlink(missing_ok=True)

        print("Wrote {}".format(snapshot_path))
        print("Wrote {}".format(status_path))
        print("Wrote {}".format(processing_log_path))
        print(
            "Processed {} projects, rewound {} projects, warnings {}".format(
                processed, rewound, warnings
            )
        )
    except CommandError as error:
        print("Error: {}".format(error), file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
