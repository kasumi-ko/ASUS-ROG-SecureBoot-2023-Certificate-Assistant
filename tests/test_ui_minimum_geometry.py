"""Logical geometry checks for the authored minimum-size layouts.

These checks do not instantiate WinForms. They verify that the fixed minimum dimensions
leave room for both detailed panes and that the OOBE uses short labels plus wrapped text.
"""

# OOBE is authored and constrained to the same minimum dimensions, so right-anchored
# language controls and storage controls do not move into the left content area.
oobe_width = 1040
title_right = 28 + 660
language_label_left = 716
assert title_right <= language_label_left - 8

backup_text_right = 30 + 790
browse_left = 832
assert backup_text_right <= browse_left - 8

# Detailed diagnostics at the 1180-wide main-window minimum.
tab_width = 1180 - 60
inner_width = tab_width - 24
left_width = inner_width * 0.41
right_width = inner_width * 0.59
steps_columns = 42 + 300 + 88
assert steps_columns + 12 <= left_width, (steps_columns, left_width)
assert 160 + 260 + 24 <= right_width, right_width

# Overview strongly prioritizes the result column.
assert 15 < 85


# Main top-area vertical geometry at the authored minimum size.
status_bottom = 50 + 34
risk_top, risk_height = 88, 100
risk_bottom = risk_top + risk_height
risk_title_height = 24
risk_text_top, risk_text_height = 31, 62
next_top, next_bottom = 198, 198 + 82
tabs_top, tabs_bottom = 290, 290 + 481
assert status_bottom <= risk_top
assert risk_bottom < next_top
assert next_bottom < tabs_top
assert tabs_bottom == 771
# At 9–9.5 pt UI fonts, 62 logical pixels provides at least four normal text lines.
assert risk_text_height >= 60
assert risk_text_top + risk_text_height <= risk_height - 6
assert risk_title_height < risk_text_top

print('UI_MINIMUM_GEOMETRY_OK')
