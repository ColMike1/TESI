`timescale 1ns/1ps

module tb_adder_HiF8 #(
    parameter integer SHIFT_START = 4,
    parameter integer SHIFT_END   = 15
)();

    // Inputs shared across all instances
    reg  [7:0] hif8_a_in;
    reg  [7:0] hif8_b_in;

    // Outputs for MAX_SHIFT = SHIFT_START .. SHIFT_END
    wire [7:0] hif8_res_out [SHIFT_START:SHIFT_END];

    // Synchronization flags/events between stimulus loop and generated loggers
    reg   files_ready;
    reg   sim_done;
    event log_event;

    integer i, j, s_init;
    reg [8*140:1] open_err_filename;
    integer test_fh;

    // Instantiate adder_HiF8 and per-instance logger for MAX_SHIFT = SHIFT_START .. SHIFT_END
    genvar s;
    generate
        for (s = SHIFT_START; s <= SHIFT_END; s = s + 1) begin : gen_adder
            adder_HiF8 #(
                .MAX_SHIFT(s)
            ) uut (
                .hif8_a_in(hif8_a_in),
                .hif8_b_in(hif8_b_in),
                .hif8_res_out(hif8_res_out[s])
            );

            integer fh;
            reg [8*140:1] fname;

            initial begin
                fh = 0;
                wait (files_ready === 1'b1);

                $sformat(fname, "results/range_max_shift/noRounding/sum_results%0d.txt", s);
                fh = $fopen(fname, "w");
                if (fh == 0) begin
                    $display("Errore: Impossibile aprire %0s per la scrittura!", fname);
                    $finish;
                end

                wait (sim_done === 1'b1);
                #1;
                if (fh != 0) begin
                    $fclose(fh);
                end
            end

            always @(log_event) begin
                if (fh != 0) begin
                    $fdisplay(fh, "\n| FP1        | FP2        | FP_RES     |");
                    $fdisplay(fh, "| %b + %b = %b | A_IS_ZERO=%b | B_IS_ZERO=%b | EXP_DIFF=%b | SHIFT_AMT=%b | MANT_A_SHF=%b | MANT_B_SHF=%b | RES_MANT_TMP=%b | SIGN=%b | DIR=%b | LOD_ZERO=%b | LOD_SHF=%b | SHF_MANT_TMP=%b | EXP=%b | MANT=%b | HIF8_RES=%b | HIF8RES_TO_FP=%b",
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
                              hif8_res_out[s],
                              uut.hif8_res_out_to_FP);
                end
            end
        end
    endgenerate

    initial begin
        files_ready = 1'b0;
        sim_done    = 1'b0;

        if (SHIFT_START > SHIFT_END) begin
            $display("Errore: SHIFT_START (%0d) non puo' superare SHIFT_END (%0d).", SHIFT_START, SHIFT_END);
            $finish;
        end

        // Verifica preventiva che i file siano apribili prima di avviare le 65.536 iterazioni
        for (s_init = SHIFT_START; s_init <= SHIFT_END; s_init = s_init + 1) begin
            $sformat(open_err_filename, "results/range_max_shift/noRounding/sum_results%0d.txt", s_init);
            test_fh = $fopen(open_err_filename, "w");
            if (test_fh == 0) begin
                $display("Errore: Impossibile aprire %0s per la scrittura!", open_err_filename);
                $finish;
            end
            $fclose(test_fh);
        end

        #1;
        files_ready = 1'b1;
        #1;

        $display("Inizio della simulazione per tutte le 65.536 combinazioni (MAX_SHIFT %0d..%0d)...", SHIFT_START, SHIFT_END);

        // Loop over all 256 x 256 input pairs
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                hif8_a_in = i[7:0];
                hif8_b_in = j[7:0];

                #10;
                -> log_event;
                #1;
            end
        end

        sim_done = 1'b1;
        #5;

        $display("Simulazione completata per MAX_SHIFT da %0d a %0d.", SHIFT_START, SHIFT_END);
        
    end

endmodule