/**
* Name: brouillon
* Author: renaud
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model brouillon

/* Insert your model definition here */
global {
	reflex essai {
		write poisson(3.5);
	}	
}

experiment essai_exp type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		display main_display type: opengl {

		}
	}
}
