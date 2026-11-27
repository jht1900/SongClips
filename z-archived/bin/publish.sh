#!/bin/bash
cd ${0%/*}
remote_user=secure
host=mobilesiteclone.net
server="$remote_user@$host://home/secure/htdocs/songclips/dist"
dev="../dist"
test=

while [[ $# > 0 ]]; do
key="$1"
case $key in
	--test)
	test=--dry-run
	echo $test
	shift
	;;
	*)
	# unknown option
	area=$1
	shift
    ;;
esac
done

xfrom="$dev"
xto="$server"
if [ "$direction" == "--from" ]; then
	xfrom="$server"
	xto="$dev"
fi
xfrom="$xfrom/$area_from"
xto="$xto/$area_to"

echo
echo "Syncing from $xfrom"
echo "          to $xto"
echo
#uncomment this to do a dry run (no changes)
#DEBUG="--dry-run"

rsync -razv --delete $test --exclude ".DS_Store" "$xfrom/"  "$xto/"

