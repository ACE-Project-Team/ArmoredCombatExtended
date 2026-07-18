"""Run ACE's pure-model and shimmed lifecycle tests under LuaJIT."""

from pathlib import Path
import shutil
import subprocess
import sys


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    lua = shutil.which("luajit")
    if lua is None:
        print("luajit was not found on PATH", file=sys.stderr)
        return 2

    tests = sorted((repo / "tests" / "lua").glob("*_selftest.lua"))
    if not tests:
        print("no LuaJIT self-tests found", file=sys.stderr)
        return 2

    failures = []
    for test in tests:
        print(f"==> {test.relative_to(repo)}", flush=True)
        result = subprocess.run([lua, str(test), str(repo)], cwd=repo)
        if result.returncode != 0:
            failures.append((test.relative_to(repo), result.returncode))

    if failures:
        print("\nLuaJIT self-test failures:", file=sys.stderr)
        for test, returncode in failures:
            print(f"- {test}: exit code {returncode}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
