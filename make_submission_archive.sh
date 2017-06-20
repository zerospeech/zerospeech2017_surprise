#!/bin/bash
#
# Copyright 2017 Mathieu Bernard, Julien Karadayi
#
# You can redistribute this file and/or modify it under the terms of
# the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.


# TODO compare the names of *.fea files with expected name from the
# datasets.


#
# Some usefull macros and functions
#

function usage {
    echo "Usage: $0 results_directory"
    echo
    echo "Check if a directory is correctly formatted and ready for the Zero"
    echo "Speech Challenge 2017 evaluation. If checked, compress the directory"
    echo "as a tar.gz archive. Otherwise display a list of detected errors."
    echo "See https://github.com/bootphon/zerospeech2017_surprise#results-directory-format for details."
    exit 0
}

# the different languages of the ERC 2017
languages="english french mandarin LANG1 LANG2"

# called on check errors, push message to $failed
function error { failed="$failed\nerror: $1"; echo "error"; }

# called on warnings, push message to $warned
function warning { warned="$warned\nwarning: $1"; echo "$1"; }

# we can have several READMEs, whatever the extension they have. We
# expect at least one but no one can be empty.
function check_readme {
    echo -n "checking $1 README... "
    readme=$(find $1 -maxdepth 1 -type f -name "README*")

    [ -z "$readme" ] && error "No README in $1" && return 1

    for r in $readme; do
        [ ! -s $r ] && error "$r is empty" && return 1
    done

    echo "found $readme"
}


#
# basic argument parser
#

[ ! $# -eq 1 ] && usage
[[ $1 == "-h" || $1 == "-help" || $1 == "--help" ]] && usage
[ ! -d $1 ] && echo "$1 is not a directory" && exit 1
results_dir=${1%/}  # remove any trailing slash


#
# check the root directory
#

# we want only 2 or 3 subdirs: system, track1 and/or track2. Nothing else.
echo -n "checking $results_dir directory..."
undesirable=$(find $results_dir -mindepth 1 -maxdepth 1 \
                   ! -name system ! -name track1 ! -name track2 \
                   -exec basename {} \; | xargs)

[ -z "$undesirable" ] && echo "done" \
    || error "undesirable content in ${results_dir}: $undesirable"


#
# check the system directory
#

system=$results_dir/system
echo -n "checking $system... "
if [ -d $system ]
then
    echo "found"
    check_readme $system
else
    error "$system is not a directory"
fi


#
# check the track1 and track2 directories
#

echo -n "checking $results_dir/{track1, track2} directories... "

[ -d "$results_dir/track1" -o -d "$results_dir/track2" ] || \
    error "expect track1 and/or track2 subdirectories"

for t in track1 track2
do
    [ -d $results_dir/$t ] && tracks="$tracks $t"
done
tracks=$(echo $tracks | xargs)  # strip $tracks
echo "found $tracks"


# track1: assert we have {$languages}/{1s, 10s, 120s}/*.fea, at least
# one lang, nothing else.
if [ -d "$results_dir/track1" ]
then
    echo -n "checking $results_dir/track1 directory... "
    undesirable=$(find $results_dir/track1 -mindepth 1 -maxdepth 1 \
                       ! -name english ! -name french ! -name mandarin \
                       ! -name LANG1 ! -name LANG2 ! -name README* \
                       -exec basename {} \; | xargs)

    [ -z "$undesirable" ] && echo "done" \
            || error "undesirable content in ${results_dir/track1}: $undesirable"


    check_readme $results_dir/track1
    ntrack1=0

    for lang in $languages
    do
        dir=$results_dir/track1/$lang
        [ ! -d $dir ] && warning "$dir is not a directory" > /dev/null && continue

        undesirable=$(find $dir -mindepth 1 -maxdepth 1 \
                           ! -name 1s ! -name 10s ! -name 120s \
                           -exec basename {} \; | xargs)

        [ ! -z "$undesirable" ] && error "undesirable content in $dir: $undesirable" > /dev/null


        ntrack1=$((ntrack1+1))

        for d in 1s 10s 120s
        do
            echo -n "checking $dir/$d... "
            [ ! -d "$dir/$d" ] && error "$dir/$d not a directory" && continue

            n_fea_files=$(find $dir/$d -type f -name "*.fea" | wc -l)
            [ $n_fea_files -eq 0 ] \
                && error "no *.fea files in $dir/$d" \
                    || echo "found $n_fea_files features files"

            undesirable=$(find $dir/$d -mindepth 1 -maxdepth 1 \
                               ! -name "*.fea" -exec basename {} \; | xargs)
            [ ! -z "$undesirable" ] \
                && error "undesirable content in $dir/$d: $undesirable" > /dev/null
        done
    done

    [ $ntrack1 -eq 0 ] && error "no result file found in $results_dir/track1"
fi


# track2: assert we have {english, french, mandarin, surprise1,
# surprise2}.txt (at least one file)
if [ -d $results_dir/track2 ]
then
    echo -n "checking $results_dir/track2 directory... "
    undesirable=$(find $results_dir/track2 -mindepth 1 -maxdepth 1 \
                       ! -name english.txt ! -name french.txt ! -name mandarin.txt \
                       ! -name LANG1.txt ! -name LANG2.txt ! -name "README*" \
                       -exec basename {} \; | xargs)

    [ -z "$undesirable" ] && echo "done" \
            || error "undesirable content in $results_dir/track2: $undesirable"


    check_readme $results_dir/track2
    ntrack2=0

    for name in $languages
    do
        cluster=$results_dir/track2/$name.txt
        echo -n "checking $cluster... "
        if [ -f $cluster ]
        then
            echo "found"
            ntrack2=$((ntrack2+1))
        else
            warning "$cluster file not found"
        fi
    done

    [ $ntrack2 -eq 0 ] && error "no result file found in $results_dir/track2"
fi


#
# End of the checks. Display warnings, errors, create the tar.gz
# archive.
#

# report detected warnings (if any)
[ ! -z "$warned" ] && \
    echo -e "The following WARNINGS have been detected," \
         "make sure this is all ok:$warned"

# report detected errors and exit (if any)
[ ! -z "$failed" ] && \
    echo -e "The following ERRORS have been detected," \
         "please correct them and run this script again:$failed" && \
    exit 1

echo "SUCCESS $results_dir directory is valid and ready for evaluation"

echo -n "creating $results_dir.tar.gz... "
rm -f $results_dir.tar.gz
tar czf $results_dir.tar.gz $results_dir
echo "done"

for path in "$results_dir" "$results_dir.tar.gz"
do
    echo -e "size of $path:\t"$(du -hs $path | awk '{print $1}')
done


exit 0
