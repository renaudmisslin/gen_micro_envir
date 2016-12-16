/**
* Name: brouillon
* Author: renaud
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model brouillon

/* Insert your model definition here */
global {
	file shp_zone <- file('../includes/bangkhutien_zone_valid.shp');
	file shp_bat_bangkhutien <- file('../includes/bldg_bangkhuntien.shp');
	geometry bangkhutien <- first(shp_zone);
	geometry shape <- envelope(shp_zone);
	
	geometry bati_obs_cell_tot;
	list<geometry> grid_valid <- bangkhutien to_squares(1000);
	
	init {
		create batiment_obs from: shp_bat_bangkhutien;
		write "Nb cells = " + length(grid_valid);
	}
}


species batiment_obs {
	rgb color_border <- rgb(90,90,90);
	
	aspect base {
		draw shape color: #black border: color_border;
	}
}


experiment essai_exp type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		display main_display type: opengl {
			graphics "espace_libre" {draw bangkhutien color: #yellow;}
			graphics "espace_libre" {draw bati_obs_cell_tot color: #yellow;}
			species batiment_obs aspect: base;
		}
	}
}
