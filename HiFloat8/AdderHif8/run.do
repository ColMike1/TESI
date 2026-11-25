if {[file exists work]} {
    vdel -lib work -all
}


vlib work

# compilazione
vlog src/HiFloat8_to_FP_converter.v
vlog src/FP_to_HiFloat8_converter.v


# ======== MAX_SHIFT= variable ===========

#        NO_ROUNDING
vlog src/range_max_shift/noRounding/AdderHiF8_rms_noRounding.v
vlog tb/range_max_shift/noRounding/tb_adder_hif8.v

#        ROUNDING
# vlog src/range_max_shift/withRounding/AdderHiF8_rms_withRounding.v
# vlog tb/range_max_shift/withRounding/tb_adder_hif8.v



# avvia simulazione 
vsim -voptargs="+acc" work.tb_adder_HiF8

# segnali
# add wave -position insertpoint sim:/...

# esegui simulazione
run -all

# zoom sui segnali
# wave zoom full