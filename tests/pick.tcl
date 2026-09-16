# Which device families ship with a given Quartus edition/version varies,
# so discover a usable part at build time rather than hardcoding one that
# only exists in some installations. Prefer the smallest package available
# to keep the compile short. lsort is stable, so sorting by name first and
# by pin count second leaves the name as the tie breaker, which keeps the
# choice deterministic.
set parts [list]
foreach fam [get_family_list] {
	foreach part [get_part_list -family $fam] {
		if {[catch {set pins [get_part_info -pin_count $part]}]} { continue }
		lappend parts [list $pins $part $fam]
	}
}
if {[llength $parts] == 0} {
	post_message -type error "no device families are installed"
	exit 1
}
set best [lindex [lsort -index 0 -integer [lsort -index 1 -ascii $parts]] 0]
set fh [open device.txt w]
puts $fh [lindex $best 2]
puts $fh [lindex $best 1]
close $fh
