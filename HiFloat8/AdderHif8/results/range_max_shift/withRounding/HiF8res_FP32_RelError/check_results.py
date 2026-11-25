import argparse
import os
import re
import numpy as np
import matplotlib.pyplot as plt

# Configurazione predefinita dell'intervallo MAX_SHIFT
SHIFT_START = 5
SHIFT_END = 15


def parse_twos_complement_6bit(bits_str):
    """Converte 6 bit in complemento a 2 nel corrispondente intero con segno."""
    val = int(bits_str, 2)
    if bits_str[0] == '1':
        val -= (1 << 6)
    return val


def decode_fp(fp_str):
    """
    Decodifica FP1/FP2/RES:
    - 1 bit segno (indice 0)
    - 6 bit esponente in complemento a 2
    - 3 bit mantissa
    Convertito in np.float32 per precisione a 32 bit.
    """
    sign_bit = fp_str[0]
    exp_bits = fp_str[1:7]
    mant_bits = fp_str[7:10]

    sign = -1 if sign_bit == '1' else 1
    exp = parse_twos_complement_6bit(exp_bits)

    m0 = int(mant_bits[0])
    m1 = int(mant_bits[1])
    m2 = int(mant_bits[2])

    mantissa_val = np.float32(1.0 + (m0 * 0.5) + (m1 * 0.25) + (m2 * 0.125))
    return np.float32(sign * (np.float32(2.0) ** exp) * mantissa_val)


PATTERN = re.compile(
    r'([01]{10})\s*\+\s*([01]{10}).*?\bA_IS_ZERO=([01]{1}).*?\bB_IS_ZERO=([01]{1}).*?\bHIF8RES_TO_FP=([01]{10})'
)

INPUT_DIR = ".."
OUTPUT_DIR = "check_results"


def parse_args():
    parser = argparse.ArgumentParser(description="Analisi errore relativo HiFloat8 al variare di MAX_SHIFT.")
    parser.add_argument("--start", type=int, default=SHIFT_START, help="Valore iniziale di MAX_SHIFT")
    parser.add_argument("--end", type=int, default=SHIFT_END, help="Valore finale di MAX_SHIFT (incluso)")
    return parser.parse_args()


