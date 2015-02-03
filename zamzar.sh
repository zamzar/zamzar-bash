#!/bin/bash

#############################################
# The MIT License (MIT)
# 
# Copyright (c) 2015 Zamzar Ltd
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# 
#############################################

#############################################
# USAGE:
#   Convert a file: 
#     zamzar.sh ~/portrait.jpg png
#   Convert a file specifying a different output directory: 
#     zamzar.sh ~/portrait.jpg png ~/Downloads/
#   List available target formats:
#     zamzar.sh ~/portrait.jpg
#   Run in debug mode:
#     zamzar.sh -d ~/portrait.jpg png
#############################################


#############################################
# Variables used for accessing the Zamzar API
#############################################
KEY='foo'        # Your API key - CHANGE THIS
SERVER='sandbox' # sandbox or api - CHANGE THIS IF YOU WANT TO USE THE LIVE ENVIRONMENT
API_VERSION='v1' # API version to use - THIS SHOULD CHANGE RARELY
#############################################

#############################################
# Functions 
#############################################

# Script name
scriptname=`basename $0`

# Prints version
function version {
  echo 1>&2 "$scriptname: version 1.0.0"
}

# Prints usage information
function usage {
  echo 1>&2 "$scriptname: expected 1 to 4 arguments but received $#"
  echo "Usage:"
  echo "  $scriptname -v                                      -- prints the version of this script"
  echo "  $scriptname [-d] inputFile                          -- list the possible formats to which this file can be converted"
  echo "  $scriptname [-d] inputFile targetFormat [outputDir] -- convert the input file into the specified target format"
  exit 2
}


# Prints the list of possible target formats for an input file
function listFormats {
  # Extract extension of argument to determine format
  format="${1##*.}"
  
  # Query Zamzar to determine possible target formats
  apiCall "formats/$format --silent"

  # Extract target formats and credit costs
  targets_and_costs=`
    echo $api_response |
    sed -e "s/.*\"targets\":\[\(.*\)\]/\\1/g" | # Extract the value of the targets array
    sed -e "s/}}$//g" | # Strip off trailing brackets to avoid excess newlines
    tr '}' '\n' | # Split each target format onto a new line
    sed -e "s/,*{\"name\"://g" | # Remove JSON from first part of line
    sed -e "s/,\"credit_cost\"://g" | # Remove JSON from middle of line
    sed -e "s/^\"//g" | # Remove first speech mark around name of format
    sed -e "s/\"/ \(/g" # Replace last speech mark with a space and a paren
  `

  # iterate over each line and print it out
  echo "$1 can be converted to the following formats: "
  while read -r line
  do
    echo " - $line credits)"
  done <<< "$targets_and_costs"
}


# Converts the first argument to a file with the name of the second argument
function convert {
  # Ensure that the source file exists
  if [ ! -f "$1" ]
  then
    echo "$scriptname: $1: No such file"
    exit 1
  fi
  
  # Extract extension of second argument to determine target format
  target_format="${2##*.}" 

  # Turn off the internal field separator as filenames can contain
  # *any* character, and so Bash must not perform fancy substitution
  # on anything!
  IFS=""
  
  # Submit the job to Zamzar
  apiCall "jobs -X POST -F \"source_file=@$1\" -F \"target_format=$target_format\" --silent"
  
  # Extract identifier of current job
  id=`echo $api_response | sed -e "s/^{\"id\":\([0-9]*\).*/\1/g"`
  status=`echo $api_response | sed -e "s/.*\"status\":\"\([^\"]*\)\".*/\1/g"`
  
  # Poll until job is finished
  until [[ $status == "successful" ]]; do
    sleep 1
    apiCall "jobs/$id --silent"
    status=`echo $api_response | sed -e "s/.*\"status\":\"\([^\"]*\)\".*/\1/g"`
    
    if [[ $status == "failed" ]]; then
      echo "Job $id has failed for an unknown reason. For support, contact Zamzar at https://developers.zamzar.com/support"
      exit 1
    else
      echo "Job $id is $status"
    fi
  done

  echo "Downloading converted file(s) for job $id"

  # Obtain the list of files created by the conversion job
  # splitting each file onto a new line
  target_files=`
    echo $api_response |
    sed -e "s/.*\"target_files\":\(\[.*\]\).*/\1/g" |
    tr "}" "\n" |
    sed '$d'
  `
  
  # Set the internal field separator so that the following
  # loop splits the target_files variable by newline
  IFS="\n"
  
  # Download all files
  while read -r target_file
  do
    # Turn off the internal field separator as filenames can contain
    # *any* character, and so Bash must not perform fancy substitution
    # on anything!
    IFS=""
    
    # Extract ID and target filename for the current file
    id=`echo $target_file | sed -e "s/.*{\"id\":\([0-9]*\).*/\1/g"`
    target_file_name=`echo $target_file | sed -e "s/.*\"name\":\"\([^\"]*\)\".*/\1/g"`

    # Download the current file
    download "$id" "$target_file_name" "$3"
  done <<< "$target_files"
}


# Downloads a file with the specified ID to the specified location on disk
function download {
  # Compute target path from target file name ($2) and target directory ($3)
  if [[ -n $3 ]] && [[ $3 != "" ]]; then
    case $3 in
      */) target="$3$2";;   # target directory with a slash => concat($3, $2)
      *)  target="$3/$2";;  # target directory without slash => concat($3, "/", $2)
    esac
  else
    target="$2"             # no target directory => $2
  fi
  
  # Request the file content and save it to the target path
  apiCallWithRedirect "files/$1/content --silent" "$target"
  echo "Converted file (id #$1) saved to: $target"
}


# Makes a call to the Zamzar API and reports any errors
function apiCall {
  api_request="curl -L https://$SERVER.zamzar.com/$API_VERSION/$1 -u $KEY:"
  api_response=`eval ${api_request}`
  
  if [[ $MODE == "debug" ]]; then
    echo "DEBUG >>> $api_request"
    echo "DEBUG <<< $api_response"
  fi

  # Check to see if any errors were encountered
  if [[ `echo $api_response` == *"errors"* ]]; then
    # If so, print and exit
    echo "Error(s) were encountered whilst issuing an API request."
    echo "  Request: $api_request"
    echo "  Errors:"
    echo "    $api_response"
    exit 1 
  fi
}


# Makes a basic call to the Zamzar API, and redirects output to file
function apiCallWithRedirect {
  api_request="curl -L https://$SERVER.zamzar.com/$API_VERSION/$1 -u $KEY:"
  `eval ${api_request} > "$2"`
}

#############################################
# Main 
#############################################

# Handle arguments to determine which function to run
if [ $# -eq 1 ] && [[ $1 == "-v" ]]; then
  version
elif [ $# -gt 0 ]; then
  
  if [[ $1 == "-d" ]]; then
    MODE="debug"
    
    if [ $# -eq 2 ]; then
      listFormats "$2"
    elif [ $# -eq 3 ] || [ $# -eq 4 ]; then
      convert "$2" "$3" "$4"
    else
      usage
    fi
  else
    if [ $# -eq 1 ]; then
      listFormats "$1"
    elif [ $# -eq 2 ] || [ $# -eq 3 ]; then
      convert "$1" "$2" "$3"
    else
      usage
    fi
  fi
else
  usage
fi
