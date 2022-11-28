// Batch_FociCountingV3.ijm
//
// Measure spots in channel 2 and 3
// Method threshold or Mean + X*StDev 
//
// Needed directory with .lsm files with 2 or 3 channels
// Ch1 - Dapi
// Ch2 - spots
// Ch3 - spots
//
// Mean spot intensity is weighted by spot size
//
// Gert van Cappellen
// 17-10-2022
// 19-10-2022 Zero values deleted from Mean spot area and intensity
// 24-10-2022 Starting a more general version which also saves spot files
// 25-10-2022 Mean+X*StDev as threshold added
// 28-10-2022 Changed output to one .csv file per group
// 14-11-2022 Select if you want zero spot values in the average, default is on

if (isOpen("Log")) { 
     selectWindow("Log"); 
     run("Close"); 
} 
roiManager("reset");
run("Clear Results");
run("Close All");

macroName="Batch_FociCountingV3.ijm";
run("Set Measurements...", "area mean standard integrated stack limit redirect=None decimal=3");

methodThreshold=true;
Ch2Treshold=64;
Ch3Treshold=140;
methodMeanSD=true;
if (methodThreshold) methodMeanSD=false;
sdFactorCh2=4; // Set threshold Mean + sdFactor*StDev as threshold
sdFactorCh3=4; // Set threshold Mean + sdFactor*StDev as threshold

minSize=100; // Minimal size for a nucleus um2
minSpotSize=0.09;   // Minimal spotsize in um2
maxSpotSize=3; // Maximal spot size in um2
Group="";
zeroSpotsInclude=true;

Dialog.create("Counting spots in 2 or 3 channels")
Dialog.addString("Group name", Group);
Dialog.addRadioButtonGroup("Threshold method", newArray("Simple","Mean+SD"), 1, 2, "Simple");
Dialog.addCheckbox("Include zero spots in average", zeroSpotsInclude);
Dialog.addMessage("Simple Threshold");
Dialog.addNumber("Threshold channel 2", Ch2Treshold);
Dialog.addNumber("Threshold channel 3", Ch3Treshold);
Dialog.addMessage("Threshold Mean + sdFactor*StDev");
Dialog.addNumber("sdFactor channel 2", sdFactorCh2);
Dialog.addNumber("sdFactor channel 3", sdFactorCh3);
Dialog.addMessage("Cell and spot size (um2)");
Dialog.addNumber("Minimal cells size (um2)", minSize);
Dialog.addNumber("Minimal spot size (um2)", minSpotSize);
Dialog.addNumber("Maximal spot size (um2)", maxSpotSize);
Dialog.show();
Group=Dialog.getString();
if (Dialog.getRadioButton()=="Simple") {
	methodThreshold=true;
	methodMeanSD=false;
}else{
	methodThreshold=false;
	methodMeanSD=true;
}
zeroSpotsInclude=Dialog.getCheckbox();
Ch2Treshold=Dialog.getNumber();
Ch3Treshold=Dialog.getNumber();
sdFactorCh2=Dialog.getNumber();
sdFactorCh3=Dialog.getNumber();
minSize=Dialog.getNumber();
minSpotSize=Dialog.getNumber();
maxSpotSize=Dialog.getNumber();

maxNumber=1000; // Maximum number of cells to analyse
maxSpot=50000; //Maximum number of spots to analyse
// Data per cell 
cellIndex=0;
nrCell=newArray(maxNumber);
spotAreaCh2=newArray(maxNumber);
spotAreaCh3=newArray(maxNumber);
spotMeanCh2=newArray(maxNumber);
spotMeanCh3=newArray(maxNumber);
nrSpotsCh2=newArray(maxNumber);
nrSpotsCh3=newArray(maxNumber);
overlapSpotsCh2=newArray(maxNumber);
overlapSpotsCh3=newArray(maxNumber);

