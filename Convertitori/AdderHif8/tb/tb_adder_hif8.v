`timescale 1ns/1ps

module tb_adder_HiF8();

    // Ingressi del modulo sotto test (UUT)
    reg [7:0] hif8_a_in;
    reg [7:0] hif8_b_in;

    // Uscite del modulo sotto test
    wire [9:0] fp_a_out;
    wire       zero_flag_a;
    wire [9:0] fp_b_out;
    wire       zero_flag_b;
    wire [9:0] fp_res_out;
    wire       zero_flag_res;
    wire [7:0] hif8_res_out;

    // Istanziazione dell'Addizionatore HiFloat8
    adder_HiF8 uut (
        .hif8_a_in(hif8_a_in),
        .hif8_b_in(hif8_b_in),
        .fp_a_out(fp_a_out),
        .zero_flag_a(zero_flag_a),
        .fp_b_out(fp_b_out),
        .zero_flag_b(zero_flag_b),
        .fp_res_out(fp_res_out),
        .zero_flag_res(zero_flag_res),
        .hif8_res_out(hif8_res_out)
    );

    integer file_handle;
    integer i, j;

    initial begin
        // Apertura del file in modalità scrittura
        file_handle = $fopen("AdderHif8/results/sum_results.txt", "w");
        if (file_handle == 0) begin
            $display("Errore: Impossibile aprire il file per la scrittura!");
            $finish;
        end

        $display("Inizio della simulazione per tutte le 65.536 combinazioni...");

        // Cicli annidati per coprire tutte le combinazioni (256 * 256)
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                hif8_a_in = i[7:0];
                hif8_b_in = j[7:0];
                
                // Breve ritardo per permettere alla logica combinatoria di propagarsi
                #10;
                
                // Scrittura nel file con il formato esatto richiesto
                $fdisplay(file_handle, "| FP1 = %b | ZERO_FP1 = %b | FP2 = %b | ZERO_FP2 = %b | FP_RES = %b | ZERO_RES = %b |",
                          fp_a_out, zero_flag_a, fp_b_out, zero_flag_b, fp_res_out, zero_flag_res);
            end
        end

        // Chiusura del file e termine della simulazione
        $fclose(file_handle);
        $display("Simulazione completata con successo. Risultati salvati in 'hif8_results.txt'.");
        $finish;
    end

endmodule