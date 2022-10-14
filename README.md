# Spot-counting-ImageJ-macro

Small macro to threshold spots in a nucleus of a cell based on the mean intensity + factor * standard deviation. This method was published in 
Compartmentalization of androgen receptor protein-protein interactions in living cells (2007). Martin E van Royen, Sónia M Cunha, Maartje C Brink, Karin A Mattern, Alex L Nigg, Hendrikus J Dubbink, Pernette J Verschure, Jan Trapman, Adriaan B Houtsmuller.  J Cell Biol. 2007 Apr 9;177(1):63-72. doi: 10.1083/jcb.200609178.

This is an imageJ macro to segment spots in a nucleus independent of the intensity of the overall signal in the nucleus
By changing the multiplication factor and the active channel the macro can be adopted to more experiments.

Expected: 
		3 channel image in which channel 2 contains the spots 
		RoiManager list with Rois of cells

 Spot Thershold Mean+2*Sdev 
 van Royen & Houtsmuller  J Cell Biol. 2007 Apr 9;177(1):63-72
