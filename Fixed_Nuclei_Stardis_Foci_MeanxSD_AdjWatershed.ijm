// Count number of foci
// Based on mean + factor * SD threshold method of Adriaan
//
// Expected 2 channel images, channel 1 Nuclear stain, channel 2 Spot stain
//
// Gert van Cappellen
// 23/7/2018 added CellID, an individual identifier per cell
// contains imagenr*1000 + cellnr
// 3-1-2023 Added Stardist to segment nuclei, install the Stardist Plugin
// 5-1-2023 Added Adjustable watershed voor Foci segmentation
// 5-1-2023 Added output with all nuclear and all spot detections

if (isOpen("Log")) { 
     selectWindow("Log"); 
     run("Close"); 
} 
run("Clear Results");
run("Close All");
if (isOpen("ROI Manager")) {
     selectWindow("ROI Manager");
     run("Close");
}
//run("Set Measurements...", "area mean standard center integrated skewness kurtosis stack limit redirect=None decimal=3");

// Define variables here

macroName="Fixed_Nuclei_Stardist_Foci_MeanxSD_AdjWatershed";
minThreshold=50; // Minimal threshold
maxThreshold=150; // Maximal threshold
minNucSize=20; // Minimal Nuclei area
sMinSize=0.05; // Minimal spot size
sMaxSize=6; // Maximal spot size
wTol=0.1; // Adjustable watershed tolerance
factor = 1; //factor*std voor threshold!

print("Macro: "+macroName);
print("---------------------------------------------------------");
print("Factor *sd: ", factor);
print("Minimal threshold: ",minThreshold);
print("Maximal threshold: ",maxThreshold);
print("Minimal nucleus size", minNucSize);
print("Minimal spot size", sMinSize);
print("Maximal spot size", sMaxSize);
print("Adjustable watershed tolerance", wTol);

getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
print("Date:",dayOfMonth,"-",month+1,"-",year," Time:",hour,":",minute,"h");
dir=getDirectory("Select the input (Stacks) directory");
print("Input directory: "+dir);
print("");

// Variables for global data storage nuclei data gn
maxCells=1000;
gnLabel=newArray(maxCells);
gnImageNr=newArray(maxCells);
gnCellID=newArray(maxCells);
gnnCell=newArray(maxCells);
gnArea=newArray(maxCells);
gnAvg=newArray(maxCells);
gnSD=newArray(maxCells);
gnThres=newArray(maxCells);
gnnSpots=newArray(maxCells);
gnAvgSArea=newArray(maxCells);
gnAvgSInt=newArray(maxCells);
gnSIntDen=newArray(maxCells);
gnIndex=0;

// Variables for global data storage spot data gs
maxSpots=10000;
gsLabel=newArray(maxSpots);
gsCellID=newArray(maxSpots);
gsnCell=newArray(maxSpots);
gsArea=newArray(maxSpots);
gsAvg=newArray(maxSpots);
gsSD=newArray(maxSpots);
gsIntDen=newArray(maxSpots);
gsIndex=0;

File.makeDirectory(dir+"\ResultImages");
File.makeDirectory(dir+"\Results");
File.makeDirectory(dir+"\Roi");

fileNames=getFileList(dir);
Array.sort(fileNames);


// MAIN LOOP
imageNr=0;