// Data per Image
nucArea=newArray(maxNumber);
nucMeanCh1=newArray(maxNumber);
nucMeanCh2=newArray(maxNumber);
nucMeanCh3=newArray(maxNumber);
nrSpotsCh2M=newArray(maxNumber);
spotAreaCh2M=newArray(maxNumber);
spotIntCh2M=newArray(maxNumber);
nrSpotsCh3M=newArray(maxNumber);
spotAreaCh3M=newArray(maxNumber);
spotIntCh3M=newArray(maxNumber);
spotOverlapCh2=newArray(maxNumber);
spotOverlapCh3=newArray(maxNumber);

// Data all images per group
nrImG=newArray(maxNumber);
nucNrG=newArray(maxNumber);
nucArG=newArray(maxNumber);
nucMCh1G=newArray(maxNumber);
nucSTDCh1G=newArray(maxNumber);
nucMCh2G=newArray(maxNumber);
nucSTDCh2G=newArray(maxNumber);
nucMCh3G=newArray(maxNumber);
nucSTDCh3G=newArray(maxNumber);
spotNrCh2G=newArray(maxNumber);
spotMCh2G=newArray(maxNumber);
spotAreaCh2G=newArray(maxNumber);
spotOverCh2G=newArray(maxNumber);
spotNrCh3G=newArray(maxNumber);
spotMCh3G=newArray(maxNumber);
spotAreaCh3G=newArray(maxNumber);
spotOverCh3G=newArray(maxNumber);



spotIndex=0; //pointer to spots position in spot array
// Data of Individual spots
spotArrayImage=newArray(maxSpot);
spotArrayCell=newArray(maxSpot);
spotArrayArea=newArray(maxSpot);
spotArrayIntensity=newArray(maxSpot);
spotArrayChannel=newArray(maxSpot);
spotArrayX=newArray(maxSpot);
spotArrayY=newArray(maxSpot);

fName=newArray(maxNumber);
nrImages=0;

dir=getDirectory("Select the input (Stacks) directory");

print("Macro: "+macroName);
print("---------------------------------------------------------");
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
print("Date:",dayOfMonth,"-",month+1,"-",year," Time:",hour,":",minute,"h");
print("Input directory: "+dir);
print("");
print("Minimum size nucleus (um2):",minSize);
print("Minimum size spot (um2):",minSpotSize);
print("Maximum size spot (um2):",maxSpotSize);
if (methodThreshold){
	print("Threshold ch2:",Ch2Treshold);
	print("Threshold ch3:",Ch3Treshold);
}
if (methodMeanSD){
	print("Threshold mean+sdFac+Stdev sdFac Ch2=",sdFactorCh2);
	print("Threshold mean+sdFac+Stdev sdFac Ch3=",sdFactorCh3);
}
print("");

fileNames=getFileList(dir);
Array.sort(fileNames);

File.makeDirectory(dir+"\\resultImages");
File.makeDirectory(dir+"\\results");


