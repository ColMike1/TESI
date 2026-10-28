`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 09.10.2026 16:24:21
// Design Name:
// Module Name: HiFloat8_to_FP_converter
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


/*Obiettiivo: estrarre (Segno, Exp2'sComp, Mantissa) da HiFloat8
                      (1 bit,   6 bit   ,   3 bit )
Exp2'sComp: 6 bit necessari per rappresentare [-22, +15]
                     

Struttura generica HiFloat8:
_________Numeri Normali________  X = (-1)^(S) x 2^(Exp) x 1.M

D=0     (S, 0001, M[2:0])                   -> Exp= 0

D=1     (S, 001, Exp[3], M[2:0])            -> Exp= +-1

D=2     (S, 01, Exp[4:3], M[2:0])           -> Exp= +-[2,3]

D=3     (S, 10, Exp[4:2], M[1:0])           -> Exp= +-[4,7]

D=4     (S, 11, Exp[4:1], M[0])             -> Exp= +-[8,15]

_________Numeri Denormali________ X = (-1)^(S) x 2^(Exp - 23) x 1.0

D=DML   (S, 0000, M[2:0])                 -> Exp = M = [-22, -16]

*/

module HiFloat8_to_FP_converter (

    input  wire [7:0] hif8_in,    // In: HiFloat8 (8 bit)
    output wire        sign_out,   // Out: S (1 bit)
    output wire [5:0]  exp_out_2s, // Out: Exp_2'scomp (6 bit)
    output reg [2:0]  mant_out,    // Out: M (3 bit)

    output wire zero_flag_out

);


// Il flag = 1 se tutti gli 8 bit dell'HiFloat8 a zeor
assign zero_flag_out = (hif8_in == 8'b0_0000_000 || hif8_in == 8'b1_0000_000 );

assign sign_out = hif8_in[7]; // Segno direttamente fuori dai blocchi procedurali

reg do_complement;
reg[5:0] abs_exp;




// Blocco procedurale per estrarre il valore assoluto dell'esponente in 2^(X), quindi per estrarre |X|
always @(hif8_in[6:0]) begin
    casex(hif8_in[6:3])
       
        4'b0000:   // Caso Denormale: invece di M-23, faccio 23-M. Poi nel blocco procedurale successivo faccio il complemento a 2
            abs_exp = 6'b01_0111 - {3'b0, hif8_in[2:0]};
        4'b0001:   // Exp = 0
            abs_exp = 6'b0;
        4'b001x:   // Exp = 1
            abs_exp = {5'b0, 1'b1};
        4'b01xx:   // Exp = {2,3}
            abs_exp = {4'b0, 1'b1, hif8_in[3]};
        4'b10xx:   // Exp = [4,7]
            abs_exp = {3'b0, 1'b1, hif8_in[3:2]};
        4'b11xx:  // Exp = [8,15]
            abs_exp = {2'b0, 1'b1, hif8_in[3:1]};
        default:
            abs_exp = 6'b0;
    endcase
end


// Blocco procedurale per controllo del complemento a 2. Qui nel caso Denormale (0000) do_complement vale 1
// perchè nel blocco procedurale precedente, viene estratto il valore assoluto dell'esponente X in 2^(X).
// Nel caso 0000, X = 23-M e non M-23. Dato che si vuole calcolare M-23, si mette
// do_complement = 1
always @(hif8_in[6:3]) begin
    casex(hif8_in[6:3])
        4'b0000: begin
            do_complement = 1'b1;
        end
        4'b0001: begin
            do_complement = 1'b0;
        end
        4'b001?: begin
            do_complement = hif8_in[3];
        end
        4'b01??: begin
            do_complement = hif8_in[4];
        end
        4'b10??: begin
            do_complement = hif8_in[4];
        end  
        4'b11??: begin
            do_complement = hif8_in[4];
        end
        default: begin
        do_complement = 1'b0;
        end
     endcase
end    

// Blocco procedurale che calcola esponente finale
assign exp_out_2s = do_complement==1'b1  ? ~abs_exp + {5'b0, 1'b1} : abs_exp;
   

//Blocco procedurale per calcolo Mantissa
always @(hif8_in[6:0]) begin
    casex(hif8_in[6:3])
        4'b0000: begin
            mant_out = 3'b000;
            end
        4'b0001: begin
            mant_out = hif8_in[2:0];
            end
        4'b001?: begin
            mant_out = hif8_in[2:0];
            end
        4'b01??: begin
            mant_out = hif8_in[2:0];
            end
        4'b10??:begin
            mant_out = {hif8_in[1:0], 1'b0};
            end
        4'b11??:begin
            mant_out = {hif8_in[0], 2'b0};
            end
        default: begin
            mant_out = 3'b0;
            end
        endcase
    end

endmodule