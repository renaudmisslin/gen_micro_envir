/**
* Name: genmicro
* Author: renaud
*/

model genmicro

global {
	// Paramètres
	float largeur_chaussee <- 4.0;
	float largeur_espace_proche_route <- 40.0 const: true;
	int max_nhab_menage <- 10;
	float lambda_nhab_menage <- 3.5;
	float taille_bat <- 10.0;
	float flip_proche_route <- 0.8;
	int n_cell_deplace_max <- 4;
	float hauteur_etage <- 2.5;
	int n_men_lim_bat_mitoyen <- 5;
	
	// Fichiers en entrée
	file grid_men <- file('../data_micro/men_zone.tif');
	file grid_pop <- file('../data_micro/pop_zone.tif');
	file grid_ndvi <- file('../data_micro/ndvi_zone.tif');
	file grid_proba_bati <- file('../data_micro/dist_raster_zone.tif');
	file grid_ggmap <- file('../data_micro/extract_ggmap_zone.tif');
	file shp_routes <- file('../data_micro/routes_zone.shp');
	
	// Variables globales
	list<geometry> chaussees;
	list<geometry> espace_proche_routes;
	geometry zone_chaussees;
	geometry zone_proche_routes;
	geometry espace_non_bati;
	geometry espace_libre_total;
	geometry espace_bati_total;
	geometry espace_libre_proche_routes;
	geometry espace_libre_loin_routes;
	
	// Initialisation
	geometry shape <- envelope(grid_pop);
	
	init {
		float min_proba_bati <- cell_proba_bati min_of (each.grid_value); //Calcul du min et du max de proba_bati pour indicer entre 0 et 1
		float max_proba_bati <- cell_proba_bati max_of (each.grid_value);
		
		/******************************************************************************************************************************************************************/
		// Initialisation des cellules environnement
		ask cell_env {
			// Variables issues des données en entrée
			self.pop <- int(self.grid_value);
			self.men <- int(cell_men[self.grid_x, self.grid_y].grid_value);
			self.ndvi <- cell_ndvi[self.grid_x, self.grid_y].grid_value;
			self.ndvi <- self.ndvi < 0 ? 0 : self.ndvi;
			self.proba_bati <- 1 - (cell_proba_bati[self.grid_x, self.grid_y].grid_value - min_proba_bati) / (max_proba_bati - min_proba_bati); // l'indice de proba_bati est indicé entre 0 et 1
			
			// Variables calculées
			self.bati <- flip(self.proba_bati); // Définition bati / nonbati
			self.pop_sdf <- self.pop;
			self.men_sdf <- self.men;
			self.color <- self.color_vegetation; //self.color <- color_bati(self.bati);
			self.men_resid <- 0;
			self.pop_resid <- 0;
		}
		
		ask cell_ggmap {
			self.occsol <- int(self.grid_value);
			self.color <- color_occsol(self.occsol);
		}
		
		/******************************************************************************************************************************************************************/
		// Initialisation des routes et des zones autour (chaussees et zones proches)
		
		create route from: shp_routes with: [type::string(read("fclass")), pont::string(read("bridge")), tunnel::string(read("tunnel"))] {
			do init_routes;
		}
		
		int nchaussees <- length(chaussees);
		int cpt <- 0;
		
		loop buff_chaussee over: chaussees {
			zone_chaussees <- zone_chaussees + buff_chaussee;
			cpt <- cpt + 1;
			write "routes pretes : " + cpt + " sur " + nchaussees;
		}
		loop buff_route over: espace_proche_routes {
			zone_proche_routes <-  zone_proche_routes + buff_route;
		}
		
		/******************************************************************************************************************************************************************/
		// Calcul de l'espace non bati (végétation, eau, routes)
		espace_non_bati <-clean(union(cell_ggmap where (each.occsol != 2)));
		geometry espace_vegetalise <- union(cell_env where (!each.bati));
		espace_non_bati <- espace_vegetalise + espace_non_bati;
		
		espace_non_bati <- clean(union([espace_non_bati, zone_chaussees])); 
		
		write "Espaces non batis = " +  espace_non_bati.area;
		write "Espaces non batis = " +  espace_non_bati.area * 100 / shape.area + "% de la zone totale";
		
		/******************************************************************************************************************************************************************/
		// Calcul de l'espace libre à batir dans chaque cell_env et création des ménages
		ask cell_env {
			mon_espace_libre <- self.shape - espace_non_bati; 
			
			// Définition des espaces loins ou proches de la route
			mon_espace_libre_proche_route <- mon_espace_libre inter zone_proche_routes; 
			mon_espace_libre_loin_route <- mon_espace_libre - mon_espace_libre_proche_route; 
			
			espace_libre_proche_routes <- espace_libre_proche_routes + mon_espace_libre_proche_route;
			espace_libre_loin_routes <- espace_libre_loin_routes + mon_espace_libre_loin_route;
			
			// Création des ménages
			//write "début création des ménages";
/*loop while: men_sdf >= 1 {
				int nhab_menage <- 0;
				// Définition du nombre d'habitants du ménage
				if ((men_sdf - pop_sdf) = 0) {nhab_menage <- 1;} // S'il reste autant de menages sdf que de population sdf, le nombre de personnes attribuées au ménage est 1
				if (men_sdf = 1) and (nhab_menage = 0) {nhab_menage <- pop_sdf;} // S'il n'y a plus qu'un seul ménage sdf, le nombre d'hab restant lui est attribué
				else { // S'il y a + que un seul ménage sdf dans la cellule
					loop while: (nhab_menage <= 0 or nhab_menage >= max_nhab_menage) { // On choisit le nb d'hab par ménage
						nhab_menage <- poisson(lambda_nhab_menage);
						if ((pop_sdf - nhab_menage) < (men_sdf - 1)) {nhab_menage <- 0;} // Si en enlevant le nb d'hab, le nb de pop sdf est inférieur au nombre de men sdf - 1, on retire
						write 'je boucle car il y a ' + pop_sdf + ' personnes et ' + men_sdf + ' ménages';
					}
				}
				// Création du ménage
				create menage number: 1 with: [n_membres::nhab_menage, ma_cell_env_origin::self]{
					add self to: myself.mes_menages;
					myself.pop_resid <- myself.pop_resid  + nhab_menage;
					myself.men_resid <- myself.men_resid  + 1;
					ma_cell_env<-myself;
					write self;
				}
				// Actualisation de la pop et des men sdf
				pop_sdf <- pop_sdf - nhab_menage;
				men_sdf <- men_sdf - 1;
			}*/
			//write "fin création des ménages d'une cellule";
		}
		
		espace_libre_total <- espace_libre_proche_routes + espace_libre_loin_routes;

		loop while: espace_libre_total.area > 50000 {
			do creer_batiment_proche_route;
		}
	}
	
//	reflex add_bat  {
//		// Création de tous les bâtiments possibles
//		//bool is_creation_batiment_possible <- true;
//		//loop while: is_creation_batiment_possible{
//			//is_creation_batiment_possible <- 
//			//do creer_batiment_proche_route;
//		//	write is_creation_batiment_possible;
//	//	}
//	}

	bool creer_batiment_proche_route {

		point loc <- any_location_in(espace_libre_total);
		point loc_old <- copy(loc);
		batiment bat_proche <- batiment closest_to(loc);
		if (bat_proche != nil){
			loc <- bat_proche.location;
			loc <- {loc.x + taille_bat*2, loc.y};
			if (loc intersects espace_bati_total or ! (loc intersects espace_libre_total)) {
				loc <- {loc.x, loc.y + taille_bat*2};
				if (loc intersects espace_bati_total or ! (loc intersects espace_libre_total)) {
					loc <- {loc.x, loc.y - taille_bat*2};
					if (loc intersects espace_bati_total or ! (loc intersects espace_libre_total)) {
						loc <- {loc.x - taille_bat*2, loc.y};
						if (loc intersects espace_bati_total or ! (loc intersects espace_libre_total)) {
							loc <- {loc.x + taille_bat*2, loc.y + taille_bat*2};
							if (loc intersects espace_bati_total or ! (loc intersects espace_libre_total)) {
								loc <- {loc.x + taille_bat*2, loc.y - taille_bat*2};
								if (loc intersects espace_bati_total or ! (loc intersects espace_libre_total)) {
									loc <- {loc.x - taille_bat*2, loc.y + taille_bat*2};
									if (loc intersects espace_bati_total or ! (loc intersects espace_libre_total)) {
										loc <- {loc.x - taille_bat*2, loc.y - taille_bat*2};
									} else {
										loc <- loc_old;
									}
								}
							}
						}
					}
				}
			}
		}
		
		create batiment with: [shape::rectangle(taille_bat,taille_bat), location::loc] {
			route route_proche <- route closest_to self;
			float dist <- route_proche distance_to self;
			if (dist < largeur_espace_proche_route) {do alignement;}

			espace_bati_total <- espace_bati_total + self.shape * 2;
			espace_libre_total <- espace_libre_total - self.shape * 2;
			write espace_libre_total.area;
		}
	
		return true;
	}
	
	
	
				/*list<geometry> segments;
			loop i from: 0 to: length(bat_proche.shape.points) - 2 {
				segments << line([bat_proche.shape.points[i], bat_proche.shape.points[i+1]]);
			}
			int n_segment_mitoyen <- 0;
			point point0 <- segments[n_segment_mitoyen];*/
	// On arrète la simulation quand tous les ménages sont logés

/*list<int> men_sdf_tot <- cell_env collect each.men_sdf;
	int sum_men_sdf <- sum(men_sdf_tot);
	list<int> men_supp_tot <- cell_env collect length(each.mes_menages_supp);
	int sum_men_supp <- sum(men_supp_tot);
	reflex halting when: sum_men_sdf = 0 and men_supp_tot = 0 {
		do halt;
		write 'Tous les ménages sont placés';
	}*/
}


