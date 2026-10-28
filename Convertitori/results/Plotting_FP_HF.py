import re
import plotly.graph_objects as go

# Pattern per trovare E ed M 
pattern = r"E:(-?\d+),\s*M:([\d.]+)"

nome_file = "results_FP_to_HF8.txt"

# Liste per i numeri positivi
FP_0EM_in = []
HF8_0EM_out = []
ZF_FP2HF_pos = []

# Liste per i numeri negativi
FP_1EM_in = []
HF8_1EM_out = []
ZF_FP2HF_neg = []

try:
    with open(nome_file, "r", encoding="utf-8") as file:
        for riga in file:
            occorrenze = re.findall(pattern, riga)
            
            # Estrazione del flag zero dalla riga
            zf_fp2hf_m = re.search(r"ZF_FP2HF:\s*([01])", riga)
            zf_fp2hf = int(zf_fp2hf_m.group(1)) if zf_fp2hf_m else 0
            
            if len(occorrenze) >= 2:
                # Il primo carattere rapprsnta il segno dell'ingresso FP (0 = positivo, 1 = negativo)
                if riga[0] == '0':
                    FP_0EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    HF8_0EM_out.append((int(occorrenze[1][0]), float(occorrenze[1][1])))
                    ZF_FP2HF_pos.append(zf_fp2hf)
                else:
                    FP_1EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    HF8_1EM_out.append((int(occorrenze[1][0]), float(occorrenze[1][1])))
                    ZF_FP2HF_neg.append(zf_fp2hf)

except FileNotFoundError:
    print('File ' + nome_file + ' non trovato')

# Calcolo valori reali Positivi
FP_in_pos   = [2**e * (1 + m) for e, m in FP_0EM_in]
HF8_out_pos = [2**e * (1 + m) for e, m in HF8_0EM_out]

# Calcolo valori reali Negativi
FP_in_neg   = [-2**e * (1 + m) for e, m in FP_1EM_in]
HF8_out_neg = [-2**e * (1 + m) for e, m in HF8_1EM_out]


FP_in    = FP_in_pos + FP_in_neg
HF8_out  = HF8_out_pos + HF8_out_neg
ZF_FP2HF = ZF_FP2HF_pos + ZF_FP2HF_neg

# Segmenti tra FP_in (Y=1) e HF8_out (Y=0)
x_segmenti = []
y_segmenti = []
for fp_val, hf8_val in zip(FP_in, HF8_out):
    x_segmenti.extend([fp_val, hf8_val, None])
    y_segmenti.extend([1, 0, None])

fig = go.Figure()

# Traccia segmenti (FP_in -> HF8_out)
fig.add_trace(go.Scatter(
    x=x_segmenti,
    y=y_segmenti,
    mode='lines',
    name='Conversione (FP -> HF8)',
    line=dict(color='rgba(150, 150, 150, 0.4)', width=1),
    hoverinfo='none',
    showlegend=True
))

# Linea Y=1 (FP_in)
text_fp_in = [f"FP_in Reale: {val:.6f}" for val in FP_in]
fig.add_trace(go.Scatter(
    x=FP_in,
    y=[1] * len(FP_in),
    mode='markers',
    name='FP_in',
    text=text_fp_in,
    hoverinfo='text',
    marker=dict(size=7, color='royalblue')
))

# Linea Y=0 (HF8_out) 
text_hf8_out = [
    f"HF8_out Reale: {val:.6f}<br>ZeroFlag_FPtoHF: {zf}" 
    for val, zf in zip(HF8_out, ZF_FP2HF)
]

fig.add_trace(go.Scatter(
    x=HF8_out,
    y=[0] * len(HF8_out),
    mode='markers',
    name='HF8_out',
    text=text_hf8_out,
    hoverinfo='text',
    marker=dict(size=9, color='darkorange')
))

# Personalizzazione del layout
fig.update_layout(
    title="(Sequenza FP -> HF8)",
    xaxis_title="Valore Numerico Reale sull'Asse X",
    yaxis=dict(
        tickmode='array',
        tickvals=[0, 1],
        ticktext=['HF8_out', 'FP_in'],
        range=[-0.5, 1.5]
    ),
    hovermode='closest',
    template='plotly_white'
)

fig.show()
