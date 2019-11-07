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

## Data Understanding

#### Temporal

- p1: Temporal Centroid

#### Spectral Centroid

[Wikipedia](https://en.wikipedia.org/wiki/Spectral_centroid)
[Module about Spectral Centroid](http://acousticslab.org/RECA220/PMFiles/Module06.htm)

- p2: Spectral Centroid average value
- p3: Spectral Centroid variance

#### Audio Spectrum Envelope (ASE)

[Wikipedia](https://en.wikipedia.org/wiki/Spectral_envelope)
[More detailed](http://recherche.ircam.fr/anasyn/schwarz/da/specenv/3_3Spectral_Envelopes.html)

- p4-37 : AES average values in 34 frequency bands
- p38   : AES average value (averaged for all frequency bands)
- p39-72: AES variance values in 34 frequency bands
- p73   : averaged ASE variance parameters

#### Audio Spectrum

[Wikipedia: Spectrum](https://en.wikipedia.org/wiki/Spectrum)
[Wikipedia: Audio Frequency](https://en.wikipedia.org/wiki/Audio_frequency)
[Wikipedia: Spectrum Analyzer](https://en.wikipedia.org/wiki/Spectrum_analyzer)

- p74,75: Audio Spectrum Centroid – average and variance values
- p76,77: Audio Spectrum Spread – average and variance values

#### Spectral Flatness Measure (SFM)

[Wikipedia](https://en.wikipedia.org/wiki/Spectral_flatness)
[Spectral flatness: resume](https://www.johndcook.com/blog/2016/05/03/spectral-flatness/)
[Note on measures for spectral flatness](https://www.researchgate.net/publication/224078693_Note_on_measures_for_spectral_flatness)
[Using a Spectral Flatness Based Feature for Audio Segmentation and Retrieval](http://ismir2000.ismir.net/posters/izmirli.pdf)

- p78-101 : SFM average values for 24 frequency bands
- p102    : SFM average value (averaged for all frequency bands)
- p103-126: SFM variance values for 24 frequency bands
- p127    : averaged SFM variance parameters

#### Mel-Frequency Cepstral

[Wikipedia: Mel-Frequency Cepstrum](https://en.wikipedia.org/wiki/Mel-frequency_cepstrum)
[Mel Frequency Cepstral Coefficient (MFCC) tutorial](http://practicalcryptography.com/miscellaneous/machine-learning/guide-mel-frequency-cepstral-coefficients-mfccs/)
[Spectrogram, Cepstrum and Mel-Frequency Analysis](http://www.speech.cs.cmu.edu/15-492/slides/03_mfcc.pdf)
[Python: Mel Frequency Cepstral Coefficients (MFCCs)](https://musicinformationretrieval.com/mfcc.html)

- p128-147: 20 first mel cepstral coefficients average values
- p148-167: the same as 128-147

#### Analysis of the distribution of the envelope/rms.

[Wikipedia: Audio Power (incluses RMS Power)](https://en.wikipedia.org/wiki/Audio_power)
[Wikipedia: Envelope Music](https://en.wikipedia.org/wiki/Envelope_(music))
[Maybe AES](https://en.wikipedia.org/wiki/Spectral_envelope)

- p168-191: dedicated parameters in time domain based of the analysis of the distribution of the envelope in relation to the rms value.
