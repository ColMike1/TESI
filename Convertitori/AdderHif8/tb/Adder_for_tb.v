/*
Questo codice è un estensione del codice sorgente 'Adder_Hif8_final.v', ed è usato per il testbench

--- Addizionatore di numeri HiFloat8 ---

Cosa fa questo modulo: 

1) prende in ingresso due HiFloat8;
2) converte i due numeri HiFloat8 nei formati FP in complemento a 2;
3) effettua uno shift della mantissa del numero FP più piccolo, allineando l'esponente di tale numero con l'FP più grande;
4) calcola il segno del risultato finale confrontando le due mantisse: quella non shiftata e quella shiftata. Il segno
   del risultato finale è quello della mantissa shiftata più grande;
5) effettua la somma (o sottrazione) delle mantisse. 
6) il risultato viene passato ad un Leading One Detector per effettuare eventuali shift da overflow/underflow e aumentare/diminuire l'esponente;
7) ricostruisce il risultato in FP: (segno, Exp, mant) in 10 bit;
8) passa il risultato al convertitore FP_to_HiFloat8;
9) L'output è l'uscita di quest'ultimo convertitore;

*/


module adder_HiF8(
	input wire [7:0] hif8_a_in,
	input wire [7:0] hif8_b_in,
	
	/* Questi 3 segnali servono solo per il testbench. */
	output wire [9:0] fp_a_out,
	output wire [9:0] fp_b_out,
	output wire [9:0] fp_res_out,

	output wire [5:0] exp_diff_out,
	output wire [2:0] shift_amt_out,
	output wire [4:0] full_mant_a_shifted_out,
	output wire [4:0] full_mant_b_shifted_out,
	output wire [5:0] result_mant_temp_out,
	/*---------------------------*/

	output wire [7:0] hif8_res_out
);




wire [9:0] fp_from_hif8_a;
wire	  a_is_zero;
wire [9:0] fp_from_hif8_b;
wire 	  b_is_zero;

reg sign_a;
reg [5:0] exp_a;
reg [3:0] full_mant_a;

reg sign_b;
reg [5:0] exp_b;
reg [3:0] full_mant_b;



/* 2. Conversione dei numeri HiFloat8 in FP*/

/*Conversione: hif8_a_in -> FP*/
HiFloat8_to_FP_converter HF8a_to_FP(
	.hif8_in(hif8_a_in),
	.fp_out(fp_from_hif8_a),
	.zero_flag_out(a_is_zero)
);

/*------------*/
assign fp_a_out = fp_from_hif8_a;
/*------------*/


/*Conversione: hif8_b_in -> FP*/
HiFloat8_to_FP_converter HF8b_to_FP(
	.hif8_in(hif8_b_in),
	.fp_out(fp_from_hif8_b),
	.zero_flag_out(b_is_zero)
);


/*-------------*/
assign fp_b_out = fp_from_hif8_b;
/*-------------*/




