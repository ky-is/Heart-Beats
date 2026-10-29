#!/bin/zsh
# App Store screenshots for the display sizes App Store Connect requires; it scales them for the other sizes:
#   iPhone with Dynamic Island (medium display), 1206 x 2622, on an iPhone 18 Pro
#   iPad 13-inch display, 2064 x 2752, on an iPad Pro 13-inch (M5)
#   iPhone Duo, inner 2007 x 2853 then cover 2034 x 1398, from duo-screenshots (required from April 2027; adds a badge)
#   Mac, 2880 x 1800: the Mac Catalyst app (a Debug build with -screenshotData) in a 1440 x 900 window, on a Retina display
# --only "iPhone iPad Duo Mac" picks some of them (all by default); --no-duo leaves out the Duo ones.
# The Mac ones open the app on this Mac for a few seconds per shot (Artists and Years; the minimum has no popover on a Mac, its steppers sit beside it,
# so there is nothing more to show), capture only its window, and need Screen Recording permission. Best run while you're away from the Mac,
# so the window can come to the front and is drawn active.
# Run with `fastlane screenshots`, or directly. Writes fastlane/screenshots/en-US/, where deliver finds them.
# Each device is the shared simulator for its type (shared-sim, see ~/.claude/CLAUDE.md), waited for while something else
# uses it, then shut down and given back as it was found.
# The simulator build shows the built-in sample library; Debug, for the debugScreen launch argument.
set -euo pipefail