// Définition des grilles
grid cell_env file: grid_pop neighbors: 8 {
	// Variables définies à l'initialisation
	int pop;
	int men;
	float ndvi;
	float proba_bati; 
	bool bati;
	int pop_sdf;
	int men_sdf;
	int men_resid;
	int pop_resid;
	rgb color;
	list<menage> mes_menages <- [];
	list<menage> mes_menages_supp <- [];
	list<batiment> mes_batiments <- [];
	geometry mon_espace_libre; // Espace libre pour y construire un batiment
	geometry mon_espace_libre_proche_route;
	geometry mon_espace_libre_loin_route;
	geometry mon_espace_bati;
	
	// Mise à jour de l'espace libre
	reflex update_espace_libre {
		mon_espace_libre <- mon_espace_libre - espace_bati_total; 
		
		// Définition des espaces loins ou proches de la route
		mon_espace_libre_proche_route <- mon_espace_libre inter zone_proche_routes; 
		mon_espace_libre_loin_route <- mon_espace_libre - mon_espace_libre_proche_route;
	}

	// Calcul des couleurs
	rgb color_bati(bool m) {
		switch m {
			match true {
				return rgb(100, 100, 100);
			}
			match false {
				return rgb(155,187,89);
			}
		}
	}
	
	rgb color_vegetation -> {rgb([90 + (130 - 90) * (ndvi), 130, 90 + (130 - 90) * (ndvi)])};
	
	aspect base {
		draw shape color: color_vegetation;
	}
}

