/*
Questo codice   un estensione del codice sorgente 'Adder_Hif8_final.v', ed   usato per il testbench

--- Addizionatore di numeri HiFloat8 ---

Cosa fa questo modulo: 

1) prende in ingresso due HiFloat8;
2) converte i due numeri HiFloat8 nei formati FP in complemento a 2;
3) effettua uno shift della mantissa del numero FP pi  piccolo, allineando l'esponente di tale numero con l'FP pi  grande;
4) calcola il segno del risultato finale confrontando le due mantisse: quella non shiftata e quella shiftata. Il segno
   del risultato finale   quello della mantissa shiftata pi  grande;
5) effettua la somma (o sottrazione) delle mantisse. 
6) il risultato viene passato ad un Leading One Detector per effettuare eventuali shift da overflow/underflow e aumentare/diminuire l'esponente;
7) ricostruisce il risultato in FP: (segno, Exp, mant) in 10 bit;
8) passa il risultato al convertitore FP_to_HiFloat8;
9) L'output   l'uscita di quest'ultimo convertitore;

*/


module adder_HiF8 (
	input wire [7:0] hif8_a_in,   // HiF8
	input wire [7:0] hif8_b_in,   // HiF8	
	output wire [7:0] hif8_res_out   // custom FP {S,Exp,M} 
									// S: 1bit. Exp: 6bit (2's complement).  M: 3bit (unsigned with 1 hidden bit)
									// Exp value in [-23,15]
);

wire [9:0] fp_from_hif8_a,fp_from_hif8_b;
wire	  a_is_zero,b_is_zero;   // inputs are zero flag

wire sign_a, sign_b;
wire [5:0] exp_a,exp_b;   // 6bit 2's comp  
wire [3:0] full_mant_a,full_mant_b; // 4bit including the hidden 1

/* 2. Conversione dei numeri HiFloat8 in FP*/

/*Conversione: hif8_a_in -> FP*/
HiFloat8_to_FP_converter HF8a_to_FP(
	.hif8_in(hif8_a_in),
	.fp_out(fp_from_hif8_a),
	.zero_flag_out(a_is_zero));

/*Conversione: hif8_b_in -> FP*/
HiFloat8_to_FP_converter HF8b_to_FP(
	.hif8_in(hif8_b_in),
	.fp_out(fp_from_hif8_b),
	.zero_flag_out(b_is_zero));

