/**
* Name: genmicro
* Author: renaud
*/

model genmicro

global {
	// Paramètres
	// A calibrer
	float largeur_espace_proche_route <- 200.0 const: true;
	int N_CELL_BAT_VOISINS <- 8;
	float flip_proche_route <- 0.8;
	float TAILLE_CARRE_GRAINES <- 50.0;
	float TOL_ESPACE_NON_BATI <- 4.0;
	float BUF_ESPACE_NON_BATI <- 2.0;
	
	// Scenarios
	int SCENARIO_BATIMENT <- 2; // SCENARIO
	int SCENARIO_MENAGE <- 3; // SCENARIO
	
	// Expérience terrain
	float largeur_chaussee <- 4.0;
	int max_nhab_menage <- 10;
	float lambda_nhab_menage <- 3.5;
	float H_ETAGE <- 2.5;
	float TAILLE_BAT_LONG <- 10.0;
	float TAILLE_BAT_LARG <- 10.0;
	
	float INTERCEPT_TAILLE_BAT <- 206.25;
	float COEF_TAILLE_BAT <- -6.25;
	float RATIO_TBAT_MAX <- 2.3;
	
	// Gites
	float RATIO_GLP_INT_MAX <- 0.3;
	float RATIO_GLP_INT_MIN <- 0.5;
	float LAMBDA_GLP_ESP_NON_BATIS_U <- 3.0;
	float LAMBDA_GLP_MEN_INTEXT_A <- 4.0;
	float LAMBDA_GLP_VOIS_EXT_B <- 2.0;
	
	// Paramètres de validation
	int RES_GRID_VALID <- 1000;
	int BUFFER_VALID <- 5;
	float dist_valid_max <- 20.0;
	float dist_valid_min <- float(BUFFER_VALID);
	
	// Paramètres visualisation
	float LIM_NDVI_COL <- 0.3;
	int vert_r <- 155;
	int vert_g <- 187;
	int vert_b <- 89;
	int gris_r <- 195;
	int gris_g <- 195;
	int gris_b <- 195;
	
	// Fichiers en entrée
	file grid_men <- file('../data_micro/men_zone.tif');
	file grid_pop <- file('../data_micro/pop_zone.tif');
	file grid_ndvi <- file('../data_micro/ndvi_zone.tif');
	file grid_proba_bati <- file('../data_micro/dist_raster_zone.tif');
	//file grid_ggmap <- file('../data_micro/extract_ggmap_zone.tif');
	file shp_routes <- file('../data_micro/routes_zone_calib_part2.shp');
	file shp_ggmap <- file('../data_micro/routes_canaux_diss.shp');
	file shp_zone <- file('../includes/bangkhutien_zone_calib_part2.shp');
	file shp_bat_bangkhutien <- file('../includes/bldg_bangkhuntien_calib_part2.shp');
	
	// Fichiers de sortie
	string sim_id <- "_SM_" + SCENARIO_MENAGE + "-SB_" + SCENARIO_BATIMENT+ "-" + seed;
	string batiments_sortie <- "../results" + sim_id+"/batiments_sortie.shp";
	string cell_env_sortie <- "../results" + sim_id+"/cell_env_sortie.shp";
	string result_valid_sortie <- "../results" + sim_id+"_valid.shp";
	string name_global_results <- "../results/global_results.txt";
	
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
	geometry bangkhutien <- first(shp_zone);
	
	float t1;
	float t2;
	float t3;
	float t4;
	float t5;
	float t6;
	float t8;
	float t7;
	float t9;
	
	
	// Initialisation
	geometry shape <- envelope(grid_pop);
	
	reflex dynamic when: cycle = 1 {
		float t <- machine_time;
		float min_proba_bati <- cell_proba_bati min_of (each.grid_value); //Calcul du min et du max de proba_bati pour indicer entre 0 et 1
		float max_proba_bati <- cell_proba_bati max_of (each.grid_value);
		
		// Initialisation des cellules environnement
		ask cell_env {
			// Variables issues des données en entrée
			self.pop <- int(self.grid_value);
			self.men <- int(cell_men[self.grid_x, self.grid_y].grid_value);
			self.ndvi <- cell_ndvi[self.grid_x, self.grid_y].grid_value;
			self.ndvi <- self.ndvi < 0 ? 0 : self.ndvi;
			self.proba_bati <- (cell_proba_bati[self.grid_x, self.grid_y].grid_value - min_proba_bati) / (max_proba_bati - min_proba_bati); // l'indice de proba_bati est indicé entre 0 et 1
			
			// Variables calculées
			self.bati <- flip(self.proba_bati); // Définition bati / nonbati
			self.pop_sdf <- self.pop;
			self.men_sdf <- self.men;
			self.color <- self.color_vegetation(ndvi); //self.color <- color_bati(self.bati);
			self.men_resid <- 0;
			self.pop_resid <- 0;
		}
		espace_non_bati <-clean(union(shp_ggmap));
		// Initialisation des routes et des zones autour (chaussees et zones proches)
		
		create route from: shp_routes with: [type::string(read("fclass")), pont::string(read("bridge")), tunnel::string(read("tunnel"))] {
			do init_routes;
		}
		int nchaussees <- length(chaussees);
		int cpt <- 0;
		
		loop buff_chaussee over: chaussees {
			zone_chaussees <- zone_chaussees + buff_chaussee;
			cpt <- cpt + 1;
			//if (cpt mod 100 = 0) {write "routes pretes : " + cpt + " sur " + nchaussees;}
		}
		loop buff_route over: espace_proche_routes {
			zone_proche_routes <-  zone_proche_routes + buff_route;
		}
		// Calcul de l'espace non bati (végétation, eau, routes)
		write "intialisation de l'espace non bati";
		espace_non_bati <- simplification(espace_non_bati, TOL_ESPACE_NON_BATI);
		espace_non_bati <- espace_non_bati + BUF_ESPACE_NON_BATI;
		write "simplification terminée";
		
		geometry espace_vegetalise <- union(cell_env where (!each.bati));
		espace_non_bati <- espace_vegetalise + espace_non_bati;
		write "ajout espace végétalisé terminée";
		
		espace_non_bati <- clean(union([espace_non_bati, zone_chaussees]));
		write "union terminée";
	
		list<geometry> geoms <- bangkhutien to_squares(shape.width/5);
		int cp <- 0;
		loop g over: espace_non_bati.geometries {
			list<geometry> geoms2;
			loop g2 over: geoms  {
				if (g2 overlaps g) {
					geoms2<< g2 - g;
				}
				else {geoms2 << g2;}
			}
			geoms <- copy(geoms2);
		//	write "difference: " +cp + "/" + length(espace_non_bati.geometries) ;
			cp <- cp + 1;
		}
		write "construction espace non bati: " + (geoms count (each.area > 0));
		espace_libre_total <- union(geoms where (each.area > 0));
		
		//espace_libre_total <- shape - espace_non_bati;)
		write "espace_libre_total: " + length(espace_libre_total.geometries );
		
		write "Espaces non batis = " +  espace_non_bati.area;
		write "Espaces non batis = " +  espace_non_bati.area * 100 / shape.area + "% de la zone totale";
		
		// Calcul de l'espace libre à batir dans chaque cell_env et création des ménages
		write "intialisation des menages";
		ask cell_env overlapping bangkhutien {			
			// Création des ménages
			//write "début création des ménages";
			loop while: men_sdf >= 1 {
				int nhab_menage <- 0;
				// Définition du nombre d'habitants du ménage
				if ((men_sdf - pop_sdf) = 0) {nhab_menage <- 1;} // S'il reste autant de menages sdf que de population sdf, le nombre de personnes attribuées au ménage est 1
				if (men_sdf = 1) and (nhab_menage = 0) {nhab_menage <- pop_sdf;} // S'il n'y a plus qu'un seul ménage sdf, le nombre d'hab restant lui est attribué
				else { // S'il y a + que un seul ménage sdf dans la cellule
					loop while: (nhab_menage <= 0 or nhab_menage > max_nhab_menage) { // On choisit le nb d'hab par ménage
						nhab_menage <- poisson(lambda_nhab_menage);
						if ((pop_sdf - nhab_menage) < (men_sdf - 1)) {nhab_menage <- 0;} // Si en enlevant le nb d'hab, le nb de pop sdf est inférieur au nombre de men sdf - 1, on retire
						//write 'je boucle car il y a ' + pop_sdf + ' personnes et ' + men_sdf + ' ménages';
					}
				}
				// Création du ménage
				create menage number: 1 with: [n_membres::nhab_menage, ma_cell_env_origin::self]{
					add self to: myself.mes_menages;
					myself.pop_resid <- myself.pop_resid  + nhab_menage;
					myself.men_resid <- myself.men_resid  + 1;
					ma_cell_env <- myself;
				}
				// Actualisation de la pop et des men sdf
				pop_sdf <- pop_sdf - nhab_menage;
				men_sdf <- men_sdf - 1;
			}
		}
		
		// Création de bâtiments
		write "Création des bâtiments";
		cp <- 0;
		float min_size <- min([TAILLE_BAT_LARG, TAILLE_BAT_LONG]);
		list<geometry> tot_geoms <- espace_libre_total.geometries where (each.area > (TAILLE_BAT_LARG * TAILLE_BAT_LONG) and each.width > min_size and each.height > min_size);
		tot_geoms <- tot_geoms sort_by (- each.area);
		loop g over:  tot_geoms{
			
			//write "zone: " + cp + "/" + length(tot_geoms) + " - " + g.area;
			list<geometry> gs <- [];
			if (g.area > 100000) {
				gs <- g to_squares(500.0);
			} else {
				gs << g;
			}
			loop g2 over: gs {
				loop g3 over: g2.geometries {
					if (g3.area > (TAILLE_BAT_LARG * TAILLE_BAT_LONG) and g3.width > min_size and g3.height > min_size) {
						if (length(g3.geometries) > 1) {g3 <- g3.geometries with_max_of (each.area);}
						int nb_habs <- sum((cell_env overlapping g3) collect each.men_resid);
						if (nb_habs > 0) {
							list<batiment> bats;
							list<geometry> decomp <- g3 to_squares(TAILLE_CARRE_GRAINES);
							loop carre over: decomp  {
								do creer_bati_proche_route(carre, bats); 
							}
							list<batiment> nouveaux_bats <- copy(bats);
							loop while: not empty(bats) {
								do creer_batiment_contigu(bats,g3, nouveaux_bats);
							}
						}
					}
				}	
			}
			cp <- cp + 1;
		}
		
		ask batiment {
			cell_env(location).mes_batiments << self;
		}
		int cpt_bat <- 0;
		ask cell_env {
			batiments_voisins <- ((self neighbors_at N_CELL_BAT_VOISINS) + self) accumulate each.mes_batiments; //Récupération des batiments voisins et des bâtiments de la cellule pour le logement des ménages	
		}
		// Logement des ménages
		write "logement des ménages";
		ask menage {
			list<batiment> bat_inhabites <- ma_cell_env.mes_batiments where (length(each.mes_menages_batiment) = 0); // Liste de bâtiments inhabités dans le voisinage)
			list<batiment> bat_inhabites_voisins <- ma_cell_env.batiments_voisins where (length(each.mes_menages_batiment) = 0); // Liste de bâtiments inhabités dans le voisinage)
			
			switch SCENARIO_MENAGE {
				match 1 { // Scenario 1 : On commence par remplir sa propre cellule puis on remplit les cellules voisines
					if (length(bat_inhabites) > 0) { // S'il reste des bat inoccupés dans la CE, on les occupe
						mon_batiment <- one_of(bat_inhabites);
					} else if (length(bat_inhabites_voisins) > 0) { 
						mon_batiment <- one_of(bat_inhabites_voisins); //S'il en reste pas dans la CE mais qu'il en reste dans les voisins, on occupe ceux des voisins
					} else {
						list<batiment> batiments_dispo <- ma_cell_env.batiments_voisins + ma_cell_env.mes_batiments;
						mon_batiment <- one_of(batiments_dispo);	// sinon on prend un bâtiment dans le voisinage
					}
				}
				match 2 { // Scenario 2 : On remplit les cellules voisines et pas forcément sa cellule
					bat_inhabites_voisins <- bat_inhabites_voisins + bat_inhabites;
					if (length(bat_inhabites_voisins) > 0) { 
						mon_batiment <- one_of(bat_inhabites_voisins); //S'il en reste pas dans la CE mais qu'il en reste dans les voisins, on occupe ceux des voisins
					} else {
						list<batiment> batiments_dispo <- ma_cell_env.batiments_voisins + ma_cell_env.mes_batiments;
						mon_batiment <- one_of(batiments_dispo); // sinon on prend un bâtiment dans le voisinage
					}
				}
				match 3 { // Scenario 3 : On construit des bâtiments de hauteur semblable en remplissant les CE voisines (pas forcément sa cellule)
					list<batiment> batiments_dispo <- ma_cell_env.batiments_voisins + ma_cell_env.mes_batiments;
					int n_etages_min <- 999;
					loop bat over: batiments_dispo {
						if (bat.n_etages < n_etages_min) {n_etages_min <- bat.n_etages;}
					}
					batiments_dispo <- batiments_dispo where (each.n_etages = n_etages_min); 
					mon_batiment <- one_of(batiments_dispo); // sinon on prend un bâtiment dans le voisinage
				}
				match 4 { // Scenario 3 : On construit des bâtiments de hauteur semblable en remplissant les CE voisines (pas forcément sa cellule). Leur taille évolue en fonction de la densité.
					
				}
			}
			if (mon_batiment = nil) {
				if (ma_cell_env != nil) {ma_cell_env.mes_menages >> self;}
				do die;
			} 
			else {
				ma_cell_env <- mon_batiment.cell_env_batiment;
				add self to: self.ma_cell_env.mes_menages;
				mon_batiment.mes_menages_batiment << self;
				mon_batiment.n_etages <- mon_batiment.n_etages + 1;
			}
			
		}
		
		int cpt_inhab <- 0;
		ask batiment {
			if (length(mes_menages_batiment) = 0) {
				cpt_inhab <- cpt_inhab + 1;
				//color <- #green;
				do die;
			}
		}
		write 'Le nb de bâtiment(s) non habité(s) est de ' + cpt_inhab;
		//Calcul du nombre de GLP par cell_env

		write "Initialisation des gites";
		ask cell_env {
			// Actualisation du nombre de ménages et d'habitants de chaque cellule
			int n_membres_men_cell_env;
			loop eachmen over: mes_menages {
				n_membres_men_cell_env <- n_membres_men_cell_env + eachmen.n_membres;
			}
			pop_resid <- n_membres_men_cell_env ;
			men_resid <- length(mes_menages);
			
			// Initialisation des paramètres aléatoires permettant de calculer le nombre de gites
			ratio_glp_int <- rnd(RATIO_GLP_INT_MIN,RATIO_GLP_INT_MAX);
			n_glp_esp_non_bati_u <- poisson(LAMBDA_GLP_ESP_NON_BATIS_U);
			n_glp_men_intext_a <- poisson(LAMBDA_GLP_MEN_INTEXT_A);
			n_glp_vois_ext_b <- poisson(LAMBDA_GLP_VOIS_EXT_B);

			// Calcul GLP INT
			ask mes_batiments {
				n_glp_int <- myself.men_resid * int(myself.n_glp_men_intext_a * myself.ratio_glp_int); // Les bâtiments calculs leur nb de GLP in en fonction de leur nn de men et autres param
				myself.n_glp_int_tot <- myself.n_glp_int_tot + n_glp_int; // On calcule le nombre de GLP INT TOT dans chaque cellule
			}
			
			// Calcul GLP EXT
			int glp_prod_vois;
			loop cell_env_neighbors over: neighbors { // Calcul du nombre de GLP créés par les voisins
				glp_prod_vois <- glp_prod_vois + cell_env_neighbors.men_resid * cell_env_neighbors.n_glp_vois_ext_b; 
			} 
			n_glp_ext <- n_glp_esp_non_bati_u + int((men_resid * n_glp_men_intext_a) * (1 - ratio_glp_int)) + glp_prod_vois;
		}
		// Sauvegarde des données initialisée
		//save batiment to: "batiments.shp" type: "shp" with: [n_etages::"n_etages", n_menages::"n_menages", n_glp_int::"n_glp_int"];
		//save cell_env to: cell_env_sortie type: "shp" with: [ndvi::"ndvi", proba_bati::"proba_bati", bati::"est_construc", n_glp_ext::"n_glp_ext"];
		
		// Comparaison estimé / observé
		list<geometry> grid_valid;
		create batiment_obs from: shp_bat_bangkhutien;
		grid_valid <- bangkhutien to_squares(RES_GRID_VALID); // Création de la grille de référence pour comparaison au sein de chaque celle de cette grille
		write "Nb cells = " + length(grid_valid);
		
		matrix<float> mat_results <-0.0 as_matrix({length(grid_valid),9});
		int cpt_results <- 0;
		
		loop cell_valid over: grid_valid  {
			write cell_valid.points;
			list<batiment> bati_est_cell <- batiment overlapping cell_valid;
			list<batiment_obs> bati_obs_cell <- batiment_obs overlapping cell_valid;
			int n_est <- length(bati_est_cell);
			int n_obs <- length(bati_obs_cell);
			
			// S'il y a des bâtiments on calcul les ratio
			if (n_est > 0 and n_obs > 0) {
				
				// Calcul du nb et de l'aire des bat de chaque cell
				int n_est <- length(bati_est_cell);
				int n_obs <- length(bati_obs_cell);
				float aire_est <- bati_est_cell sum_of(each.shape.area);
				float aire_obs <- bati_obs_cell sum_of(each.shape.area);
				
				write "Aire est. = " + aire_est + " | Aire obs. = " + aire_obs;
				write "Nb est. = " + n_est + " | Nb obs. = " + n_obs;
				
				// Calcul des ratios de concordances
				//list<geometry> bati_est_cell_buff <- bati_est_cell collect (each + BUFFER_VALID);
				int n_bat_est_inter <- 0;
				float n_bat_est_inter_pond <- 0.0;
				
				ask bati_est_cell{
					list<batiment_obs> batiments_proches <- bati_obs_cell at_distance (dist_valid_max + BUFFER_VALID);
					if not(empty(batiments_proches)) {
						float dist_bat_proche <- max([0.0,(batiments_proches min_of (each distance_to self)) - BUFFER_VALID]);
					
						if (dist_bat_proche = 0.0) {
							// Calcul du ratio normal pour les EST
							n_bat_est_inter <- n_bat_est_inter + 1;
							n_bat_est_inter_pond <- n_bat_est_inter_pond + 1;
						} else {
							// Prise en compte de la distance pour le ratio pondéré par la distance pour les EST
							if (dist_bat_proche < dist_valid_max) {
								float ratio <- 1 - (dist_bat_proche / dist_valid_max);
								n_bat_est_inter_pond <- n_bat_est_inter_pond + ratio;
							}
						}
					}
				}
				
				//list<geometry> bati_obs_cell_buff <- bati_obs_cell collect (each + BUFFER_VALID);
				int n_bat_obs_inter <- 0;
				float n_bat_obs_inter_pond <- 0.0;
				
				ask bati_obs_cell {
					list<batiment> batiments_proches <- bati_est_cell at_distance (dist_valid_max + BUFFER_VALID);
					if not(empty(batiments_proches)) {
						float dist_bat_proche <- max([0.0,(batiments_proches min_of (each distance_to self)) - BUFFER_VALID]);
						if (dist_bat_proche = 0.0) {
							// Calcul du ratio normal pour les OBS
							n_bat_obs_inter <- n_bat_obs_inter + 1;
							n_bat_obs_inter_pond <- n_bat_obs_inter_pond + 1;
						} else {
							// Prise en compte de la distance pour le ratio pondéré par la distance pour les EST
							if (dist_bat_proche < dist_valid_max) {
								float ratio <- 1 - (dist_bat_proche / dist_valid_max);
								n_bat_obs_inter_pond <- n_bat_obs_inter_pond + ratio;
							}
						}
					}
				}
				
				
				// Inscription des resultats
				mat_results[cpt_results,0] <- cpt_results;
				mat_results[cpt_results,1] <- n_est;
				mat_results[cpt_results,2] <- n_obs;
				mat_results[cpt_results,3] <- aire_est;
				mat_results[cpt_results,4] <- aire_obs;
				mat_results[cpt_results,5] <- n_bat_est_inter / n_est;
				mat_results[cpt_results,6] <- n_bat_est_inter_pond / n_est;
				mat_results[cpt_results,7] <- n_bat_obs_inter / n_obs;
				mat_results[cpt_results,8] <- n_bat_obs_inter_pond / n_obs;		
			} else {
				// Inscription des resultats si jamais il n'y a pas de bâtiments observés ou de bâtiments estimés
				float aire_est <- 0.0;
				float aire_obs <- 0.0;
				if (n_est > 0) {
					geometry bati_est_cell_tot <- union(bati_est_cell);
					float aire_est <- bati_est_cell sum_of(each.shape.area);
				}
				
				if (n_est > 0) {
					geometry bati_obs_cell_tot <- union(bati_obs_cell);
					float aire_obs <- bati_obs_cell sum_of(each.shape.area);
				}
								
				mat_results[cpt_results,0] <- cpt_results;
				mat_results[cpt_results,1] <- n_est;
				mat_results[cpt_results,2] <- n_obs;
				mat_results[cpt_results,3] <- aire_est;
				mat_results[cpt_results,4] <- aire_obs;
				mat_results[cpt_results,5] <- 0;
				mat_results[cpt_results,6] <- 0;
				mat_results[cpt_results,7] <- 0;
				mat_results[cpt_results,8] <- 0;	
			}

			cpt_results <- cpt_results + 1;
			write "resultats n°" + cpt_results + " sur " + length(grid_valid); 
		}
		
		// Calcul des erreurs globales
		float sum <- 0.0;
		loop i from:0 to: cpt_results - 1 {
			sum <- sum + (mat_results[i,2] - mat_results[i,1])^2; 
		}
		float rmse_nb_bat <- sqrt(sum / (cpt_results - 1));
		
		sum <- 0.0;
		loop i from:0 to: cpt_results - 1 {
			sum <- sum + (mat_results[i,4] - mat_results[i,3])^2; 
		}
		float rmse_area_bat <- sqrt(sum / (cpt_results - 1));
		
		mat_results <- transpose(mat_results);
		list<list> list_mat_results <- columns_list(mat_results);
		list<list> new_mat <- nil;
		loop i from:0 to: length(list_mat_results)-1 {
			new_mat << list_mat_results[i];
		}
		matrix new_mat_results <- matrix(new_mat); 
		
		float median_est_inter <- median(new_mat_results column_at 5);
		float median_obs_inter <- median(new_mat_results column_at 7);
		float median_est_pond <- median(new_mat_results column_at 6);
		float median_obs_pond <- median(new_mat_results column_at 8);
	
		matrix global_results <- matrix([["SCENARIO_BATIMENT","SCENARIO_MENAGE","largeur_espace_proche_route","N_CELL_BAT_VOISINS","flip_proche_route","TAILLE_CARRE_GRAINES","TOL_ESPACE_NON_BATI","BUF_ESPACE_NON_BATI","rmse_n","rmse_area","median_est_inter","median_obs_inter","median_est_pond","median_obs_pond"],[SCENARIO_BATIMENT,SCENARIO_MENAGE,largeur_espace_proche_route,N_CELL_BAT_VOISINS,flip_proche_route,TAILLE_CARRE_GRAINES,TOL_ESPACE_NON_BATI,BUF_ESPACE_NON_BATI,rmse_nb_bat,rmse_area_bat,median_est_inter,median_obs_inter,median_est_pond,median_obs_pond]]);
		// Enregistrement
		save new_mat_results to: "../results/results_valid.txt" type:"text";
		
		save transpose(global_results) to: name_global_results type:"text";
	}
	
	action creer_bati_proche_route(geometry carre, list<batiment> bats) {
		float larg <- TAILLE_BAT_LARG;
		float long <- TAILLE_BAT_LONG;
		if (SCENARIO_BATIMENT = 2) {
			list<cell_env> cs <- (cell_env overlapping carre);
			float mean_nmen <- empty(cs) ? 0.0 : mean(cs collect (float(each.men_resid)));
			float aire_bat <- INTERCEPT_TAILLE_BAT + (COEF_TAILLE_BAT * mean_nmen);
			float ratio_tbat <- rnd(1.0,RATIO_TBAT_MAX);
			larg <- sqrt(aire_bat * ratio_tbat);
			long <- aire_bat / larg;
		} 
		geometry possible_surface <- (carre - long);
		if ((possible_surface != nil) and possible_surface.area > 0) {
			point loc <- any_location_in(carre - long);
			cell_env loc_cell_env <- cell_env closest_to loc;
			if (loc distance_to espace_non_bati > long) and empty(batiment overlapping (rectangle(long, larg) at_location loc)) {
				create batiment with: [shape::rectangle(long,larg), location::loc, color:: (rgb(80,80,80)), n_etages::0, cell_env_batiment::loc_cell_env] {
					route route_proche <- route closest_to self;
					float dist <- route_proche distance_to self;
					if (dist < largeur_espace_proche_route) {do alignement;}
					bats << self;
				}
			}
		}
	}
	
	action creer_batiment_contigu(list<batiment> batiments, geometry  g, list<batiment> nouveaux_bats){
		batiment bat_proche <- one_of(batiments);
		batiments >> bat_proche;
		list<geometry> murs <- [];
		loop i from: 0 to:length(bat_proche.shape.points) -2 {
			geometry li <- line([bat_proche.shape.points[i],bat_proche.shape.points[i+1]]);
			if (li != nil and (li.perimeter > 0)) {murs << li;}
		}
		list<route> routes <-[];
		ask bat_proche {
			routes <- route at_distance max([bat_proche.shape.height, bat_proche.shape.width]); 
		}
		
		loop mur over: murs {
			geometry bat_geom <- copy(bat_proche.shape) translated_by (mur.points[1] - mur.points[0]);
			if (bat_geom != nil and bat_geom.area > 0 ) {
				if (length(bat_geom.geometries) > 1) {bat_geom <- bat_geom.geometries with_max_of (each.area);}
						
				bool deja_pris <- false;
				loop b over: (nouveaux_bats overlapping bat_geom)  { 
					geometry it <- (b inter bat_geom);
					if (it != nil and ((b inter bat_geom).area > 0.1)) {deja_pris <- true; break;} //le 0.1 c'est une tolérance (surface acceptée de superposition entre 2 batiments)
				}
				if ((not deja_pris) and (bat_geom intersects world) and ( g covers bat_geom) and empty(routes overlapping bat_geom)) {
					cell_env loc_cell_env <- cell_env (bat_geom.location);
					create batiment with:[shape::bat_geom, color:: rgb(100,100,100), n_etages::0, cell_env_batiment::loc_cell_env] {
						batiments << self;
						nouveaux_bats << self;
					}
				}
			}
			
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
	int men_resid;
	int pop_resid;
	rgb color;
	
	list<menage> mes_menages <- [];
	list<menage> mes_menages_supp <- [];
	list<batiment> mes_batiments <- [];
	list<batiment> batiments_voisins <- [];
	
	geometry mon_espace_libre; // Espace libre pour y construire un batiment
	geometry mon_espace_libre_proche_route;
	geometry mon_espace_libre_loin_route;
	geometry mon_espace_bati;
	
	int n_glp_ext;
	int n_glp_int_tot;
	float ratio_glp_int;
	int n_glp_esp_non_bati_u;
	int n_glp_men_intext_a;
	int n_glp_vois_ext_b;	
	
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

	rgb color_vegetation(float i)  {
	if (i > LIM_NDVI_COL) {
			return rgb(vert_r,vert_g,vert_b);
		} else {
			int r <- int(vert_r + (gris_r - vert_r) * (1 - i / LIM_NDVI_COL));
			int b <- int(vert_b + (gris_b - vert_b) * (1 - i / LIM_NDVI_COL));
			return rgb(r, gris_g, b);
		}
	}
	aspect base {
		draw shape color: color_vegetation;
	}
}

grid cell_men file: grid_men use_regular_agents: false use_individual_shapes: false schedules: [];

grid cell_ndvi file: grid_ndvi use_regular_agents: false use_individual_shapes: false schedules: [];

grid cell_proba_bati file: grid_proba_bati use_regular_agents: false use_individual_shapes: false schedules: [];

/*grid cell_ggmap file: grid_ggmap use_regular_agents: false use_individual_shapes: false use_neighbors_cache: false schedules: [] {
	int occsol;
	rgb color;
	float transparency_ggmap;
	
	rgb color_occsol(int m) {
		switch m {
			match 1 {
				return rgb(0,0,0); // routes
			}
			match 2 {
				return rgb(253,234,218); // espace libre
			}
			match 3 {
				return rgb(85,142,220); // eau
			}
		}
	}
}*/

species ggmap_display {
	int occsol;
	rgb color_occsol;
	
	rgb color_occsol(int m) {
		switch m {
			match 1 {
				return rgb(0,0,0); // routes
			}
			match 2 {
				return rgb(253,234,218); // espace libre
			}
			match 3 {
				return rgb(85,142,220); // eau
			}
		}
	}

	aspect base {
		draw shape color: color_occsol;
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
}

species batiment frequency: 1 {
	int n_etages;
	cell_env cell_env_batiment;
	list<menage> mes_menages_batiment;
	rgb color <- rgb(110,110,110);
	rgb color_border <- rgb(90,90,90);
	bool proche_route;
	float dist_route_voisine;
	int n_glp_int;
	int n_menages -> {length(mes_menages_batiment)};
	
	action alignement {
		route route_voisine <- route closest_to self;
		geometry pproche <- route_voisine.segments with_min_of (self distance_to each);
		int angle_route_voisine <- first(pproche.points) towards last(pproche.points);
		shape <- shape rotated_by (angle_route_voisine + (flip(0.7) ? 90 : 0));
	}

	aspect base {
		draw shape color: color depth: n_etages * 5 border: color_border;
	}
}

species batiment_obs {
	aspect base {
		draw shape color: #red border: #red;
	}
}


experiment genmicro type: gui {
	output {
		display main_display type: opengl {
			grid cell_env;
			//species ggmap_display aspect: base;
			//grid cell_ggmap;
            //graphics "espace_non_bati" {draw espace_non_bati color: rgb(155,187,89);}
            //graphics "espace_libre" {draw espace_libre_total color: rgb(100,100,100);}
            //graphics "chaussee" {draw zone_chaussees color: rgb(255,255,255);}
            //graphics "espace_libre_proche_route" {draw espace_libre_proche_routes color: rgb(100,100,100);}
            //graphics "espace_libre_proche_route" {draw espace_libre_loin_routes color: #red;}
            //graphics "zone_proche_routes" transparency:0.9 {draw zone_proche_routes color:#red;}
			//species route aspect: base;
			//species batiment aspect: base;
			//species batiment_obs aspect: base;
		}
	}
}

experiment batch type: batch until: cycle = 2 repeat: 12 keep_seed:true {
	parameter SCENARIO_BATIMENT var:SCENARIO_BATIMENT among:[2,1];
	parameter SCENARIO_MENAGE var:SCENARIO_MENAGE among:[1,2,3];
}

experiment openmole keep_seed:true {
	parameter "largeur_espace_proche_route" var: largeur_espace_proche_route; //among[100:300] by:50
	parameter "flip_proche_route" var: flip_proche_route; //among[0.5:0.9] by: 0.1 
	parameter "TAILLE_CARRE_GRAINES" var: TAILLE_CARRE_GRAINES; //among[30:80] by: 10   
	parameter "N_CELL_BAT_VOISINS" var: N_CELL_BAT_VOISINS; //among[1:10] by: 1
	parameter "TOL_ESPACE_NON_BATI" var: TOL_ESPACE_NON_BATI; //among[1:10] by: 1
	parameter "BUF_ESPACE_NON_BATI" var: BUF_ESPACE_NON_BATI; //among[1:10] by: 1
}
