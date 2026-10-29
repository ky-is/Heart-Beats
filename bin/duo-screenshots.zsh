# Duo hinge-pose screenshots: run `duo-screenshots` from the repo
project='Heart Beats.xcodeproj'
scheme='Heart Beats'
title='Heart Beats'
# Printed in sample mode once the screen is drawn, covers and all
ready_pattern='\[screenshot\] ready'
sheet_first=(artists-grid artists-list genres years settings minimum)

# NAME is TAB-VIEWMODE or a debugScreen (settings, minimum) shown over Artists
screen() {
	case $1 in
		artists-grid) launch -selectedTab artists -listViewMode grid ;;
		artists-list) launch -selectedTab artists -listViewMode list ;;
		genres) launch -selectedTab genres -listViewMode grid ;;
		years) launch -selectedTab years ;;
		settings) launch -selectedTab artists -listViewMode grid -debugScreen $1 ;;
		minimum)
			# A launch per pose: a hinge move closes the popover
			for p in $poses; do
				set_pose $p
				launch -selectedTab artists -listViewMode grid -debugScreen $1
				capture $1
			done
			return ;;
	esac
	shoot $1
}

duo_shots() { shots screen artists-grid artists-list genres years settings minimum }
