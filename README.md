# Consumer

## A basic synthesizer for iOS.

Consumer is a very basic synthesizer that I wrote for a project in the summer of 2013, but the project went in another direction and Consumer was no longer needed. Which is fine, since Consumer has a number of flaws. The main one being that performance is terrible, and it sounds kinda shitty.

Consumer was my first (well, second, if you count Conform) foray into writing a synthesizer, and I basically just jumped into it without knowing anything about how to generate audio. (now I have books and shit) But still, the code might be of interest to someone.

The goal was to write a synthesizer that was easily accessed through an Objective-C interface. The filter is more or less lifted wholesale from [mobilesynth](https://code.google.com/p/mobilesynth/). (sorry) Consumer uses The Amazing Audio Engine, which is integrated via [CocoaPods](http://cocoapods.org/).
