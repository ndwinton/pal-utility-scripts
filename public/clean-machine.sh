#!/usr/bin/bash
#
# Just a simple script to wipe clean the home directory
# of a PAL user on a Meerkat.

function confirm() {
	local answer
	
	echo "$*"
	read -p "Type 'ok' to proceed or anything else to quit: " answer
	if [[ $answer != 'ok' ]]
	then
		echo "Aborted."
		exit 1
	fi
}

EXECUTE=true
function execute() {
	echo "-> $*"
	$EXECUTE && "$@"
}

case $1 in
-n)
	EXECUTE=false
	;;
-*)
	echo "Usage: $0 [-n]"
	;;
esac

confirm '>>> WARNING <<<

This script will remove the contents of ~/workspace,
a number of hidden configuration files and other data
potentially left over from a PAL course.
'

cd $HOME
case $PWD in
*/pal_user|*/pal-user|*/paluser)
	;;
*)
	confirm "The current home directory ($PWD) doesn't seem to be a PAL user directory."
	;;
esac

echo "Removing files and directories ..."
	
for f in \
	.aws \
	.cache/google-chrome/* \
	.cache/mozilla/* \
	.cf \
	.config/google-chrome \
	.gitconfig \
	.gradle \
	.idea \
	.minio \
	.ssh/* \
	shared \
	workspace/*
do
	execute rm -rf $f
done

echo 'Fixing .bashrc'
execute sed -i -e '/^source.*workspace.*\.env$/d' ~/.bashrc

echo 'Clearing history'
execute cp /dev/null ~/.bash_history
