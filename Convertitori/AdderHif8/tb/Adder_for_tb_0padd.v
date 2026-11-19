/*
Questo codice è un'estensione del codice sorgente 'Adder_Hif8_final.v', ed è usato per il testbench
(variante senza padding: mantissa a 4 bit [3:0], result_mant_temp a 5 bit [4:0])

--- Addizionatore di numeri HiFloat8 ---
*/

module adder_HiF8(
	input wire [7:0] hif8_a_in,
	input wire [7:0] hif8_b_in,
	
	/* Questi segnali servono solo per il testbench. */
	output wire [9:0] fp_a_out,
	output wire [9:0] fp_b_out,
	output wire [9:0] fp_res_out,

	output wire [5:0] exp_diff_out,
	output wire [2:0] shift_amt_out,
	output wire [3:0] full_mant_a_shifted_out,
	output wire [3:0] full_mant_b_shifted_out,
	output wire [4:0] result_mant_temp_out,
	/*---------------------------*/

	output wire [7:0] hif8_res_out
);

wire [9:0] fp_from_hif8_a;
wire       a_is_zero;
wire [9:0] fp_from_hif8_b;
wire       b_is_zero;

reg sign_a;
reg [5:0] exp_a;
reg [3:0] full_mant_a;

reg sign_b;
reg [5:0] exp_b;
reg [3:0] full_mant_b;

/* 2. Conversione dei numeri HiFloat8 in FP */

HiFloat8_to_FP_converter HF8a_to_FP(
	.hif8_in(hif8_a_in),
	.fp_out(fp_from_hif8_a),
	.zero_flag_out(a_is_zero)
);
assign fp_a_out = fp_from_hif8_a;

HiFloat8_to_FP_converter HF8b_to_FP(
	.hif8_in(hif8_b_in),
	.fp_out(fp_from_hif8_b),
	.zero_flag_out(b_is_zero)
);
assign fp_b_out = fp_from_hif8_b;

