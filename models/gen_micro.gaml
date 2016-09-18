/**
* Name: genmicro
* Author: renaud
*/

model genmicro

global {
	// Paramètres
	float largeur_chaussee <- 10.0;
	int max_nhab_menage <- 10;
	float lambda_nhab_menage <- 3.5;
	
	int menages_crees <- 0;
	
	// Fichiers en entrée
	file grid_men <- file('../data_micro/men_zone.tif');
	file grid_pop <- file('../data_micro/pop_zone.tif');
	file grid_ndvi <- file('../data_micro/ndvi_zone.tif');
	file grid_proba_bati <- file('../data_micro/dist_raster_zone.tif');
	file grid_ggmap <- file('../data_micro/extract_ggmap_zone.tif');
	file shp_routes <- file('../data_micro/routes_zone.shp');
	
	// Variables globales
	list<geometry> buffer_chaussees;
	list<geometry> buffer_routes;
	geometry zone_chaussees;
	geometry zone_routes;
	
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
		}
		
//		ask cell_ggmap {
//			self.occsol <- int(self.grid_value);
//			self.color <- color_occsol(self.occsol);
//		}
		
		// Initialisation des routes
		create route from: shp_routes {
			//do init_routes;
			//loop buf_chaussee over: buffer_chaussees {
			//	zone_chaussees <-  zone_chaussees + buffer_chaussee;
			//}
//			loop buf_route over: buffer_routes {
//				zone_routes <-  zone_routes + buf_route;
//			}
		}
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
	reflex creer_menage when: self.men_sdf > 0 { //les ménages sont créés tant que le nb de ménages sdf est supérieur à 0
		int nhab_menage;
		loop while: nhab_menage = 0 or nhab_menage >= max_nhab_menage { // On choisit le nb d'hab par ménage
			nhab_menage <- poisson(lambda_nhab_menage);
			if (nhab_menage > self.pop_sdf){nhab_menage <- self.pop_sdf;} // Si le nb d'hab choisit est sup au nombre d'hab sdf, le nb d'hab choisit est égal au nb d'hab sdf (éviter de créer plus de monde qu'il y en a)
			if (self.men_sdf = 1){nhab_menage <- self.pop_sdf;} // S'il n'y a plus qu'un seul ménage sdf, le nombre d'hab restant lui est attribué
		}
		create menage number: 1 with: [n_membres::nhab_menage, mon_cell_env::self]{
			add self to: myself.mes_menages;
		}
		self.pop_sdf <- self.pop_sdf - nhab_menage;
		self.men_sdf <- self.men_sdf - 1;
		menages_crees <- menages_crees + 1;
		write self.men_sdf;
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
	geometry buffer_chaussee;
	list<geometry> segments;
		
	action init_routes {
		//buffer_chaussee <- self.shape + largeur_chaussee;
		//add buffer_chaussee to: buffer_chaussees;
		//buffer_route <- self.shape + taille_buffer_route;
		//add buffer_route to: buffer_routes;
		//loop i from: 0 to: length(shape.points) - 2 {
		//	segments << line([shape.points[i], shape.points[i+1]]);
		//}
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