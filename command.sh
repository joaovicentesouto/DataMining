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
export SUBMISSION_FILE=$SUBMISSION_DATA/submission.csv

export HOME=$(pwd)/$VENV

export WEKA="java -classpath weka.jar"
export WEKA36="java -classpath weka-3-6.jar"

#===============================================================================
# Weka Operations
#===============================================================================

function build_model() # (model_args, train_data, output_model)
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
	mkdir -p $MODELS

	# # Appends genre to the header
	# cat $RAW_DATA/genresTest.csv \
	# 	| grep "PAR_3RMS_TCD_10FR_VAR" \
	# 	| sed  -e "s/\"PAR_3RMS_TCD_10FR_VAR\"/\"PAR_3RMS_TCD_10FR_VAR\",\"GENRE\"/g" \
	# 	> $PREPROCESSED_DATA/genresTest.csv

	# # Make test data to unlabeled data
	# cat $RAW_DATA/genresTest.csv \
	# 	| grep -v "PAR_3RMS_TCD_10FR_VAR" \
	# 	| sed  -e "s/$/,?/"       \
	# 	>> $PREPROCESSED_DATA/genresTest.csv
}

# Run experiments
function preprocess()
{
	echo "Preprocessing..."

	echo "Build ARFF with Original Data"

	${WEKA} weka.core.converters.CSVLoader $RAW_DATA/genresTrain.csv > $PREPROCESSED_DATA/train-nn.arff
	${WEKA} weka.core.converters.CSVLoader $RAW_DATA/genresTest.csv > $PREPROCESSED_DATA/tmp-test-nn.arff

	${WEKA} weka.filters.unsupervised.attribute.Add -T NOM -N GENRE -L Pop,Blues,Jazz,Classical,Rock,Metal -C last -W 1.0 \
		-i $PREPROCESSED_DATA/tmp-test-nn.arff -o $PREPROCESSED_DATA/test-nn.arff

	echo "Build ARFF with Normalized Data"

	${WEKA} weka.filters.unsupervised.attribute.Normalize -S 2.0 -T -1.0 \
		-b -i $PREPROCESSED_DATA/train-nn.arff -o $PREPROCESSED_DATA/train-n.arff \
		-r $PREPROCESSED_DATA/test-nn.arff -s $PREPROCESSED_DATA/test-n.arff

	echo "Build ARFF with Principal Components Algorithm Data"

	${WEKA36} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-n.arff -o $PREPROCESSED_DATA/train-n-pca.arff \
		-r $PREPROCESSED_DATA/test-n.arff -s $PREPROCESSED_DATA/test-n-pca.arff \
		-c last \
		-E "weka.attributeSelection.PrincipalComponents -R 0.95 -A 5" \
		-S "weka.attributeSelection.Ranker -T -1.7976931348623157E308 -N -1"

	${WEKA} weka.filters.unsupervised.attribute.InterquartileRange -R first-last -O 3.0 -E 6.0 \
		-i $PREPROCESSED_DATA/train-n-pca.arff -o $PREPROCESSED_DATA/tmp-train-quartis.arff
	${WEKA} weka.filters.unsupervised.instance.RemoveWithValues -S 0.0 -C last -L last \
		-i $PREPROCESSED_DATA/tmp-train-quartis.arff -o $PREPROCESSED_DATA/train-extremes.arff
	${WEKA} weka.filters.unsupervised.attribute.Remove -R 76-77 \
		-i $PREPROCESSED_DATA/train-extremes.arff -o $PREPROCESSED_DATA/tmp-train-final.arff
	
	echo "Build ARFF with Normalized Data"

	${WEKA} weka.filters.unsupervised.attribute.Normalize -S 2.0 -T -1.0 \
		-b -i $PREPROCESSED_DATA/tmp-train-final.arff -o $PREPROCESSED_DATA/train-final.arff \
		-r $PREPROCESSED_DATA/test-n-pca.arff -s $PREPROCESSED_DATA/test-final.arff

	rm $PREPROCESSED_DATA/tmp*
}

