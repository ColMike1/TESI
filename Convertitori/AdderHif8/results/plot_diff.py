import re
from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

try:
    import mplcursors
    HAS_MPLCURSORS = True
except ImportError:
    HAS_MPLCURSORS = False


def fp10_to_float32(bits_10: str) -> np.float32:
    """
    Decodifica un valore FP a 10 bit:
      - bit [9]   : segno (1 bit)
      - bits [8:3]: esponente in complemento a 2 (6 bit)
      - bits [2:0] : mantissa frazionaria (3 bit), con bit implicito 1 -> 1.m2m1m0
    """
    bits_10 = bits_10.strip()
    if len(bits_10) != 10 or not set(bits_10) <= {"0", "1"}:
        raise ValueError(f"Valore FP a 10 bit non valido: '{bits_10}'")

    sign_bit = int(bits_10[0], 2)
    exp_bits = bits_10[1:7]
    mant_bits = bits_10[7:10]

    # Esponente in complemento a 2 su 6 bit
    exp_val = int(exp_bits, 2)
    if exp_val & (1 << 5):
        exp_val -= (1 << 6)

    # Mantissa normalizzata 1.xxx (1 + m/8)
    mant_val = 1.0 + int(mant_bits, 2) / 8.0

    val = (-1.0 if sign_bit else 1.0) * mant_val * (2.0 ** exp_val)
    return np.float32(val)


def extract_diff_row_indices(diff_path: Path) -> list[int]:
    """
    Estrae i numeri di 'Riga <N>' presenti in check_diff.txt che hanno
    almeno una riga modificata ('-' o '+') all'interno del loro blocco.
    """
    row_indices: list[int] = []
    current_row: int | None = None
    current_has_change = False

    riga_re = re.compile(r"^[+\-\s]?\s*---\s*Riga\s+(\d+)\s*---")

    with diff_path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = riga_re.match(line.rstrip("\r\n"))
            if m:
                if current_row is not None and current_has_change:
                    row_indices.append(current_row)
                current_row = int(m.group(1))
                current_has_change = False
            elif current_row is not None:
                if line.startswith("-") or line.startswith("+"):
                    current_has_change = True

    if current_row is not None and current_has_change:
        row_indices.append(current_row)

    return list(dict.fromkeys(row_indices))


def parse_fp_pair_from_line(line: str) -> tuple[str, str] | None:
    """
    Estrae i due valori FP a 10 bit da una riga come:
    | 0101001000 + 0101010000  = 0101010100 | ----- | ...
    """
    m = re.search(r"\|\s*([01]{10})\s*\+\s*([01]{10})\s*=", line)
    if not m:
        return None
    return m.group(1), m.group(2)


def main() -> None:
    diff_file = Path("check_diff.txt")
    sum_file = Path("sum_results.txt")

    row_nums = extract_diff_row_indices(diff_file)
    if not row_nums:
        print("Nessuna differenza trovata in check_diff.txt.")
        return

    sum_lines = sum_file.read_text(encoding="utf-8", errors="replace").splitlines()

    fp1_bins, fp2_bins = [], []
    fp1_vals, fp2_vals = [], []
    matched_rows = []

    for r in row_nums:
        if 1 <= r <= len(sum_lines):
            pair = parse_fp_pair_from_line(sum_lines[r - 1])
            if pair:
                b1, b2 = pair
                fp1_bins.append(b1)
                fp2_bins.append(b2)
                fp1_vals.append(float(fp10_to_float32(b1)))
                fp2_vals.append(float(fp10_to_float32(b2)))
                matched_rows.append(r)
                continue

        print(f"[Attenzione] Impossibile estrarre coppia FP valida per Riga {r}")

    print(f"Coppie estratte: {len(fp1_vals)}")
    if not fp1_vals:
        return

    # Soglia lineare attorno allo zero basata sul minimo valore assoluto non nullo
    nonzero_abs = [abs(v) for v in (fp1_vals + fp2_vals) if v != 0.0]
    linthresh = (min(nonzero_abs) * 0.5) if nonzero_abs else 1e-7

    fig, ax = plt.subplots(figsize=(9, 6))
    sc = ax.scatter(fp1_vals, fp2_vals, alpha=0.75, edgecolors="k", linewidths=0.4)

    ax.set_xscale("symlog", base=2, linthresh=linthresh, linscale=1.0)
    ax.set_yscale("symlog", base=2, linthresh=linthresh, linscale=1.0)

    ax.axhline(0, color="gray", linestyle="--", linewidth=0.8)
    ax.axvline(0, color="gray", linestyle="--", linewidth=0.8)
    ax.set_xlabel("FP1")
    ax.set_ylabel("FP2")
    ax.set_title("Identificazione coppie (FP1, FP2) che hanno Errori relativi diversi")
    ax.grid(True, which="major", linestyle="-", alpha=0.35)
    ax.grid(True, which="minor", linestyle=":", alpha=0.25)

    if HAS_MPLCURSORS:
        cursor = mplcursors.cursor(sc, hover=True)

        @cursor.connect("add")
        def on_add(sel):
            idx = sel.index
            sel.annotation.set_text(
                f"Riga: {matched_rows[idx]}\n"
                f"FP1: {fp1_vals[idx]} ({fp1_bins[idx]})\n"
                f"FP2: {fp2_vals[idx]} ({fp2_bins[idx]})"
            )

    plt.tight_layout()
    plt.show()


if __name__ == "__main__":
    main()