import os
import re
from pathlib import Path

# Path to missile definitions
MISSILES_DIR = "lua/acf/shared/missiles"

# Mirrors ace_roundfunctions missile defaults
DEFAULT_MISSILE_MINPROJ_RATIO = 0.5
LEGACY_MINPROJ_RATIO = 1.5

# Known real-world body calibers (cm)
REAL_CALIBERS = {
    "AIM-9 AAM": 12.7, "AIM-7 AAM": 20.3, "AIM-120 AAM": 17.8, "AIM-54 AAM": 38.0,
    "SRAAM AAM": 16.5, "Magic AAM": 15.7, "MICA AAM": 16.0, "Meteor AAM": 17.8,
    "R-60 AAM": 12.0, "R-73 AAM": 16.5, "R-77 AAM": 20.0, "R-27 AAM": 23.0, "R-33 AAM": 38.0,
    "FIM-92 SAM": 7.0, "Mistral SAM": 9.0, "TY-90 AAM": 9.0, "Strela-1 SAM": 12.0, "VT-1 SAM": 16.5,
    "9M311 SAM": 7.6, "9M331 SAM": 15.0, "9M38M1 SAM": 33.0, "9M317ME SAM": 38.0, "Scaled 9M317ME SAM": 38.0,
    "5V55 SAM": 51.4, "Scaled 5V55 SAM": 51.4, "StarstreakHVM": 6.6,
    "BGM-71E ASM": 15.2, "9M113 ATGM": 13.5, "9M133 ASM": 15.2, "AT-3 ASM": 12.5, "AT-2 ASM": 16.0,
    "FGM-148 ASM": 12.7, "Spike-LR ASM": 17.0, "Ataka ASM": 13.0, "AGM-114 ASM": 17.8, "Vikhr ASM": 13.0,
    "MGM-166": 16.2, "MIM-146": 15.2,
    "AGM-122 ASM": 12.7, "AGM-45 ASM": 20.3, "AGM-88 ASM": 25.4, "KH-31 ASM": 36.0, "AGM-65 ASM": 30.5,
    "AS-30 ASM": 34.2, "KH-23 ASM": 27.5, "KH-25 ASM": 27.5, "KH-29 ASM": 38.0,
    "Type 63 RA": 10.7, "SAKR-10 RA": 12.2, "RW61 RA": 38.0, "M26 RA": 22.7, "SS-40 RA": 18.0,
    "M31 RA": 22.7, "ATACMS RA": 61.0, "9M79-1": 65.0,
    "BGM-109 Tomahawk": 51.8, "Scaled BGM-109 Tomahawk": 51.8, "AGM-84 Harpoon": 34.3, "Scaled AGM-84 Harpoon": 34.3,
    "Storm Shadow ASM": 48.0, "Scaled Storm Shadow ASM": 48.0, "3M-54 Kalibr": 53.3, "Scaled 3M-54 Kalibr": 53.3,
    "Black Shark Torp": 53.3, "Scaled Black Shark Torp": 53.3, "G7a Torp": 53.3, "Scaled G7a Torp": 53.3,
    "Mk13 Torp": 57.0, "Scaled Mk13 Torp": 57.0, "Mk54 Torp": 32.4,
    "50kgBOMB": 5.0, "100kgBOMB": 10.0, "250kgBOMB": 12.5, "500kgBOMB": 30.0, "1000kgBOMB": 30.0,
    "Mk82Bomb": 27.3, "Mk83Bomb": 35.6, "Mk84Bomb": 45.7, "100kgGBOMB": 10.0, "250kgGBOMB": 12.5,
    "GBU-39": 19.0, "FAB250-UPMP": 25.0, "227kgGBU": 27.3, "454kgGBU": 35.6, "909kgGBU": 45.7, "WalleyeGBU": 31.8,
    "40mmFFAR": 4.0, "70mmFFAR": 7.0, "S8KO": 8.0, "Zuni ASR": 12.7, "SPG-9 ASR": 7.3, "RS82 ASR": 8.2,
    "HVAR ASR": 12.7, "S-24 ASR": 24.0,
}


def extract_number(block: str, key: str):
    match = re.search(rf"{re.escape(key)}\s*=\s*([\d.]+)", block)
    return float(match.group(1)) if match else None


def extract_comment_real_caliber_cm(gun_block: str):
    # Old style: -- Actual is 380
    old = re.search(r"caliber.*?--.*?[Aa]ctual(?:\s+is)?\s+([\d.]+)", gun_block)
    if old:
        return float(old.group(1)) / 10.0

    # New style: -- Real diameter (380 mm)
    new = re.search(r"caliber.*?--.*?[Rr]eal(?:\s+diameter)?\s*\(?\s*([\d.]+)\s*mm", gun_block)
    if new:
        return float(new.group(1)) / 10.0

    return None