function feature_selection()
{
	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-nn.arff -o $PREPROCESSED_DATA/train-nn-cfss-foward.arff \
		-r $PREPROCESSED_DATA/test-nn.arff -s $PREPROCESSED_DATA/test-nn-cfss-foward.arff \
		-c last \
		-E "weka.attributeSelection.CfsSubsetEval -P 1 -E 1" \
		-S "weka.attributeSelection.BestFirst -D 1 -N 5"

	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-n.arff -o $PREPROCESSED_DATA/train-n-cfss-foward.arff \
		-r $PREPROCESSED_DATA/test-n.arff -s $PREPROCESSED_DATA/test-n-cfss-foward.arff \
		-c last \
		-E "weka.attributeSelection.CfsSubsetEval -P 1 -E 1" \
		-S "weka.attributeSelection.BestFirst -D 1 -N 5"

	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-n.arff -o $PREPROCESSED_DATA/train-n-cfss-backward.arff \
		-r $PREPROCESSED_DATA/test-n.arff -s $PREPROCESSED_DATA/test-n-cfss-backward.arff \
		-c last \
		-E "weka.attributeSelection.CfsSubsetEval -P 1 -E 1" \
		-S "weka.attributeSelection.BestFirst -D 0 -N 5"

	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-nn.arff -o $PREPROCESSED_DATA/train-nn-ca-0.2.arff \
		-r $PREPROCESSED_DATA/test-nn.arff -s $PREPROCESSED_DATA/test-nn-ca-0.2.arff \
		-c last \
		-E "weka.attributeSelection.CorrelationAttributeEval " \
		-S "weka.attributeSelection.Ranker -T 0.2 -N -1"

	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-nn.arff -o $PREPROCESSED_DATA/train-nn-ca-0.25.arff \
		-r $PREPROCESSED_DATA/test-nn.arff -s $PREPROCESSED_DATA/test-nn-ca-0.25.arff \
		-c last \
		-E "weka.attributeSelection.CorrelationAttributeEval " \
		-S "weka.attributeSelection.Ranker -T 0.25 -N -1"

	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-n.arff -o $PREPROCESSED_DATA/train-n-ca-0.2.arff \
		-r $PREPROCESSED_DATA/test-n.arff -s $PREPROCESSED_DATA/test-n-ca-0.2.arff \
		-c last \
		-E "weka.attributeSelection.CorrelationAttributeEval " \
		-S "weka.attributeSelection.Ranker -T 0.2 -N -1"

	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-n.arff -o $PREPROCESSED_DATA/train-n-ca-0.25.arff \
		-r $PREPROCESSED_DATA/test-n.arff -s $PREPROCESSED_DATA/test-n-ca-0.25.arff \
		-c last \
		-E "weka.attributeSelection.CorrelationAttributeEval " \
		-S "weka.attributeSelection.Ranker -T 0.25 -N -1"

	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-nn.arff -o $PREPROCESSED_DATA/train-nn-gra-0.1.arff \
		-r $PREPROCESSED_DATA/test-nn.arff -s $PREPROCESSED_DATA/test-nn-gra-0.1.arff \
		-c last \
		-E "weka.attributeSelection.GainRatioAttributeEval " \
		-S "weka.attributeSelection.Ranker -T 0.1 -N -1"

	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-nn.arff -o $PREPROCESSED_DATA/train-nn-gra-0.15.arff \
		-r $PREPROCESSED_DATA/test-nn.arff -s $PREPROCESSED_DATA/test-nn-gra-0.15.arff \
		-c last \
		-E "weka.attributeSelection.GainRatioAttributeEval " \
		-S "weka.attributeSelection.Ranker -T 0.15 -N -1"

	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-n.arff -o $PREPROCESSED_DATA/train-n-gra-0.1.arff \
		-r $PREPROCESSED_DATA/test-n.arff -s $PREPROCESSED_DATA/test-n-gra-0.1.arff \
		-c last \
		-E "weka.attributeSelection.GainRatioAttributeEval " \
		-S "weka.attributeSelection.Ranker -T 0.1 -N -1"

	${WEKA} weka.filters.supervised.attribute.AttributeSelection \
		-b -i $PREPROCESSED_DATA/train-n.arff -o $PREPROCESSED_DATA/train-n-gra-0.15.arff \
		-r $PREPROCESSED_DATA/test-n.arff -s $PREPROCESSED_DATA/test-n-gra-0.15.arff \
		-c last \
		-E "weka.attributeSelection.GainRatioAttributeEval " \
		-S "weka.attributeSelection.Ranker -T 0.15 -N -1"
}

