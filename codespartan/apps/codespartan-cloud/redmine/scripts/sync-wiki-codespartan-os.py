#!/usr/bin/env python3
"""Sync Codespartan-OS markdown doc tree to the Redmine wiki (project codespartan-os).

Usage:
  REDMINE_API_KEY=<key> python3 sync-wiki-codespartan-os.py <repo_dir> [--dry-run]

Mapping (idempotent, re-runnable):
  - Every directory becomes a wiki *folder page*: title = full relative path with
    '/' -> '-' (unique), parent_title = parent folder's title (creates nested tree).
  - Every *.md becomes a wiki page: title = dirpath transformed, parent = its folder.
  - {{attach(file)}} references upload the file as an attachment to that page.
  - Non-markdown files (scripts/*.sh, *.yml templates) are attached to their
    folder index page and listed with {{attach()}}.
  - A top-level "Home" page indexes all root folders.
"""

import argparse
import json
import os
import re
import socket
import sys
import urllib.parse
import urllib.request

# Prefer IPv4: this host resolves to both A+AAAA; on some networks urllib's
# Happy Eyeballs waits on IPv6 first which adds many seconds per request.
_orig_getaddrinfo = socket.getaddrinfo


def _ipv4_first_getaddrinfo(*args, **kwargs):
    results = list(_orig_getaddrinfo(*args, **kwargs))
    results.sort(key=lambda r: 0 if r[0] == socket.AF_INET else 1)
    return results


socket.getaddrinfo = _ipv4_first_getaddrinfo

REDMINE_URL = os.environ.get("REDMINE_URL", "https://project.codespartan.cloud").rstrip("/")
API_KEY = os.environ.get("REDMINE_API_KEY", "")
PROJECT_ID = "codespartan-os"

UA = {"User-Agent": "codespartan-wiki-sync/1.0"}


