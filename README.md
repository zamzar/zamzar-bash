# Introduction

This repository provides a simple Bash Command Line program (**zamzar.sh**) for using the REST-based [Zamzar file conversion API](https://developers.zamzar.com). It has been tested on OSX but should also work with cygwin (on Windows) and Linux since it uses standard Bash conventions.

You will need to have [cURL installed](http://curl.haxx.se/download.html) on your system to use this script.

If you find any issues please raise them against this repository, since it is monitored by the Zamzar development team. We welcome pull requests and suggestions for improvements. The code in this repository is MIT licensed.

# Installation

* Signup for a Zamzar API account at [https://developers.zamzar.com/pricing](https://developers.zamzar.com/pricing)

* Clone this repository:
 
        git clone git@github.com:zamzar/zamzar-bash.git
             
    **OR** if you don't have git you can just download the script from [https://github.com/zamzar/zamzar-bash/raw/master/zamzar.sh](https://github.com/zamzar/zamzar-bash/raw/master/zamzar.sh) - don't forget to make it executable by running `chmod +x zamzar.sh` from your shell.
               
* Edit your local copy of zamzar.sh to update it with your API key, replacing `FOO` (your key is available from [your account page](https://developers.zamzar.com/user)):

        KEY='foo' # Your API key - CHANGE THIS 

* Make sure you have [cURL installed](http://curl.haxx.se/download.html) locally.    

# Usage

* To find out what "to" formats are available for conversion for a given input file:

        ./zamzar.sh ~/portrait.jpg

	… should output:
	
        - bmp (1 credits)
        - gif (1 credits)
        - ico (1 credits)
        - pcx (1 credits)
        - pdf (1 credits)
        - png (1 credits)        
        - ps (1 credits)
        - tga (1 credits)
        - thumbnail (1 credits)
        - tiff (1 credits)
        - wbmp (1 credits)
        - webp (1 credits)

* To convert a file into a different format and automatically download and save it to your **current working directory** with the same name and the file extension of the converted format:

        ./zamzar.sh ~/portrait.jpg png

	… should output:

        Job 313 is successful
        Downloading converted file(s) for job 313
        Converted file (id #2870) saved to: portrait.png
	
* To convert a file into a different format and automatically download and save it to **a different directory**:

        ./zamzar.sh ~/portrait.jpg png ~/Downloads/

* To print out the version of the script being used:

        ./zamzar.sh -v

* To run a conversion in "debug" mode (useful for examining the cURL commands being run under the covers):

        ./zamzar.sh -d ~/portrait.jpg png

# Further Reading

If you want to browse all the formats you can convert "from" and "to" using the Zamzar API then check out [https://developers.zamzar.com/formats](https://developers.zamzar.com/formats)

If you want to extend this script to perform more advanced functions why not take a look at our [comprehensive documentation](https://developers.zamzar.com/docs) which gives information on other operations and endpoints available in the API.
