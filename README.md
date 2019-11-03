# INE5644 - Data Mining

The following steps configures a virtual envorinment with python3.

**Requirements:**
* python3
* pip3
* virtualenv
* kaggle.json associeted with your Kaggle Account

**Setup the environment:**
```
	bash command.sh setup YOUR-PATH/kaggle.json
```

**Download the raw data:**
```
	bash command.sh download
```

**Build and use a J48 tree:**
```
	bash command.sh prepare
	bash command.sh preprocess
	bash command.sh model
	bash command.sh run
```

**Submit model result:**
```
	bash command.sh submit "A message"
```
