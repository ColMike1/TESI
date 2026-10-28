import re
import plotly.graph_objects as go

# Pattern per trovare E ed M (gestisce già i segni negativi su E)
pattern = r"E:(-?\d+),\s*M:([\d.]+)"

nome_file = "results_FP_HF_FP.txt"

# Liste per i numeri positivi
FP_0EM_in = []
HF8_0EM_mid = []
FP_0EM_out = []
ZF_FP2HF_pos = []
ZF_HF2FP_pos = []

# Liste per i numeri negativi
FP_1EM_in = []
HF8_1EM_mid = []
FP_1EM_out = []
ZF_FP2HF_neg = []
ZF_HF2FP_neg = []

try:
    with open(nome_file, "r", encoding="utf-8") as file:
        for riga in file:
            occorrenze = re.findall(pattern, riga)
            
            # Estrazione dei flag zero dalla riga
            zf_fp2hf_m = re.search(r"ZF_FP2HF:\s*([01])", riga)
            zf_hf2fp_m = re.search(r"ZF_HF2FP:\s*([01])", riga)
            
            zf_fp2hf = int(zf_fp2hf_m.group(1)) if zf_fp2hf_m else 0
            zf_hf2fp = int(zf_hf2fp_m.group(1)) if zf_hf2fp_m else 0
            
            if len(occorrenze) >= 4:
                # Supponiamo che riga[0] determini il segno (0 = positivo, 1 = negativo)
                if riga[0] == '0':
                    FP_0EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    HF8_0EM_mid.append((int(occorrenze[1][0]), float(occorrenze[1][1])))
                    FP_0EM_out.append((int(occorrenze[3][0]), float(occorrenze[3][1])))
                    ZF_FP2HF_pos.append(zf_fp2hf)
                    ZF_HF2FP_pos.append(zf_hf2fp)
                else:
                    FP_1EM_in.append((int(occorrenze[0][0]), float(occorrenze[0][1])))
                    HF8_1EM_mid.append((int(occorrenze[1][0]), float(occorrenze[1][1])))
                    FP_1EM_out.append((int(occorrenze[3][0]), float(occorrenze[3][1])))
                    ZF_FP2HF_neg.append(zf_fp2hf)
                    ZF_HF2FP_neg.append(zf_hf2fp)

except FileNotFoundError:
    print('File ' + nome_file + ' non trovato')

# Calcolo valori reali Positivi
FP_in_pos = [2**e * (1 + m) for e, m in FP_0EM_in]
HF8_mid_pos = [2**e * (1 + m) for e, m in HF8_0EM_mid]
FP_out_pos = [2**e * (1 + m) for e, m in FP_0EM_out]

# Calcolo valori reali Negativi
FP_in_neg = [-2**e * (1 + m) for e, m in FP_1EM_in]
HF8_mid_neg = [-2**e * (1 + m) for e, m in HF8_1EM_mid]
FP_out_neg = [-2**e * (1 + m) for e, m in FP_1EM_out]


FP_in = FP_in_pos + FP_in_neg
HF8_mid = HF8_mid_pos + HF8_mid_neg
FP_out = FP_out_pos + FP_out_neg
ZF_FP2HF = ZF_FP2HF_pos + ZF_FP2HF_neg
ZF_HF2FP = ZF_HF2FP_pos + ZF_HF2FP_neg

# Mappatura HF8 -> FP estesa a tutti i valori
mappa_hf8_a_fp = {}
for fp_val, hf8_val in zip(FP_in, HF8_mid):
    if hf8_val not in mappa_hf8_a_fp:
        mappa_hf8_a_fp[hf8_val] = []
    mappa_hf8_a_fp[hf8_val].append(fp_val)

# Segmenti tra FP_in (Y=2) e HF8_mid (Y=1)
x_segmenti_in = []
y_segmenti_in = []
for fp_in_val, hf8_val in zip(FP_in, HF8_mid):
    x_segmenti_in.extend([fp_in_val, hf8_val, None])
    y_segmenti_in.extend([2, 1, None])

# Segmenti tra HF8_mid (Y=1) e FP_out (Y=0)
x_segmenti_out = []
y_segmenti_out = []
for hf8_val, fp_out_val in zip(HF8_mid, FP_out):
    x_segmenti_out.extend([hf8_val, fp_out_val, None])
    y_segmenti_out.extend([1, 0, None])

fig = go.Figure()

# Traccia segmenti (FP_in -> HF8_mid)
fig.add_trace(go.Scatter(
    x=x_segmenti_in,
    y=y_segmenti_in,
    mode='lines',
    name='Mappatura (FP_in -> HF8)',
    line=dict(color='rgba(150, 150, 150, 0.4)', width=1),
    hoverinfo='none',
    showlegend=True
))

# Traccia segmenti (HF8_mid -> FP_out)
fig.add_trace(go.Scatter(
    x=x_segmenti_out,
    y=y_segmenti_out,
    mode='lines',
    name='Mappatura (HF8 -> FP_out)',
    line=dict(color='rgba(100, 150, 200, 0.4)', width=1),
    hoverinfo='none',
    showlegend=True
))

# Linea Y=2 (FP_in)
text_fp_in = [f"FP_in Reale: {val:.6f}" for val in FP_in]
fig.add_trace(go.Scatter(
    x=FP_in,
    y=[2] * len(FP_in),
    mode='markers',
    name='FP_in',
    text=text_fp_in,
    hoverinfo='text',
    marker=dict(size=7, color='royalblue')
))

# Linea Y=1 (HF8_mid) 
text_hf8 = [
    f"HF8_mid Reale: {val:.6f}<br>FP_in associati: {len(mappa_hf8_a_fp.get(val, []))}<br>ZeroFlag_FPtoHF: {zf1}" 
    for val, zf1 in zip(HF8_mid, ZF_FP2HF)]


fig.add_trace(go.Scatter(
    x=HF8_mid,
    y=[1] * len(HF8_mid),
    mode='markers',
    name='HF8_mid',
    text=text_hf8,
    hoverinfo='text',
    marker=dict(size=9, color='darkorange')
))

# Linea Y=0 (FP_out)
text_fp_out = [f"FP_out Reale: {val:.6f} <br>ZeroFlag_HFtoFP: {zf2}" for val, zf2 in zip(FP_out, ZF_HF2FP)]
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
    title="(Sequenza FP -> HF8 -> FP)",
    xaxis_title="Valore Numerico Reale sull'Asse X",
    yaxis=dict(
        tickmode='array',
        tickvals=[0, 1, 2],
        ticktext=['FP_out', 'HF8_mid', 'FP_in'],
        range=[-0.5, 2.5]
    ),
    hovermode='closest',
    template='plotly_white'
)

fig.show()