grid cell_men file: grid_men use_regular_agents: false use_individual_shapes: false schedules: [];

grid cell_ndvi file: grid_ndvi use_regular_agents: false use_individual_shapes: false schedules: [];

grid cell_proba_bati file: grid_proba_bati use_regular_agents: false use_individual_shapes: false schedules: [];

grid cell_ggmap file: grid_ggmap use_regular_agents: false use_individual_shapes: false schedules: [] {
	int occsol;
	rgb color;
	
	rgb color_occsol(int m) {
		switch m {
			match 1 {
				return rgb(220,220,220); // routes
			}
			match 2 {
				return rgb(253,234,218); // espace libre
			}
			match 3 {
				return rgb(85,142,220); // eau
			}
		}
	}
}


species route {
	string type;
	string pont;
	string tunnel;
	rgb color <- #black;
	geometry chaussee;
	geometry espace_proche_route;
	list<geometry> segments;
		
	action init_routes {
		// Toutes les routes ont une chaussee (il faudrait enlever les tunnels ...)
		chaussee <- self.shape + largeur_chaussee;
		add chaussee to: chaussees;
		
		// Seules les petites routes (et non les grosses routes, les embranchements et les ponts) peuvent avoir un "espace proche route"
		if !(pont = 'T' or type = 'primary' or type = 'primary_link' or type = 'secondary_link') {
			espace_proche_route <- self.shape + largeur_espace_proche_route - chaussee;
			add espace_proche_route to: espace_proche_routes;
		}
		// Construction de segments pour aligner les batiments sur les routes
		loop i from: 0 to: length(shape.points) - 2 {
			segments << line([shape.points[i], shape.points[i+1]]);
		}
	}

	aspect base {
		draw shape color: color;
	}
}

