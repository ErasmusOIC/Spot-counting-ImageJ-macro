// Macro CountSpotsV3
//
// Expected: 
//		3 channel image in which channel 2 contains the spots 
//		RoiManager list with Rois of cells
//
// Spot Thershold Mean+2Sdev 
// van Royen en Houtsmuller  J Cell Biol. 2007 Apr 9;177(1):63-72
//
// Gert van Cappellen
// 26/7/2011

stDevFactor=2;
Dialog.create("Count number of foci in preselected cells");
Dialog.addMessage("Open 8 bit 3 channel image with channel two with your data\nand your ROI's");
Dialog.addNumber("treshold standard deviation factor :",stDevFactor);
Dialog.show();
stDevFactor=Dialog.getNumber;
nRoi=roiManager("Count");
if (nRoi<1) exit ("You should load Roi's in the Roi manager");
getDimensions(width, height, channels, slices, frames);
//print (width, height, channels, slices, frames);
if (channels>2) setSlice(2);
dirPath=getDirectory("image");
fileName=getTitle();
run("Copy");
run("Internal Clipboard");
run("8-bit");
meanArray=newArray(nRoi);
stdArray=newArray(nRoi);
fociArray=newArray(nRoi);
run("Set Measurements...", "area mean standard center redirect=None decimal=3");
for (i=0; i<nRoi; i++) {
	roiManager("Select", i);
	getRawStatistics(nPixels, mean, min, max, std);
	setThreshold(mean+stDevFactor*std, 255);
//	run("Analyze Particles...", "size=5-Infinity circularity=0.00-1.00 show=Masks display clear slice");
	run("Analyze Particles...", "size=5-Infinity circularity=0.50-1.00 show=Nothing display clear slice");
	meanArray[i]=mean;
	stdArray[i]=std;
	fociArray[i]=nResults;
	for (j=0; j<nResults; j++){
		print(i+", "+getResult("XM",j)+", "+getResult("YM",j));
	}
//	print ("Cell ", i+1,"Mean ",mean,"STD ",std," FociNumber: ", nResults);
}
run("Clear Results");
for (i=0; i<nRoi; i++) {
//	setResult("Cell nr",i,i+1);
	setResult("Mean",i,meanArray[i]);
	setResult("StDev",i,stdArray[i]);
	setResult("Foci number",i,fociArray[i]);
}
updateResults();
String.copyResults();
close();
saveAs("Measurements", dirPath+"Results"+fileName+".xls");