function build()
{
	echo "Random Forest 0"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" nn-cfss-foward rfnn-cfss-foward > rfnn-cfss-foward.txt

	echo "Random Forest 1"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" n-cfss-foward rfn-cfss-foward > rfn-cfss-foward.txt

	echo "Random Forest 2"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" n-cfss-backward rfn-cfss-backward > rfn-cfss-backward.txt

	echo "Random Forest 3"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" nn-ca-0.2 rfnn-ca-0.2 > rfnn-ca-0.2.txt

	echo "Random Forest 4"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" nn-ca-0.2 rfnn-ca-0.25 > rfnn-ca-0.25.txt

	echo "Random Forest 5"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" n-ca-0.2 rfn-ca-0.2 > rfn-ca-0.2.txt

	echo "Random Forest 6"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" n-ca-0.2 rfn-ca-0.25 > rfn-ca-0.25.txt

	echo "Random Forest 7"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" nn-gra-0.1 rfnn-gra-0.1 > rfnn-gra-0.1.txt

	echo "Random Forest 8"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" nn-gra-0.15 rfnn-gra-0.15 > rfnn-gra-0.15.txt

	echo "Random Forest 9"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" n-gra-0.1 rfn-gra-0.1 > rfn-gra-0.1.txt

	echo "Random Forest 10"
	model "weka.classifiers.trees.RandomForest -P 100 -I 100 -num-slots 1 -K 0 -M 1.0 -V 0.001 -S 1" n-gra-0.15 rfn-gra-0.15 > rfn-gra-0.15.txt


	echo "J48 0"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" nn-cfss-foward j48nn-cfss-foward > j48nn-cfss-foward.txt

	echo "J48 1"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" n-cfss-foward j48n-cfss-foward > j48n-cfss-foward.txt

	echo "J48 2"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" n-cfss-backward j48n-cfss-backward > j48n-cfss-backward.txt

	echo "J48 3"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" nn-ca-0.2 j48nn-ca-0.2 > j48nn-ca-0.2.txt

	echo "J48 4"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" nn-ca-0.2 j48nn-ca-0.25 > j48nn-ca-0.25.txt

	echo "J48 5"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" n-ca-0.2 j48n-ca-0.2 > j48n-ca-0.2.txt

	echo "J48 6"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" n-ca-0.2 j48n-ca-0.25 > j48n-ca-0.25.txt

	echo "J48 7"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" nn-gra-0.1 j48nn-gra-0.1 > j48nn-gra-0.1.txt

	echo "J48 8"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" nn-gra-0.15 j48nn-gra-0.15 > j48nn-gra-0.15.txt

	echo "J48 9"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" n-gra-0.1 j48n-gra-0.1 > j48n-gra-0.1.txt

	echo "J48 10"
	model "weka.classifiers.trees.J48 -C 0.25 -M 2" n-gra-0.15 j48n-gra-0.15 > j48n-gra-0.15.txt


	echo "Naive Bayes 0"
	model "weka.classifiers.bayes.NaiveBayes" nn-cfss-foward nbnn-cfss-foward > nbnn-cfss-foward.txt

	echo "Naive Bayes 1"
	model "weka.classifiers.bayes.NaiveBayes" n-cfss-foward nbn-cfss-foward > nbn-cfss-foward.txt

	echo "Naive Bayes 2"
	model "weka.classifiers.bayes.NaiveBayes" n-cfss-backward nbn-cfss-backward > nbn-cfss-backward.txt

	echo "Naive Bayes 3"
	model "weka.classifiers.bayes.NaiveBayes" nn-ca-0.2 nbnn-ca-0.2 > nbnn-ca-0.2.txt

	echo "Naive Bayes 4"
	model "weka.classifiers.bayes.NaiveBayes" nn-ca-0.2 nbnn-ca-0.25 > nbnn-ca-0.25.txt

	echo "Naive Bayes 5"
	model "weka.classifiers.bayes.NaiveBayes" n-ca-0.2 nbn-ca-0.2 > nbn-ca-0.2.txt

	echo "Naive Bayes 6"
	model "weka.classifiers.bayes.NaiveBayes" n-ca-0.2 nbn-ca-0.25 > nbn-ca-0.25.txt

	echo "Naive Bayes 7"
	model "weka.classifiers.bayes.NaiveBayes" nn-gra-0.1 nbnn-gra-0.1 > nbnn-gra-0.1.txt

	echo "Naive Bayes 8"
	model "weka.classifiers.bayes.NaiveBayes" nn-gra-0.15 nbnn-gra-0.15 > nbnn-gra-0.15.txt

	echo "Naive Bayes 9"
	model "weka.classifiers.bayes.NaiveBayes" n-gra-0.1 nbn-gra-0.1 > nbn-gra-0.1.txt

	echo "Naive Bayes 10"
	model "weka.classifiers.bayes.NaiveBayes" n-gra-0.15 nbn-gra-0.15 > nbn-gra-0.15.txt


	echo "MLP 0"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" nn-cfss-foward mlpnn-cfss-foward > mlpnn-cfss-foward.txt

	echo "MLP 1"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" n-cfss-foward mlpn-cfss-foward > mlpn-cfss-foward.txt

	echo "MLP 2"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" n-cfss-backward mlpn-cfss-backward > mlpn-cfss-backward.txt

	echo "MLP 3"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" nn-ca-0.2 mlpnn-ca-0.2 > mlpnn-ca-0.2.txt

	echo "MLP 4"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" nn-ca-0.2 mlpnn-ca-0.25 > mlpnn-ca-0.25.txt

	echo "MLP 5"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" n-ca-0.2 mlpn-ca-0.2 > mlpn-ca-0.2.txt

	echo "MLP 6"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" n-ca-0.2 mlpn-ca-0.25 > mlpn-ca-0.25.txt

	echo "MLP 7"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" nn-gra-0.1 mlpnn-gra-0.1 > mlpnn-gra-0.1.txt

	echo "MLP 8"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" nn-gra-0.15 mlpnn-gra-0.15 > mlpnn-gra-0.15.txt

	echo "MLP 9"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" n-gra-0.1 mlpn-gra-0.1 > mlpn-gra-0.1.txt

	echo "MLP 10"
	model "weka.classifiers.functions.MultilayerPerceptron -L 0.3 -M 0.2 -N 500 -V 0 -S 0 -E 20 -H a" n-gra-0.15 mlpn-gra-0.15 > mlpn-gra-0.15.txt
}

