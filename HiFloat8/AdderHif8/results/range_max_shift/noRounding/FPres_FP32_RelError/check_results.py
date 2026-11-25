import argparse
import os
import re
import numpy as np
import matplotlib.pyplot as plt

# Configurazione predefinita dell'intervallo MAX_SHIFT
SHIFT_START = 4
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

    # Restituisce esplicitamente un float a 32 bit di NumPy
    return np.float32(sign * (np.float32(2.0) ** exp) * mantissa_val)


PATTERN = re.compile(r'([01]{10})\s*\+\s*([01]{10})\s*=\s*([01]{10})')
INPUT_DIR = ".."
OUTPUT_DIR = "check_results"


def parse_args():
    parser = argparse.ArgumentParser(description="Analisi errore relativo FP_RES (10 bit) al variare di MAX_SHIFT.")
    parser.add_argument("--start", type=int, default=SHIFT_START, help="Valore iniziale di MAX_SHIFT")
    parser.add_argument("--end", type=int, default=SHIFT_END, help="Valore finale di MAX_SHIFT (incluso)")
    return parser.parse_args()


def process_shift(s_idx):
    input_filename = f"sum_results{s_idx}.txt"
    output_filename = f"check_results{s_idx}.txt"

    file_path = os.path.join(INPUT_DIR, input_filename)
    output_file_path = os.path.join(OUTPUT_DIR, output_filename)

    if not os.path.isfile(file_path):
        print(f"[MAX_SHIFT={s_idx}] File non trovato: {file_path} (saltato)")
        return

    indici_riga = []
    errori_relativi = []
    dettagli_righe = []

    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            match = PATTERN.search(line)
            if match:
                fp1_str, fp2_str, res_str = match.groups()

                val_fp1 = decode_fp(fp1_str)
                val_fp2 = decode_fp(fp2_str)
                val_res = decode_fp(res_str)

                somma_attesa = np.float32(val_fp1 + val_fp2)

                if somma_attesa != 0:
                    err_rel = abs(somma_attesa - val_res) / abs(somma_attesa)
                else:
                    err_rel = 0.0 if val_res == float(2 ** (-23)) else float(1)

                err_rel_float = float(err_rel)
                indici_riga.append(line_num)
                errori_relativi.append(err_rel_float)
                dettagli_righe.append((line_num, val_fp1, val_fp2, somma_attesa, val_res, err_rel_float))

    if errori_relativi:
        max_err = max(errori_relativi)
        max_line_num = indici_riga[errori_relativi.index(max_err)]
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
        out_file.write("  - Risultato AdderHif8 in FP (10 bit):\n")
        out_file.write("      * Segno: 1 bit\n")
        out_file.write("      * Esponente: 6 bit (complemento a 2)\n")
        out_file.write("      * Mantissa: 3 bit\n")
        out_file.write("  - Risultato Atteso float32:\n")
        out_file.write("      * Segno: 1 bit\n")
        out_file.write("      * Esponente: 8 bit\n")
        out_file.write("      * Mantissa: 23 bit\n")
        out_file.write("-" * 60 + "\n\n")

        if max_err is not None and mean_err is not None:
            out_file.write(f"ERRORE RELATIVO MASSIMO: {max_err:.6e} (Riga {max_line_num})\n")
            out_file.write(f"ERRORE RELATIVO MEDIO:   {mean_err:.6e}\n")
            out_file.write("-" * 60 + "\n\n")

        for line_num, val_fp1, val_fp2, somma_attesa, val_res, err_rel_float in dettagli_righe:
            out_file.write(f"--- Riga {line_num} di {input_filename} ---\n")
            out_file.write(f"  FP1 (10 bit):      {val_fp1}\n")
            out_file.write(f"  FP2 (10 bit):      {val_fp2}\n")
            out_file.write(f"  Atteso (f32):      {somma_attesa}\n")
            out_file.write(f"  Risultato (FP10):  {val_res}\n")
            out_file.write(f"  Errore Relativo:   {err_rel_float:.6e}\n\n")

    # Creazione del grafico per questo MAX_SHIFT
    if errori_relativi:
        plt.figure(figsize=(12, 6))
        plt.plot(indici_riga, errori_relativi, linewidth=0.5, color='#1f77b4', alpha=0.8)
        plt.axhline(max_err, color='red', linestyle='--', linewidth=1, label=f'Max: {max_err:.2e}')
        plt.axhline(mean_err, color='orange', linestyle='-.', linewidth=1, label=f'Media: {mean_err:.2e}')
        plt.legend()

        plt.title(f"Errore Relativo - MAX_SHIFT={s_idx} ({input_filename})", fontsize=14)
        plt.xlabel(f"Indice della riga di {input_filename}", fontsize=12)
        plt.ylabel("Errore relativo", fontsize=12)
        plt.grid(True, linestyle='--', alpha=0.6)
        plt.tight_layout()
        #plt.show()


def main():
    args = parse_args()
    if args.start > args.end:
        raise ValueError(f"SHIFT_START ({args.start}) non puo' essere maggiore di SHIFT_END ({args.end}).")

    max_shifts = range(args.start, args.end + 1)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    for s_idx in max_shifts:
        process_shift(s_idx)


if __name__ == "__main__":
    main()