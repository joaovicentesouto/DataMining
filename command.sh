#!/bin/bash

# MIT License
#
# Copyright(c) 2019-2019 João Vicente Souto
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

#===============================================================================
# Global Variables
#===============================================================================

export VENV=venv
export RAW_DATA=raw_data
export PREPROCESSED_DATA=preprocessed_data

export HOME=$(pwd)/$VENV

#===============================================================================
# Python Options
#===============================================================================

# Plot data.
function plot()
{
	echo "It is not implemented yet."
}

# Run experiments
function run()
{
	echo "It is not implemented yet."
}

# Build a model to submit
function model()
{
	echo "It is not implemented yet."
}

#===============================================================================
# Kaggle Options
#===============================================================================

# Download raw data from kaggle plataform.
function download()
{
	source $HOME/bin/activate

	mkdir -p $RAW_DATA
	cd $RAW_DATA
	kaggle competitions download -c data-mining-class-ufsc-20192

	echo "Download finished!"
}

# Submmit a model to the competition.
function submit()
{
	echo "It is not implemented yet."
}

# Setup environment.
function setup()
{
	kaggle_key=$1

	# Setup is ok?
	if prerequisites;
	then
		echo "Setup is already complete!"
		exit 1;
	fi

	# Missing pip?
	if [ command -v pip3 >/dev/null 2>&1 ];
	then
		echo "[setup] pip3 is unavailable!"
		exit 1
	fi

	# Missing virtualenv?
	if [ command -v virtualenv >/dev/null 2>&1 ];
	then
		echo "[setup] virtualenv is unavailable, run: sudo pip3 install virtualenv!"
		exit 1
	fi

	# Wrong kaggle key specified.
	if [[ ! $kaggle_key == *kaggle\.json ]]; 
	then
		echo "kaggle key path not specified! $1"; 
		exit 1
	fi

	# Create environment
	virtualenv -p python3 $VENV
	source $HOME/bin/activate

	# Install requirements
	pip3 install -r requirements.txt

	# Configure kaggle
	mkdir $HOME/.kaggle
	cp $kaggle_key $HOME/.kaggle/kaggle.json
	chmod 600 $HOME/.kaggle/kaggle.json

	# Exit
	echo "Setup successfully complete!"
}

# Prerequisites to run kaggle commands.
function prerequisites()
{
	# Missing virtual environment?
	if [ ! -d $HOME ];
	then
		echo "[prerequisites] Virtual Environment not setup!"
		return 1
	fi

	# Missing kaggle?
	if [ command -v kaggle >/dev/null 2>&1 ];
	then
		echo "[prerequisites] Kaggle is unavailable, run bash scripts.sh setup FILEPATH/kaggle.json!"
		return 1
	fi

	# Missing kaggle key?
	if [ ! -f $HOME/.kaggle/kaggle.json ];
	then
		echo "[prerequisites] Kaggle key path not exists, please configure kaggle first!!"
		return 1
	fi

	return 0
}

case $1 in
    plot|run|model)
		echo "I will call but $1() is not implemented."
		;;

	download|submit)
		if ! prerequisites;
		then
			exit 1; # error
		fi
		;;

	setup)
		if prerequisites;
		then
			echo "Setup already complete."
			exit 0 # ok
		fi
		;;

	# Every else.
    *)
		echo "Function $1() not defined."
		exit 1 # error
		;;
esac

# Call function passing its arguments.
"$@"