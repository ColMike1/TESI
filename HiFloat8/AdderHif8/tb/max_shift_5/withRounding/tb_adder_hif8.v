`timescale 1ns/1ps

module tb_adder_HiF8();

    // Inputs to the Unit Under Test (UUT)
    reg  [7:0] hif8_a_in;
    reg  [7:0] hif8_b_in;

    // Output of the UUT
    wire [7:0] hif8_res_out;

    // Instantiate the HiFloat8 adder
    adder_HiF8 uut (
        .hif8_a_in(hif8_a_in),
        .hif8_b_in(hif8_b_in),
        .hif8_res_out(hif8_res_out)
    );

    integer file_handle;
    integer i, j;

    initial begin
        // Open output log file for writing
        file_handle = $fopen("results/max_shift_5/withRounding/sum_results.txt", "w");
        if (file_handle == 0) begin
            $display("Errore: Impossibile aprire il file per la scrittura!");

        end

        $display("Inizio della simulazione per tutte le 65.536 combinazioni...");

        // Loop over all 256 x 256 input pairs (same sign and opposite sign)
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                hif8_a_in = i[7:0];
                hif8_b_in = j[7:0];

                #10;

                $fdisplay(file_handle, "\n| FP1        | FP2        | FP_RES     |");
                $fdisplay(file_handle, "| %b + %b = %b | EXP_DIFF=%b | SHIFT_AMT=%b | MANT_A_SHF=%b | MANT_B_SHF=%b | RES_MANT_TMP=%b | SIGN=%b | DIR=%b | LOD_ZERO=%b | LOD_SHF=%b | SHF_MANT_TMP=%b | EXP_APRX=%b | EXP=%b | MANT=%b | HIF8_RES=%b | HIF8RES_TO_FP=%b",
                          uut.fp_from_hif8_a,
                          uut.fp_from_hif8_b,
                          uut.sum_result_in_FP,
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
                          uut.result_exp_aprx,
                          uut.result_exp,
                          uut.result_mant,
                          hif8_res_out,
                          uut.hif8_res_out_to_FP);
            end
        end

        // Close file and finish simulation
        $fclose(file_handle);

    end

endmodule