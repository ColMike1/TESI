import argparse
from pathlib import Path
import re
import matplotlib.pyplot as plt

# Configurazione predefinita dell'intervallo MAX_SHIFT
SHIFT_START = 4
SHIFT_END = 15

base_dir = Path(".")
check_dir = base_dir / "check_results"

max_pattern = re.compile(r"ERRORE RELATIVO MASSIMO:\s*([0-9.eE+-]+)")
mean_pattern = re.compile(r"ERRORE RELATIVO MEDIO:\s*([0-9.eE+-]+)")


def parse_args():
    parser = argparse.ArgumentParser(description="Plot errore relativo massimo e medio vs MAX_SHIFT.")
    parser.add_argument("--start", type=int, default=SHIFT_START, help="Valore iniziale di MAX_SHIFT")
    parser.add_argument("--end", type=int, default=SHIFT_END, help="Valore finale di MAX_SHIFT (incluso)")
    return parser.parse_args()


def main():
    args = parse_args()
    if args.start > args.end:
        raise ValueError(f"SHIFT_START ({args.start}) non puo' essere maggiore di SHIFT_END ({args.end}).")

    shifts = list(range(args.start, args.end + 1))

    x_vals = []
    rel_max_vals = []
    rel_mean_vals = []

    for s in shifts:
        target_file = check_dir / f"check_results{s}.txt"
        if not target_file.is_file():
            print(f"File non trovato: {target_file} (saltato)")
            continue

        text = target_file.read_text(encoding="utf-8", errors="replace")
        m_max = max_pattern.search(text)
        m_mean = mean_pattern.search(text)

        if m_max and m_mean:
            x_vals.append(s)
            rel_max_vals.append(float(m_max.group(1)))
            rel_mean_vals.append(float(m_mean.group(1)))
        else:
            print(f"Intestazione max/mean non trovata in: {target_file}")

    print("x_vals:", x_vals)
    print("rel_max_vals:", rel_max_vals)
    print("rel_mean_vals:", rel_mean_vals)

    if x_vals:
        plt.figure(figsize=(9, 5))
        plt.plot(x_vals, rel_max_vals, marker="o", linewidth=1.8, label="Errore relativo massimo")
        plt.plot(x_vals, rel_mean_vals, marker="s", linewidth=1.8, label="Errore relativo medio")

        plt.title(f"Errore relativo massimo e medio vs MAX_SHIFT ({args.start}..{args.end})", fontsize=13)
        plt.xlabel("MAX_SHIFT", fontsize=11)
        plt.ylabel("Errore relativo (scala log2)", fontsize=11)
        plt.xticks(shifts)
        plt.yscale("log", base=2)
        plt.grid(True, which="both", linestyle="--", alpha=0.5)
        plt.legend()
        plt.tight_layout()
        plt.show()
    else:
        print("Nessun dato valido trovato da plottare.")


if __name__ == "__main__":
    main()