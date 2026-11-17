import re
import numpy as np
import matplotlib.pyplot as plt

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
    
    mantissa_val = 1.0 + (m0 * 0.5) + (m1 * 0.25) + (m2 * 0.125)
    
    # Restituisce esplicitamente un float a 32 bit di NumPy
    return np.float32(sign * (2 ** exp) * mantissa_val)

pattern = re.compile(r'([01]{10})\s*\+\s*([01]{10})\s*=\s*([01]{10})')

file_path = "sum_results.txt"
output_file_path = "check_results.txt"

indici_riga = []
errori_relativi = []



with open(output_file_path, 'w', encoding='utf-8') as out_file:

    out_file.write("=" * 60 + "\n")
    out_file.write("             ANALISI CONFRONTO FORMATI IN VIRGOLA MOBILE\n")
    out_file.write("=" * 60 + "\n\n")
    
    out_file.write("[ TIPO dei Dati ]\n")
    out_file.write("  - Risultato Adder Hif8:\n")
    out_file.write("      * Segno: 1 bit\n")
    out_file.write("      * Esponente: 6 bit (complemento a 2)\n")
    out_file.write("      * Mantissa: 3 bit\n")
    out_file.write("  - Risultato Atteso (in NumPy float32):\n")
    out_file.write("      * Segno: 1 bit\n")
    out_file.write("      * Esponente: 8 bit\n")
    out_file.write("      * Mantissa: 23 bit\n")
    out_file.write("-" * 60 + "\n\n")
  

    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            match = pattern.search(line)
            if match:
                fp1_str, fp2_str, res_str = match.groups()
                
                val_fp1 = decode_fp(fp1_str)
                val_fp2 = decode_fp(fp2_str)
                val_res = decode_fp(res_str)
                
                somma_attesa = np.float32(val_fp1 + val_fp2)
                
                if somma_attesa != 0:
                    err_rel = abs(somma_attesa - val_res) / abs(somma_attesa)
                else:
                    err_rel = 0.0 if val_res == float(2.3283064365386963e-10) else float('inf')
                
                # Scrittura multilinea pulita per ogni operazione
                out_file.write(f"--- Riga {line_num} ---\n")
                out_file.write(f"  FP1 (10 bit):   {val_fp1}\n")
                out_file.write(f"  FP2 (10 bit):   {val_fp2}\n")
                out_file.write(f"  Atteso (f32):   {somma_attesa}\n")
                out_file.write(f"  Adder:  {val_res}\n")
                out_file.write(f"  Errore Relativo: {err_rel:.6e}\n") 
                out_file.write("\n")
                
                indici_riga.append(line_num)
                errori_relativi.append(float(err_rel))


# Creazione del grafico
plt.figure(figsize=(12, 6))
plt.plot(indici_riga, errori_relativi, linewidth=0.5, color='#1f77b4', alpha=0.8)

plt.title("Errore Relativo (risultato atteso - risultato dell'adderHif8)", fontsize=14)
plt.xlabel("Indice della riga del file sum_results.txt", fontsize=12)
plt.ylabel("Errore relativo", fontsize=12)
plt.grid(True, linestyle='--', alpha=0.6)
# plt.xscale('log')

plt.tight_layout()
plt.show()