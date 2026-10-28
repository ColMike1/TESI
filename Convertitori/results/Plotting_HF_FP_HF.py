import re
import plotly.graph_objects as go

# Pattern per trovare E ed M
pattern = r"E:(-?\d+),\s*M:([\d.]+)"

nome_file = "results_HF_FP_HF.txt"

# Liste per i numeri positivi
HF8_0EM_in = []
FP_0EM_mid = []
HF8_0EM_out = []
ZF_HF2FP_pos = []
ZF_FP2HF_pos = []

# Liste per i numeri negativi
HF8_1EM_in = []
FP_1EM_mid = []
HF8_1EM_out = []
ZF_HF2FP_neg = []
ZF_FP2HF_neg = []

try:
    with open(nome_file, "r", encoding="utf-8") as file:
        for riga in file:
            occorrenze = re.findall(pattern, riga)
            
            # Estrazione dei flag zero dalla riga
            
            zf_hf2fp_m = re.search(r"ZF_HF2FP:\s*([01])", riga)
            zf_fp2hf_m = re.search(r"ZF_FP2HF:\s*([01])", riga)
            
            
            zf_hf2fp = int(zf_hf2fp_m.group(1)) if zf_hf2fp_m else 0
            zf_fp2hf = int(zf_fp2hf_m.group(1)) if zf_fp2hf_m else 0
            
            if len(occorrenze) >= 4:
                # Il primo carattere rappresenta il segno dell'ingresso HF8 (0 = positivo, 1 = negativo)
                if riga[0] == '0':
                    HF8_0EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    FP_0EM_mid.append((int(occorrenze[1][0]), float(occorrenze[1][1])))
                    HF8_0EM_out.append((int(occorrenze[3][0]), float(occorrenze[3][1])))
                    ZF_HF2FP_pos.append(zf_hf2fp)
                    ZF_FP2HF_pos.append(zf_fp2hf)
                else:
                    HF8_1EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    FP_1EM_mid.append((int(occorrenze[1][0]), float(occorrenze[1][1])))
                    HF8_1EM_out.append((int(occorrenze[3][0]), float(occorrenze[3][1])))
                    ZF_HF2FP_neg.append(zf_hf2fp)
                    ZF_FP2HF_neg.append(zf_fp2hf)

except FileNotFoundError:
    print('File ' + nome_file + ' non trovato')

# Calcolo valori reali Positivi
HF8_in_pos  = [2**e * (1 + m) for e, m in HF8_0EM_in]
FP_mid_pos  = [2**e * (1 + m) for e, m in FP_0EM_mid]
HF8_out_pos = [2**e * (1 + m) for e, m in HF8_0EM_out]

# Calcolo valori reali Negativi
HF8_in_neg  = [-2**e * (1 + m) for e, m in HF8_1EM_in]
FP_mid_neg  = [-2**e * (1 + m) for e, m in FP_1EM_mid]
HF8_out_neg = [-2**e * (1 + m) for e, m in HF8_1EM_out]


HF8_in   = HF8_in_pos + HF8_in_neg
FP_mid   = FP_mid_pos + FP_mid_neg
HF8_out  = HF8_out_pos + HF8_out_neg
ZF_HF2FP = ZF_HF2FP_pos + ZF_HF2FP_neg
ZF_FP2HF = ZF_FP2HF_pos + ZF_FP2HF_neg

# Mappatura FP_mid -> HF8_in per tracciare convergenza ad un unico valore HF8
mappa_fp_a_hf8 = {}
for hf8_in_val, fp_val in zip(HF8_in, FP_mid):
    if fp_val not in mappa_fp_a_hf8:
        mappa_fp_a_hf8[fp_val] = []
    mappa_fp_a_hf8[fp_val].append(hf8_in_val)

# Segmenti tra HF8_in (Y=2) e FP_mid (Y=1)
x_segmenti_in = []
y_segmenti_in = []
for hf8_in_val, fp_mid_val in zip(HF8_in, FP_mid):
    x_segmenti_in.extend([hf8_in_val, fp_mid_val, None])
    y_segmenti_in.extend([2, 1, None])

# Segmenti tra FP_mid (Y=1) e HF8_out (Y=0)
x_segmenti_out = []
y_segmenti_out = []
for fp_mid_val, hf8_out_val in zip(FP_mid, HF8_out):
    x_segmenti_out.extend([fp_mid_val, hf8_out_val, None])
    y_segmenti_out.extend([1, 0, None])

fig = go.Figure()

# Traccia segmenti (HF8_in -> FP_mid)
fig.add_trace(go.Scatter(
    x=x_segmenti_in,
    y=y_segmenti_in,
    mode='lines',
    name='Mappatura (HF8_in -> FP)',
    line=dict(color='rgba(100, 150, 200, 0.4)', width=1),
    hoverinfo='none',
    showlegend=True
))

# Traccia segmenti (FP_mid -> HF8_out)
fig.add_trace(go.Scatter(
    x=x_segmenti_out,
    y=y_segmenti_out,
    mode='lines',
    name='Mappatura (FP -> HF8_out)',
    line=dict(color='rgba(150, 150, 150, 0.4)', width=1),
    hoverinfo='none',
    showlegend=True
))

# Linea Y=2 (HF8_in)
text_hf8_in = [f"HF8_in Reale: {val:.6f}" for val in HF8_in]
fig.add_trace(go.Scatter(
    x=HF8_in,
    y=[2] * len(HF8_in),
    mode='markers',
    name='HF8_in',
    text=text_hf8_in,
    hoverinfo='text',
    marker=dict(size=9, color='darkorange')
))

# Linea Y=1 (FP_mid) 
text_fp_mid = [
    f"FP_mid Reale: {val:.6f}<br>HF8_in associati: {len(mappa_fp_a_hf8.get(val, []))}<br>ZeroFlag_HFtoFP: {zf1}" 
    for val, zf1 in zip(FP_mid, ZF_HF2FP)
]

fig.add_trace(go.Scatter(
    x=FP_mid,
    y=[1] * len(FP_mid),
    mode='markers',
    name='FP_mid',
    text=text_fp_mid,
    hoverinfo='text',
    marker=dict(size=7, color='royalblue')
))

# Linea Y=0 (HF8_out)
text_hf8_out = [f"HF8_out Reale: {val:.6f} <br>ZeroFlag_FPtoHF: {zf2}" for val, zf2 in zip(HF8_out, ZF_FP2HF)]
fig.add_trace(go.Scatter(
    x=HF8_out,
    y=[0] * len(HF8_out),
    mode='markers',
    name='HF8_out',
    text=text_hf8_out,
    hoverinfo='text',
    marker=dict(size=9, color='forestgreen')
))

# Personalizzazione del layout
fig.update_layout(
    title="(Sequenza HF8 -> FP -> HF8)",
    xaxis_title="Valore Numerico Reale sull'Asse X",
    yaxis=dict(
        tickmode='array',
        tickvals=[0, 1, 2],
        ticktext=['HF8_out', 'FP_mid', 'HF8_in'],
        range=[-0.5, 2.5]
    ),
    hovermode='closest',
    template='plotly_white'
)

fig.show()