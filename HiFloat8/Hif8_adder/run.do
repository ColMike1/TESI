if {[file exists work]} {
    vdel -lib work -all
}


vlib work

# compilazione
vlog src/HiFloat8_to_FP_converter.v
vlog src/FP_to_HiFloat8_converter.v
vlog src/adderHiFloat8.v

vlog tb/tb_adderHiFloat8.v


# avvia simulazione 
vsim -voptargs="+acc" work.tb_adder_HiF8

# segnali
# add wave -position insertpoint sim:/tb_adder_HiF8

# esegui simulazione
run -all

# zoom sui segnali
# wave zoom full