# Build a model to submit
function model()
{
	# if [ ! -f $TRAIN_FILE ]; then
	# 	echo "Train Data does not exist!"
	# 	exit 1
	# fi

	# model_args="weka.classifiers.trees.J48 -C 0.25 -M 2"
	# train_data=$TRAIN_FILE
	# output_model=$MODELS/j48.model

	build_model "$1" $PREPROCESSED_DATA/train-$2.arff $MODELS/$3.model

	echo "Model builded."
}

function run_models()
{
	# echo "Random Forest 0"
	# run rf nn-cfss-foward

	# echo "Random Forest 1"
	# run rf n-cfss-foward

	# echo "Random Forest 2"
	# run rf n-cfss-backward

	# echo "Random Forest 3"
	# run rf nn-ca-0.2

	# echo "Random Forest 4"
	# run rf nn-ca-0.25

	# echo "Random Forest 5"
	# run rf n-ca-0.2

	# echo "Random Forest 6"
	# run rf n-ca-0.25

	# echo "Random Forest 7"
	# run rf nn-gra-0.1

	# echo "Random Forest 8"
	# run rf nn-gra-0.15

	# echo "Random Forest 9"
	# run rf n-gra-0.1

	# echo "Random Forest 10"
	# run rf n-gra-0.15


	# echo "J48 0"
	# run j48 nn-cfss-foward

	# echo "J48 1"
	# run j48 n-cfss-foward

	# echo "J48 2"
	# run j48 n-cfss-backward

	# echo "J48 3"
	# run j48 nn-ca-0.2

	# echo "J48 4"
	# run j48 nn-ca-0.25

	# echo "J48 5"
	# run j48 n-ca-0.2

	# echo "J48 6"
	# run j48 n-ca-0.25

	# echo "J48 7"
	# run j48 nn-gra-0.1

	# echo "J48 8"
	# run j48 nn-gra-0.15

	# echo "J48 9"
	# run j48 n-gra-0.1

	# echo "J48 10"
	# run j48 n-gra-0.15


	# echo "Naive Bayes 0"
	# run nb nn-cfss-foward

	# echo "Naive Bayes 1"
	# run nb n-cfss-foward

	# echo "Naive Bayes 2"
	# run nb n-cfss-backward

	# echo "Naive Bayes 3"
	# run nb nn-ca-0.2

	# echo "Naive Bayes 4"
	# run nb nn-ca-0.25

	# echo "Naive Bayes 5"
	# run nb n-ca-0.2

	# echo "Naive Bayes 6"
	# run nb n-ca-0.25

	# echo "Naive Bayes 7"
	# run nb nn-gra-0.1

	# echo "Naive Bayes 8"
	# run nb nn-gra-0.15

	# echo "Naive Bayes 9"
	# run nb n-gra-0.1

	# echo "Naive Bayes 10"
	# run nb n-gra-0.15


	# echo "MLP 0"
	# run mlp nn-cfss-foward

	echo "MLP 1"
	run mlp n-cfss-foward

	echo "MLP 2"
	run mlp n-cfss-backward

	echo "MLP 3"
	run mlp nn-ca-0.2

	echo "MLP 4"
	run mlp nn-ca-0.25

	echo "MLP 5"
	run mlp n-ca-0.2

	echo "MLP 6"
	run mlp n-ca-0.25

	echo "MLP 7"
	run mlp nn-gra-0.1

	echo "MLP 8"
	run mlp nn-gra-0.15

	echo "MLP 9"
	run mlp n-gra-0.1

	echo "MLP 10"
	run mlp n-gra-0.15
}