/* 2.1 / 2.2 Estrazione campi */
always @(fp_from_hif8_a) begin
	sign_a      = fp_from_hif8_a[9];
	exp_a       = fp_from_hif8_a[8:3];
	full_mant_a = {1'b1, fp_from_hif8_a[2:0]};
end

always @(fp_from_hif8_b) begin
	sign_b      = fp_from_hif8_b[9];
	exp_b       = fp_from_hif8_b[8:3];
	full_mant_b = {1'b1, fp_from_hif8_b[2:0]};
end

/* 3. Calcolo dello shift */
wire       exp_a_ge_exp_b = $signed(exp_a) >= $signed(exp_b);
wire [5:0] result_exp_tmp = exp_a_ge_exp_b ? exp_a : exp_b;

reg [2:0] shift_amount;
reg [5:0] exp_diff;

always @(exp_a, exp_b, exp_a_ge_exp_b) begin
	exp_diff     = exp_a_ge_exp_b ? ($signed(exp_a) - $signed(exp_b)) : ($signed(exp_b) - $signed(exp_a));
	shift_amount = (exp_diff > 6'd7) ? 3'd7 : exp_diff[2:0];
end

assign exp_diff_out  = exp_diff;
assign shift_amt_out = shift_amount;

reg [3:0] full_mant_a_shifted;
reg [3:0] full_mant_b_shifted;

/* 3.2 Shift senza padding (vettore a 4 bit) */
always @(shift_amount, exp_a_ge_exp_b, full_mant_a, full_mant_b) begin
	full_mant_a_shifted = exp_a_ge_exp_b ? full_mant_a : (full_mant_a >> shift_amount);
	full_mant_b_shifted = exp_a_ge_exp_b ? (full_mant_b >> shift_amount) : full_mant_b;
end

assign full_mant_a_shifted_out = full_mant_a_shifted;
assign full_mant_b_shifted_out = full_mant_b_shifted;

/* 4. Segno del risultato */
reg  result_sign;
wire mant_a_ge_mant_b = (full_mant_a_shifted >= full_mant_b_shifted);

always @(sign_a, sign_b, mant_a_ge_mant_b) begin
	result_sign = (sign_a == sign_b) ? sign_a : (mant_a_ge_mant_b ? sign_a : sign_b);
end

/* 5. Somma o sottrazione su 5 bit [4:0] */
reg [4:0] result_mant_temp;

always @(full_mant_a_shifted, full_mant_b_shifted, sign_a, sign_b, mant_a_ge_mant_b) begin
	case ({sign_a, sign_b})
		2'b00, 2'b11: begin
			result_mant_temp = {1'b0, full_mant_a_shifted} + {1'b0, full_mant_b_shifted};
		end
		2'b01, 2'b10: begin
			result_mant_temp = mant_a_ge_mant_b ? ({1'b0, full_mant_a_shifted} - {1'b0, full_mant_b_shifted}) :
			                                      ({1'b0, full_mant_b_shifted} - {1'b0, full_mant_a_shifted});
		end
		default: begin
			result_mant_temp = 5'd0;
		end
	endcase
end

assign result_mant_temp_out = result_mant_temp;

/* 6. Leading One Detector su 5 bit [4:0] */
reg       direction;     /* 0 = sinistra, 1 = destra */
reg       lod_zero;
reg [2:0] lod_shift_amt;

always @(result_mant_temp) begin
	lod_zero      = 1'b0;
	lod_shift_amt = 3'd0;
	direction     = 1'b0;

	casex (result_mant_temp)
		5'b1_xxxx: begin
			lod_shift_amt = 3'd1; /* Riporto sul bit 4 -> shift di 1 a destra */
			direction     = 1'b1;
		end
		5'b0_1xxx: begin
			lod_shift_amt = 3'd0; /* Già allineato al bit 3 */
			direction     = 1'b0;
		end
		5'b0_01xx: begin
			lod_shift_amt = 3'd1; /* Shift di 1 a sinistra */
			direction     = 1'b0;
		end
		5'b0_001x: begin
			lod_shift_amt = 3'd2; /* Shift di 2 a sinistra */
			direction     = 1'b0;
		end
		5'b0_0001: begin
			lod_shift_amt = 3'd3; /* Shift di 3 a sinistra */
			direction     = 1'b0;
		end
		default: begin
			lod_zero = 1'b1;
		end
	endcase
end

/* 7. Ricostruzione del risultato in FP (troncamento diretto senza bit frazionari extra) */
reg [5:0]  result_exp_aprx;
reg [5:0]  result_exp;
reg [2:0]  result_mant;
wire [9:0] sum_result_in_FP;
reg [4:0]  shifted_result_mant_temp;

always @(direction, result_exp_tmp, lod_shift_amt, result_mant_temp) begin
	result_exp_aprx = direction ? ($signed(result_exp_tmp) + $signed({3'b000, lod_shift_amt}))
	                            : ($signed(result_exp_tmp) - $signed({3'b000, lod_shift_amt}));

	shifted_result_mant_temp = direction ? (result_mant_temp >> lod_shift_amt)
	                                      : (result_mant_temp << lod_shift_amt);

	if (shifted_result_mant_temp[4] == 1'b1) begin
		result_mant = shifted_result_mant_temp[3:1];
		result_exp  = result_exp_aprx + 6'd1;
	end else begin
		result_mant = shifted_result_mant_temp[2:0];
		result_exp  = result_exp_aprx;
	end
end

assign sum_result_in_FP = lod_zero ? {1'b0, 6'b100_000, 3'b000} : {result_sign, result_exp, result_mant};
assign fp_res_out       = sum_result_in_FP;

/* 8. Conversione in HiFloat8 */
wire [7:0] sum_result_in_HF8;

FP_to_HiFloat8_converter FP_to_HF8(
	.fp_in(sum_result_in_FP),
	.hif_out(sum_result_in_HF8),
	.zero_flag_out()
);

assign hif8_res_out = (a_is_zero || b_is_zero) ? (a_is_zero ? hif8_b_in : hif8_a_in) : sum_result_in_HF8;

endmodule