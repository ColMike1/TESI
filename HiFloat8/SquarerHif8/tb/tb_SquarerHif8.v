`timescale 1ns/1ps

module tb_squarer_HiF8();

    // Ingressi del modulo sotto test (UUT)
    reg [7:0] hif8_in;
    reg [7:0] hif8_squared;


    // Istanziazione dell'Addizionatore HiFloat8
    squarer_Hif8 uut (

        .hif8_in(hif8_in),
        .hif8_res.(hif8_squared)
    );

    integer file_handle;
    integer i, j;

    initial begin
        // Apertura del file in modalità scrittura
        file_handle = $fopen("results/squared_results.txt", "w");
        if (file_handle == 0) begin
            $display("Error: can't open the file in write!");
            $finish;
        end

        $display("Simulating all 256 combinations...");

        // Cicli  (256)
        for (i = 0; i < 256; i = i + 1) begin
            
            hif8_in = i[7:0];
            
            // Breve ritardo 
            #10;

            // da finire
            $fdisplay(file_handle, "| HIF8_IN=%b | HIF8IN_ISZERO=%b | FP_FROM_HIF8IN=%b | FULL_MANT=%b | FULL_MANT_SQUARED=%b | MANT_RES=%b | EXP_RES_TMP=%b | EXP_RES=%b")
            
         
        $fclose(file_handle);
        
       
        end
    end

endmodule