for (ii=0; ii<fileNames.length; ii++){
	if(endsWith(fileNames[ii],".lsm")){
		open(dir+fileNames[ii]);
		run("Select None");
		getDimensions(width, height, channels, slices, frames);
		
		nameOrg=getTitle();
		fName[nrImages]=nameOrg;
		name="Analyse";
		run("Duplicate...", "title=&name duplicate");
		selectWindow(name);
		run("Split Channels");
		
		// Segment nucleus
		// Gausian blur, watershed
		run("Set Measurements...", "area mean standard integrated stack limit redirect=None decimal=3");
		selectWindow("C1-"+name);
		rename("Nucleus");
		run("Gaussian Blur...", "sigma=2");
		setAutoThreshold("Li dark");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		run("Watershed");
		run("Analyze Particles...", "size=$minSize-Infinity exclude include add");
		nrCells=roiManager("Count");
		selectWindow(nameOrg);
		roiManager("multi-measure measure_all");
		run("Select None");

		// Reorder the results table to get data of the channels next to each other
		areaAr=newArray(nrCells);
		meanCh1Ar=newArray(nrCells);
		meanCh2Ar=newArray(nrCells);
		meanCh3Ar=newArray(nrCells);
		nucStdCh1=newArray(nrCells);
		nucStdCh2=newArray(nrCells);
		nucStdCh3=newArray(nrCells);
		for (i=0; i<nrCells; i++){
			areaAr[i]=getResult("Area",i);
			meanCh1Ar[i]=getResult("Mean",i);
			nucStdCh1[i]=getResult("StdDev",i);
			nucArea[nrImages]+=areaAr[i];
			nucMeanCh1[nrImages]+=meanCh1Ar[i];
			
		}
		for (i=0; i<nrCells; i++){
			meanCh2Ar[i]=getResult("Mean",i+nrCells);
			nucStdCh2[i]=getResult("StdDev",i+nrCells);
			nucMeanCh2[nrImages]+=meanCh2Ar[i];
		}
		if (channels>2){
			for (i=0; i<nrCells; i++){
				meanCh3Ar[i]=getResult("Mean",i+2*nrCells);
				nucStdCh3[i]=getResult("StdDev",i+2*nrCells);
				nucMeanCh3[nrImages]+=meanCh3Ar[i];
			}
		}

	print(fileNames[ii]," nr Nuclei: ", nrCells);

	// Spot measurement
	run("Set Measurements...", "area mean standard centroid stack limit redirect=None decimal=3");

	// Channel 2
	selectWindow("C2-Analyse");
	if (methodThreshold) setThreshold(Ch2Treshold,255);
	startCh2Spot=nrCells;
	zeroSpots=0;
	for (i=0; i<nrCells; i++){
		if (methodMeanSD) {
			setThreshold(meanCh2Ar[i]+sdFactorCh2*nucStdCh2[i], 255);
		}
		spotNr=0; // count spots per cell
		roiManager("Select",i);
		run("Clear Results");
		run("Analyze Particles...", "size=$minSpotSize-$maxSpotSize display exclude include add");

		nrSpotsCh2[i]=nResults;
		if (nResults>0){
			area=0;
			intDen=0;
			for(j=0; j<nResults; j++){
			area+=getResult("Area", j);
			intDen+=getResult("Mean", j)*getResult("Area", j);
			spotArrayImage[spotIndex]=nameOrg;
			spotArrayCell[spotIndex]=i+1; // First cell is 1
			spotArrayArea[spotIndex]=getResult("Area", j);;
			spotArrayIntensity[spotIndex]=getResult("Mean", j);
			spotArrayX[spotIndex]=getResult("X",j);
			spotArrayY[spotIndex]=getResult("Y",j);
			spotArrayChannel[spotIndex]=2;
			spotIndex++;
			}
			spotAreaCh2[i]=area/nResults;
			spotMeanCh2[i]=intDen/area;
			}
		else {
			spotMeanCh2[i]=0;	
			spotAreaCh2[i]=0;
			zeroSpots++;
		}
	nrSpotsCh2M[nrImages]+=nrSpotsCh2[i];
	spotAreaCh2M[nrImages]+=spotAreaCh2[i];
	spotIntCh2M[nrImages]+=spotMeanCh2[i];
		
	}
	if (zeroSpotsInclude){
		nrSpotsCh2M[nrImages]/=nrCells;
	}else {
		nrSpotsCh2M[nrImages]/=(nrCells-zeroSpots);
	}
	spotIntCh2M[nrImages]/=(nrCells-zeroSpots);
	spotAreaCh2M[nrImages]/=(nrCells-zeroSpots);
	startCh3Spot=roiManager("Count");
	for (i=startCh2Spot; i<startCh3Spot; i++){
		roiManager("select", i);
		Roi.setStrokeColor("green");
	}
	roiManager("deselect");

// Channel 3 spots

	if (channels>2){
		selectWindow("C3-Analyse");
		if (methodThreshold) setThreshold(Ch3Treshold,255);
		zeroSpots=0;
		for (i=0; i<nrCells; i++){
		if (methodMeanSD) {
			setThreshold(meanCh3Ar[i]+sdFactorCh3*nucStdCh3[i], 255);
		}
			spotNr=0; // count spots per cell
			roiManager("Select",i);
			run("Clear Results");
			run("Analyze Particles...", "size=$minSpotSize-$maxSpotSize display exclude include add");
	
			nrSpotsCh3[i]=nResults;
			if (nResults>0){
				area=0;
				intDen=0;
				for(j=0; j<nResults; j++){
				area+=getResult("Area", j);
				intDen+=getResult("Mean", j)*getResult("Area", j);
				spotArrayImage[spotIndex]=nameOrg;
				spotArrayCell[spotIndex]=i+1; // First cell is 1
				spotArrayArea[spotIndex]=getResult("Area", j);;
				spotArrayIntensity[spotIndex]=getResult("Mean", j);
				spotArrayX[spotIndex]=getResult("X",j);
				spotArrayY[spotIndex]=getResult("Y",j);
				spotArrayChannel[spotIndex]=3;
				spotIndex++;
				}
				spotAreaCh3[i]=area/nResults;
				spotMeanCh3[i]=intDen/area;
				}
				else {
					spotMeanCh3[i]=0;	
					spotAreaCh3[i]=0;
				}
		nrSpotsCh3M[nrImages]+=nrSpotsCh3[i];
		spotAreaCh3M[nrImages]+=spotAreaCh3[i];
		spotIntCh3M[nrImages]+=spotMeanCh3[i];
			
		}
		if (zeroSpotsInclude){
			nrSpotsCh3M[nrImages]/=nrCells;
		}else {
			nrSpotsCh3M[nrImages]/=(nrCells-zeroSpots);
		}
		spotIntCh3M[nrImages]/=(nrCells-zeroSpots);
		spotAreaCh3M[nrImages]/=(nrCells-zeroSpots);
		
		endSpot=roiManager("Count");
		for (i=startCh3Spot; i<endSpot; i++){
			roiManager("select", i);
			Roi.setStrokeColor("red");
		}
		roiManager("deselect");
	}

// Check overlap between spots in channel 2 and 3
	overlap=0;
	indexCh2=startCh2Spot;
	indexCh3=startCh3Spot;
	for (k=0; k<nrCells; k++){
		overlapCell=0;
		if ((nrSpotsCh2[k]>0)&&(nrSpotsCh2[k]>0)){
			for (i=indexCh2; i<indexCh2+nrSpotsCh2[k]; i++){
				for (j=indexCh3; j<indexCh3+nrSpotsCh3[k]; j++){
					roiManager('select',newArray(i,j));
		      		roiManager("AND");
			    	if (selectionType()>-1) {
			    		overlapCell++;
			    		break;
			    	}
				}
			}
			overlap+=overlapCell;
		}
		if(nrSpotsCh2[k]>0) {
			overlapSpotsCh2[k]=overlapCell/nrSpotsCh2[k];
		}else overlapSpotsCh2[k]=0;
		if(nrSpotsCh3[k]>0) {
			overlapSpotsCh3[k]=overlapCell/nrSpotsCh3[k];
		}else overlapSpotsCh3[k]=0;
		indexCh2+=nrSpotsCh2[k];
		indexCh3+=nrSpotsCh3[k];
		
	}

	spotOverlapCh2[nrImages]=overlap/(startCh3Spot-startCh2Spot);
	spotOverlapCh3[nrImages]=overlap/(endSpot-startCh3Spot);
	
// Make table with results of one image 
	run("Clear Results");
	for (i=0; i<nrCells; i++){
		setResult("Label",i,Group);
		setResult("Image",i,nrImages+1);
		setResult("Cell",i,i+1);
		setResult("Area",i, areaAr[i]);
		setResult("MeanCh1",i, meanCh1Ar[i]);
		setResult("StdDevCh1",i,nucStdCh1[i]);
		setResult("MeanCh2",i, meanCh2Ar[i]);
		setResult("StdDevCh2",i, nucStdCh2[i]);
		if (channels>2) {
			setResult("MeanCh3",i, meanCh3Ar[i]);
			setResult("StdDevCh3",i, nucStdCh3[i]);
		}
		setResult("nrSpotsCh2", i, nrSpotsCh2[i]);
		setResult("MeanSpotCh2", i, spotMeanCh2[i]);
		setResult("SpotAreaCh2", i, spotAreaCh2[i]);
		setResult("OverLapSpCh2",i, overlapSpotsCh2[i]);
		if (channels>2) {
			setResult("nrSpotsCh3", i, nrSpotsCh3[i]);
			setResult("MeanSpotCh3", i, spotMeanCh3[i]);
			setResult("SpotAreaCh3", i, spotAreaCh3[i]);
			setResult("OverLapSpCh3",i, overlapSpotsCh3[i]);
		}
	}
	// Put all data in the group file
	for(i=0;i<nrCells; i++){
		nrImG[cellIndex]=nrImages+1;
		nucNrG[cellIndex]=i+1;
		nucArG[cellIndex]=areaAr[i];
		nucMCh1G[cellIndex]=meanCh1Ar[i];
		nucSTDCh1G[cellIndex]=nucStdCh1[i];
		nucMCh2G[cellIndex]=meanCh2Ar[i];
		nucSTDCh2G[cellIndex]=nucStdCh2[i];
		if (channels>2){
			nucMCh3G[cellIndex]=meanCh3Ar[i];
			nucSTDCh3G[cellIndex]=nucStdCh3[i];
		}
		spotNrCh2G[cellIndex]=nrSpotsCh2[i];
		spotMCh2G[cellIndex]=spotMeanCh2[i];
		spotAreaCh2G[cellIndex]=spotAreaCh2[i];
		spotOverCh2G[cellIndex]=overlapSpotsCh2[i];
		if (channels>2){
			spotNrCh3G[cellIndex]=nrSpotsCh3[i];
			spotMCh3G[cellIndex]=spotMeanCh3[i];
			spotAreaCh3G[cellIndex]=spotAreaCh3[i];
			spotOverCh3G[cellIndex]=overlapSpotsCh3[i];
		}
	cellIndex++;	
	}
	
	nucArea[nrImages]/=nrCells;
	nucMeanCh1[nrImages]/=nrCells;
	nucMeanCh2[nrImages]/=nrCells;
	if (channels>2) nucMeanCh3[nrImages]/=nrCells;
	nrCell[nrImages]=nrCells;
	if (methodThreshold) saveAs("Results", dir+"\\results\\"+Group+"_"+nameOrg+"_tr.csv");
	if (methodMeanSD) saveAs("Results", dir+"\\results\\"+Group+"_"+nameOrg+"_sd.csv");
	nrImages++;

	selectWindow(nameOrg);
	roiManager("Show All without labels");
	if (methodThreshold) saveAs("Tiff", dir+"resultImages\\"+nameOrg+"_tr.tif");
	if (methodThreshold) roiManager("Save", dir+"\\resultImages\\RoiSet"+nameOrg+"_tr.zip");
	if (methodMeanSD) saveAs("Tiff", dir+"resultImages\\"+nameOrg+"_sd.tif");
	if (methodMeanSD) roiManager("Save", dir+"\\resultImages\\RoiSet"+nameOrg+"_sd.zip");
	roiManager("reset");
	run("Close All");
	run("Clear Results");
	}
}

