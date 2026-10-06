# Detailed release evidence; run after the full Quartus 17.0.2 flow.
package require ::quartus::project
package require ::quartus::sta
project_open VTG9000
create_timing_netlist
read_sdc
update_timing_netlist
report_clocks -file output_files/release-clocks.rpt
report_timing -setup -npaths 20 -detail full_path -file output_files/release-setup.rpt
report_timing -hold -npaths 20 -detail full_path -file output_files/release-hold.rpt
report_timing -recovery -npaths 10 -detail full_path -file output_files/release-recovery.rpt
report_timing -removal -npaths 10 -detail full_path -file output_files/release-removal.rpt
report_ucp -file output_files/release-unconstrained.rpt
project_close
