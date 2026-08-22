"""Rewrite canonical repository loader paths from acf/ to ace/ in text files."""

from pathlib import Path


TEXT_SUFFIXES = {".lua", ".txt", ".properties", ".md", ".py", ".json"}


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    changed = 0
    replacements = 0
    for path in sorted(repo.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        if ".git" in path.parts:
            continue
        if path.parent.name == "tools":
            continue
        source = path.read_bytes()
        rewritten = source.replace(b"acf/", b"ace/")
        count = source.count(b"acf/")
        if "tests" in path.parts:
            rewritten = rewritten.replace(b'"acf"', b'"ace"')
            count += source.count(b'"acf"')
        if count and rewritten != source:
            path.write_bytes(rewritten)
            changed += 1
            replacements += count
    print(f"rewrote {replacements} canonical acf/ paths across {changed} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
