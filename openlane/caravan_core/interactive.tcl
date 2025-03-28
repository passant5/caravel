package require openlane
variable SCRIPT_DIR [file dirname [file normalize [info script]]]
# prep -ignore_mismatches -design $SCRIPT_DIR -tag techlef_for_antenna -overwrite -verbose 0
prep -ignore_mismatches -design $SCRIPT_DIR -tag $::env(OPENLANE_RUN_TAG) -overwrite -verbose 0

set save_path $::env(CARAVEL_ROOT)

################   Synthesis   ################
run_synthesis
# set_netlist $::env(DESIGN_DIR)/synth_configuration/caravan_core.v
# set ::env(CURRENT_SDC) $::env(DESIGN_DIR)/sdc_files/base.sdc

################   Floorplan   ################
init_floorplan
apply_def_template

# Placing the macros in the core area and marking them fixed
file copy -force $::env(MACRO_PLACEMENT_CFG) $::env(placement_tmpfiles)/macro_placement.cfg
manual_macro_placement -f

# Tap/Decap insertion
tap_decap_or

# 
set ::env(GRT_OBS) "\
    pwell 0 4195 3165 4767, \
    nwell 0 4195 3165 4767, \
    li1 0 4195 3165 4767, \
    met1 0 4195 3165 4767, \
    met2 0 4195 3165 4767, \
    met3 0 4195 3165 4767, \
    met4 0 4195 3165 4767, \
    met5 0 4195 3165 4767, \
    met4 990 0 1075 45, \
    met5 0 128 22 205, \
    met5 3123 2085 3165 2167, \
    met5 0 1983 50 2071, \
    met4 857 0 878 165, \
    met4 965 0 980 172, \
    met5 59.52 1183.09 3103.58 4703.09, \
    met5 1943 1153 1944 1155, \
    met5 1815 1130 1816 1132, \
    met5 631 144 650 183, \
    met4 1040 189 1052 190 \
"
add_route_obs

run_power_grid_generation

# run_magic
# save_final_views
# save_views -save_path .. -tag $::env(OPENLANE_RUN_TAG)
################   placement   ################
set ::env(PL_TARGET_DENSITY) 0.19
run_placement

################   CTS   ################
run_cts
run_resizer_timing

################ Global Routing Optmization  ################
run_resizer_design_routing
run_resizer_timing_routing

##   Placement again  ##
set ::env(PL_TARGET_DENSITY) 0.24
run_placement
run_cts

run_resizer_timing

##  Routing Optmization  ##
run_resizer_design_routing
run_resizer_timing_routing

################ Place and route on the optmized netlist ################
set ::env(PL_TARGET_DENSITY) 0.26
set ::env(PL_RESIZER_DESIGN_OPTIMIZATIONS) 0
set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) 0
set ::env(GLB_RESIZER_DESIGN_OPTIMIZATIONS) 0
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 1
run_placement
run_cts

# Adding met4/5 routing obstructions over the the RAMs, housekeeping, and PoR to prevent routing DRCs
set ::env(GRT_OBS) "\
    met5 90 175.0 496.18 612.92, \
    met5 582.00 175.00 988.18 612.92, \
    met5 1800 125.00 2206.18 562.92, \
    met5 2650 190 3060.23 740.95, \
    met4 90 175.0 496.18 612.92, \
    met4 582.00 175.00 988.18 612.92, \
    met4 1800 125.00 2206.18 562.92, \
    met4 2650 190 3060.23 740.95, \
    met3 1040.21 137.49 1064.35 134.81, \
    met3 1137.92 135.15 1116.81 131.81, \
    met3 653.10 41.58 701.69 33.85, \
    met4 1046 133 1133 143, \
    met4 63.13 1219.47 86.32 1142.66, \
    met4 3040.60 1220.06 3089.40 1118.88 \
"
# adding hk_serial_clock and hk_serial_load as clocks after CTS by changing
# the sdc file to another one which they are defined as clocks in it. 
set ::env(CURRENT_SDC) $::env(DESIGN_DIR)/sdc_files/base_2.sdc

set ::env(GRT_ALLOW_CONGESTION) 0
run_routing
################   RCX sta    ################
run_parasitics_sta

################   IR drop    ################
# run_irdrop_report

################   Antenna check    ################
run_antenna_check

################   magic    ################
run_magic

################   LVS    ################
# run_magic_spice_export;
# run_lvs;

###############   DRC    ################
run_magic_drc

################   Saving views and reports    ################
save_final_views
save_views -save_path .. -tag $::env(OPENLANE_RUN_TAG)
## 
    calc_total_runtime
    save_state
    generate_final_summary_report
    check_timing_violations
    if { [info exists arg_values(-save_path)]\
        && $arg_values(-save_path) != "" } {
        set ::env(HOOK_OUTPUT_PATH) "[file normalize $arg_values(-save_path)]"
    } else {
        set ::env(HOOK_OUTPUT_PATH) $::env(RESULTS_DIR)/final
    }
    if {[info exists flags_map(-run_hooks)]} {
        run_post_run_hooks
    }
    puts_success "Flow complete."
    show_warnings "Note that the following warnings have been generated:"

################   Copying reports    ################
set run_dir $::env(DESIGN_DIR)/runs/$::env(RUN_TAG)
## copying signoff reports
set sourceDir $run_dir/reports/signoff
set targetDir $::env(CARAVEL_ROOT)/signoff/$::env(DESIGN_NAME)/openlane-signoff/
foreach f [glob -directory $sourceDir -nocomplain *] {
    file copy -force $f $targetDir
}
## copying spefs
set sourceDir $run_dir/results/routing/mca/spef/
set targetDir $::env(CARAVEL_ROOT)/signoff/$::env(DESIGN_NAME)/openlane-signoff/spef/
foreach f [glob -directory $sourceDir -nocomplain *] {
    file copy -force $f $targetDir
}
## copying sdf
set sourceDir $run_dir/results/routing/mca/sdf/nom/
set targetDir $::env(CARAVEL_ROOT)/signoff/$::env(DESIGN_NAME)/openlane-signoff/sdf/nom/
foreach f [glob -directory $sourceDir -nocomplain *] {
    file copy -force $f $targetDir
}
set sourceDir $run_dir/results/routing/mca/sdf/min/
set targetDir $::env(CARAVEL_ROOT)/signoff/$::env(DESIGN_NAME)/openlane-signoff/sdf/min/
foreach f [glob -directory $sourceDir -nocomplain *] {
    file copy -force $f $targetDir
}
set sourceDir $run_dir/results/routing/mca/sdf/max/
set targetDir $::env(CARAVEL_ROOT)/signoff/$::env(DESIGN_NAME)/openlane-signoff/sdf/max/
foreach f [glob -directory $sourceDir -nocomplain *] {
    file copy -force $f $targetDir
}
## coping other files
set flist [list $run_dir/config.tcl $run_dir/openlane.log $run_dir/runtime.yaml $run_dir/warnings.log]
file copy -force {*}$flist $::env(CARAVEL_ROOT)/signoff/$::env(DESIGN_NAME)/