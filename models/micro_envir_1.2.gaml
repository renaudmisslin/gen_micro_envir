/**
 *  microenvir11
 *  Author: renaud
 *  Description:
 * 
 * 	A corriger: 
 * 		- certains  patchpop deviennent non-constructibles alors qu'ils le sont encore.
 * 	 	- certains foyers sont sdf
 */

model microenvir12

global {
	file shp_enveloppe <- file("../includes/zone_bangwa_utm.shp");
	geometry shape <- envelope(shp_enveloppe);
	file shp_routes <- file("../includes/roads_bangwa_utm.shp");
	file shp_canaux <- file("../includes/streams_bangwa_utm.shp");
	file shp_population <- file("../includes/popco_bangwa_utm.shp");
	//file shp_occsol <- file("../includes/occsol_bangwa_utm.shp");
	file shp_ndbi_ndvi <- file("../includes/ndbi_ndvi_bangwa_utm.shp");
	
	map<string, rgb> couleur_map <- [ "bati_dense"::#grey,"bati_vegetation"::#lightgrey,"batiment"::#grey,"bati_dense-asphalte"::#black,"vegetation_basse"::#lightgreen,"vegetation_haute"::#green];

	
	int taille_bat <- 10;
	int max_taille_bat <- taille_bat;
	
	float taille_buffer_route <- 25.0;
	float taille_buffer_chaussee <- 5.0;
	list<geometry> buffer_chaussees;
	list<geometry> buffer_routes;
	geometry zone_chaussees;
	geometry zone_routes;
	geometry zone_canaux;
	
	int cpt_patch <- 0;
	int cpt_patch_constructible <- 0;
	geometry espace_non_constructible <- nil;
	geometry espace_bati <- nil; 
	
	int nb_batiment_loin_route <- 0;
	int nb_batiment_proche_route <- 0;
	
	list<patchpop> patchpop_vides;
	/********* Liste de test ******************/
	list<foyer> foyers_sdf;
	/******************************************/
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
		create canal from: shp_canaux {
			zone_canaux <- zone_canaux + self.shape;
		}

//Initialisation population		
		create patchpop from: shp_population with: [nb_indiv_100m::int(read("hab100int"))]{
			nb_indiv <- int(nb_indiv_100m * self.shape.area / 10000);
			reserve_indiv <- nb_indiv;
			if (nb_indiv = 0) {
				add self to: patchpop_vides;
			}
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
	
}

species route {
	rgb color <- #black;
	geometry buffer_chaussee;
	geometry buffer_route;
	list<geometry> segments;
		
	action init_zone_routes {
		buffer_chaussee <- self.shape + taille_buffer_chaussee;
		add buffer_chaussee to: buffer_chaussees;
		buffer_route <- self.shape + taille_buffer_route;
		add buffer_route to: buffer_routes;
		loop i from: 0 to: length(shape.points) - 2 {
			segments << line([shape.points[i], shape.points[i+1]]);
		}
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
	bool patch_constructible;
	bool patch_cultivable <- false;
	rgb couleur_patch;
	int nb_cont_out <- 0;
	int nb_cont_in <- 0;
	
	action init_patch {
		cpt_patch <- cpt_patch + 1;
		if ndvi < 0.8 and ndvi >= 0.4 and ndbi < 0.8 and ndbi > 0.40 {
			if !flip(ndbi) {
				patch_constructible <- true;
				cpt_patch_constructible <- cpt_patch_constructible + 1;
			}
			else {
				espace_non_constructible <- espace_non_constructible + self.shape;
				couleur_patch <- #green;
			}
		}
		else if ndvi >= 0.8 or ndbi <= 0.40 {
			espace_non_constructible <- espace_non_constructible + self.shape;
			couleur_patch <- #green;			
		}
		else {
			patch_constructible <- true;
			cpt_patch_constructible <- cpt_patch_constructible + 1;			
		}
		
	// Calcul du nombre de containers outdoors initiaux 
		nb_cont_out <- int(nb_cont_out + (ndvi * 20));
//		if flip(ndvi){
//			patch_cultivable <- true; 
//		}
	}
	
	
 
	aspect base {
		draw shape color: couleur_patch;
	}		
}

species batiment {
	int nb_etage;
	list<foyer> mes_foyers_batiment;
	rgb color <- #red;
	patchpop mon_patchpop_batiment;
	bool proche_route;
	route route_voisine;
	int angle_route_voisine;
	
	init {
		if (proche_route){
			route_voisine <- route closest_to self; // (route at_distance 30.0) closest_to self;
			geometry pproche <- route_voisine.segments with_min_of (self distance_to each);
			angle_route_voisine <- first(pproche.points) towards last(pproche.points);
			shape <- shape rotated_by (angle_route_voisine + (flip(0.7) ? 90 : 0));
		}
		
	}	
	
	aspect base {
		draw shape color: color depth: nb_etage * 5;
	}
}

species patchpop {
	int nb_indiv_100m;
	int nb_indiv;
	int reserve_indiv;
	list<foyer> mes_foyers;
	list<batiment> mes_batiments;
	geometry place_libre_patchpop;
	bool est_constructible <- true;
	bool loin_route_est_constructible <- true;
	bool proche_route_est_constructible <- true;
	rgb couleur <- #white;
	geometry place_libre_proche_route;
	geometry place_libre_loin_route;
	
	init {
		place_libre_patchpop <- self.shape - ((zone_canaux + max_taille_bat) + (zone_chaussees + max_taille_bat));
		place_libre_proche_route <- (place_libre_patchpop - espace_non_constructible - (espace_bati + max_taille_bat)) inter zone_routes;
		place_libre_loin_route <- place_libre_patchpop - zone_routes - espace_non_constructible - (espace_bati + max_taille_bat);

		if (place_libre_patchpop = nil) {
			est_constructible <- false;
			proche_route_est_constructible <- false;
			loin_route_est_constructible <- false;
		}
		if (place_libre_proche_route = nil){
			proche_route_est_constructible <- false;
		}
		if (place_libre_loin_route = nil){
			loin_route_est_constructible <- false;
		}
		
		if place_libre_proche_route != nil {
			if ((place_libre_proche_route.area) < (max_taille_bat^2)) {
				proche_route_est_constructible <- false;
			}
		}
		if place_libre_loin_route != nil {
			if ((place_libre_loin_route.area) < (max_taille_bat^2)) {
				loin_route_est_constructible <- false;
			}
		}		
	}

	reflex creation_foyers when: reserve_indiv > 0 {
		int taille_foyer <- rnd_choice([0.15,0.25,0.3,0.25,0.05]) + 1;
		create foyer number: 1 with: [nb_membre::taille_foyer, mon_patchpop::self]{
			add self to: myself.mes_foyers;
		}
		reserve_indiv <- reserve_indiv - taille_foyer;
	}

	aspect base {
		draw shape color: couleur;
	}
}


species foyer {
	int nb_membre;
	patchpop mon_patchpop;
	batiment mon_batiment;
	
	init {
		//Construire un bâtiment
		geometry bat_shape <- rectangle(taille_bat,taille_bat);
		if (mon_patchpop.proche_route_est_constructible or mon_patchpop.loin_route_est_constructible) {
			geometry ou_construire <- nil;
			bool bat_proche_route <- false;
			//Choix de la zone de construction du bâtiment (proche de la route ou loin de la route
			if (mon_patchpop.proche_route_est_constructible and mon_patchpop.loin_route_est_constructible) {
				if flip(0.8) {
					ou_construire <- mon_patchpop.place_libre_proche_route;
					bat_proche_route <- true;			
				}
				else {
					ou_construire <- mon_patchpop.place_libre_loin_route;
				}
			}
			else if (mon_patchpop.proche_route_est_constructible and (!mon_patchpop.loin_route_est_constructible)) {
				ou_construire <- mon_patchpop.place_libre_proche_route;
				bat_proche_route <- true;
			}
			else if ((!mon_patchpop.proche_route_est_constructible) and (mon_patchpop.loin_route_est_constructible)) {
				ou_construire <- mon_patchpop.place_libre_loin_route;
			}			

			else {
				write 'probleme 1';
			}
			//Constuction du bâtiment n'importe où das la zone choisie	
			if (ou_construire != nil) {
				point loc <- any_location_in(ou_construire);	
				create batiment with: [shape::bat_shape, mon_patchpop_batiment::mon_patchpop, location::loc, nb_etage::1, proche_route::bat_proche_route]{
					add myself to: self.mes_foyers_batiment;
					add self to: myself.mon_patchpop.mes_batiments;
					espace_bati <- espace_bati + (self.shape * 2);
				}
			}
			else {
				write 'probleme 1 bis';
			}			
			
			//Vérification que les zones proche et loin de la routes sont toujours constructibles
				if (mon_patchpop.proche_route_est_constructible and mon_patchpop.loin_route_est_constructible){
					mon_patchpop.place_libre_proche_route <- (mon_patchpop.place_libre_patchpop - espace_non_constructible - espace_bati) inter zone_routes;
					mon_patchpop.place_libre_loin_route <- mon_patchpop.place_libre_patchpop - zone_routes - espace_non_constructible - espace_bati;
					if (mon_patchpop.place_libre_proche_route.area < bat_shape.area) {
						mon_patchpop.proche_route_est_constructible <- false;
					}
					if (mon_patchpop.place_libre_loin_route.area < bat_shape.area) {
						mon_patchpop.loin_route_est_constructible <- false;
					}
				}
				else if (mon_patchpop.proche_route_est_constructible and (! mon_patchpop.loin_route_est_constructible)) {
					mon_patchpop.place_libre_proche_route <- (mon_patchpop.place_libre_patchpop - espace_non_constructible - espace_bati) inter zone_routes;
					if (mon_patchpop.place_libre_proche_route.area < bat_shape.area) {
						mon_patchpop.proche_route_est_constructible <- false;
						mon_patchpop.couleur <- #red;
					}
				}
				else if (mon_patchpop.loin_route_est_constructible and (! mon_patchpop.proche_route_est_constructible)) {
					mon_patchpop.place_libre_loin_route <- mon_patchpop.place_libre_patchpop - zone_routes - espace_non_constructible - espace_bati;
					if (mon_patchpop.place_libre_loin_route.area < bat_shape.area) {
						mon_patchpop.loin_route_est_constructible <- false;
						mon_patchpop.couleur <- #red;
					}
				}
				else {
					write 'probleme 4';
				}					
		}
		
		// Construire un batiment dans un patch voisin
		else if (! mon_patchpop.loin_route_est_constructible and ! mon_patchpop.proche_route_est_constructible) and (length(patchpop_vides) > 0) {
			patchpop patchpop_voisin <- patchpop_vides closest_to mon_patchpop;
			remove self from: mon_patchpop.mes_foyers;
			mon_patchpop <- patchpop_voisin;
			add self to: mon_patchpop.mes_foyers;
			geometry ou_construire <- nil;
			bool bat_proche_route <- false;
			if (mon_patchpop.proche_route_est_constructible or mon_patchpop.loin_route_est_constructible) {
				if (mon_patchpop.proche_route_est_constructible and mon_patchpop.loin_route_est_constructible) {
					if flip(0.8) {
						ou_construire <- mon_patchpop.place_libre_proche_route;
						bat_proche_route <- true;			
					}
					else {
						ou_construire <- mon_patchpop.place_libre_loin_route;
					}
				}
				else if ((mon_patchpop.proche_route_est_constructible) and (! mon_patchpop.loin_route_est_constructible)) {
					ou_construire <- mon_patchpop.place_libre_proche_route;
					bat_proche_route <- true;
				}
				else if ((! mon_patchpop.proche_route_est_constructible) and (mon_patchpop.loin_route_est_constructible)) {
					ou_construire <- mon_patchpop.place_libre_loin_route;
				}			
	
				else {
					write 'probleme 2';
				}
				/*********************************/	
				if (ou_construire != nil) {
					point loc <- any_location_in(ou_construire);	
					create batiment with: [shape::bat_shape, mon_patchpop_batiment::mon_patchpop, location::loc, nb_etage::1, proche_route::bat_proche_route]{
						add myself to: self.mes_foyers_batiment;
						add self to: myself.mon_patchpop.mes_batiments;
						espace_bati <- espace_bati + (self.shape * 2);
					}
				}
				else {
					write 'probleme 2 bis';
				}			
				/*********************************/
				if (mon_patchpop.proche_route_est_constructible and mon_patchpop.loin_route_est_constructible){
					mon_patchpop.place_libre_proche_route <- (mon_patchpop.place_libre_patchpop - espace_non_constructible - espace_bati) inter zone_routes;
					mon_patchpop.place_libre_loin_route <- mon_patchpop.place_libre_patchpop - zone_routes - espace_non_constructible - espace_bati;
					if (mon_patchpop.place_libre_proche_route.area < bat_shape.area) {
						mon_patchpop.proche_route_est_constructible <- false;
					}
					if (mon_patchpop.place_libre_loin_route.area < bat_shape.area) {
						mon_patchpop.loin_route_est_constructible <- false;
					}
					if ((mon_patchpop.place_libre_loin_route.area < bat_shape.area) and (mon_patchpop.place_libre_proche_route.area < bat_shape.area)) {
						remove mon_patchpop from: patchpop_vides;
					}
				}
				else if (mon_patchpop.proche_route_est_constructible and (! mon_patchpop.loin_route_est_constructible)) {
					mon_patchpop.place_libre_proche_route <- (mon_patchpop.place_libre_patchpop - espace_non_constructible - espace_bati) inter zone_routes;
					if (mon_patchpop.place_libre_proche_route.area < bat_shape.area) {
						mon_patchpop.proche_route_est_constructible <- false;
						mon_patchpop.couleur <- #red;
						remove mon_patchpop from: patchpop_vides;
					}
				}
				else if (mon_patchpop.loin_route_est_constructible and (! mon_patchpop.proche_route_est_constructible)) {
					mon_patchpop.place_libre_loin_route <- mon_patchpop.place_libre_patchpop - zone_routes - espace_non_constructible - espace_bati;
					if (mon_patchpop.place_libre_loin_route.area < bat_shape.area) {
						mon_patchpop.loin_route_est_constructible <- false;
						mon_patchpop.couleur <- #red;
						remove mon_patchpop from: patchpop_vides;
					}
				}
			}
			else {
				write 'probleme 4 bis';
			}
		}
		// Construire un étage (avec une tendance à construire des étages dans les zones proches des routes)
		else {
			batiment batiment_a_agrandir <- nil;
			if (length(mon_patchpop.mes_batiments where each.proche_route) > 0) and ((length(mon_patchpop.mes_batiments where (each.proche_route = false))) > 0) {
				if flip(0.8) {
					batiment_a_agrandir <- one_of(mon_patchpop.mes_batiments where each.proche_route);
					mon_batiment <- batiment_a_agrandir;
					add self to: mon_batiment.mes_foyers_batiment;
					mon_batiment.nb_etage <- mon_batiment.nb_etage + 1;  
					write '' + mon_batiment + ' = ' + mon_batiment.nb_etage;
					nb_batiment_proche_route <- nb_batiment_proche_route + 1;					
				}
				else {
					batiment_a_agrandir <- one_of(mon_patchpop.mes_batiments where ! each.proche_route);
					mon_batiment <- batiment_a_agrandir;
					add self to: mon_batiment.mes_foyers_batiment;
					mon_batiment.nb_etage <- mon_batiment.nb_etage + 1;  
					write '' + mon_batiment + ' = ' + mon_batiment.nb_etage;
					nb_batiment_loin_route <- nb_batiment_loin_route + 1;
				}
			}
			else if (length(mon_patchpop.mes_batiments where each.proche_route) > 0) and ((length(mon_patchpop.mes_batiments where (each.proche_route = false))) = 0) {
				batiment_a_agrandir <- one_of(mon_patchpop.mes_batiments where each.proche_route);
				mon_batiment <- batiment_a_agrandir;
				add self to: mon_batiment.mes_foyers_batiment;
				mon_batiment.nb_etage <- mon_batiment.nb_etage + 1;  
				write '' + mon_batiment + ' = ' + mon_batiment.nb_etage;
				nb_batiment_proche_route <- nb_batiment_proche_route + 1;				
			}
			else if (length(mon_patchpop.mes_batiments where each.proche_route) = 0) and ((length(mon_patchpop.mes_batiments where (each.proche_route = false))) > 0) {
				batiment_a_agrandir <- one_of(mon_patchpop.mes_batiments where ! each.proche_route);
				mon_batiment <- batiment_a_agrandir;
				add self to: mon_batiment.mes_foyers_batiment;
				mon_batiment.nb_etage <- mon_batiment.nb_etage + 1;  
				write '' + mon_batiment + ' = ' + mon_batiment.nb_etage;
				nb_batiment_loin_route <- nb_batiment_loin_route + 1;				
			}
			else {
				write "Je ne sais pas quoi faire, je m'appelle " + mon_patchpop;
			}
		}
	}
}

experiment microenvir12 type: gui {
	output {
        display zone_display type: opengl {
			species patch aspect: base ;
			//species patchpop aspect: base ;			
			species route aspect: base ;
			species canal aspect: base ;
			species batiment aspect: base;
		}
		monitor "nb patchpop vides" value: length(patchpop_vides);
		monitor "batiment agrandi proches route" value: nb_batiment_proche_route;
		monitor "batiment agrandi loin route" value: nb_batiment_loin_route;
	}
}		