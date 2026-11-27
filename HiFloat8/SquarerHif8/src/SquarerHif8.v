module squarer_Hif8(
    input wire [7:0] hif8_in,
    input wire [7:0] hif8_res
)

wire [7:0] hif8_in;                 
wire [9:0] fp_in;          
wire hif8_in_iszero;


wire [9:0] fp_res;

HiFloat8_to_FP_converter hif8_to_fp_converter(
    .hif8_in(hif8_in),                  // In: HiFloat8 (8 bit)                               
    .fp_out(fp_in),                     // Out: FP [S (1 bit), Exp_2scomp (6 bit), M (3 bit)] 
    .zero_flag_out(hif8_in_iszero)     // Flag zero                                          
);
/*==============================*/

wire [5:0] exp_in = fp_in[8:3];
wire [2:0] mant_in = fp_in[2:0];


// Extension of the mantissa: 1.xxx. (1bit integer part (IP), 3 bits fractional part (FP))
wire [3:0] full_mant_in = {1'b1, mant_in};

// squaring fp_in. Number of bits needed for storing the result is 2*IP + 2*FP =2*1 + 2*3 = 8bits
wire [7:0] full_mant_in_squared = full_mant_in * full_mant_in;

// check if there was an overflow over the integer part
wire mant_overflow = full_mant_in_squared[7];

// take the bits [5:3] of the results if there was not an overflow, else take the bits [6:4]
wire [2:0] mant_res = mant_overflow ? full_mant_in_squared[6:4] : full_mant_in_squared[5:3];

// exp_in is in the range [-22, +15]. If:
// exp_in = -22 -> exp_in*2 = -44. Number of bits needed for rapresent -44 is 7bits in 2'scomplement.
// exp_in = 15  -> exp_in*2 = 30 . Number of bits needed for rapresent 30 is 5bits.
// We take the max(7bits, 5bits) = 7bits. NB this is the 'WORounding the mantissa' case.

wire [6:0] exp_res_tmp = ({1'b0, exp_in} << 1);
assign exp_res_tmp[0] = mant_overflow;

// exp_in[5] ? .... the exponent in input is negative? it means that can be in range [-32,-1] 
//              y:  exp_res_tmp[5] ? .... if exp_in[5] == 1,  exp_res_tmp[6:5] can be or 10 or 11. 
//                      y:  exp_res_tmp[6:5] = 11. It means that exp_res_tmp >= -32. So the result is exp_res_tmp[5:0]
//                      n:  exp_res_tmp[6:5] = 10. It means that exp_res_tmp < -32.   So the result is un underflow of the exponent and the result of the squared number should be 0.
//              n:  the result should be exp_res_tmp[5:0] because the maximum positive exponent in input is 15. 15*2 = 30 that is expressed in 7bits as 0_011_110. So i take 30 in 6bits = 011_110                
wire [5:0] exp_res = exp_in[5] ? (exp_res_tmp[5]? exp_res_tmp[5:0]: {6'b101001}) : exp_res_tmp[5:0];


assign fp_res = {1'b0, exp_res, mant_res};

/*==============================*/

FP_to_HiFloat8_converter fp_to_hif8_converter(
    .fp_in(fp_res),
    .hif_out(hif8_res),
    .zero_flag_out()
);






endmodule