if {[file exists work]} {
    vdel -lib work -all
}


vlib work

# compilazione
vlog src/FP_to_HiFloat8_converter.v
vlog tb/tb_FP_HF8.sv


# avvia simulazione 
vsim -voptargs="+acc" work.tb_FP_HF8


# segnali
# add wave -position insertpoint sim:/tb_FP_HF8/*


# esegui simulazione
run -all


# zoom sui segnali
# wave zoom full