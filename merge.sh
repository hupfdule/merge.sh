#!/bin/sh

# Synopsis:
# merge.sh <source> <target>
#
# List all files that are
#   - only exist in <source>, but not in <target>
#   - exactly the same in <source> and <target>
#   - exist in both <source and <target>, but are different in both hierarchies
# Be aware that files, that exist in <target>, but not in <source> are
# /not/ listed!
#
# The results are written to three files: missingfile, duplicatefile and
# differentfile, respectively.
#
# At the moment this utility does not support deletion, moving and renaming of files,
# but all it does is writing its information into the above mentioned files.
#
# This tool always works recursively.
# It only processes regular files. Directories and empty files are ignored.
# It uses the external tools 'find', 'sed' and 'md5sum' for doing its work.
# Its implementation is not efficient. Therefore it is likely much slower than
# other tools like rdfind, fdupes or jdupes.
#
# The information gathered by this tool can be used to
#   - Delete files from 'source' that exist in 'target'
#   - Move files from 'source' that are fully missing in 'target'
#   - Move files from 'source' to 'target' that exist, but differ
#     in both. This needs a rename of the moved file.

# TODO check cmdline args
#      - number of arguments
#      - type of arguments (must be directories)
#      - possible options
# TODO write logs (debug, info, error)

debug=0

replace() {
  echo $(echo $1 | sed "s|${2}|${3}|")
}

process() {
  sourcefile="${2}/${1}"
  targetfile="${3}/${1}"

  # only process regular files
  if [ ! -f "${sourcefile}" ]; then
    debug "${sourcefile} is not a regular file. Ignoring it."
    return
  fi

  #TODO: We could provide other actions
  if [ ! -f "${targetfile}" ]; then
    debug "${targetfile} does not exist. Should we /move/ it?"
    echo "${sourcefile}" >> missingfile
    return
  fi

  sourcefile_size=$(wc -c <"$sourcefile")
  targetfile_size=$(wc -c <"$targetfile")

  if [ "$sourcefile_size" -ne "$targetfile_size" ]; then
    debug "${sourcefile} has different size than its counterpart. Not doing anything with it."
    echo "${sourcefile}" >> differentfile
    return
  fi

  if [ "$sourcefile_size" -eq 0 ]; then
    debug "${sourcefile} has zero length. Ignoring it."
    return
  fi

  sourcefile_md5=$(md5sum "${sourcefile}" | cut -d" " -f1)
  targetfile_md5=$(md5sum "${targetfile}" | cut -d" " -f1)
  #debug "${sourcefile_md5}  ${targetfile_md5}"

  if [ "${sourcefile_md5}" != "${targetfile_md5}" ]; then
    debug "${sourcefile} has different MD5 hash as its counterpart. Ignoring it."
    echo "${sourcefile}" >> differentfile
    return
  fi

  # FIXME: Do another check?
  debug "${sourcefile} has same MD5 hash as its counterpart. It can be deleted."
  echo "${sourcefile}" >> duplicatefile
}

debug() {
  if [ "$debug" -ne 0 ]; then
    echo "DEBUG: ${1}"
  fi
}

# TODO Check parameters and print usage if incorrect

source=$1
target=$2

cwd=$(pwd)
cd "$source"
source_abs=$(replace "$(pwd)" "/*$" "")
cd "$cwd"
cd "$target"
target_abs=$(replace "$(pwd)" "/*$" "")

echo "Comparing ${source_abs} with ${target_abs}"

cd "$cwd"

# clear any existing result files
> missingfile
> duplicatefile
> differentfile

find "$source_abs" -type f | while read -r f; do
  f_rel=$(replace "$f" "$source_abs" "")
  f_rel=$(replace "$f_rel" "^/*" "")
  process "${f_rel}" "${source_abs}" "${target_abs}"
done
