/**
* Name: genmicro
* Author: renaud
*/

model genmicro

global {
	// Paramètres
	float largeur_chaussee <- 10.0;
	float largeur_espace_proche_route <- 35.0;
	int max_nhab_menage <- 10;
	float lambda_nhab_menage <- 3.5;
	float taille_bat <- 10.0;

	
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
	
	// Initialisation
	geometry shape <- envelope(grid_pop);
	
	init {
		float min_proba_bati <- cell_proba_bati min_of (each.grid_value); //Calcul du min et du max de proba_bati pour indicer entre 0 et 1
		float max_proba_bati <- cell_proba_bati max_of (each.grid_value);
		
		// Initialisation des cellules environnement
		ask cell_env {
			// Variables issues des données en entrée
			self.pop <- int(self.grid_value);
			self.men <- int(cell_men[self.grid_x, self.grid_y].grid_value);
			self.ndvi <- cell_ndvi[self.grid_x, self.grid_y].grid_value;
			self.proba_bati <- 1 - (cell_proba_bati[self.grid_x, self.grid_y].grid_value - min_proba_bati) / (max_proba_bati - min_proba_bati); // l'indice de proba_bati est indicé entre 0 et 1
			
			// Variables calculées
			self.bati <- flip(self.proba_bati); // Définition bati / nonbati
			self.pop_sdf <- self.pop;
			self.men_sdf <- self.men;
			self.color <- color_bati(self.bati);
			self.men_resid <- 0;
			self.pop_resid <- 0;
		}
		
//		ask cell_ggmap {
//			self.occsol <- int(self.grid_value);
//			self.color <- color_occsol(self.occsol);
//		}
		
		// Initialisation des routes et des zones autour (chaussees et zones proches)
		
		create route from: shp_routes {
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
		
		write "La zone chaussees fait " + zone_chaussees.area;
		write "La zone proche route fait " + zone_proche_routes.area;
	}
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
	list<menage> mes_menages;
	
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
	
	// Création des ménages
	reflex creer_menage when: men_sdf >= 1 { //les ménages sont créés tant que le nb de ménages sdf est supérieur à 0
		int nhab_menage <- 0;
		
		// Définition du nombre d'habitants du ménage
		if ((men_sdf - pop_sdf) = 0) {nhab_menage <- 1;} // S'il reste autant de menages sdf que de population sdf, le nombre de personnes attribuées au ménage est 1
		if (men_sdf = 1) and (nhab_menage = 0) {nhab_menage <- pop_sdf;} // S'il n'y a plus qu'un seul ménage sdf, le nombre d'hab restant lui est attribué
		else { // S'il y a + que un seul ménage sdf dans la cellule
			loop while: (nhab_menage <= 0 or nhab_menage >= max_nhab_menage) { // On choisit le nb d'hab par ménage
				nhab_menage <- poisson(lambda_nhab_menage);
				if ((pop_sdf - nhab_menage) < men_sdf) {nhab_menage <- 0;} // Si en enlevant le nb d'hab, le nb de pop sdf est inférieur au nombre de men sdf, on retire
			}
		}
		
		// Création du ménage
		create menage number: 1 with: [n_membres::nhab_menage, mon_cell_env::self]{
			add self to: myself.mes_menages;
			myself.pop_resid <- myself.pop_resid  + nhab_menage;
			myself.men_resid <- myself.men_resid  + 1; 
		} 
		
		// Actualisation de la pop et des men sdf
		pop_sdf <- pop_sdf - nhab_menage;
		men_sdf <- men_sdf - 1;
		
		// Check erreur nombre de menages et nombre d'hab finaux de la cellule
		if (pop_sdf = 0 and men_sdf > 0) { write "Il reste" + men_sdf + " ménages sur " + self;}
		if (men_sdf = 0 and pop_sdf > 0) { write "Il reste" + pop_sdf + " habitants sur " + self;}
	}
	
	aspect base {
	
	}
}

grid cell_men file: grid_men use_regular_agents: false use_individual_shapes: false schedules: [];

grid cell_ndvi file: grid_ndvi use_regular_agents: false use_individual_shapes: false schedules: [];

grid cell_proba_bati file: grid_proba_bati use_regular_agents: false use_individual_shapes: false schedules: [];

/*grid cell_ggmap file: grid_ggmap use_regular_agents: false use_individual_shapes: false schedules: [] {
	int occsol;
	rgb color;
	
	rgb color_occsol(int m) {
		switch m {
			match 1 {
				return rgb(220,220,220);
			}
			match 2 {
				return rgb(253,234,218);
			}
			match 3 {
				return rgb(85,142,220);
			}
		}
	}
}
*/

species route {
	rgb color <- #black;
	geometry chaussee;
	geometry espace_proche_route;
	list<geometry> segments;
		
	action init_routes {
		// Inclure ici --> if je suis une petite route alors je fais ce qu'il y a en dessous
		chaussee <- self.shape + largeur_chaussee;
		add chaussee to: chaussees;
		espace_proche_route <- self.shape + largeur_espace_proche_route - chaussee;
		add espace_proche_route to: espace_proche_routes;
//		loop i from: 0 to: length(shape.points) - 2 {
//			segments << line([shape.points[i], shape.points[i+1]]);
//		}
	}

	aspect base {
		draw shape color: color;
	}
}

species menage {
	int n_membres;
	batiment mon_batiment;
	int mon_etage;
	cell_env mon_cell_env;
	
	init {
		// --- loger le ménage ---
		//
		
		geometry bat_shape <- rectangle(taille_bat,taille_bat); // Définition de la forme et de la taille du bâtiment
		
	}
}

species batiment {
	
}

experiment genmicro type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		display main_display type: opengl {
			grid cell_env;
			//grid cell_ggmap;
			species route aspect: base ;
		}
	}
}