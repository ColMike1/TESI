`timescale 1ns / 1ps

module tb_HF8_FP;

 
    reg  [7:0] hif8_in;
    

    wire       sign_out;
    wire [5:0] exp_out_2s;
    wire [2:0] mant_out;
    
    // Ricostruzione dell'uscita in formato 10-bit FP
    wire [9:0] fp_out;
    assign fp_out = {sign_out, exp_out_2s, mant_out};

    
    wire zero_flag_hif8_to_fp;
 
    integer i;
    integer total_tests = 0;
    integer file_handle; 

    // Istanza del modulo HiFloat8 -> FP
    HiFloat8_to_FP_converter u_HiFloat8_to_FP (
        .hif8_in       (hif8_in),
        .sign_out      (sign_out),
        .exp_out_2s    (exp_out_2s),
        .mant_out      (mant_out),
        .zero_flag_out (zero_flag_hif8_to_fp)
    );

    // Funzione per formattare il testo nelle colonne di FP 
    function automatic string format_fp_details(input [9:0] fp);
        reg s;
        reg [5:0] exp_val;
        reg [2:0] mant_val;
        real mant_real; 
        begin
            s        = fp[9];
            exp_val  = fp[8:3];
            mant_val = fp[2:0];
            
            mant_real = real'(mant_val) / 8.0;

            return $sformatf("%b_%b_%b (Dec:%4d | E:%0d, M:%0.3f)", 
                             s, exp_val, mant_val, fp, $signed(exp_val), mant_real);
        end
    endfunction

    // Funzione per formattare correttamente il testo nelle colonne di HiFloat8
    function automatic string format_hif8_details(input [7:0] hif);
        reg s;
        reg [3:0] dot_selector;
        reg [5:0] abs_exp;
        reg do_comp;
        reg [5:0] final_exp;
        reg [2:0] m_out;
        real m_real; 
        string bin_str;
        string dot_display_str;
        begin
            s            = hif[7];
            dot_selector = hif[6:3];
            
            casex (dot_selector)
                4'b0000: begin // Denormal 
                    abs_exp         = 6'b01_0111 - {3'b0, hif[2:0]};
                    do_comp         = 1'b1;
                    m_out           = 3'b000;
                    dot_display_str = $sformatf("%04b", hif[6:3]);
                    bin_str         = $sformatf("%b_%4b_----_%3b", s, hif[6:3], hif[2:0]);
                end
                4'b0001: begin // Exp = 0 (Dot = 0001)
                    abs_exp         = 6'b0;
                    do_comp         = 1'b0;
                    m_out           = hif[2:0];
                    dot_display_str = $sformatf("%04b", hif[6:3]);
                    bin_str         = $sformatf("%b_%4b_----_%3b", s, hif[6:3], hif[2:0]);
                end
                4'b001?: begin // Exp = 1 (Dot = 001)
                    abs_exp         = {5'b0, 1'b1};
                    do_comp         = hif[3];
                    m_out           = hif[2:0];
                    dot_display_str = $sformatf("%03b", hif[6:4]);
                    bin_str         = $sformatf("%b_%3b_%1b_%3b", s, hif[6:4], hif[3], hif[2:0]);
                end
                4'b01??: begin // Exp = [2,3] (Dot = 01)
                    abs_exp         = {4'b0, 1'b1, hif[3]};
                    do_comp         = hif[4];
                    m_out           = hif[2:0];
                    dot_display_str = $sformatf("%02b", hif[6:5]);
                    bin_str         = $sformatf("%b_%2b_%2b_%3b", s, hif[6:5], hif[4:3], hif[2:0]);
                end
                4'b10??: begin // Exp = [4,7] (Dot = 10)
                    abs_exp         = {3'b0, 1'b1, hif[3:2]};
                    do_comp         = hif[4];
                    m_out           = {hif[1:0], 1'b0};
                    dot_display_str = $sformatf("%02b", hif[6:5]);
                    bin_str         = $sformatf("%b_%2b_%3b_%2b", s, hif[6:5], hif[4:2], hif[1:0]);
                end
                4'b11??: begin // Exp = [8,15] (Dot = 11)
                    abs_exp         = {2'b0, 1'b1, hif[3:1]};
                    do_comp         = hif[4];
                    m_out           = {hif[0], 2'b0};
                    dot_display_str = $sformatf("%02b", hif[6:5]); 
                    bin_str         = $sformatf("%b_%2b_%4b_%1b", s, hif[6:5], hif[4:1], hif[0]);
                end
                default: begin
                    abs_exp         = 6'b0;
                    do_comp         = 1'b0;
                    m_out           = 3'b0;
                    dot_display_str = "----";
                    bin_str         = $sformatf("%b_%4b_----_---", s, hif[6:3]);
                end
            endcase
            
            final_exp = (do_comp == 1'b1) ? (~abs_exp + 6'd1) : abs_exp;
            
            m_real = real'(m_out) / 8.0;
            
            return $sformatf("%s (Dot:%s | E:%0d, M:%0.3f)", bin_str, dot_display_str, $signed(final_exp), m_real);
        end
    endfunction

    initial begin
        
        file_handle = $fopen("results/results_HF8_to_FP.txt", "w");
        if (file_handle == 0) begin
            $display("ERRORE: impossibile creare il file results/results_HF8_to_FP.txt");
            $finish;
        end

        // Ciclo su tutte le 256 combinazioni (2^8) del formato HiFloat8
        for (i = 0; i < 256; i = i + 1) begin
            hif8_in = i[7:0];
            #5; 
            
            // Scrittura dei risultati sul file 
            $fdisplay(file_handle, "%-45s | %-45s | %-18s",
                      format_hif8_details(hif8_in),
                      format_fp_details(fp_out),
                      $sformatf("ZF_HF2FP: %0d", zero_flag_hif8_to_fp));
            
            total_tests = total_tests + 1;
        end

        // Scrittura del riepilogo finale sul file
        $fdisplay(file_handle, "RIEPILOGO TESTBENCH:");
        $fdisplay(file_handle, "    Totale combinazioni testate : %0d", total_tests);
        
        $fclose(file_handle);

    end

endmodule
