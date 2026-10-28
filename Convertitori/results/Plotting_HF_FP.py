import re
import plotly.graph_objects as go

# Pattern per trovare E ed M 
pattern = r"E:(-?\d+),\s*M:([\d.]+)"

nome_file = "results_HF8_to_FP.txt"

# Liste per i numeri positivi
HF8_0EM_in = []
FP_0EM_out = []
ZF_HF2FP_pos = []

# Liste per i numeri negativi
HF8_1EM_in = []
FP_1EM_out = []
ZF_HF2FP_neg = []

try:
    with open(nome_file, "r", encoding="utf-8") as file:
        for riga in file:
            occorrenze = re.findall(pattern, riga)
            
            # Estrazione del flag zero dalla riga
            zf_hf2fp_m = re.search(r"ZF_HF2FP:\s*([01])", riga)
            zf_hf2fp = int(zf_hf2fp_m.group(1)) if zf_hf2fp_m else 0
            
            if len(occorrenze) >= 2:
                # Il primo carattere rappresenta il segno dell'ingresso HF8 (0 = positivo, 1 = negativo)
                if riga[0] == '0':
                    HF8_0EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    FP_0EM_out.append((int(occorrenze[1][0]), float(occorrenze[1][1])))
                    ZF_HF2FP_pos.append(zf_hf2fp)
                else:
                    HF8_1EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    FP_1EM_out.append((int(occorrenze[1][0]), float(occorrenze[1][1])))
                    ZF_HF2FP_neg.append(zf_hf2fp)

except FileNotFoundError:
    print('File ' + nome_file + ' non trovato')

# Calcolo valori reali Positivi
HF8_in_pos = [2**e * (1 + m) for e, m in HF8_0EM_in]
FP_out_pos = [2**e * (1 + m) for e, m in FP_0EM_out]

# Calcolo valori reali Negativi
HF8_in_neg = [-2**e * (1 + m) for e, m in HF8_1EM_in]
FP_out_neg = [-2**e * (1 + m) for e, m in FP_1EM_out]


HF8_in = HF8_in_pos + HF8_in_neg
FP_out = FP_out_pos + FP_out_neg
ZF_HF2FP = ZF_HF2FP_pos + ZF_HF2FP_neg

# Segmenti tra HF8_in (Y=1) e FP_out (Y=0)
x_segmenti = []
y_segmenti = []
for hf8_val, fp_val in zip(HF8_in, FP_out):
    x_segmenti.extend([hf8_val, fp_val, None])
    y_segmenti.extend([1, 0, None])

fig = go.Figure()

# Traccia segmenti  (HF8_in -> FP_out)
fig.add_trace(go.Scatter(
    x=x_segmenti,
    y=y_segmenti,
    mode='lines',
    name='Conversione (HF8 -> FP)',
    line=dict(color='rgba(100, 150, 200, 0.4)', width=1),
    hoverinfo='none',
    showlegend=True
))

# Linea Y=1 (HF8_in)
text_hf8_in = [f"HF8_in Reale: {val:.6f}" for val in HF8_in]
fig.add_trace(go.Scatter(
    x=HF8_in,
    y=[1] * len(HF8_in),
    mode='markers',
    name='HF8_in',
    text=text_hf8_in,
    hoverinfo='text',
    marker=dict(size=9, color='darkorange')
))

# Linea Y=0 (FP_out) 
text_fp_out = [
    f"FP_out Reale: {val:.6f}<br>ZeroFlag_HFtoFP: {zf}" 
    for val, zf in zip(FP_out, ZF_HF2FP)
]

fig.add_trace(go.Scatter(
    x=FP_out,
    y=[0] * len(FP_out),
    mode='markers',
    name='FP_out',
    text=text_fp_out,
    hoverinfo='text',
    marker=dict(size=7, color='forestgreen')
))

# Personalizzazione del layout
fig.update_layout(
    title="(Sequenza HF8 -> FP)",
    xaxis_title="Valore Numerico Reale sull'Asse X",
    yaxis=dict(
        tickmode='array',
        tickvals=[0, 1],
        ticktext=['FP_out', 'HF8_in'],
        range=[-0.5, 1.5]
    ),
    hovermode='closest',
    template='plotly_white'
)

fig.show()