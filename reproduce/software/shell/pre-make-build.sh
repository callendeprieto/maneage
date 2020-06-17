#!/bin/sh
#
# Very basic tools necessary to start Maneage's default building.
#
# Copyright (C) 2020 Mohammad Akhlaghi <mohammad@akhlaghi.org>
#
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this script.  If not, see <http://www.gnu.org/licenses/>.





# Script settings
# ---------------
# Stop the script if there are any errors.
set -e





# Input arguments.
bdir=$1
ddir=$2
downloader="$3"





# Basic directories/files
topdir=$(pwd)
sdir=$bdir/software
tardir=$sdir/tarballs
instdir=$sdir/installed
tmpblddir=$sdir/build-tmp
confdir=reproduce/software/config
ibidir=$instdir/version-info/proglib
downloadwrapper=reproduce/analysis/bash/download-multi-try

# Derived directories
bindir=$instdir/bin
versionsfile=$confdir/versions.conf
checksumsfile=$confdir/checksums.conf
backupfile=$confdir/servers-backup.conf




# Set the system to first look into our newly installed programs.
export PATH="$bindir:$PATH"





# Load the backup servers
backupservers=$(awk '!/^#/{printf "%s ", $1}' $backupfile)





# Download the necessary tarball.
download_tarball() {
  # Basic definitions
  maneagetar=$tardir/$tarball

  # See if the tarball already exists in Maneage.
  if [ -f "$maneagetar" ]; then
    just_a_place_holder=1
  else
    ucname=$tardir/$tarball.unchecked

    # See if it is in the input software directory.
    if [ -f "$ddir/$tarball" ]; then
      cp $ddir/$tarball $ucname
    else
      $downloadwrapper "$downloader" nolock $url/$tarball $ucname \
                       "$backupservers"
    fi

    # Make sure this is the correct tarball.
    if type sha512sum > /dev/null 2> /dev/null; then
      checksum=$(sha512sum "$ucname" | awk '{print $1}')
      expectedchecksum=$(awk '/^'$progname'-checksum/{print $3}' $checksumsfile)
      if [ x$checksum = x$expectedchecksum ]; then mv "$ucname" "$maneagetar"
      else
        echo "ERROR: Non-matching checksum for '$tarball'."
        echo "Checksum should be: $expectedchecksum"
        echo "Checksum is:        $checksum"
        exit 1
      fi;
    else mv "$ucname" "$maneagetar"
    fi
  fi

  # If the tarball is newer than the (possibly existing) program (the version
  # has changed), then delete the program.
  if [ -f $ibidir/$progname ]; then
      if [ $maneagetar -nt $ibidir/$progname ]; then
          rm $ibidir/$progname
      fi
  fi
}





# Build the program from the tarball
build_program() {
  if ! [ -f $ibidir/$progname ]; then

    # Go into the temporary building directory.
    cd $tmpblddir
    unpackdir="$progname"-"$version"

    # Some implementations of 'tar' don't recognize Lzip, so we need to
    # manually call Lzip first, then call tar afterwards.
    csuffix=$(echo $tarball | sed -e's/\./ /g' | awk '{print $NF}')
    rm -rf $unpackdir
    if [ x$csuffix = xlz ]; then
      intarrm=1
      intar=$(echo $tarball | sed -e's/.lz//')
      lzip -c -d $tardir/$tarball > $intar
    else
      intarrm=0
      intar=$tardir/$tarball
    fi

    # Unpack the tarball and build the program.
    tar xf $intar
    if [ x$intarrm = x1 ]; then rm $intar; fi
    cd $unpackdir
    ./configure --prefix=$instdir
    make
    make install
    cd $topdir
    rm -rf $tmpblddir/$unpackdir
    echo "$progname_tex $version" > $ibidir/$progname
  fi
}





# Lzip
# ----
#
# Lzip is a compression program that is the first built program in Maneage
# because the sources of all other programs (including other compression
# softwaer) are compressed. Lzip has the advantage that it is very small
# (without compression it is just ~400Kb). So we use its '.tar' file and
# won't rely on the host's compression tools at all.
progname="lzip"
progname_tex="Lzip"
url=http://akhlaghi.org/src
version=$(awk '/^'$progname'-version/{print $3}' $versionsfile)
tarball=$progname-$version.tar
download_tarball
build_program





# GNU Make
# --------
#
# The job orchestrator of Maneage is GNU Make. Although it is not
# impossible to account for all the differences between various Make
# implementations, its much easier (for reading the code and
# writing/debugging it) if we can count on a special implementation. So
# before going into the complex job orchestration in building high-level
# software, we start by building GNU Make.
progname="make"
progname_tex="GNU Make"
url=http://akhlaghi.org/src
version=$(awk '/^'$progname'-version/{print $3}' $versionsfile)
tarball=$progname-$version.tar.lz
download_tarball
build_program





# Dash
# ----
#
# Dash is a shell (http://gondor.apana.org.au/~herbert/dash). Having it in
# this phase will allow us to have a fixed/identical shell for 'basic.mk'
# (which builds GNU Bash).
progname="dash"
progname_tex="Dash"
url=http://akhlaghi.org/src
version=$(awk '/^'$progname'-version/{print $3}' $versionsfile)
tarball=$progname-$version.tar.lz
download_tarball
build_program

# If the 'sh' symbolic link isn't set yet, set it to point to Dash.
if [ -f $bindir/sh ]; then just_a_place_holder=1
else ln -sf $bindir/dash $bindir/sh;
fi





# Flock
# -----
#
# Flock (or file-lock) is necessary to serialize operations when
# necessary. GNU/Linux machines have it as part of their `util-linux'
# programs. But to be consistent in non-GNU/Linux systems, we will be using
# our own build.
#
# The reason that `flock' is built here is that generally the building of
# software is done in parallel, but we need it to serialize the download
# process of the software tarballs to avoid network complications when too
# many simultaneous download commands are called.
progname="flock"
progname_tex="Discoteq flock"
url=http://akhlaghi.org/src
version=$(awk '/^'$progname'-version/{print $3}' $versionsfile)
tarball=$progname-$version.tar.lz
download_tarball
build_program





# Finish this script successfully
exit 0