/* Estrazione segno, esponente, mantissa dai due FP in uscita dai convertitori*/
/* 2.1 Primo blocco procedurale: estrae sign_a, exp_a, mant_a*/
always @(fp_from_hif8_a) begin
	sign_a = fp_from_hif8_a[9];
	exp_a  = fp_from_hif8_a[8:3];
	full_mant_a = {1'b1, fp_from_hif8_a[2:0]};
end

/* 2.2 Secondo blocco procedurale: estrae sign_b, exp_b, mant_b*/
always @(fp_from_hif8_b) begin
	sign_b = fp_from_hif8_b[9];
	exp_b  = fp_from_hif8_b[8:3];
	full_mant_b = {1'b1, fp_from_hif8_b[2:0]};
end



/* 3. Calcolo dello shift del numero FP più piccolo*/


wire exp_a_ge_exp_b = $signed(exp_a) >= $signed(exp_b);
wire [5:0] result_exp_tmp = exp_a_ge_exp_b ? exp_a : exp_b;     /*Per il momento, il risultato ha come esponente quello più grande tra i due FP. Dopo ci possono essere degli shift
						   	    e magari cambia di nuovo. Per il momento è tmp=temporaneo*/

reg [2:0] shift_amount;
reg [5:0] exp_diff;
/* 3.1 Terzo blocco procedurale: Calcolo lo shift
Shift di massimo 5 posizioni, non oltre. Questo perchè uno shift >= 5 renderebbe inutile l'intervento del numero più piccolo nella somma.

   Ad esempio: 	A = 2^(0)*1.011, 	B = 2^(5)*1.111.
  		exp_diff = 5, ciò implica che per allineare gli esponenti, dobbiamo shiftare la mantissa del numero più piccolo a destra di 5 posizioni 

		Quindi dovremmo sommare :
		A+B = 2^(5)*0.000_01011 + 2^(5)* 1.111_00000.

		Quindi : 0.000_01011+
                         1.111_00000=
 			 -----------
                         1.111_01011

		Sommando add_0000_1 per il round away, notiamo che non c'è alcun contibuto del numero più piccolo sulla mantissa finale.
		Se exp_diff fosse stato =4, allora la mantissa del numero più piccolo avrebbe influito sul risultato finale.
*/
always @(exp_a, exp_b, exp_a_ge_exp_b) begin
	
	exp_diff    = exp_a_ge_exp_b ? ($signed(exp_a) - $signed(exp_b)) : ($signed(exp_b) - $signed(exp_a));
	shift_amount   = (exp_diff > 3'b101) ? 3'b101 : exp_diff[2:0]; /*Massimo 5*/ 

end

/*------------*/
assign exp_diff_out = exp_diff;
assign shift_amt_out = shift_amount;
/*------------*/



reg [4:0] full_mant_a_shifted;
reg [4:0] full_mant_b_shifted;
/* 3.2 Quarto blocco procedurale: Effettuo lo shift */
always @(shift_amount, exp_a_ge_exp_b, full_mant_a, full_mant_b) begin

	full_mant_a_shifted = exp_a_ge_exp_b ? {full_mant_a, 1'b0} : ({full_mant_a, 1'b0} >> shift_amount);
	full_mant_b_shifted = exp_a_ge_exp_b ? ({full_mant_b, 1'b0} >> shift_amount) : {full_mant_b, 1'b0};

end

/*----------*/
assign full_mant_a_shifted_out = full_mant_a_shifted;
assign full_mant_b_shifted_out = full_mant_b_shifted;
/*----------*/


/* 4. Calcola il segno del risultato finale*/

reg result_sign;
wire mant_a_ge_mant_b = (full_mant_a_shifted >= full_mant_b_shifted);
/* 4.1: Quinto blocco procedurale*/
/*Il segno del risultato res_sign è:
	- se i segni dei due numeri sono uguali, il segno finale sarà uguale a tale segno (Pos + Pos = Pos, Neg + Neg = Neg)
	- se i segni dei due numeri sono diversi, il segno finale è quello del numero con mantissa shiftata più grande
*/
always @(sign_a, sign_b, mant_a_ge_mant_b) begin

	result_sign = (sign_a == sign_b) ? sign_a : (mant_a_ge_mant_b ? sign_a : sign_b);

end


/* 5. Effettua la somma o la sottrazione delle mantisse */

reg [5:0] result_mant_temp;
localparam add_000_001 = 6'b000_001;
/* 5.1 Sesto blocco procedurale*/
always @(full_mant_a_shifted, full_mant_b_shifted, sign_a, sign_b, mant_a_ge_mant_b) begin


	case ({sign_a, sign_b}) 
		2'b00, 2'b11: begin
			result_mant_temp = {1'b0, full_mant_a_shifted} + {1'b0, full_mant_b_shifted} + add_000_001;
		end
		2'b01, 2'b10: begin
			result_mant_temp = mant_a_ge_mant_b ? {1'b0, full_mant_a_shifted} - {1'b0, full_mant_b_shifted} + add_000_001 : 
                                           		      {1'b0, full_mant_b_shifted} - {1'b0, full_mant_a_shifted} + add_000_001; 
		end

		default:
			result_mant_temp = 6'b000_000;
	endcase

end


/*---------*/
assign result_mant_temp_out = result_mant_temp;
/*---------*/


/* 6. Leading One Detector*/


reg direction; /* 0 = sinistra, 1 = destra*/
reg lod_zero;
reg [1:0] lod_shift_amt;

/* 6.1 settimo blocco procedurale */
always @(result_mant_temp[5:1]) begin
	
	lod_zero = 1'b0;
	lod_shift_amt = 2'b00;
	direction = 1'b0;

	casex(result_mant_temp[5:1])

		5'b1_xxxx: begin
			lod_shift_amt = 2'b01; /*Shift di uno...*/
			direction = 1'b1;      /*... a destra*/
		end
		5'b01_xxx: begin
			lod_shift_amt = 2'b00; /*Shift di 0...*/
			direction = 1'b0;      /*indifferente, può essere anche 1'b1*/
		end
		5'b001_xx: begin
			lod_shift_amt = 2'b01; /*Shift di uno...*/
			direction = 1'b0;      /*... a sinistra*/
		end
		5'b0001_x: begin
			lod_shift_amt = 2'b10; /*Spostati di due...*/
			direction = 1'b0;      /*... a sinistra*/
		end
		5'b00001: begin
			lod_shift_amt = 2'b11; /*Spostati di tre...*/
			direction = 1'b0;      /*... a sinistra*/
		end
		default:
			lod_zero = 1'b1;
	endcase

end



/* 7. Ricostruzione del risultato in FP, considerando gli eventuali shift tenuti in considerazione dal LOD*/



reg [5:0] result_exp;
reg [2:0] result_mant;
wire [9:0] sum_result_in_FP; 
reg [5:0] shifted_mant_temp;
/* 7.1 */
always @(direction, result_exp_tmp, lod_shift_amt, result_mant_temp) begin

        /* 
	Aggiorna l'esponente in base al verso dello shift del LOD
           direction == 1'b0 (a sinistra) -> decrementa l'esponente
           direction == 1'b1 (a destra)   -> incrementa l'esponente
	*/
        result_exp = direction ? ($signed(result_exp_tmp) + lod_shift_amt) : ($signed(result_exp_tmp) - $signed(lod_shift_amt));
      
	/* Shifta di lod_shift_amt la mantissa*/  
        shifted_mant_temp = direction ? (result_mant_temp >> lod_shift_amt) : (result_mant_temp << lod_shift_amt) ; 
	result_mant = shifted_mant_temp[3:1];
end

assign sum_result_in_FP = lod_zero ? {result_sign, 6'b100_000, 3'b000} : {result_sign, result_exp, result_mant};

assign fp_res_out = sum_result_in_FP;


/* 8. Conversione del risultato in HiFloat8*/

wire [7:0] sum_result_in_HF8;

FP_to_HiFloat8_converter FP_to_HF8(
    .fp_in(sum_result_in_FP),
    .hif_out(sum_result_in_HF8),            
    .zero_flag_out()
);



/*Se uno dei due HiFloat8 in Input all'adder è Zero, assegna l'altro Input. Altrimenti assegna il risultato della somma.

(a_is_zero = 0, b_is_zero = 0) -> sum_result
(a_is_zero = 0, b_is_zero = 1) -> hif8_a_in
(a_is_zero = 1, b_is_zero = 0) -> hif8_b_in
(a_is_zero = 1, b_is_zero = 1) -> hif8_b_in (che è sempre 0)

 */
assign hif8_res_out = (a_is_zero || b_is_zero)? (a_is_zero ? hif8_b_in : hif8_a_in): sum_result_in_HF8;






endmodule










