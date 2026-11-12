import re
import math

def parse_fp10(fp_str, zero_flag):
    """
    Converte una stringa binaria di 10 bit (1 segno, 6 esponente in comp. a 2, 3 mantissa) 
    nel corrispettivo valore float di Python, usando la formula:
    +/- 2^(exp) * (1.mantissa)
    """
    if zero_flag == 1 or fp_str == '0000000000':
        return 0.0
    
    # Estrazione dei campi secondo la struttura Verilog:
    # Bit [9] -> Segno
    # Bit [8:3] -> Esponente (6 bit in complemento a 2)
    # Bit [2:0] -> Mantissa (3 bit)
    sign_bit = int(fp_str[0])
    exp_bits = fp_str[1:7]
    mant_bits = fp_str[7:10]
    
    # Conversione dell'esponente a 6 bit in complemento a due (il sesto bit pari a 1 vale -32)
    exp_val = int(exp_bits, 2)
    if exp_bits[0] == '1':  # Se il bit più significativo dei 6 è 1
        exp_val -= 64       # Equivalente a sottrarre 32 se sommato ai bit positivi, 
                            # oppure gestito come: -(32) + bit successivi. 
                            # Più semplicemente: int(val) con segno a 6 bit:
    
    # Nota pulita per il complemento a 2 su 6 bit:
    if exp_val >= 32:
        exp_val -= 64
        
    # Conversione della mantissa (formato implicito 1.xxx -> 1 + mant_val / 8)
    mant_val = int(mant_bits, 2)
    mantissa = 1.0 + (mant_val / 8.0)
    
    # Calcolo del valore finale: +/- 2^(exp) * (1.xxx)
    val = ((-1) ** sign_bit) * (2 ** exp_val) * mantissa
    return val

def main():
    filename = "sum_results.txt"
    correct_count = 0
    incorrect_count = 0
    total_lines = 0

    # Regex per catturare la riga generata dal testbench
    pattern = re.compile(
        r"\|\s*FP1\s*=\s*([01]{10})\s*\|\s*ZERO_FP1\s*=\s*([01])\s*\|\s*"
        r"FP2\s*=\s*([01]{10})\s*\|\s*ZERO_FP2\s*=\s*([01])\s*\|\s*"
        r"FP_RES\s*=\s*([01]{10})\s*\|\s*ZERO_RES\s*=\s*([01])\s*\|"
    )

    try:
        with open(filename, "r") as f:
            for line in f:
                match = pattern.search(line)
                if match:
                    total_lines += 1
                    fp1_str, zero1_str, fp2_str, zero2_str, res_str, zero_res_str = match.groups()
                    
                    zero1 = int(zero1_str)
                    zero2 = int(zero2_str)
                    zero_res = int(zero_res_str)
                    
                    # Calcolo dei valori decimali
                    v1 = parse_fp10(fp1_str, zero1)
                    v2 = parse_fp10(fp2_str, zero2)
                    v_hw = parse_fp10(res_str, zero_res)
                    
                    # Somma teorica attesa
                    v_expected = v1 + v2
                    
                    # Confronto tollerando lievi scostamenti di arrotondamento hardware
                    if math.isclose(v_hw, v_expected, rel_tol=1e-4, abs_tol=1e-4):
                        correct_count += 1
                    else:
                        incorrect_count += 1
                        
        print(f"=== ANALISI COMPLETATA ===")
        print(f"Totale combinazioni testate: {total_lines}")
        print(f"Risultati corretti/coerenti: {correct_count}")
        print(f"Risultati differenti (es. arrotondamenti/overflow): {incorrect_count}")
        
    except FileNotFoundError:
        print(f"Errore: Il file '{filename}' non è stato trovato.")

if __name__ == "__main__":
    main()