root=${0:A:h:h}
cd $root
project="$root/Heart Beats.xcodeproj"
scheme='Heart Beats'
bundle_id=is.ky.Heart-Beats
out=$root/fastlane/screenshots/en-US
derived=$root/fastlane/build/ScreenshotsDerivedData
work=$(mktemp -d)
device=
appearance=
only=(iPhone iPad Duo Mac)
while (( $# )); do
	case $1 in
		--only) only=(${=2}); shift ;;
		--no-duo) only=(${only:#Duo}) ;;
		*) echo "Unknown option $1" >&2; exit 2 ;;
	esac
	shift
done
wants() { (( ${only[(Ie)$1]} )) }

console_pid=
# Puts back what this changed on the shared simulator and gives it back, still booted (marked idle), so the next run
# doesn't have to boot it from scratch
release_device() {
	[[ -n $console_pid ]] && kill $console_pid 2>/dev/null
	console_pid=
	[[ -n $device ]] || return 0
	xcrun simctl terminate $device $bundle_id 2>/dev/null || true
	xcrun simctl status_bar $device clear 2>/dev/null || true
	[[ -n $appearance ]] && xcrun simctl ui $device appearance $appearance 2>/dev/null || true
	shared-sim release $device
	device=
}
trap 'release_device; rm -rf $work' EXIT

# replace_set NAME FOLDER: the new NAME-* shots in FOLDER replace the old ones. One that looks the same as the shot it
# replaces (no pixel off by more than 3%) keeps the old file, so its checksum still matches what App Store Connect has and
# `fastlane upload_screenshots` leaves it alone; a fresh capture is a new JPEG even when nothing on screen changed.
replace_set() {
	local name=$1 folder=$2 new old kept=0
	for new in $folder/$name-*.jpg; do
		old=$out/${new:t}
		if [[ -f $old ]] && [[ $(magick compare -metric AE -fuzz 3% $old $new null: 2>&1 | awk '{print $1}') == 0 ]]; then
			cp -p $old $new
			(( kept++ ))
		fi
	done
	rm -f $out/$name-*.jpg(N)
	mv $folder/$name-*.jpg $out/
	(( kept )) && echo "  $name: $kept unchanged, kept as they were"
	return 0
}

# NAME:DEVICE TYPE
devices=(
	iPhone:com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro
	iPad:com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB
)
# NAME:LAUNCH ARGUMENTS, in App Store order
shots=(
	'artists:-selectedTab artists -listViewMode grid'
	'minimum:-selectedTab artists -listViewMode grid -debugScreen minimum'
	'years:-selectedTab years -listViewMode grid'
)

if wants iPhone || wants iPad; then
echo 'Building…'
xcodebuild -project $project -scheme $scheme -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath $derived -quiet build
app=$derived/Build/Products/Debug-iphonesimulator/Heart\ Beats.app

# launch_ready SCREEN [ARGS…]: launches the app and waits for its console line saying SCREEN is drawn ("[screenshot] ready
# SCREEN", printed in sample mode), instead of a fixed delay. Relaunches if it doesn't come: right after a boot the home
# screen can still be starting, or crash and restart.
launch_ready() {
	local screen=$1 attempt
	shift
	for attempt in {1..3}; do
		[[ -n $console_pid ]] && kill $console_pid 2>/dev/null
		: > $work/console.log
		xcrun simctl launch --console-pty --terminate-running-process $device $bundle_id "$@" > $work/console.log 2>&1 &
		console_pid=$!
		for _ in {1..60}; do
			grep -q "\[screenshot\] ready $screen" $work/console.log && return 0
			sleep 0.25
		done
		echo "  $screen: no ready line after 15 s, relaunching" >&2
	done
	echo "  $screen: the app never got ready" >&2
	exit 1
}

# Saves the screen once it keeps still (two frames the same), after the ready line. A blank screen (the launch screen)
# is one flat color, a tiny PNG, so it doesn't count.
capture() {
	local device=$1 file=$2 previous= frame index
	for index in {1..40}; do
		frame=$work/frame-$index.png
		xcrun simctl io $device screenshot $frame > /dev/null 2>&1
		if [[ -n $previous ]] && (( $(stat -f %z $frame) > 150000 )) && cmp -s $previous $frame; then
			break
		fi
		previous=$frame
		sleep 0.3
	done
	(( index < 40 )) || echo "  never kept still, taking the last frame" >&2
	# App Store Connect rejects images with an alpha channel
	sips -s format jpeg -s formatOptions best $frame --out $file > /dev/null
	rm -f $work/frame-*.png(N)
}

mkdir -p $out

for entry in $devices; do
	name=${entry%%:*}
	kind=${entry#*:}
	wants $name || continue
	udid=$(shared-sim udid $kind)
	echo "$name: $(xcrun simctl list devices | grep $udid | sed -E 's/^ +//; s/ \(.*//')…"
	shared-sim acquire $udid 'Heart Beats App Store screenshots'
	device=$udid
	# Left booted by the last run, it needn't boot again
	xcrun simctl list devices | grep -q "($device) (Booted)" || xcrun simctl boot $device
	xcrun simctl bootstatus $device -b > /dev/null
	appearance=$(xcrun simctl ui $device appearance)
	xcrun simctl ui $device appearance light
	xcrun simctl uninstall $device $bundle_id 2>/dev/null || true
	xcrun simctl install $device $app
	# The new set goes beside the old one, which it replaces only once every shot is taken, so a failed run leaves it alone
	fresh=$work/$name
	mkdir -p $fresh
	index=1
	# On iPad the minimum's steppers sit beside it, with no popover, so that shot would repeat the Artists one
	device_shots=($shots)
	[[ $name == iPad ]] && device_shots=(${shots:#minimum:*})
	for shot in $device_shots; do
		shot_name=${shot%%:*}
		# The screen whose ready line to wait for: the artists list, or the minimum popover over it, or the years
		ready_screen=${${shot_name/artists/artist}}
		launch_ready $ready_screen ${=shot#*:}
		# After each launch: an override set right after boot is recorded but not always drawn
		xcrun simctl status_bar $device override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
		capture $device $fresh/$name-$index-$shot_name.jpg
		echo "  $name-$index-$shot_name.jpg"
		(( index++ ))
	done
	replace_set $name $fresh
	release_device
done
fi

# iPhone Duo: the same screens open (inner screen, portrait), then closed (cover screen), from bin/duo-screenshots.zsh
if wants Duo; then
	duo_names=(artists-grid minimum years)
	# The first pose shot after boot comes out in the boot orientation (landscape), so a throwaway open pose goes first
	# --warm: from the simulator as the last run left it, booted, rather than a fresh boot
	duo-screenshots --warm --poses 'open closed open-tall' --only "$duo_names"
	mkdir -p $work/Duo
	index=1
	for pose in open-tall closed; do
		for shot_name in $duo_names; do
			# Open, the screen is wide enough for the minimum's steppers beside it, with no popover to show
			[[ $pose == open-tall && $shot_name == minimum ]] && continue
			shot=($root/build/duo-screenshots/$pose/$shot_name-*.png(N))
			[[ -n ${shot[1]:-} ]] || { echo "No Duo $pose $shot_name shot" >&2; exit 1 }
			sips -s format jpeg -s formatOptions best $shot[1] --out $work/Duo/Duo-$(printf %02d $index)-$pose-$shot_name.jpg > /dev/null
			(( index++ ))
		done
	done
	replace_set Duo $work/Duo
fi

# Mac: the Mac Catalyst app, always in the grid layout (the list looks empty at this width), a Debug build so it takes
# -screenshotData (the sample library, in a 1440 x 900 window) and
# -debugScreen. Signed with the App Store Connect API key in fastlane/.env, since Xcode has no account signed in.
if wants Mac; then
	echo 'Mac: building…'
	set -a; source $root/fastlane/.env; set +a
	key_path=${~ASC_KEY_PATH}
	mac_derived=$root/fastlane/build/MacDerivedData
	xcodebuild -project $project -scheme $scheme -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath $mac_derived -allowProvisioningUpdates -authenticationKeyPath $key_path -authenticationKeyID $ASC_KEY_ID -authenticationKeyIssuerID $ASC_ISSUER_ID -quiet build
	mac_app=$mac_derived/Build/Products/Debug-maccatalyst/Heart\ Beats.app
	# The app's main window: its id, origin and size in points, found by process, so another copy of the app can't be picked up
	cat > $work/window.swift <<'SWIFT'
import CoreGraphics
let pid = Int(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
// The biggest one: a popover is a window of its own
let main = windows.filter { $0[kCGWindowOwnerPID as String] as? Int == pid && $0[kCGWindowLayer as String] as? Int == 0 }.max { (($0[kCGWindowBounds as String] as? [String: Double])?["Width"] ?? 0) < (($1[kCGWindowBounds as String] as? [String: Double])?["Width"] ?? 0) }
for window in [main].compactMap({ $0 }) {
	let bounds = window[kCGWindowBounds as String] as? [String: Double] ?? [:]
	print(window[kCGWindowNumber as String]!, Int(bounds["X"] ?? 0), Int(bounds["Y"] ?? 0), Int(bounds["Width"] ?? 0), Int(bounds["Height"] ?? 0))
	break
}
SWIFT
	swiftc -O $work/window.swift -o $work/window
	quit_mac_app() { pkill -f "$mac_app/Contents/MacOS/" 2>/dev/null || true; sleep 1 }
	trap 'quit_mac_app; release_device; rm -rf $work' EXIT
	mkdir -p $work/Mac
	index=1
	# Not the minimum: its steppers sit beside it on a Mac, with no popover to show
	for shot in ${shots:#minimum:*}; do
		shot_name=${shot%%:*}
		quit_mac_app
		# No restored window: SwiftUI caps a restored window at its saved size, which would win over the 1440 x 900
		# -minimum 15: the sample minimum, over any this Mac's copy of the app has saved
		open -n $mac_app --args -ApplePersistenceIgnoreState YES -screenshotData YES -minimum 15 ${=shot#*:}
		pid= window=
		for _ in {1..40}; do
			pid=$(pgrep -f "$mac_app/Contents/MacOS/" | head -1 || true)
			[[ -n $pid ]] && window=($($work/window $pid))
			(( ${#window} == 5 )) && break
			sleep 0.5
		done
		(( ${#window} == 5 )) || { echo "  Mac $shot_name: no window" >&2; exit 1 }
		# In front if macOS allows it, so the window is drawn active (it doesn't while you're using another app)
		open $mac_app
		sleep 2
		# Only the app's window, never the screen, so nothing else on screen can end up in it, once it keeps still
		previous=
		for frame_index in {1..30}; do
			frame=$work/mac-$frame_index.png
			screencapture -o -x -l${window[1]} $frame
			[[ -n $previous ]] && cmp -s $previous $frame && break
			previous=$frame
			sleep 0.5
		done
		size=$(sips -g pixelWidth -g pixelHeight $frame | awk '/pixel/{printf "%s ", $2}')
		[[ $size == '2880 1800 ' ]] || { echo "  Mac $shot_name: captured ${size}instead of 2880 x 1800 (a non-Retina display?)" >&2; exit 1 }
		# The window's rounded corners are transparent, and App Store Connect rejects alpha
		magick -quiet $frame -background white -flatten -quality 92 $work/Mac/Mac-$index-$shot_name.jpg
		rm -f $work/mac-*.png(N)
		echo "  Mac-$index-$shot_name.jpg"
		(( index++ ))
	done
	quit_mac_app
	replace_set Mac $work/Mac
fi
echo "Saved in $out"
