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
export RAW_DATA=raw
export PREPROCESSED_DATA=preprocessed
export SUBMISSION_DATA=submission
export MODELS=models

export TRAIN_FILE=$PREPROCESSED_DATA/train-data.arff
export TEST_FILE=$PREPROCESSED_DATA/test-data.arff
export SUBMIT_FILE=$SUBMISSION_DATA/submission.csv

export HOME=$(pwd)/$VENV

export WEKA="java -classpath weka.jar"

#===============================================================================
# Weka Operations
#===============================================================================

function build_model() # (model_parameters, train_data, output_model)
{
	${WEKA} $1 -t $2 -d $3
}

function classify() # (model, train_data, unlabeled_data, output_classification)
{
	# Header
	echo "\"Id\",\"Genres\"" > $4

	# Data
	${WEKA} weka.classifiers.misc.InputMappedClassifier -L $1 -t $2 -T $3        \
		-classifications weka.classifiers.evaluation.output.prediction.PlainText \
	| grep "?"                                                                   \
	| sed -e "s/:/ /g"                                                           \
	| awk '{print "\""($1 - 1) "\",\"" $4 "\""}'                                 \
	>> $4
}

#===============================================================================
# Running Operations
#===============================================================================

# Run experiments
function prepare()
{
	echo "Preparing..."

	mkdir -p $PREPROCESSED_DATA
	mkdir -p $SUBMISSION_DATA

	# Appends genre to the header
	cat $RAW_DATA/genresTest.csv \
		| grep "PAR_3RMS_TCD_10FR_VAR" \
		| sed  -e "s/\"PAR_3RMS_TCD_10FR_VAR\"/\"PAR_3RMS_TCD_10FR_VAR\",\"GENRE\"/g" \
		> $PREPROCESSED_DATA/genresTest.csv

	# Make test data to unlabeled data
	cat $RAW_DATA/genresTest.csv \
		| grep -v "PAR_3RMS_TCD_10FR_VAR" \
		| sed  -e "s/$/,?/"       \
		>> $PREPROCESSED_DATA/genresTest.csv
}

# Run experiments
function preprocess()
{
	echo "Preprocessing..."

	echo "Turn GENRE string to nominal"
	${WEKA} weka.filters.unsupervised.attribute.StringToNominal -R last \
		-i $PREPROCESSED_DATA/genresTest.csv -o $PREPROCESSED_DATA/tmp-test-nominal.arff

	echo "Normalizes values"
	${WEKA} weka.filters.unsupervised.attribute.Normalize -S 1.0 -T 0.0 \
		-i $PREPROCESSED_DATA/tmp-test-nominal.arff -o $TEST_FILE
	${WEKA} weka.filters.unsupervised.attribute.Normalize -S 1.0 -T 0.0 \
		-i $RAW_DATA/genresTrain.csv -o $PREPROCESSED_DATA/tmp-train-normalize.arff

	echo "Removes extreme values"
	${WEKA} weka.filters.unsupervised.attribute.InterquartileRange -R first-last -O 3.0 -E 6.0 \
		-i $PREPROCESSED_DATA/tmp-train-normalize.arff -o $PREPROCESSED_DATA/tmp-train-extreme-values.arff
	${WEKA} weka.filters.unsupervised.instance.RemoveWithValues -S 0.0 -C last -L last \
		-i $PREPROCESSED_DATA/tmp-train-extreme-values.arff -o $PREPROCESSED_DATA/tmp-train-extreme-values-free.arff
	${WEKA} weka.filters.unsupervised.attribute.Remove -R 193-194 \
		-i $PREPROCESSED_DATA/tmp-train-extreme-values-free.arff -o $TRAIN_FILE

	rm $PREPROCESSED_DATA/tmp*
}

# Build a model to submit
function model()
{
	if [ ! -f $TRAIN_FILE ]; then
		echo "Train Data does not exist!"
		exit 1
	fi

	model_parameters="weka.classifiers.trees.J48 -C 0.25 -M 2"
	train_data=$TRAIN_FILE
	output_model=$MODELS/j48.model

	build_model "$model_parameters" $train_data $output_model

	echo "Model builded."
}

# Run
function run()
{
	if [ ! -f $MODELS/j48.model ]; then
		echo "J48 Model does not exist!"
		exit 1
	fi

	model=$MODELS/j48.model
	train_data=$TRAIN_FILE
	unlabeled_data=$TEST_FILE
	output_classification=$SUBMIT_FILE

	classify $model $train_data $unlabeled_data $output_classification

	echo "Data classified."
}

#===============================================================================
# Kaggle Operations
#===============================================================================

# Download raw data from kaggle plataform.
function download()
{
	source $HOME/bin/activate

	mkdir -p $RAW_DATA
	cd $RAW_DATA

	# Download
	kaggle competitions download -c data-mining-class-ufsc-20192

	# Unzip
	unzip genresTest.csv.zip
	unzip genresTrain.csv.zip

	# Read/Write permissions
	chmod 660 genresTest.csv
	chmod 660 genresTrain.csv

	# Clean dir
	rm -f genresTest.csv.zip
	rm -f genresTrain.csv.zip

	echo "Download finished!"
}

# Submmit a model to the competition.
function submit()
{
	MESSAGE=$1

	if [ -z "$MESSAGE" ];
	then
		MESSAGE="test"
	fi

	echo "Submit: $MESSAGE"

	source $HOME/bin/activate

	kaggle competitions submit -c data-mining-class-ufsc-20192 -f $SUBMIT_FILE -m "$MESSAGE"

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
    prepare|preprocess|model|run)
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