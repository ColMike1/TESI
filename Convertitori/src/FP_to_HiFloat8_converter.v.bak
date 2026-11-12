`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.10.2026 17:49:58
// Design Name: 
// Module Name: FP_to_HiFloat8_converter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
/*
Obiettivo: estrarre [Segno, Dot, Exp_mod&sign, Mantissa] da FP

Input: [sign, exp_2scomp, mantissa]
        1 bit    6 bit      3 bit

Output: [sign,      Dot,       sign_exp,       mod_exp,      Mantissa]
        1 bit     [2,4]bit      [0,1]bit       [0,4]bit         [1,3]bit
    
*/

module FP_to_HiFloat8_converter(

    input  wire [9:0] fp_in,             // In: FP (10 bit)
    output reg  [7:0] hif_out,           // Out: HiFloat8 (8 bit)  
    output wire zero_flag_out
    );
    
    wire [5:0]  exp_in;                  // exp_in può essere sia positivo che negativo. Varia nel range [-32, 31].
    reg  [5:0]  exp_mod_in;              // exp_mod_in è il valore assoluto dell'esponente exp_in    
    wire [2:0]  mant_in;      
    wire        sign_out;
    
    reg         exp_sign_out;
    reg  [5:0]  exp_mod_out;
    reg  [3:0]  dot_out;
    reg  [2:0]  mant_out;


    localparam add_001 = 3'b00_1; 
    localparam add_010 = 3'b0_10;  
    localparam add_100 = 3'b100; 
    
   
    reg [5:0] exp_mod_adjusted;
    reg [3:0] dot_adjusted;
    reg [3:0] tmp;




    // Estrazione campi dall'Input
    assign sign_out = fp_in[9];          // segno
    assign exp_in   = fp_in[8:3];        // esponente
    assign mant_in  = fp_in[2:0];        // mantissa
    





    /*      Blocco 1
    Blocco procedurale per ricostruire campi:
    - dot (4 bit)
    - segno_esponente (1 bit)
    - modulo_esponente (5 bit)
    
    */
    always @(exp_in[5:0]) begin
        exp_sign_out = exp_in[5];                                       
        exp_mod_in   = (exp_sign_out) ? (~exp_in + 1'b1) : exp_in;      			// [0, 32] 
        exp_mod_out  = (exp_mod_in > 6'd23 && exp_mod_in <= 6'd32) ? 6'd23 : exp_mod_in;    	// [0, 23]
         
        // Determinazione campo dot
        if (exp_sign_out && (exp_mod_out >= 16 && exp_mod_out <= 23))  
            dot_out = 4'b0000;
        else begin
            casex (exp_mod_out)
                5'b00000:       dot_out = 4'b0001;
                5'b0000_1:      dot_out = {3'b001, 1'b0};
                5'b000_10, 
                5'b000_11:      dot_out = {2'b01, 2'b00};                 
                5'b00_1xx:      dot_out = {2'b10, 2'b00};                 
                5'b0_1xxx:      dot_out = {2'b11, 2'b00};                 
                default:        dot_out = {2'b11, 2'b00};
            endcase
        end
    end
    
  

    /*  Blocco 2
    Blocco procedurale che ricostruisce la mantissa usando la somma per il Round Away
    
    */
    always @(dot_out, mant_in, exp_sign_out ,exp_mod_out) begin
        // copia segnali del blocco 1
        exp_mod_adjusted = exp_mod_out;
        dot_adjusted     = dot_out;
        mant_out         = mant_in;
        tmp              = 4'b0;

        casex(dot_out)
            4'b0000: begin
		tmp = {1'b0, mant_in} + {1'b0, add_100};
		exp_mod_adjusted = (tmp[3] && exp_mod_out <= 6'd22) ? exp_mod_out - 6'b000001 : exp_mod_out;
		dot_adjusted = exp_mod_adjusted == 6'd15 ? {2'b11, 2'b00} : dot_out;
		mant_out = (dot_out == {2'b11, 2'b00}) ? {tmp[2], 2'b00} :  6'd23 - exp_mod_adjusted;
		
	    	end

            4'b0001, 
            4'b001x, 
            4'b01xx: mant_out = mant_in;     
            
            4'b10xx: begin
                tmp = {1'b0, mant_in} + {1'b0, add_001}; // Rounding away		
		mant_out = {tmp[2:1], 1'b0};                     
                exp_mod_adjusted = 		 tmp[3] ? ((exp_sign_out==1'b1) ? exp_mod_out - 6'b000001 : exp_mod_out + 6'b000001) : exp_mod_out;
		dot_adjusted = exp_mod_adjusted == 6'd8 ? {2'b11, 2'b00} : (exp_mod_adjusted == 6'd3 ? {2'b01, 2'b00} : dot_out);
			 
            	end
            
            4'b11xx: begin 
                tmp = {1'b0, mant_in} + {1'b0, add_010}; // Rounding away
		mant_out = {tmp[2], 2'b00};
		exp_mod_adjusted = tmp[3] ? (exp_sign_out==1'b1 ? exp_mod_out - 6'b000001 : exp_mod_out + 6'b000001) : exp_mod_out;
		if(exp_mod_adjusted > 6'd15) begin
			exp_mod_adjusted = 6'd15;
			mant_out 	 = 3'b111;	
		end
		
		dot_adjusted = exp_mod_adjusted == 6'd7 ? {2'b10, 2'b00} : dot_out;

            end

            default: mant_out = 3'b111;
        endcase
    end
    

	
    assign zero_flag_out = (dot_adjusted == 4'b0000 && mant_out == 3'b000);

    /*  Blocco 3
    Blocco procedurale che assembla hif_out
    */
    always @(sign_out, dot_adjusted, exp_sign_out, exp_mod_adjusted, mant_out) begin
        hif_out[7] = sign_out;
    
        casex(dot_adjusted)
            4'b0000: hif_out[6:0] = {4'b0000, mant_out};
	    4'b0001: hif_out[6:0] = {4'b0001, mant_out};
            4'b001x: hif_out[6:0] = {3'b001, exp_sign_out, mant_out};
            4'b01xx: hif_out[6:0] = {2'b01, exp_sign_out, exp_mod_adjusted[0], mant_out};
            4'b10xx: hif_out[6:0] = {2'b10, exp_sign_out, exp_mod_adjusted[1:0], mant_out[2:1]};
            4'b11xx: hif_out[6:0] = {2'b11, exp_sign_out, exp_mod_adjusted[2:0], mant_out[2]};  
            default: hif_out[6:0] = 7'b0;
        endcase
    end

endmodule
















