`timescale 1ns/1ps

module tb_adder_HiF8();

    // Ingressi del modulo sotto test (UUT)
    reg [7:0] hif8_a_in;
    reg [7:0] hif8_b_in;

    // Uscite del modulo sotto test
    wire [9:0] fp_a_out;  
    wire [9:0] fp_b_out;
    wire [9:0] fp_res_out;
    wire [5:0] exp_diff;
    wire [2:0] shift_amt;
    wire [5:0] res_mant_temp;
    wire [4:0] full_mant_a_shifted;
    wire [4:0] full_mant_b_shifted;
    wire [7:0] hif8_res_out;

    // Istanziazione dell'Addizionatore HiFloat8
    adder_HiF8 uut (
        .hif8_a_in(hif8_a_in),
        .hif8_b_in(hif8_b_in),      
        .hif8_res_out(hif8_res_out)
    );

    integer file_handle;
    integer i, j;

    initial begin
        // Apertura del file in modalità scrittura
        file_handle = $fopen("results/sum_results.txt", "w");
        if (file_handle == 0) begin
            $display("Errore: Impossibile aprire il file per la scrittura!");
            $finish;
        end

        $display("Inizio della simulazione per tutte le 65.536 combinazioni...");

        // Cicli  (256 * 256)
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                hif8_a_in = i[7:0];
                hif8_b_in = j[7:0];
                
                // Breve ritardo 
                #10;
                
                // Scrittura nel file 
                $fdisplay(file_handle, "\n| FP1        | FP2        | FP_RES     |");
                $fdisplay(file_handle, "| %b + %b = %b | A_IS_ZERO=%b | B_IS_ZERO=%b | EXP_DIFF=%b | SHIFT_AMT=%b | MANT_A_SHF=%b | MANT_B_SHF=%b | RES_MANT_TMP=%b | SIGN=%b | DIR=%b | LOD_ZERO=%b | LOD_SHF=%b | SHF_MANT_TMP=%b |EXP=%b | MANT=%b | HIF8_RES=%b | HIF8RES_TO_FP=%b",
                              uut.fp_from_hif8_a,
                              uut.fp_from_hif8_b,
                              uut.sum_result_in_FP,
                              uut.a_is_zero,
                              uut.b_is_zero,
                              uut.exp_diff,
                              uut.shift_amount,
                              uut.full_mant_a_shifted,
                              uut.full_mant_b_shifted,
                              uut.result_mant_temp,
                              uut.result_sign,
                              uut.direction,
                              uut.lod_zero,
                              uut.lod_shift_amt,
                              uut.shifted_result_mant_temp,
                              uut.result_exp,
                              uut.result_mant,
                              uut.hif8_res_out,
                              uut.hif8_res_out_to_FP);
            end
        end

        // Chiusura del file 
        $fclose(file_handle);
        
       
    end

endmodule