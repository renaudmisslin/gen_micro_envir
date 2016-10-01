/**
* Name: brouillon
* Author: renaud
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model brouillon

/* Insert your model definition here */
global {
	float TAILLE_BAT <- 20.0;
	
	// Fichiers en entrée
	file grid_pop <- file('../data_micro/pop_zone.tif');
	// Variables globales
	geometry espace_libre;
	geometry espace_bati_total;
	bool constructible <- true;
	// Initialisation
	geometry shape <- envelope(grid_pop);

	init {
		espace_libre <- shape;	
	}
	
	int i <- 0;
	reflex when: i < 50 {
		point loc <- any_location_in(espace_libre);
		point loc_old <- copy(loc);
		batiment bat_proche <- batiment closest_to(loc);
		batiment bat_en_cours;		
		write "loc_old = " + loc_old;

		
		if (bat_proche != nil){
			loc <- bat_proche.location;
			loc <- {loc.x + TAILLE_BAT*2, loc.y};
			do creer_batiment(loc);
			if (loc intersects espace_bati_total or !(loc intersects espace_libre)) {
				do detruire(batiment[length(batiment) - 1]);
				loc <- {loc.x, loc.y + TAILLE_BAT*2};
				do creer_batiment(loc);
				if (loc intersects espace_bati_total or !(loc intersects espace_libre)) {
					do detruire(batiment[length(batiment) - 1]);
					loc <- {loc.x, loc.y - TAILLE_BAT*2};
					do creer_batiment(loc);
					if (loc intersects espace_bati_total or !(loc intersects espace_libre)) {
						do detruire(batiment[length(batiment) - 1]);
						loc <- {loc.x - TAILLE_BAT*2, loc.y};
						do creer_batiment(loc);
						if (loc intersects espace_bati_total or !(loc intersects espace_libre)) {
							do detruire(batiment[length(batiment) - 1]);
							loc <- {loc.x + TAILLE_BAT*2, loc.y + TAILLE_BAT*2};
							do creer_batiment(loc);
							if (loc intersects espace_bati_total or !(loc intersects espace_libre)) {
								do detruire(batiment[length(batiment) - 1]);
								loc <- {loc.x + TAILLE_BAT*2, loc.y - TAILLE_BAT*2};
								do creer_batiment(loc);
								if (loc intersects espace_bati_total or !(loc intersects espace_libre)) {
									do detruire(batiment[length(batiment) - 1]);
									loc <- {loc.x - TAILLE_BAT*2, loc.y + TAILLE_BAT*2};
									do creer_batiment(loc);
									if (loc intersects espace_bati_total or !(loc intersects espace_libre)) {
										do detruire(batiment[length(batiment) - 1]);
										loc <- {loc.x - TAILLE_BAT*2, loc.y - TAILLE_BAT*2};
										do creer_batiment(loc);
									} else {
										loc <- loc_old;
										do creer_batiment(loc);
										write "bat créé nouvelle position";
									}
								}
							}
						}
					}
				}
			}
		} else {
			do creer_batiment(loc);
			write "bat créé position aléatoire";
		}
		i <- i+1;
		write "loc = " + loc;
	}
	
	action creer_batiment(point loc){
		create batiment with: [shape::rectangle(TAILLE_BAT,TAILLE_BAT), location::loc] returns: ce_bat {
			espace_bati_total <- espace_bati_total + self.shape;
			espace_libre <- espace_libre - self.shape * 2;
			write "bat number = " + i; 
		}
	}
	action detruire(batiment bat) {
			espace_bati_total <- espace_bati_total - self.shape;
			espace_libre <- espace_libre + self.shape * 2;
			ask(bat) {do die;}
			write "bat number = " + i; 		
	}
	
}


species batiment frequency: 0 {
	rgb color <- rgb(110,110,110);
	rgb color_border <- rgb(90,90,90);
	
	aspect base {
		draw shape color: #orange border: color_border;
	}
}
experiment essai_exp type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		display main_display type: opengl {
			graphics "espace_libre_proche_route" {draw espace_libre color: #yellow;}
			species batiment aspect: base;
		}
	}
}
