import re
import numpy as np
import matplotlib.pyplot as plt

# PIP INSTALL MPLCURSORS se l'interprete non riconosce l'import
import mplcursors  

def parse_twos_complement_6bit(bits_str):
    val = int(bits_str, 2)
    if bits_str[0] == '1':
        val -= (1 << 6)
    return val

def decode_fp(fp_str):
    sign_bit = fp_str[0]
    exp_bits = fp_str[1:7]
    mant_bits = fp_str[7:10]
    
    sign = -1 if sign_bit == '1' else 1
    exp = parse_twos_complement_6bit(exp_bits)
    
    m0 = int(mant_bits[0])
    m1 = int(mant_bits[1])
    m2 = int(mant_bits[2])
    
    mantissa_val = 1.0 + (m0 * 0.5) + (m1 * 0.25) + (m2 * 0.125)
    return np.float32(sign * (2 ** exp) * mantissa_val)

pattern = re.compile(r'([01]{10})\s*\+\s*([01]{10})\s*=\s*([01]{10})')
file_path = "sum_results.txt"

valori_fp1 = []
valori_fp2 = []
errori_relativi = []
bin_fp1_list = []
bin_fp2_list = []


with open(file_path, 'r', encoding='utf-8') as f:
    for line in f:
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
                err_rel = 0.0 if val_res == 2**(-32) else 1
            
            valori_fp1.append(float(val_fp1))
            valori_fp2.append(float(val_fp2))
            errori_relativi.append(float(err_rel))
            bin_fp1_list.append(fp1_str)
            bin_fp2_list.append(fp2_str)


fig, ax = plt.subplots(figsize=(10, 8))

scatter = ax.scatter(
    valori_fp1, 
    valori_fp2, 
    c=errori_relativi, 
    cmap='magma_r', 
    s=12,          
    alpha=0.8     
)

cbar = plt.colorbar(scatter, ax=ax)
cbar.set_label('Errore Relativo (più scuro = errore maggiore)', fontsize=12)

ax.set_title("Errore Relativo (usato solo 2 bit di paddin: 1.xxx_00)", fontsize=14)
ax.set_xlabel("Valore FP1 (scala logaritmica)", fontsize=12)
ax.set_ylabel("Valore FP2 (scala logaritmica)", fontsize=12)

ax.set_xscale('symlog',  base=2)
ax.set_yscale('symlog',  base=2)
ax.grid(True, linestyle='--', alpha=0.4)

# Configurazione del cursore 
cursor = mplcursors.cursor(scatter, hover=True)

@cursor.connect("add")
def on_add(sel):
    index = sel.index
    b1 = bin_fp1_list[index]
    b2 = bin_fp2_list[index]
    err = errori_relativi[index]
    
   
    sel.annotation.set_text(
        f"FP1 (bin): {b1}\n"
        f"FP2 (bin): {b2}\n"
        f"Err. Relativo: {err:.4e}"
    )
    sel.annotation.get_bbox_patch().set(facecolor='white', alpha=0.9, edgecolor='black')

plt.tight_layout()
plt.show()