if {[file exists work]} {
    vdel -lib work -all
}


vlib work

# compilazione
vlog src/HiFloat8_to_FP_converter.v
vlog tb/tb_HF8_FP.sv


# avvia simulazione 
vsim -voptargs="+acc" work.tb_HF8_FP


# segnali
# add wave -position insertpoint sim:/tb_HF8_FP/*


# esegui simulazione
run -all

# zoom sui segnali
# wave zoom full