/* Estrazione segno, esponente, mantissa dai due FP in uscita dai convertitori*/
/*  estrae sign_a, exp_a, mant_a*/
assign	sign_a = fp_from_hif8_a[9];
assign	exp_a  = fp_from_hif8_a[8:3];
assign	full_mant_a = {1'b1, fp_from_hif8_a[2:0]};
/*  estrae sign_b, exp_b, mant_b*/
assign	sign_b = fp_from_hif8_b[9];
assign	exp_b  = fp_from_hif8_b[8:3];
assign	full_mant_b = {1'b1, fp_from_hif8_b[2:0]};

/* 3. Calcolo dello shift del numero FP pi  piccolo*/
wire exp_a_ge_exp_b = $signed(exp_a) >= $signed(exp_b);
wire [5:0] result_exp_tmp = exp_a_ge_exp_b ? exp_a : exp_b;     
/*Per il momento, il risultato ha come esponente quello pi  
grande tra i due FP. Dopo ci possono essere degli shift
e magari cambia di nuovo. Per il momento   tmp=temporaneo*/



wire [2:0] shift_amount;




wire [6:0] exp_diff;  // 7bit 2's compl. Is the difference of 2 signals on 6 bitsin [-23,15]
// Extreme values [-23-(+15),15-(-23)] = [-38,+38]
wire [5:0] abs_exp_diff;  // 6bit 2's compl. This is always positive in [0,+38] 
// 3.1  Calcolo lo shift di massimo 7 posizioni
assign	exp_diff = ($signed(exp_a) - $signed(exp_b));
assign	abs_exp_diff = exp_diff[6] ? (-exp_diff) : (exp_diff);
assign shift_amount = (abs_exp_diff > 3'b101) ? 3'b101 : abs_exp_diff[2:0];


// mantissa shift
wire [3:0] to_be_shifted;
wire [4:0] mant_shifted;
wire [4:0] full_mant_a_shifted;  
wire [4:0] full_mant_b_shifted;  
assign to_be_shifted = exp_a_ge_exp_b ? full_mant_b : full_mant_a; 


assign mant_shifted = ({to_be_shifted, 1'b0} >> shift_amount);
assign full_mant_a_shifted = exp_a_ge_exp_b ? {full_mant_a, 1'b0} : mant_shifted;
assign full_mant_b_shifted = exp_a_ge_exp_b ?  mant_shifted : {full_mant_b, 1'b0};



/* 4. Calcola il segno del risultato finale
Il segno del risultato res_sign  :
	- se i segni dei due numeri sono uguali, il segno finale sar  uguale a tale segno (Pos + Pos = Pos, Neg + Neg = Neg)
	- se i segni dei due numeri sono diversi, il segno finale   quello del numero con mantissa shiftata pi  grande */
//  compare final mantissas 
wire mant_a_ge_mant_b = full_mant_a_shifted >= full_mant_b_shifted;  // check if can be simplified. Use the case when shift_amount=0 and only comp 2 btis

// decide sign of the result
wire result_sign;
assign	result_sign = (sign_a == sign_b) ? sign_a : (mant_a_ge_mant_b ? sign_a : sign_b);


/* 5. Effettua la somma o la sottrazione delle mantisse */

reg [5:0] result_mant_temp;

/* 5.1 Sesto blocco procedurale*/
always @(full_mant_a_shifted, full_mant_b_shifted, sign_a, sign_b, mant_a_ge_mant_b) begin
	case ({sign_a, sign_b}) 
		2'b00, 2'b11: 	result_mant_temp <= {1'b0, full_mant_a_shifted} + {1'b0, full_mant_b_shifted};
		2'b01, 2'b10: 	result_mant_temp <= mant_a_ge_mant_b ? {1'b0, full_mant_a_shifted} - {1'b0, full_mant_b_shifted} : 
                                           		      {1'b0, full_mant_b_shifted} - {1'b0, full_mant_a_shifted}; 
		default:	result_mant_temp <= 6'bxxx_xxx;
	endcase
end

/* 6. Leading One Detector*/
wire direction; /* 0 = sinistra, 1 = destra*/
wire lod_zero;
reg [2:0] lod_shift_amt;

/* 6.1 settimo blocco procedurale */

assign lod_zero = ({~hif8_a_in[7],hif8_a_in[6:0]}==hif8_b_in);

always @(result_mant_temp) begin
	casex(result_mant_temp)
		6'b1_xxxx_x: lod_shift_amt = 3'b001; /*Shift di uno...*/
		6'b0_1xxx_x: lod_shift_amt = 3'b000; /*Shift di 0...*/
		6'b0_01xx_x: lod_shift_amt = 3'b001; /*Shift di uno...*/
		6'b0_001x_x: lod_shift_amt = 3'b010; /*Shift di due...*/
		6'b0_0001_x: lod_shift_amt = 3'b011; /*Shift di tre...*/
		6'b0_0000_1: lod_shift_amt = 3'b100; /*Shift di quattro...*/

		default: lod_shift_amt     	  = 3'b101; /*Shift di cinque*/ 		
	endcase
end

assign direction = result_mant_temp[5];

/* 7. Ricostruzione del risultato in FP, considerando gli eventuali shift tenuti in considerazione dal LOD*/


wire [5:0] result_exp;
wire [2:0] result_mant;
wire [9:0] sum_result_in_FP; 
wire [5:0] shifted_result_mant_temp;

     /* 
	Aggiorna l'esponente in base al verso dello shift del LOD
           direction == 1'b0 (a sinistra) -> decrementa l'esponente
           direction == 1'b1 (a destra)   -> incrementa l'esponente
	*/

// Estensione sicura con bit di segno 0 per evitare interpretazioni negative involontarie
wire signed [3:0] shift_ext = {1'b0, lod_shift_amt};
wire signed [3:0] signed_delta = direction ? shift_ext : -shift_ext;
assign result_exp = $signed(result_exp_tmp) + signed_delta;

// assign result_exp = direction ? ($signed(result_exp_tmp) + lod_shift_amt) : ($signed(result_exp_tmp) - $signed(lod_shift_amt));   // DA SOSTITUIRE CON UN SOLO ADDIZIONATORE 
assign shifted_result_mant_temp = direction ? (result_mant_temp >> 1'b1) : (result_mant_temp << lod_shift_amt);
assign result_mant = shifted_result_mant_temp[3:1];

assign sum_result_in_FP = lod_zero ? {1'b0, 6'b101_001, 3'b000} : {result_sign, result_exp, result_mant};

/* 8. Conversione del risultato in HiFloat8*/

wire [7:0] sum_result_in_HF8;

FP_to_HiFloat8_converter FP_to_HF8(
    .fp_in(sum_result_in_FP),
    .hif_out(sum_result_in_HF8),            
    .zero_flag_out()
);

/*Se uno dei due HiFloat8 in Input all'adder   Zero, assegna l'altro Input. Altrimenti assegna il risultato della somma.

(a_is_zero = 0, b_is_zero = 0) -> sum_result
(a_is_zero = 0, b_is_zero = 1) -> hif8_a_in
(a_is_zero = 1, b_is_zero = 0) -> hif8_b_in
(a_is_zero = 1, b_is_zero = 1) -> hif8_b_in (che   sempre 0)

 */
assign hif8_res_out = (a_is_zero || b_is_zero)? (a_is_zero ? hif8_b_in : hif8_a_in): sum_result_in_HF8;

wire [9:0] hif8_res_out_to_FP;

HiFloat8_to_FP_converter HF8res_to_FP(
	.hif8_in(hif8_res_out),
	.fp_out(hif8_res_out_to_FP),
	.zero_flag_out());

endmodule