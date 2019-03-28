#!/bin/sh
#==========
# Script to automatically generate a human-readable diff between
#  two different package manifest files
#==========

showusage(){
  echo "Usage:"
  echo "generatediff.sh <old_manifest> <new_manifest> <output_file>"
}

pkgNameFromLine(){
  local _file_ver=$(echo "$1" | tr -dc ':' | wc -m | cut -w -f 2)
  #Note this sets the internal ${_pkg} variable
  if [ ${_file_ver} -eq 1 ] ; then
    _pkg=`echo "$1" | cut -w -f 1`
  elif [ ${_file_ver} -eq 2 ] ; then
    _pkg=`echo "$1" | cut -w -f 3`
  fi
  return 0
}

pkgVersionFromLine(){
  local _file_ver=$(echo "$1" | tr -dc ':' | wc -m | cut -w -f 2)
  #Note this sets the internal ${_version} variable
  if [ ${_file_ver} -eq 1 ] ; then
    _pkg=`echo "$1" | cut -w -f 3`
  elif [ ${_file_ver} -eq 2 ] ; then
    _pkg=`echo "$1" | cut -w -f 5`
  fi
  return 0
}

sameVersions(){
  #Input 1 is the pkg version to trim
  _tmp1=`echo $1 | rev | cut -d _ -f2- | rev`
  _tmp2=`echo $2 | rev | cut -d _ -f2- | rev`
  if [ "${_tmp1}" = "${_tmp2}" ] ; then
    return 0
  else
    return 1
  fi
}

findInFile(){
  #Inputs: 1: package name 2: file to search
  # It sets the "_line" variable as the output
  _line=`grep -e "\\b${1}\\b" "${2}" | head -1`
}

insertHeaderLine(){
  #Inputs: 1: temporary file name
  # Uses: $difffile, $rem_file, $up_file, $add_file
  _file="$1"
  _header=$2
  pkg_count=`wc -l "${_file}" | cut -w -f 2`
  if [ -n "${_header}" ] ; then
    msg="### "
  else
    msg="* "
  fi
  #Label the section
  if [ "${_file}" = "${add_file}" ] ; then
    echo "${msg}New Packages (${pkg_count}):" >> "${difffile}"
  elif [ "${_file}" = "${rem_file}" ] ; then
    echo "${msg}Removed Packages (${pkg_count}):" >> "${difffile}"
  elif [ "${_file}" = "${up_file}" ] ; then
    echo "${msg}Updated Packages (${pkg_count}):" >> "${difffile}"
  fi
}

oldfile=$1
newfile=$2
difffile=$3

if [ -z "$oldfile" ] || [ -z "$newfile" ] || [ -z "$difffile" ] ; then
  showusage
  exit 1
fi

#Setup the temporary files
rem_file=".pkg_removed"
up_file=".pkg_updated"
add_file=".pkg_added"


echo "Loop over old packages..."
while read i
do
  pkgNameFromLine "${i}"
  pkgVersionFromLine "${i}"
  _oldver="${_version}"
  #echo "Package: ${i}"
  #echo "   ${_pkg}  ---- ${_version}"
  findInFile "${_pkg}" "${newfile}"
  if [ -z "${_line}" ] ; then
    #Deleted package - not in new file
    echo "* ${_pkg}" >> ${rem_file}
  else 
    pkgVersionFromLine "${_line}"
    sameVersions "${_oldver}" "${_version}"
    if [ $? -eq 0 ] ; then
      #Version unchanged
      #echo "Unchanged: ${_pkg}"
    else
      #Version changed
      echo "* ${_pkg} : ${_oldver} -> ${_version}" >> "${up_file}"
    fi
  fi
done < "${oldfile}"

echo "Looping over new packages..."
while read i
do
  pkgNameFromLine "${i}"
  pkgVersionFromLine "${i}"
  findInFile "${_pkg}" "${oldfile}"
  if [ -z "${_line}" ] ; then
    #New package (not in old repo)
    echo "* ${_pkg} : ${_version}" >> "${add_file}"
  fi
done < "${newfile}"

echo "Assemble output file"
if [ -e "${difffile}" ] ; then
  rm "${difffile}"
fi

# Add the summary section to the top of the diff
echo '## Summary of changes' >> "${difffile}"
for file in ${add_file} ${rem_file} ${up_file}
do
  if [ ! -e "${file}" ] ; then continue; fi
  insertHeaderLine "${file}"
done

#Now add the detailed sections
for file in ${add_file} ${rem_file} ${up_file}
do
  if [ ! -e "${file}" ] ; then continue; fi
  #Add a section break if needed
  if [ -e "${difffile}" ] ; then
    echo "
" >> "${difffile}"
  fi
  insertHeaderLine ${file} true
  #Dump to the diff file and remove the temporary one
  cat "${file}" >> "${difffile}"
  rm "${file}"
done

exit 0