//Make spot file with all data
run("Clear Results");
for (i=0; i<spotIndex; i++){
	setResult("Label", i, spotArrayImage[i]);
	setResult("Cell", i, spotArrayCell[i]);
	setResult("Area", i, spotArrayArea[i]);
	setResult("Mean", i, spotArrayIntensity[i]);
	setResult("X", i, spotArrayX[i]);
	setResult("Y", i, spotArrayY[i]);
	setResult("Channel", i, spotArrayChannel[i]);
}
if (methodThreshold) saveAs("Results", dir+"\\results\\Spots_tr.csv");
if (methodMeanSD) saveAs("Results", dir+"\\results\\Spots_sd.csv");

// Make all nuclei file for whole group

run("Clear Results");
for (i=0; i<cellIndex; i++){
	setResult("Label",i,Group);
	setResult("Image",i,nrImG[i]);
	setResult("Cell",i,nucNrG[i]);
	setResult("Area",i, nucArG[i]);
	setResult("MeanCh1",i, nucMCh1G[i]);
	setResult("StdDevCh1",i,nucSTDCh1G[i]);
	setResult("MeanCh2",i, nucMCh2G[i]);
	setResult("StdDevCh2",i, nucSTDCh2G[i]);
	if (channels>2) {
		setResult("MeanCh3",i, nucMCh3G[i]);
		setResult("StdDevCh3",i, nucSTDCh3G[i]);
	}
	setResult("nrSpotsCh2", i, spotNrCh2G[i]);
	setResult("MeanSpotCh2", i, spotMCh2G[i]);
	setResult("SpotAreaCh2", i, spotAreaCh2G[i]);
	setResult("OverLapSpCh2",i, spotOverCh2G[i]);
	if (channels>2) {
		setResult("nrSpotsCh3", i, spotNrCh3G[i]);
		setResult("MeanSpotCh3", i, spotMCh3G[i]);
		setResult("SpotAreaCh3", i, spotAreaCh3G[i]);
		setResult("OverLapSpCh3",i, spotOverCh3G[i]);
	}
}
if (methodThreshold) saveAs("Results", dir+"\\results\\"+Group+"_All_tr.csv");
if (methodMeanSD) saveAs("Results", dir+"\\results\\"+Group+"_All_sd.csv");

