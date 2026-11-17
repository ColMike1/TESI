/*
Questo codice � un estensione del codice sorgente 'Adder_Hif8_final.v', ed � usato per il testbench

--- Addizionatore di numeri HiFloat8 ---

Cosa fa questo modulo: 

1) prende in ingresso due HiFloat8;
2) converte i due numeri HiFloat8 nei formati FP in complemento a 2;
3) effettua uno shift della mantissa del numero FP pi� piccolo, allineando l'esponente di tale numero con l'FP pi� grande;
4) calcola il segno del risultato finale confrontando le due mantisse: quella non shiftata e quella shiftata. Il segno
   del risultato finale � quello della mantissa shiftata pi� grande;
5) effettua la somma (o sottrazione) delle mantisse. 
6) il risultato viene passato ad un Leading One Detector per effettuare eventuali shift da overflow/underflow e aumentare/diminuire l'esponente;
7) ricostruisce il risultato in FP: (segno, Exp, mant) in 10 bit;
8) passa il risultato al convertitore FP_to_HiFloat8;
9) L'output � l'uscita di quest'ultimo convertitore;

*/


module adder_HiF8(
	input wire [7:0] hif8_a_in,
	input wire [7:0] hif8_b_in,
	
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




/*Conversione: hif8_b_in -> FP*/
HiFloat8_to_FP_converter HF8b_to_FP(
	.hif8_in(hif8_b_in),
	.fp_out(fp_from_hif8_b),
	.zero_flag_out(b_is_zero)
);






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



/* 3. Calcolo dello shift del numero FP pi� piccolo*/


wire exp_a_ge_exp_b = $signed(exp_a) >= $signed(exp_b);
wire [5:0] result_exp_tmp = exp_a_ge_exp_b ? exp_a : exp_b;     /*Per il momento, il risultato ha come esponente quello pi� grande tra i due FP. Dopo ci possono essere degli shift
						   	    e magari cambia di nuovo. Per il momento � tmp=temporaneo*/

reg [2:0] shift_amount;
reg [5:0] exp_diff;
/* 3.1 Terzo blocco procedurale: Calcolo lo shift
Shift di massimo 7 posizioni
*/
always @(exp_a, exp_b, exp_a_ge_exp_b) begin
	
	exp_diff    = exp_a_ge_exp_b ? ($signed(exp_a) - $signed(exp_b)) : ($signed(exp_b) - $signed(exp_a));
	shift_amount   = (exp_diff > 3'b111) ? 3'b111 : exp_diff[2:0]; /*Massimo 7*/ 

end




reg [6:0] full_mant_a_shifted;
reg [6:0] full_mant_b_shifted;
/* 3.2 Quarto blocco procedurale: Effettuo lo shift */
always @(shift_amount, exp_a_ge_exp_b, full_mant_a, full_mant_b) begin

	full_mant_a_shifted = exp_a_ge_exp_b ? {full_mant_a, 3'b000} : ({full_mant_a, 3'b000} >> shift_amount);
	full_mant_b_shifted = exp_a_ge_exp_b ? ({full_mant_b, 3'b000} >> shift_amount) : {full_mant_b, 3'b000};

end


/* 4. Calcola il segno del risultato finale*/

reg result_sign;
wire mant_a_ge_mant_b = (full_mant_a_shifted >= full_mant_b_shifted);
/* 4.1: Quinto blocco procedurale*/
/*Il segno del risultato res_sign �:
	- se i segni dei due numeri sono uguali, il segno finale sar� uguale a tale segno (Pos + Pos = Pos, Neg + Neg = Neg)
	- se i segni dei due numeri sono diversi, il segno finale � quello del numero con mantissa shiftata pi� grande
*/
always @(sign_a, sign_b, mant_a_ge_mant_b) begin

	result_sign = (sign_a == sign_b) ? sign_a : (mant_a_ge_mant_b ? sign_a : sign_b);

end


/* 5. Effettua la somma o la sottrazione delle mantisse */

reg [7:0] result_mant_temp;
localparam add_0000_0100 = 8'b0000_0100;
/* 5.1 Sesto blocco procedurale*/
always @(full_mant_a_shifted, full_mant_b_shifted, sign_a, sign_b, mant_a_ge_mant_b) begin


	case ({sign_a, sign_b}) 
		2'b00, 2'b11: begin
			result_mant_temp = {1'b0, full_mant_a_shifted} + {1'b0, full_mant_b_shifted};
		end
		2'b01, 2'b10: begin
			result_mant_temp = mant_a_ge_mant_b ? {1'b0, full_mant_a_shifted} - {1'b0, full_mant_b_shifted} : 
                                           		      {1'b0, full_mant_b_shifted} - {1'b0, full_mant_a_shifted}; 
		end

		default:
			result_mant_temp = 8'b0000_0000;
	endcase

end



/* 6. Leading One Detector*/


reg direction; /* 0 = sinistra, 1 = destra*/
reg lod_zero;
reg [2:0] lod_shift_amt;

/* 6.1 settimo blocco procedurale */
always @(result_mant_temp) begin
	
	lod_zero = 1'b0;
	lod_shift_amt = 3'b000;
	direction = 1'b0;

	casex(result_mant_temp)

		8'b1xxx_xxxx: begin
			lod_shift_amt = 3'b001; /*Shift di uno...*/
			direction = 1'b1;      /*... a destra*/
		end
		8'b01xx_xxxx: begin
			lod_shift_amt = 3'b000; /*Shift di 0...*/
			direction = 1'b0;      /*indifferente, pu� essere anche 1'b1*/
		end
		8'b001x_xxxx: begin
			lod_shift_amt = 3'b001; /*Shift di uno...*/
			direction = 1'b0;      /*... a sinistra*/
		end
		8'b0001_xxxx: begin
			lod_shift_amt = 3'b010; /*Shift di due...*/
			direction = 1'b0;      /*... a sinistra*/
		end
		8'b0000_1xxx: begin
			lod_shift_amt = 3'b011; /*Shift di tre...*/
			direction = 1'b0;      /*... a sinistra*/
		end
		8'b0000_01xx: begin
			lod_shift_amt = 3'b100; /*Shift di quattro...*/
			direction = 1'b0;      /*... a sinistra*/
		end
		8'b0000_001x: begin
			lod_shift_amt = 3'b101; /*Shift di cinque...*/
			direction = 1'b0;      /*... a sinistra*/
		end
		8'b0000_0001: begin
			lod_shift_amt = 3'b110; /*Shift di sei...*/
			direction = 1'b0;      /*... a sinistra*/
		end
		default:
			lod_zero = 1'b1;
	endcase

end



/* 7. Ricostruzione del risultato in FP, considerando gli eventuali shift tenuti in considerazione dal LOD*/



reg [5:0] result_exp_aprx;
reg [5:0] result_exp;
reg [2:0] result_mant;
wire [9:0] sum_result_in_FP; 
reg [7:0] shifted_result_mant_temp;

/* 7.1 */
always @(direction, result_exp_tmp, lod_shift_amt, result_mant_temp) begin

        /* 
	Aggiorna l'esponente in base al verso dello shift del LOD
           direction == 1'b0 (a sinistra) -> decrementa l'esponente
           direction == 1'b1 (a destra)   -> incrementa l'esponente
	*/
        result_exp_aprx = direction ? ($signed(result_exp_tmp) + lod_shift_amt) : ($signed(result_exp_tmp) - $signed(lod_shift_amt));
      
	/* Shifta di lod_shift_amt la mantissa. Al termine dello shift il risultato è normalizzato, quindi espresso nella forma
		+/- 2^(exp)(1.xxx), ma bisogna ancora aggiungere add_0000_0100 per il round away from zero. Questo può causare un riporto, e se avviene lo gestisco
		incrementando l'esponente di uno e prendendo i bit shifted_result_mant_temp[4:2] piuttosto che [3:1]*/  
        shifted_result_mant_temp = direction ? (result_mant_temp >> lod_shift_amt) + add_0000_0100 : (result_mant_temp << lod_shift_amt) + add_0000_0100;
		
		result_mant = shifted_result_mant_temp[7] == 1'b1 ? shifted_result_mant_temp[6:4] : shifted_result_mant_temp[5:3];
		result_exp  = shifted_result_mant_temp[7] == 1'b1 ? result_exp_aprx + 6'b000_0001 : result_exp_aprx;


end

assign sum_result_in_FP = lod_zero ? {1'b0, 6'b100_000, 3'b000} : {result_sign, result_exp, result_mant};

assign fp_res_out = sum_result_in_FP;


/* 8. Conversione del risultato in HiFloat8*/

wire [7:0] sum_result_in_HF8;

FP_to_HiFloat8_converter FP_to_HF8(
    .fp_in(sum_result_in_FP),
    .hif_out(sum_result_in_HF8),            
    .zero_flag_out()
);



/*Se uno dei due HiFloat8 in Input all'adder � Zero, assegna l'altro Input. Altrimenti assegna il risultato della somma.

(a_is_zero = 0, b_is_zero = 0) -> sum_result
(a_is_zero = 0, b_is_zero = 1) -> hif8_a_in
(a_is_zero = 1, b_is_zero = 0) -> hif8_b_in
(a_is_zero = 1, b_is_zero = 1) -> hif8_b_in (che � sempre 0)

 */
assign hif8_res_out = (a_is_zero || b_is_zero)? (a_is_zero ? hif8_b_in : hif8_a_in): sum_result_in_HF8;




endmodule