species menage {
	int n_membres;
	batiment mon_batiment;
	cell_env ma_cell_env;
	cell_env ma_cell_env_origin;
	int deplace <- 0;
	
	init { // --- loger le ménage ---
		//do emmenager;
	}
	
	reflex chercher_nouveau_batiment when: deplace > 0 {
		do emmenager;
	}
	
	action emmenager {
		// Construire un bâtiment
		geometry bat_shape <- rectangle(taille_bat,taille_bat); // Définition de la forme et de la taille du bâtiment
		geometry ou_construire <- nil;
		bool bat_proche_route <- false;
		
		if (ma_cell_env.mon_espace_libre_proche_route != nil and ma_cell_env.mon_espace_libre_loin_route != nil) { // La cellule contient des espaces proches et loin route
			if (flip(flip_proche_route)) {
				ou_construire <- ma_cell_env.mon_espace_libre_proche_route;
				bat_proche_route <- true;
			} // on construit dans le proche route
			else {ou_construire <- ma_cell_env.mon_espace_libre_loin_route;} // on construit dans le loin route
		} else if (ma_cell_env.mon_espace_libre_proche_route != nil and ma_cell_env.mon_espace_libre_loin_route = nil) { // La cellule contient des espace proche route et pas de loin route
			ou_construire <- ma_cell_env.mon_espace_libre_proche_route; // on construit dans le proche route
			bat_proche_route <- true;
		} else if (ma_cell_env.mon_espace_libre_proche_route = nil and ma_cell_env.mon_espace_libre_loin_route != nil) { // La cellule contient des espace proche route et pas de loin route
			ou_construire <- ma_cell_env.mon_espace_libre_loin_route; // on construit dans le proche route
		} else {
			// Le ménage choisis une cell_env voisine s'il y a des espaces libres
			list<cell_env> mes_voisins_libres <- ma_cell_env.neighbors where (each.mon_espace_libre != nil);
			cell_env ma_new_cell_env <- one_of(mes_voisins_libres);
			
			if (ma_new_cell_env != nil and deplace <= n_cell_deplace_max) {
				ma_cell_env <- ma_new_cell_env;
				do changer_cell_env;
			} else { // S'il n'y a pas d'espace libre à côté il construit un étage dans sa cell_env d'origine
				list<batiment> batiments_possibles <- ma_cell_env_origin.mes_batiments collect each;
				if (length(batiments_possibles) >= 1) {
					mon_batiment <- one_of(batiments_possibles);
					add self to: mon_batiment.mes_menages_batiment;
				} else {
					mon_batiment <- batiment closest_to ma_cell_env_origin;
				}
				mon_batiment.n_etages <- mon_batiment.n_etages + 1;
				deplace <- 0;
				remove self from: ma_cell_env.mes_menages_supp;
			}
		}
		
		// Si une zone ou_construire a été définie, on construit un batiment
		if (ou_construire != nil) {
			point loc <- any_location_in(ou_construire);	
			create batiment with: [shape::bat_shape, cell_env_batiment::ma_cell_env, location::loc, proche_route::bat_proche_route] returns: bat_en_cours {
				espace_bati_total <- espace_bati_total + self.shape * 2;
			}
			
			ask bat_en_cours {
				add myself to: mes_menages_batiment;
				add self to: cell_env_batiment.mes_batiments;
				//do initialisation;
			}
			
			if (ma_cell_env.mes_menages_supp contains self) {remove self from: ma_cell_env.mes_menages_supp;}
			deplace <- 0;
		}		
	}
	
	action changer_cell_env { // Le ménage est transféré a une autre cellule environnement (il est détruit, puis sera créer ailleurs)
		ask ma_cell_env_origin { // On change les paramètres de la cellule d'origine liés à ce ménage
			remove myself from: mes_menages;
			pop_resid <- pop_resid  - myself.n_membres;
			men_resid <- men_resid  - 1;
		}
		add self to: ma_cell_env.mes_menages_supp;
		deplace <- deplace + 1;
	}
}

species batiment frequency: 0 {
	int n_etages;
	cell_env cell_env_batiment;
	list<menage> mes_menages_batiment;
	rgb color <- rgb(110,110,110);
	rgb color_border <- rgb(90,90,90);
	bool proche_route;
	float dist_route_voisine;
	list<batiment> batiments_voisins <- [];

	action alignement {
		route route_voisine <- route closest_to self;
		geometry pproche <- route_voisine.segments with_min_of (self distance_to each);
		int angle_route_voisine <- first(pproche.points) towards last(pproche.points);
		shape <- shape rotated_by (angle_route_voisine + (flip(0.7) ? 90 : 0));
	}

	aspect base {
		draw shape color: #orange depth: n_etages * 5 border: color_border;
	}
}

experiment genmicro type: gui {
	output {
		display main_display type: opengl {
			//grid cell_env;
			//grid cell_ggmap transparency: 0.6;
            //graphics "espace_non_bati" {draw espace_non_bati color: rgb(155,187,89);}
            //graphics "espace_libre" {draw espace_libre_total color: rgb(100,100,100);}
            graphics "chaussee" {draw zone_chaussees color: rgb(255,255,255);}
            graphics "espace_libre_proche_route" {draw espace_libre_proche_routes color: rgb(100,100,100);}
            graphics "espace_libre_proche_route" {draw espace_libre_loin_routes color: #red;}
            //graphics "zone_proche_routes" transparency:0.9 {draw zone_proche_routes color:#red;}
			species route aspect: base;
			species batiment aspect: base;
		}
	}
}