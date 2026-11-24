import re

import matplotlib.pyplot as plt

# Pattern per trovare E ed M
pattern = r"E:(-?\d+),\s*M:([\d.]+)"

nome_file = "results_HF_FP_HF.txt"

# Liste per i numeri positivi
HF8_0EM_in = []
HF8_0EM_out = []


# Liste per i numeri negativi
HF8_1EM_in = []
HF8_1EM_out = []


try:
    with open(nome_file, "r", encoding="utf-8") as file:
        for riga in file:
            occorrenze = re.findall(pattern, riga)
            
            
            if len(occorrenze) >= 4:
                # Il primo carattere rappresenta il segno dell'ingresso HF8 (0 = positivo, 1 = negativo)
                if riga[0] == '0':
                    HF8_0EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))      
                    HF8_0EM_out.append((int(occorrenze[3][0]), float(occorrenze[3][1])))
                    
                else:
                    HF8_1EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    HF8_1EM_out.append((int(occorrenze[3][0]), float(occorrenze[3][1])))
                    

except FileNotFoundError:
    print('File ' + nome_file + ' non trovato')

# Calcolo valori reali Positivi
HF8_in_pos  = [2**e * (1 + m) for e, m in HF8_0EM_in]
HF8_out_pos = [2**e * (1 + m) for e, m in HF8_0EM_out]

# Calcolo valori reali Negativi
HF8_in_neg  = [-2**e * (1 + m) for e, m in HF8_1EM_in]
HF8_out_neg = [-2**e * (1 + m) for e, m in HF8_1EM_out]


HF8_in   = HF8_in_pos + HF8_in_neg
HF8_out  = HF8_out_pos + HF8_out_neg



# Plotting
dati_ordinati = sorted(zip(HF8_in, HF8_out))
HF8_in_ordinato, HF8_out_ordinato = zip(*dati_ordinati)

# ALPHA REGOLA LA TRASPARENZA DELLA LINEA (0 = MASSIMA TRASPARENZA)
plt.plot(HF8_in_ordinato, HF8_out_ordinato, drawstyle='steps-post', alpha=0.6)

# COMMENTARE plt.scatter(...) per togliere i punti
plt.scatter(HF8_in_ordinato, HF8_out_ordinato, marker='o', s=3)

plt.figtext(.7, .2, "I punti sono i valori in ingresso reali.\n La linea serve solo a collegarli")
plt.title("HF8in to FP to HF8out")
plt.xlabel("HiFloat8 in")
plt.ylabel("HiFloat8 out")
plt.xscale('symlog', base=2)
plt.yscale('symlog', base=2)
plt.grid(True, which="both", ls="--", alpha=0.5)
plt.show()