for (ii=0; ii<fileNames.length; ii++){
	if(endsWith(fileNames[ii],".tif")){
		open(dir+fileNames[ii]);
		getDimensions(width, height, channels, slices, frames);
		getVoxelSize(xSize, ySize, zSize, unit);
		run("Select None");
		print(fileNames[ii]);
		name=getTitle();
		imageNr++;
		
		// Put your macro here
// Segment nuclei using Stardist
		run("Split Channels");
		// exclude on boundery put at 50
		run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=['input':'C1-"+name+"', 'modelChoice':'Versatile (fluorescent nuclei)', 'normalizeInput':'true', 'percentileBottom':'1.0', 'percentileTop':'99.8', 'probThresh':'0.5', 'nmsThresh':'0.4', 'outputType':'Both', 'nTiles':'1', 'excludeBoundary':'50', 'roiPosition':'Automatic', 'verbose':'false', 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");
// Remove nuclei that are smaller than minNucSize
		jj=roiManager("count");
		for(i=jj-1;i>=0;i--){
			roiManager("select", i);
			getStatistics(ar);
			ar=ar*xSize*ySize; // Convert area to square microns
			if (ar<minNucSize){
				roiManager("delete");
			}
		}
		roiManager("deselect");
// Measure Mean and StDev from roiManger with segmented nuclei 	
		selectWindow("C2-"+name);
		roiManager("Show All without labels");
		roiManager("Measure");
		Area = newArray(nResults);
		Mean = newArray(nResults);
		Std = newArray(nResults);
		nSpots = newArray(nResults);
		areaSpots = newArray(nResults);
		avgIntensitySpots = newArray(nResults);
		intDenSpots=newArray(nResults);
		for (i=0;i<nResults;i++){
			Area[i] = getResult("Area",i);
			Mean[i] = getResult("Mean",i);
			Std[i] = getResult("StdDev",i);
		}
		run("Clear Results");
		start =0;
		end=roiManager("Count");
		for (i=0; i<end; i++){
			selectWindow("C2-"+name);
			roiManager("Select", i);
			start = nResults;
			Threshold = Mean[i]+factor*Std[i];
			if (Threshold<minThreshold) Threshold=minThreshold; 
			if (Threshold>maxThreshold) Threshold=maxThreshold;
			setThreshold(Threshold,255);

// Segmentation nuclei with adjustable watershed 	
			run("Analyze Particles...", "size=$sMinSize-$sMaxSize show=Masks include slice");
			setThreshold(Threshold,255);
			run("Convert to Mask");
			run("Adjustable Watershed", "tolerance="+wTol);
			run("Analyze Particles...", "size=$sMinSize-$sMaxSize display include slice add");
			//waitForUser("Test");
			close();
// Analyse spots
			run("Analyze Particles...", "size=$sMinSize-$sMaxSize display include slice add");
			count = 0;
			summeanSpots = 0;
			sumareaSpots = 0;
			for (j=start; j<nResults; j++){
				setResult("nCel",j,i+1);
				setResult("CellID",j,(imageNr*1000)+i+1);
// Put Spot data in global array
				gsLabel[gsIndex]=name;
				gsCellID[gsIndex]=(getResult("CellID",j));
				gsnCell[gsIndex]=(getResult("nCel",j));
				gsArea[gsIndex]=(getResult("Area",j));
				gsAvg[gsIndex]=(getResult("Mean",j));
				gsSD[gsIndex]=(getResult("StdDev",j));
				gsIntDen[gsIndex]=(getResult("IntDen",j));
				gsIndex++;
				if (gsIndex>maxSpots) exit("Error to many spots counted, maximum is "+maxSpots);
				count++;
				sumareaSpots = sumareaSpots + getResult("Area",j);
				summeanSpots = summeanSpots + getResult("Mean",j);
				intDenSpots[i]=intDenSpots[i]+getResult("IntDen");
			}
		
			nSpots[i] = count;
			areaSpots[i] = sumareaSpots/count;
			avgIntensitySpots[i] = summeanSpots/count;
			
		} // End For

		saveAs("Results", dir+"Results/ResultsSpots"+name+".xls");
		run("Clear Results");
		
		for (i=0; i<end; i++){
			setResult("CellID",i,(imageNr*1000)+i+1);
			setResult("nCel",i,i+1);
			setResult("AreaNuclei",i, Area[i]);
			setResult("MeanNuclei", i, Mean[i]);
			setResult("StdNuclei",i, Std[i]);
			tr=Mean[i]+factor*Std[i];
			if (tr<minThreshold) tr=minThreshold;
			if (tr>maxThreshold) tr=maxThreshold;
			setResult("Threshold",i, tr);
			setResult("nSpots",i, nSpots[i]);
			setResult("AvgAreaSpots",i, areaSpots[i]);
			setResult("AvgIntensitySpots",i, avgIntensitySpots[i]);
			setResult("IntDenSpots",i,intDenSpots[i]);
// Add global nuclei data
			gnLabel[gnIndex]=name;
			gnImageNr[gnIndex]=imageNr;
			gnCellID[gnIndex]=(imageNr*1000)+i+1;
			gnnCell[gnIndex]=i+1;
			gnArea[gnIndex]=Area[i];
			gnAvg[gnIndex]=Mean[i];
			gnSD[gnIndex]=Std[i];
			gnThres[gnIndex]=tr;
			gnnSpots[gnIndex]=nSpots[i];
			gnAvgSArea[gnIndex]=areaSpots[i];
			gnAvgSInt[gnIndex]=avgIntensitySpots[i];
			gnSIntDen[gnIndex]=intDenSpots[i];
			gnIndex++;
			if(gnIndex>maxCells) exit("Error to many cells counted, max is "+maxCells);
		}
		saveAs("Results", dir+"Results/ResultsNuclei"+name+".xls");
		run("Merge Channels...", "c1=[C1-"+name+"] c2=[C2-"+name+"] create");
		roiManager("Show All without labels");
		run("From ROI Manager");
		saveAs("Tiff", dir+"ResultImages/Result_"+name);
		roiManager("Deselect");
		roiManager("Save", dir+"Roi/ROI_"+name+".zip");

		run("Close All");
		run("Clear Results");
		roiManager("Reset");

	} // END IF MAIN LOOP
}// END FOR MAIN LOOP

// Write global spot file
for (i=0;i<gsIndex; i++){
	setResult("Label",i,gsLabel[i]);
	setResult("CellID",i,gsCellID[i]);
	setResult("nCell",i,gsnCell[i]);
	setResult("Area",i,gsArea[i]);
	setResult("Mean",i,gsAvg[i]);
	setResult("StDev",i,gsSD[i]);
	setResult("IntDen",i,gsIntDen[i]);
}
saveAs("Results", dir+"Results/TotalSpots.xls");
run("Clear Results");

// Write global nuclei data
for (i=0; i<gnIndex; i++){
	setResult("Label",i,gnLabel[i]);
	setResult("ImageNr",i,gnImageNr[i]);
	setResult("CellID",i,gnCellID[i]);
	setResult("nCell",i,gnnCell[i]);
	setResult("AreaNuc",i,gnArea[i]);
	setResult("MeanNuc",i,gnAvg[i]);
	setResult("StdNuc",i,gnSD[i]);
	setResult("Threshold",i,gnThres[i]);
	setResult("nSpots",i,gnnSpots[i]);
	setResult("AvgAreaSpots",i,gnAvgSArea[i]);
	setResult("AvgIntSpots",i,gnAvgSInt[i]);
	setResult("IntDenSpots",i,gnSIntDen[i]);
}
saveAs("Results", dir+"Results/TotalNuclei.xls");
run("Clear Results");


// End log file and save in result images directory
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
print("End: ",hour+":"+minute+":"+second);
print("---------------------------------------------------------");
print("Macro ended correctly");
selectWindow("Log");
getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
saveAs("Text",dir+"ResultImages\\Log_"+macroName+"_"+dayOfMonth+"_"+month+1+"_"+year+".txt");