def parse_missile_file(filepath: Path):
    missiles = []
    content = filepath.read_text(encoding="utf-8")

    gun_pattern = r'ACF_defineGun\s*\(\s*"([^"]+)"\s*,\s*\{(.*?)\n\}\s*\)'

    for match in re.finditer(gun_pattern, content, re.DOTALL):
        name = match.group(1)
        gun_block = match.group(2)

        body_caliber = extract_number(gun_block, "caliber")
        if body_caliber is None:
            continue

        # Look for round block
        round_match = re.search(r"round\s*=\s*\{(.*?)\n\s*\}", gun_block, re.DOTALL)
        if not round_match:
            continue
        round_block = round_match.group(1)

        maxlength = extract_number(round_block, "maxlength")
        if maxlength is None:
            continue

        # Real body caliber reference
        comment_real = extract_comment_real_caliber_cm(gun_block)
        real_body_caliber = comment_real or REAL_CALIBERS.get(name, body_caliber)

        # New behavior:
        # - Body caliber is physical diameter and drives missile min projectile length
        # - Ballistic/warhead calcs also use the real body caliber by default
        effective_caliber = body_caliber

        minproj_length = extract_number(round_block, "minprojlength")
        if minproj_length is None:
            minproj_length = extract_number(gun_block, "minprojlength")

        minproj_ratio = extract_number(round_block, "minprojratio")
        if minproj_ratio is None:
            minproj_ratio = extract_number(gun_block, "minprojratio")
        if minproj_ratio is None:
            minproj_ratio = DEFAULT_MISSILE_MINPROJ_RATIO

        if minproj_length is None:
            minproj_current = body_caliber * minproj_ratio
            minproj_source = f"ratio:{minproj_ratio:g}"
        else:
            minproj_current = minproj_length
            minproj_source = "fixed"

        # Legacy reference (for balance sanity checks only)
        minproj_legacy = body_caliber * LEGACY_MINPROJ_RATIO

        percent_current = (minproj_current / maxlength) * 100 if maxlength > 0 else 0
        percent_legacy = (minproj_legacy / maxlength) * 100 if maxlength > 0 else 0

        missiles.append(
            {
                "name": name,
                "file": filepath.name,
                "body_caliber": body_caliber,
                "real_body_caliber": real_body_caliber,
                "effective_caliber": effective_caliber,
                "maxlength": maxlength,
                "minproj_current": minproj_current,
                "minproj_legacy": minproj_legacy,
                "percent_current": percent_current,
                "percent_legacy": percent_legacy,
                "minproj_source": minproj_source,
                "body_mismatch": abs(body_caliber - real_body_caliber) > 0.1,
            }
        )

    return missiles


def main():
    if not os.path.exists(MISSILES_DIR):
        print(f"Error: Directory '{MISSILES_DIR}' not found.")
        print(f"Current working directory: {os.getcwd()}")
        return

    missile_files = sorted(Path(MISSILES_DIR).glob("*.lua"))
    if not missile_files:
        print(f"No .lua files found in {MISSILES_DIR}")
        return

    print(f"Found {len(missile_files)} missile files:")
    for fpath in missile_files:
        print(f"  - {fpath.name}")
    print()

    all_missiles = []
    for fpath in missile_files:
        missiles = parse_missile_file(fpath)
        all_missiles.extend(missiles)
        if missiles:
            print(f"Parsed {len(missiles)} missiles from {fpath.name}")

    print(f"\nTotal missiles found: {len(all_missiles)}\n")
    if not all_missiles:
        print("No missiles parsed.")
        return

    # Sort by current min pressure descending
    missiles_sorted = sorted(all_missiles, key=lambda x: x["percent_current"], reverse=True)

    print("=" * 180)
    print(
        f"{'Missile':<30} {'File':<22} {'Body':<6} {'Real':<6} {'Eff':<6} "
        f"{'MaxLen':<7} {'MinNow':<7} {'MinOld':<7} {'Now%':<7} {'Old%':<7} {'Mode':<9} {'Status'}"
    )
    print("=" * 180)

    for m in missiles_sorted:
        status = "MISMATCH" if m["body_mismatch"] else "OK"
        print(
            f"{m['name']:<30} {m['file']:<22} {m['body_caliber']:<6.1f} {m['real_body_caliber']:<6.1f} "
            f"{m['effective_caliber']:<6.1f} {m['maxlength']:<7.1f} {m['minproj_current']:<7.1f} "
            f"{m['minproj_legacy']:<7.1f} {m['percent_current']:<6.1f}% {m['percent_legacy']:<6.1f}% "
            f"{m['minproj_source']:<9} {status}"
        )

    mismatches = [m for m in missiles_sorted if m["body_mismatch"]]
    severe_min = [m for m in missiles_sorted if m["percent_current"] > 50]
    exceeds = [m for m in missiles_sorted if m["minproj_current"] > m["maxlength"]]

    print("\n" + "=" * 180)
    print("STATISTICS")
    print("=" * 180)
    print(f"Total missiles analyzed: {len(all_missiles)}")
    print(f"Body caliber mismatches (code vs real): {len(mismatches)}")
    print("Using explicit warhead caliber override: 0 (retired in this model)")
    print("Warhead caliber differs from body caliber: 0 (real body caliber is authoritative)")
    print(f"Min projectile exceeds maxlength (current logic): {len(exceeds)}")
    print(f"Missiles with >50% minimum warhead space (current logic): {len(severe_min)}")

    if mismatches:
        print("\nBody mismatch entries:")
        for m in mismatches:
            print(f"  - {m['name']} ({m['file']}): code {m['body_caliber']:.1f}cm vs real {m['real_body_caliber']:.1f}cm")

    # No warhead override reporting in the real-body-caliber model.

    # Largest delta between legacy and current min rule pressure
    delta_sorted = sorted(
        missiles_sorted,
        key=lambda x: (x["minproj_legacy"] - x["minproj_current"]),
        reverse=True,
    )
    top_delta = delta_sorted[:10]
    if top_delta:
        print("\nTop 10 reductions vs legacy min rule (old 1.5x body vs current):")
        for m in top_delta:
            delta = m["minproj_legacy"] - m["minproj_current"]
            print(
                f"  - {m['name']}: -{delta:.1f}cm ({m['minproj_legacy']:.1f} -> {m['minproj_current']:.1f})"
            )


if __name__ == "__main__":
    main()
