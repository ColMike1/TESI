import re

import matplotlib.pyplot as plt

# Pattern per trovare E ed M (gestisce già i segni negativi su E)
pattern = r"E:(-?\d+),\s*M:([\d.]+)"

nome_file = "results_FP_HF_FP.txt"

# Liste per i numeri positivi
FP_0EM_in = []
FP_0EM_out = []


# Liste per i numeri negativi
FP_1EM_in = []
FP_1EM_out = []


try:
    with open(nome_file, "r", encoding="utf-8") as file:
        for riga in file:
            occorrenze = re.findall(pattern, riga)
            
            
            if len(occorrenze) >= 4:
                # riga[0] determina il segno (0 = positivo, 1 = negativo)
                if riga[0] == '0':
                    FP_0EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    FP_0EM_out.append((int(occorrenze[3][0]), float(occorrenze[3][1])))

                else:
                    FP_1EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    FP_1EM_out.append((int(occorrenze[3][0]), float(occorrenze[3][1])))


except FileNotFoundError:
    print('File ' + nome_file + ' non trovato')

# Calcolo valori reali Positivi
FP_in_pos = [2**e * (1 + m) for e, m in FP_0EM_in]
FP_out_pos = [2**e * (1 + m) for e, m in FP_0EM_out]

# Calcolo valori reali Negativi
FP_in_neg = [-2**e * (1 + m) for e, m in FP_1EM_in]
FP_out_neg = [-2**e * (1 + m) for e, m in FP_1EM_out]


FP_in = FP_in_pos + FP_in_neg
FP_out = FP_out_pos + FP_out_neg


# Plotting
dati_ordinati = sorted(zip(FP_in, FP_out))
FP_in_ordinato, FP_out_ordinato = zip(*dati_ordinati)


# ALPHA REGOLA LA TRASPARENZA DELLA LINEA (0 = MASSIMA TRASPARENZA)
plt.plot(FP_in_ordinato, FP_out_ordinato, drawstyle='steps-post', alpha=0.6)

# COMMENTARE plt.scatter(...) per togliere i punti
plt.scatter(FP_in_ordinato, FP_out_ordinato, marker='o', s=3)

plt.figtext(.7, .2, "I punti sono i valori in ingresso reali.\n La linea serve solo a collegarli")
plt.title("FPin to HF8 to FPout")
plt.xlabel("FP in")
plt.ylabel("FP out")
plt.xscale('symlog', base=2)
plt.yscale('symlog', base=2)
plt.grid(True, which="both", ls="--", alpha=0.5)
plt.show()