module fp_square_and_scale #
(
parameter integer truc_man = 4,
parameter integer DATA_WIDTH = 32-truc_man
)
(
input wire  [DATA_WIDTH - 1 : 0] x,  // in - mean
output wire [DATA_WIDTH - 1 : 0] sqr, // (in - mean)^2
input wire  [2 : 0] scale
);

localparam integer hidden_size = 768;
localparam integer   Exp_Width = 8;
localparam integer   Man_Width = 23-truc_man;



wire [Man_Width - 1 : 0] x_man; // mantissa of input
wire [Exp_Width - 1 : 0] x_exp; // exponent of input
//wire x_sign; // sign of input

wire [Exp_Width   : 0] x_exp_sqr_temp; // exponent of input squared
wire [(2*Man_Width)+1:0] sqr_man_temp; // mantissa of square

wire [Man_Width - 1 : 0] sqr_man; // mantissa of square
wire [Exp_Width - 1 : 0] sqr_exp; // exponent of square
wire sqr_sign; // sign of square

assign x_man =  x[DATA_WIDTH - 2 - (Exp_Width - 1) - 1 : 0];
assign x_exp =  x[DATA_WIDTH - 2 : DATA_WIDTH - 2 - (Exp_Width - 1)];
//assign x_sign =  x[DataWidth - 1];

assign x_exp_sqr_temp =  (x_exp << 1) - 8'b0111_1111; //((x_exp - 127) * 2 ) + 127 (+ 1) = x_exp * 2 -127 (+ 1)
assign sqr_man_temp =  {1'b1 , x_man} * {1'b1 , x_man};
// minimum multiplication is 1.0000000 * 1.0000000 = 1.0000000 d = 01.0000000000000000000000_000000000000000000000000 b.
// maximum multiplication is 1.9999999 * 1.9999999 = 3.99999960000001 d = 11.1111111111111111111110_010100101000000011010111 b.
// leading one bit should be first or second.

assign sqr_man =  sqr_man_temp[(2*Man_Width)+1] ? ( sqr_man_temp[(2*Man_Width) : Man_Width+1] ) : ( sqr_man_temp[(2*Man_Width)-1 : Man_Width] );
assign sqr_exp =  sqr_man_temp[(2*Man_Width)+1] ? ( x_exp_sqr_temp + 8'd1 - scale ) : ( x_exp_sqr_temp - scale );
assign sqr_sign =  1'b0;

assign sqr = {sqr_sign , sqr_exp, sqr_man};

endmodule