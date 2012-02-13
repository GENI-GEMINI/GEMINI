#!/bin/bash

MAKEROOT=""
if [[ $EUID -ne 0 ]];
then
	MAKEROOT="sudo"
fi

for i in `cat ../dependencies`
do
	NAME=`echo $i | awk '{ split($0, a, ",");print a[1] }'`
	VER=`echo $i | awk '{ split($0, a, ",");print a[2] }'`

	if [ -z $VER ];
	then
		echo "Checking for $NAME..."
	else
		echo "Checking for version $VER of $NAME..."
	fi

	typeset -x LIBRARY=$NAME
	VERSION=`perl -e 'my $module = $ENV{LIBRARY};eval "require $module";print $module->VERSION unless ( $@ );'`

	if [ -z $VERSION ];
	then
		echo "Upgrading $NAME"
		$MAKEROOT cpan $NAME
	else
		if [ -z $VER ];
		then
			echo "Upgrading $NAME from $VERSION..."
			$MAKEROOT cpan $NAME
		else
			if [[ $VERSION < $VER ]];
			then
				echo "Upgrading $NAME from $VERSION..."
				$MAKEROOT cpan $NAME
			else
				echo "$NAME is not being upgraded, version $VERSION is installed." 
			fi
		fi
	fi
done

echo "Exiting install_dependencies.sh"

