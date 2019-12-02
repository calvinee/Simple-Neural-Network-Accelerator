
quietly set PROJECT_DIR "/home/ecegrid/a/695r07/ece695r/Project/SoCProject"

vlog -reportprogress 300 -work work "${PROJECT_DIR}/Custom-Hardware-Blocks/AcceleratorPackage.sv"

vlog -reportprogress 300 -work work "${PROJECT_DIR}/Custom-Hardware-Blocks/fp_adder.sv"
vlog -reportprogress 300 -work work "${PROJECT_DIR}/Custom-Hardware-Blocks/fp_multiplier.sv"
vlog -reportprogress 300 -work work "${PROJECT_DIR}/Custom-Hardware-Blocks/pipeline_registers.sv"
vlog -reportprogress 300 -work work "${PROJECT_DIR}/Custom-Hardware-Blocks/data_buffer.sv"
vlog -reportprogress 300 -work work "${PROJECT_DIR}/Custom-Hardware-Blocks/datapath.sv"
vlog -reportprogress 300 -work work "${PROJECT_DIR}/Custom-Hardware-Blocks/AcceleratorTopMod.sv"

vlog -reportprogress 300 -work work "${PROJECT_DIR}/Custom-Hardware-Blocks/tbAccl.sv"

vsim -novopt work.tbAccl


add wave -position insertpoint sim:/tbAccl/accl/*
# add wave -position insertpoint sim:/tbAccl/accl/mac/*

run 200 ns