// Make summary of Cell data
run("Clear Results");
for (i=0; i<nrImages; i++){
	setResult("Label",i,fName[i]);
	setResult("NrCells",i,nrCell[i]);
	setResult("NucArea",i,nucArea[i]);
	setResult("NucMeanCh1",i,nucMeanCh1[i]);
	setResult("NucMeanCh2",i,nucMeanCh2[i]);
	if (channels>2) setResult("NucMeanCh3",i,nucMeanCh3[i]);
	setResult("NrSpotCh2",i,nrSpotsCh2M[i]);
	setResult("MeanSpotIntCh2",i,spotIntCh2M[i]);
	setResult("MeanSpotAreaCh2",i,spotAreaCh2M[i]);
	setResult("OverlapSpotC2C3",i,spotOverlapCh2[i]);
	if (channels>2){
		setResult("NrSpotCh3",i,nrSpotsCh3M[i]);
		setResult("MeanSpotIntCh3",i,spotIntCh3M[i]);
		setResult("MeanSpotAreaCh3",i,spotAreaCh3M[i]);
		setResult("OverlapSpotC3C2",i,spotOverlapCh3[i]);
	}
}
if (methodThreshold) saveAs("Results", dir+"\\results\\Summary_tr.csv");
if (methodMeanSD) saveAs("Results", dir+"\\results\\Summary_sd.csv");

getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
print("End: ",hour+":"+minute+":"+second);
print("---------------------------------------------------------");
print("Macro correctly ended");
selectWindow("Log");
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
saveAs("Text",dir+"resultImages\\Log_"+macroName+"_"+dayOfMonth+"_"+month+1+"_"+year+".txt");

		