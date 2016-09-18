/**
 *  microenvir11
 *  Author: renaud
 *  Description: 
 */

model microenvir11

global {
	file shp_enveloppe <- file("../includes/zone_bangwa_utm.shp");
	geometry shape <- envelope(shp_enveloppe);
	file shp_routes <- file("../includes/roads_bangwa_utm.shp");
	file shp_canaux <- file("../includes/streams_bangwa_utm.shp");
	file shp_population <- file("../includes/popco_bangwa_utm.shp");
	//file shp_occsol <- file("../includes/occsol_bangwa_utm.shp");
	file shp_ndbi_ndvi <- file("../includes/ndbi_ndvi_bangwa_utm.shp");
	
	map<string, rgb> couleur_map <- [ "bati_dense"::#grey,"bati_vegetation"::#lightgrey,"batiment"::#grey,"bati_dense-asphalte"::#black,"vegetation_basse"::#lightgreen,"vegetation_haute"::#green];

	
	int taille_bat <- 15;
	int max_taille_bat <- taille_bat;
	
	float taille_buffer_route <- 30.0;
	float taille_buffer_chaussee <- 6.0;
	list<geometry> buffer_chaussees;
	list<geometry> buffer_routes;
	geometry zone_chaussees;
	geometry zone_routes;
	
	int cpt_patch <- 0;
	int cpt_patch_constructible <- 0;
	geometry espace_non_constructible <- nil;
	
	int nb_indiv_min;
	int nb_indiv_max;
	
	init {
//Initialisation réseaux routes et canaux		
		create route from: shp_routes {
			do init_zone_routes;
			loop buf_chaussee over: buffer_chaussees {
				zone_chaussees <-  zone_chaussees + buffer_chaussee;
			}
			loop buf_route over: buffer_routes {
				zone_routes <-  zone_routes + buf_route;
			}
		}
		create canal from: shp_canaux;

//Initialisation population		
		create population from: shp_population with: [nb_indiv_100m::int(read("hab100int"))]{
			nb_indiv <- int(nb_indiv_100m * self.shape.area / 10000);
		}
		list<int> populations <- (population collect each.nb_indiv);
		nb_indiv_min <- min(populations);
		nb_indiv_max <- max(populations);
		write 'list nb indiv = ' + populations;
		write 'nb indiv min = ' + nb_indiv_min;
		ask population {
			do init_pop;
		}
//Initialisation des foyers
		

//Initialisation patchs ndvi-ndbi		
		create patch from: shp_ndbi_ndvi with: [ndbi::float(read("ndbi_corri")), ndvi::float(read("ndvi_corri"))] {
			do init_patch;
		}

//Initialisation zone totale
		create zone_tot from: shp_enveloppe {
		}
		write "pourcentage de bati = " + cpt_patch_constructible / cpt_patch * 100;
		write 'zone_routes.area = ' + zone_routes.area;
		write 'zone_chaussees.area = ' + zone_chaussees.area;
	}

}

species zone_tot {
/*	list<batiment> batiments_zone_tot;
	int nb_batiment update: length(batiments_zone_tot);
	int nb_batiment_max <- 300;
	bool est_constructible <- true;
	geometry place_libre;
	geometry place_libre_proche_route;
	geometry place_libre_loin_route;  */
	

}

species route {
	rgb color <- #black;
	geometry buffer_chaussee;
	geometry buffer_route;
	
	action init_zone_routes {
		buffer_chaussee <- self.shape + taille_buffer_chaussee;
		add buffer_chaussee to: buffer_chaussees;
		buffer_route <- self.shape + taille_buffer_route;
		add buffer_route to: buffer_routes;
	}

	aspect base {
		draw shape color: color;
//		draw buffer_route color: #pink;
		draw buffer_chaussee color: #black;
	}
}

species canal {
	rgb color <- #blue;
	
	aspect base {
		draw shape color: color;
	}		
}

species patch {
	float ndbi;
	float ndvi;
	bool patch_constructible <- false;
	bool patch_cultivable <- false;
	rgb couleur_patch;

	
	action init_patch {
		cpt_patch <- cpt_patch + 1;
		if flip(ndbi) {
			patch_constructible <- true;
			cpt_patch_constructible <- cpt_patch_constructible + 1;
//			write cpt_patch;
		}
		else {
			espace_non_constructible <- espace_non_constructible + self.shape;
			couleur_patch <- #green;
		}
//		if flip(ndvi){
//			patch_cultivable <- true; 
//		}
	}
 
	aspect base {
		draw shape color: couleur_patch;
	}		
}

species batiment {
	patch mon_patch;
	population mon_patchpop;
	int nb_habitant_batiment;
	int nb_foyer_batiment;
	int nb_etage;
	rgb color <- #red;
	list<foyer> mes_foyers_batiment;
	
	action init_batiment {
		add self to: mon_patchpop.batiments_patchpop;
	}
	
	aspect base {
		draw shape color: color;
	}
}

species population {
	int nb_indiv_100m;
	int nb_indiv;
	rgb couleur_pop;
	int pop_sdf;
	int nb_foyer_sdf;
	int nb_habitant_patchpop;
	int nb_foyer_patchpop;
	list<foyer> mes_foyers_patchpop;
	list<foyer> mes_foyers_sdf_patchpop;

	list<batiment> batiments_patchpop;
	int nb_batiment update: length(batiments_patchpop);
	bool est_constructible <- true;
	geometry place_libre;
	geometry place_libre_proche_route;
	geometry place_libre_loin_route;
	batiment batiment_a_occuper;
	
	action init_pop {
		//Calcul des espaces libres
		place_libre_proche_route <- zone_routes - (zone_chaussees + max_taille_bat) inter self.shape;
		place_libre_loin_route <- self.shape - zone_routes - espace_non_constructible;		
		
		//Création des foyers et de leur bâtiment
		pop_sdf <- nb_indiv;
		loop while: pop_sdf > 0 {
			int taille_foyer <- rnd_choice([0.15,0.25,0.3,0.25,0.05]) + 1;
			population patchpop_en_cours <- self;
			create foyer number: 1 with: [nb_membre::taille_foyer, mon_patchpop::patchpop_en_cours]{
				add self to: patchpop_en_cours.mes_foyers_patchpop;
				add self to: patchpop_en_cours.mes_foyers_sdf_patchpop;
			}
			pop_sdf <- pop_sdf - taille_foyer;
			write 'loop creation foyer';
		}
		nb_foyer_patchpop <- length(mes_foyers_patchpop);
		write 'mes foyers sdf' + mes_foyers_sdf_patchpop;
		//couleur_pop <- rgb([255 * (1-(nb_indiv - nb_indiv_min)/(nb_indiv_max - nb_indiv_min)),255,255]);	
	}
	
	reflex construction when: (length(mes_foyers_sdf_patchpop) > 0) and (est_constructible) {
		ask foyer {
			do emmenager;
		}
	}
	
	action construire_batiment  {
		geometry bat_shape <- rectangle(taille_bat,taille_bat);
		//Choix emplacement du bâtiment dans le patch pop (si ce n'est pas le premier)
		if empty(self.batiments_patchpop) = false {
			if flip(0.8) {
				loop bat over: self.batiments_patchpop {
					place_libre_proche_route <- place_libre_proche_route - (bat.shape + max_taille_bat);
					place_libre <- place_libre_proche_route;
				}
			}
			else {
				loop bat over: self.batiments_patchpop {
					place_libre_loin_route <- place_libre_loin_route - (bat.shape + max_taille_bat);
					place_libre <- place_libre_loin_route;
				}
			}			
		}
		//Choix emplacement du premier bâtiment du patchpop
		else {
			if flip(0.8) {
				place_libre <- place_libre_proche_route;
			}
			else {
				place_libre <- place_libre_loin_route;
			}
		}
		//Construction d'un bâtiment dans le patch en question
		if (place_libre != nil and place_libre.area > bat_shape.area) {
			point loc <- any_location_in(place_libre);	
			create batiment with: [shape::bat_shape, mon_patchpop::self, location::loc, nb_etage::1, nb_foyer::1] {
				do init_batiment;
				myself.batiment_a_occuper <- self;
			}
		}
		else {
			est_constructible <- false;
			write "Plus de place dans le patch.";
		}
	}			
	
	aspect base {
		draw shape color: couleur_pop;
	}
}


species foyer {
	int nb_membre;
	batiment mon_batiment;
	population mon_patchpop;

	action emmenager {
//Si une cellule de mon patch pop est constructible alors je construis dedans
		if mon_patchpop.est_constructible = true {
			ask mon_patchpop {
				do construire_batiment;
			}
			self.mon_batiment <- mon_patchpop.batiment_a_occuper;
			add self to: mon_batiment.mes_foyers_batiment;
			remove self from: mon_patchpop.mes_foyers_sdf_patchpop;
			write 'taille liste foyer sdf' + int(length(mon_patchpop.mes_foyers_sdf_patchpop));
		}
		else {
//Si non je construits dans un patch où il n'y a personne
//Si il n'y de la place nul part, je construis des étages	
		}
 	}	
}

experiment microenvir11 type: gui {
	output {
        display zone_display type: opengl {
			//species patch aspect: base ;
			species route aspect: base ;
			species canal aspect: base ;
			species batiment aspect: base;
			species population aspect: base ;
		}
	}
}		