def req(method, url, data=None, headers=None, timeout=120):
    h = {**UA, "X-Redmine-API-Key": API_KEY, **(headers or {})}
    r = urllib.request.Request(url, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            body = resp.read()
            return resp.status, body.decode("utf-8", "replace") if body else ""
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace") if e.fp else ""
        return e.code, body


def title_from(rel_noext):
    """rel_noext uses '/'; transform to a unique flat wiki title."""
    return rel_noext.replace("/", "-")


def parent_from(rel_dir):
    """Parent folder of a page given its directory rel path ('' for top-level)."""
    if not rel_dir:
        return None
    return title_from(rel_dir)


def put_page(title, text, parent_title=None, uploads=None, dry=False):
    path = f"/projects/{PROJECT_ID}/wiki/{urllib.parse.quote(title)}.json"
    wp = {"text": text, "title": title}
    if parent_title:
        wp["parent_title"] = parent_title
    if uploads:
        wp["uploads"] = uploads
    body = json.dumps({"wiki_page": wp}).encode("utf-8")
    if dry:
        print(f"[dry] PUT {title} (parent={parent_title}, {len(text)} chars, {len(uploads or [])} uploads)")
        return 200
    # PUT with ?parent_title uses title as-is
    code, err = req("PUT", f"{REDMINE_URL}{path}", data=body,
                    headers={"Content-Type": "application/json"})
    if code in (200, 201, 204):
        print(f"OK   {title}" + (f"  <- {parent_title}" if parent_title else ""), flush=True)
    else:
        print(f"ERR  {title}: HTTP {code} {err[:200]}", file=sys.stderr, flush=True)
    return code


def upload_file(path):
    with open(path, "rb") as f:
        data = f.read()
    ctype = "application/octet-stream"  # Redmine rejects odd mimetypes (.sh, .mmd) with 406
    code, body = req("POST", f"{REDMINE_URL}/uploads.json", data=data,
                     headers={"X-Redmine-API-Key": API_KEY,
                              "Content-Type": ctype})
    if code != 201:
        print(f"ERR upload {path}: HTTP {code} {body[:200]}", file=sys.stderr)
        return None
    return json.loads(body)["upload"]["token"]


def collect(repo_dir):
    md = []
    for root, dirs, files in os.walk(repo_dir):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        dirs.sort()
        for fn in sorted(files):
            if fn.endswith(".md"):
                rel = os.path.relpath(os.path.join(root, fn), repo_dir)
                md.append((rel.replace(os.sep, "/"), os.path.join(root, fn)))
    md.sort()
    dirs_set = set()
    for rel, _ in md:
        d = rel.rpartition("/")[0]
        while d and d not in dirs_set:
            dirs_set.add(d)
            d = d.rpartition("/")[0]
    return md, sorted(dirs_set)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("repo_dir")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if not API_KEY:
        sys.stderr.write("REDMINE_API_KEY env var required\n")
        return 2
    repo_dir = os.path.abspath(args.repo_dir)
    md, dirs_list = collect(repo_dir)
    print(f"Found {len(md)} markdown pages, {len(dirs_list)} folders")

    # 1) Folder pages (parents must exist before children)
    text_map = {}
    for rel, abs_path in md:
        text_map[rel] = open(abs_path, encoding="utf-8").read()

    dirs_set_full = set(dirs_list)
    for d in dirs_list:
        # Direct child folders: dirs exactly one level below d
        child_dirs = sorted(x for x in dirs_list
                            if x.startswith(d + "/") and "/" not in x[len(d) + 1:])
        # Direct child files: md files exactly one level below d
        child_files = sorted(rel[:-3] for rel, _ in md if rel.startswith(d + "/") and "/" not in rel[len(d) + 1:])
        entries = []
        for c in child_dirs:
            entries.append((title_from(c), c.rpartition("/")[2]))
        for c in child_files:
            entries.append((title_from(c), c.rpartition("/")[2]))
        if entries:
            lines = [f"# {d}", ""]
            for title, label in entries:
                lines.append(f"- [[{title}|{label.replace('_', ' ')}]]")
            content = "\n".join(lines) + "\n"
        else:
            content = f"# {d}\n"
        put_page(title_from(d), content, parent_from(d.rpartition("/")[0]), dry=args.dry_run)

    # 2) File pages
    for rel, abs_path in md:
        rel_noext = rel[:-3]
        text = text_map[rel]
        uploads = []
        for m in re.finditer(r"\{\{attach\(([^)]+)\)\}\}", text):
            fname = m.group(1)
            cand = os.path.join(os.path.dirname(abs_path), fname)
            if os.path.isfile(cand):
                token = upload_file(cand) if not args.dry_run else "dry-token"
                uploads.append({"token": token, "filename": fname,
                                "content_type": "application/octet-stream"})
            else:
                print(f"WARN attach missing: {fname}", file=sys.stderr)
        d = rel.rpartition("/")[0]
        put_page(title_from(rel_noext), text, parent_from(d), uploads, dry=args.dry_run)

    # 3) Attach non-markdown templates (scripts/*.sh, *.yml under 10-Templates) to their folders
    tpl_files = {}
    for root, dirs, files in os.walk(repo_dir):
        if any(part.startswith(".") for part in root.replace(repo_dir, "").split(os.sep)):
            continue
        for fn in sorted(files):
            if fn.endswith((".sh", ".yml")) and not fn.endswith(".md"):
                rel = os.path.relpath(os.path.join(root, fn), repo_dir)
                dirp = rel.replace(os.sep, "/").rpartition("/")[0]
                tpl_files.setdefault(dirp, []).append((rel, os.path.join(root, fn)))
    for dirp, files in tpl_files.items():
        uploads = []
        content_lines = [f"# {dirp}", ""]
        for rel, abs_path in files:
            fname = os.path.basename(abs_path)
            content_lines.append(f"- `{{{{attach({fname})}}}}`")
            token = upload_file(abs_path) if not args.dry_run else "dry-token"
            uploads.append({"token": token, "filename": fname,
                            "content_type": "application/octet-stream"})
        put_page(title_from(dirp), "\n".join(content_lines) + "\n", parent_from(dirp.rpartition("/")[0]), uploads, dry=args.dry_run)

    # 4) Home page
    roots = sorted({d.split("/")[0] for d in dirs_list})
    home = ["# CodeSpartan-OS", "",
            "Base de conocimiento sincronizada desde el repositorio `TechnoSpartan/Codespartan-OS`.",
            "", "## Índice", ""]
    for r in roots:
        home.append(f"- [[{title_from(r)}]]")
    home.append(f"- [[{'README'}]]")
    put_page("Home", "\n".join(home) + "\n", dry=args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())