def process_shift(s_idx):
    input_filename = f"sum_results{s_idx}.txt"
    output_filename = f"check_results{s_idx}.txt"

    file_path = os.path.join(INPUT_DIR, input_filename)
    output_file_path = os.path.join(OUTPUT_DIR, output_filename)

    if not os.path.isfile(file_path):
        print(f"[MAX_SHIFT={s_idx:2d}] File non trovato: {file_path} (saltato)")
        return None

    indici_riga = []
    errori_relativi = []
    dettagli_righe = []

    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            match = PATTERN.search(line)
            if match:
                fp1_str, fp2_str, a_is_zero_str, b_is_zero_str, res_str = match.groups()

                val_fp1 = decode_fp(fp1_str)
                val_fp2 = decode_fp(fp2_str)
                val_res = decode_fp(res_str)
                a_is_zero = int(a_is_zero_str)
                b_is_zero = int(b_is_zero_str)

                somma_attesa = np.float32(val_fp1 + val_fp2)

                # Costringo la somma_attesa ad essere compresa tra |2^(-22)| e |2^(15) * 1.5|
                max_val = np.float32((np.float32(2.0) ** 15) * 1.5)
                min_abs_val = np.float32(np.float32(2.0) ** (-22))
                floor_val = np.float32(np.float32(2.0) ** (-23))

                if abs(somma_attesa) < min_abs_val:
                    somma_attesa = floor_val
                elif abs(somma_attesa) > max_val:
                    somma_attesa = np.copysign(max_val, somma_attesa)

                if (a_is_zero and b_is_zero) or somma_attesa == 0:
                    somma_attesa = np.float32(np.float32(2.0) ** (-23))
                    err_rel = 0.0 if np.float32(abs(val_res)) == np.float32(np.float32(2.0) ** (-23)) else 1.0
                elif a_is_zero and not b_is_zero:
                    somma_attesa = val_fp2
                    err_rel = 0.0 if val_res == val_fp2 else float(abs(somma_attesa - val_res) / abs(somma_attesa))
                elif not a_is_zero and b_is_zero:
                    somma_attesa = val_fp1
                    err_rel = 0.0 if val_res == val_fp1 else float(abs(somma_attesa - val_res) / abs(somma_attesa))
                else:
                    err_rel = float(abs(somma_attesa - val_res) / abs(somma_attesa))

                indici_riga.append(line_num)
                errori_relativi.append(err_rel)
                dettagli_righe.append((line_num, val_fp1, val_fp2, somma_attesa, val_res, err_rel))

    if errori_relativi:
        max_err = max(errori_relativi)
        max_idx = errori_relativi.index(max_err)
        max_line_num = indici_riga[max_idx]
        mean_err = float(np.mean(errori_relativi))
        print(
            f"[MAX_SHIFT={s_idx:2d}] Max rel err: {max_err:.6e} (riga {max_line_num}) | "
            f"Mean rel err: {mean_err:.6e} | Righe valide: {len(errori_relativi)}"
        )
    else:
        max_err = None
        max_line_num = None
        mean_err = None
        print(f"[MAX_SHIFT={s_idx:2d}] Nessuna riga valida trovata in {input_filename}.")

    with open(output_file_path, 'w', encoding='utf-8') as out_file:
        out_file.write("=" * 60 + "\n")
        out_file.write(f"   ANALISI CONFRONTO FORMATI (MAX_SHIFT = {s_idx})\n")
        out_file.write("=" * 60 + "\n\n")

        out_file.write("[ TIPO dei Dati ]\n")
        out_file.write("  - Risultato AdderHif8 in HiFloat8 (8 bit):\n")
        out_file.write("      * Segno: 1 bit\n")
        out_file.write("      * dot: [2,4] bit\n")
        out_file.write("      * Esponente: [0,4] bit\n")
        out_file.write("      * Mantissa: [1,3] bit\n")
        out_file.write("  - Risultato Atteso in fp32:\n")
        out_file.write("      * Segno: 1 bit\n")
        out_file.write("      * Esponente: 8 bit\n")
        out_file.write("      * Mantissa: 23 bit\n")
        out_file.write("-" * 60 + "\n\n")

        if max_err is not None and mean_err is not None:
            out_file.write(f"ERRORE RELATIVO MASSIMO: {max_err:.6e} (Riga {max_line_num})\n")
            out_file.write(f"ERRORE RELATIVO MEDIO:   {mean_err:.6e}\n")
            out_file.write("-" * 60 + "\n\n")

        for line_num, val_fp1, val_fp2, somma_attesa, val_res, err_rel in dettagli_righe:
            out_file.write(f"--- Riga {line_num}   di  {input_filename} ---\n")
            out_file.write(f"  FP1 (10 bit):      {val_fp1}\n")
            out_file.write(f"  FP2 (10 bit):      {val_fp2}\n")
            out_file.write(f"  Atteso (f32):      {somma_attesa}\n")
            out_file.write(f"  Risultato (HiF8):  {val_res}\n")
            out_file.write(f"  Errore Relativo:   {err_rel:.6e}\n")
            out_file.write("\n")

    if max_err is not None and mean_err is not None:
        return s_idx, max_err, mean_err
    return None


def main():
    args = parse_args()
    if args.start > args.end:
        raise ValueError(f"SHIFT_START ({args.start}) non puo' essere maggiore di SHIFT_END ({args.end}).")

    shifts = list(range(args.start, args.end + 1))
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    x_vals = []
    rel_max_vals = []
    rel_mean_vals = []

    for s in shifts:
        res = process_shift(s)
        if res is not None:
            s_idx, max_err, mean_err = res
            x_vals.append(s_idx)
            rel_max_vals.append(max_err)
            rel_mean_vals.append(mean_err)

    print("\nx_vals:", x_vals)
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
        plt.savefig(os.path.join(OUTPUT_DIR, f"summary_rel_error_{args.start}_{args.end}.png"), dpi=150)
        plt.show()
    else:
        print("Nessun dato valido da plottare.")


if __name__ == "__main__":
    main()