# Run
function run()
{
	model=$MODELS/$1$2.model
	train_data=$PREPROCESSED_DATA/train-$2.arff
	unlabeled_data=$PREPROCESSED_DATA/test-$2.arff
	output_classification=$SUBMISSION_DATA/submission-$1$2.csv

	classify $model $train_data $unlabeled_data $output_classification

	echo "Data classified."
}

function exchange()
{
	for file in $(ls ./submission/old); do

		cp ./submission/old/$file ./submission/$file

		sed -i "s/,\"1/,\"7/g" ./submission/$file
		sed -i "s/,\"2/,\"1/g" ./submission/$file
		sed -i "s/,\"4/,\"2/g" ./submission/$file
		sed -i "s/,\"6/,\"4/g" ./submission/$file
		sed -i "s/,\"5/,\"6/g" ./submission/$file
		sed -i "s/,\"7/,\"5/g" ./submission/$file

	done
}

#===============================================================================
# Kaggle Operations
#===============================================================================

# Download raw data from kaggle plataform.
function download()
{
	# source $HOME/bin/activate

	mkdir -p $RAW_DATA
	cd $RAW_DATA

	# Download
	# kaggle competitions download -c data-mining-class-ufsc-20192

	# Unzip
	# unzip genresTest.csv.zip
	# unzip genresTrain.csv.zip

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

	kaggle competitions submit -c data-mining-class-ufsc-20192 -f $SUBMISSION_FILE -m "$MESSAGE"

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
    prepare|preprocess|model|run|feature_selection|build|run_models|exchange)
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