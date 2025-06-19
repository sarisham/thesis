/**
* Name: ThesisABM
* Based on the internal empty template. 
* Author: Sara Cristina Herranz Amado
* Tags: 
*/

model ThesisABM


global {
   // CRIME CONTEXT
	// Proxy crime scores assigned per neighborhood (barrio).   
	map<string, float> barrio_crime_scores <- [
	  "Iturrama"::0.89427313,
	  "San Juan/Donibane"::0.59251101,
	  "Casco Viejo/Alde Zaharra":: 0.27533040,
	  "Ensanche/Zabalgunea":: 1.00000000,
	  "Milagrosa-Arrosadia":: 0.00000000,
	  "Rochapea/Arrotxapea":: 0.22687225,
	  "Mendillorri":: 0.50660793,
	  "Ermitaga�a-Mendebaldea":: 0.61894273,
	  "San Jorge-Sanduzelai":: 0.04185022,
	  "Txantrea":: 0.50881057,
	  "Etxabakoitz":: 0.31718062,
	  "Lezkairu":: 0.57929515,
	  "Buztintxuri-Euntzetxiki":: 0.45154185
	];
	
   	// Lightning scores assigned per neighborhood (barrio).   
  	map<string, float> lightning_score <- [
	  "Iturrama"::0.4507321,
	  "San Juan/Donibane"::0.8556841,
	  "Casco Viejo/Alde Zaharra":: 1.0000000,
	  "Ensanche/Zabalgunea":: 0.7291974,
	  "Milagrosa-Arrosadia":: 0.3390208,
	  "Rochapea/Arrotxapea":: 0.8253720,
	  "Mendillorri":: 0.4419651,
	  "Ermitaga�a-Mendebaldea":: 0.4124052,
	  "San Jorge-Sanduzelai":: 0.3424507,
	  "Txantrea"::0.2146612,
	  "Etxabakoitz":: 0.1571991,
	  "Lezkairu"::0.5833965,
	  "Buztintxuri-Euntzetxiki":: 0.0000000
	];
	
	
	// Parameters for power estimation
  int J <- 1;           // Number of parameter configurations (usually 1 for stochastic analysis)
  float ES <- 0.3;      // Expected effect size (e.g., 0.1 = small, 0.3 = medium)
  
  int n_required <- int(14.091 * (J ^ -0.640) * (ES ^ -1.986)); // Formula from Secchi & Seri (2016)

  init {
    write "─────────────────────────────────────────────";
    write "STOCHASTIC ANALYSIS – REPLICATION CALCULATOR";
    write "Configurations (J): " + J;
    write "Expected Effect Size (ES): " + ES;
    write "➤ Estimated runs required for power = 0.95 and α = 0.01: " + n_required;
    write "─────────────────────────────────────────────";    
  }
	
	
   // INPUT DATA
	// Loading the dataset containing resident attributes and effects
    file resident_csv <- csv_file("../includes/gama_agents.csv", ",", true);
    matrix res_matrix <- matrix(resident_csv);
		
		// attributes loaded from csv
	list<int> gender <- res_matrix column_at 1;	
	list<int> nationality <- res_matrix column_at 2;
	list<string> victimized <- res_matrix column_at 3;
	list<float> gen_ins <- res_matrix column_at 4;
	list<int> p7_8 <- res_matrix column_at 5;
	list<int> age <- res_matrix column_at 6;
	list<int> p10_1 <- res_matrix column_at 7;
	list<int> p10_2 <- res_matrix column_at 8;
	
	list<string> barrio_res <- res_matrix column_at 10;
	
	list<string> id <- res_matrix column_at 9;
	list<float> p10_2_escaled <- res_matrix column_at 17;
    list<float> p10_1_escaled <- res_matrix column_at 16;
	list<float> darksens <- res_matrix column_at 15;
	
	
		// effects loaded from csv
	list<float> gender_effect <- res_matrix column_at 11;
	list<float> nationality_effect <- res_matrix column_at 12;
	list<float> victimized_effect <- res_matrix column_at 13;
	list<float> p7_8_effect <- res_matrix column_at 14;
	list<float> darksens_b <- res_matrix column_at 18;
	list<float> darksens_c <- res_matrix column_at 19;
	  
    
   // SPATIAL DATA: MAP COMPONENTS
	// Loading the map
	file pamplona_shapefile <- shape_file('../includes/pamplona_barrios.shp', true);
    
    // Loading the roads
    file roads_shapefile  <- shape_file('../includes/caminos.shp', true);
    
    //Loading the buildings
    file buildings_shapefile  <- shape_file('../includes/edificios.shp', true);
    
    //Loading the parks
    file parques_shapefile  <- shape_file('../includes/parques.shp', true);
    	
    geometry shape <- envelope(pamplona_shapefile);	// full simulation area
    graph the_graph;		// road network graph	
    
   // TIME AND AGENT PARAMETERS
    float step <- 1 #h;
    date starting_date <- date("2019-09-01-00-00-00"); // Simulation starts Sept 1st, 2019
    int min_work_start <- 6;
    int max_work_start <- 8;
    int min_work_end <- 16; 
    int max_work_end <- 20; 
    
    float min_speed <- 1.0 #km / #h;  
  	float max_speed <- 5.0 #km / #h; 
  	float insecure_distance <- 5 #m; // max distance at which residents can detect nearby botelloneros
  	float threshold_pred <- 1.0;  // threshold above which a resident is considered insecure
  	float probabilidad_ocio_fuera <- 0.2; // probability of engaging in leisure activity outside home after work
  	float crime_weight <- 0.5; // importance of crime proxy in nighttime prediction formula
  	
   // POPULATION PARAMETERS
  	int nb_residents <- 167; 	 // number of residents in my sample
  	int nb_insecure_init <- 0; 	 // number of residents feeling insecure at the begininng
  	int nb_grupos_botellon <- 7; // number of botellón gropus
	int min_grupo <- 6; 		 // group size (botellón)
	int ciclo_crimen_botellonero <- 3; // number of days per week botellonero groups are visible
	  	
  	list<building> all_leisure_buildings;
  	
  	// MONITORED GLOBAL INDICATORS
  	int nb_resident_insecure <- nb_insecure_init update: resident count (each.is_insecure); // count of residents marked insecure
	int nb_resident_not_insecure <- nb_residents - nb_insecure_init update: nb_residents - nb_resident_insecure; // remaining secure residents
	float insecure_rate update: nb_resident_insecure / nb_residents; // proportion of insecure residents in total
  	float avg_prediction <- 0.0;
	float stddev_prediction <- 0.0;
	float max_prediction <- 0.0;
	float avg_prediction_women <- 0.0;
  	float victimization_weight <- 1.0; // scaling factor for victimization effect
  	
  	
   // INITIALIZATION PROCEDURE
    init {
    	// Create spatial features
    	create barrio from: pamplona_shapefile;   
    	ask barrio {
			real_crime_proxy <- barrio_crime_scores[barrio_name];
		}

        create parques from: parques_shapefile;
        create road from: roads_shapefile where (each != nil);
        the_graph <- as_edge_graph(road);
        
        // Create building and color-code by type
        create building from: buildings_shapefile with: [type::read ("bldng_t")] {
        	if type = "residence" {
        		color <- #steelblue; 
        		}
        	if type = "work_place" {
        		color <- #palevioletred; 
        		}
        	if type = "leisure" {
        		color <- #peru; 
        		}
        }	
        
        // Group buildings by function
        list<building> work_building <- building where (each.type="work_place");
        list<building> residential_buildings <- building where (each.type="residence");
		all_leisure_buildings <- building where (each.type = "leisure");
   
        
        // FOR BOTELLONEROS
        // Step 1: Get barrios with at least one park
		list<barrio> barrios_con_parques <- barrio where (length(parques where (intersects(each.shape, self.shape))) > 0);
	
		// Step 2: Select a random sample of nb_grupos_botellon barrios
		barrios_con_parques <- shuffle(barrios_con_parques);
		int total_grupos <- min(nb_grupos_botellon, length(barrios_con_parques));
		list<barrio> barrios_seleccionados <- barrios_con_parques[0::total_grupos];
	        
        int group_counter <- 0;
        
        // Step 3: Use ask to iterate through selected barrios
       	ask barrios_seleccionados {
			list<parques> parques_en_barrio <- parques where (intersects(each.shape, self.shape));
			if (length(parques_en_barrio) > 0) {
				parques p <- one_of(parques_en_barrio);
				point centro_grupo <- any_location_in(p.shape);
				create botellonero number: min_grupo with: [
					group_id::group_counter,
					my_ubi::self,
					parque_ubi::p,
					centro_base::centro_grupo
				];
				group_counter <- group_counter + 1;
			}
		}
     	
     	// Create resident agents with personalized attributes and schedule
	    create resident number: nb_residents from: resident_csv {
		    speed <- rnd(min_speed, max_speed);
		    start_work <- rnd (min_work_start, max_work_start);
			end_work <- rnd(min_work_end, max_work_end);
    	  	leisure_duration <- 0.0;
			leisure_end_time <- 0.0;
			leisure_place <- nil;
			objective <- "resting";
			
    	  	barrio my_barrio <- one_of(barrio where (each.barrio_name = self.barrio_res));
    	  	list<building> edificios_en_mi_barrio <- residential_buildings where (each intersects my_barrio.shape);            	   
    	    living_place <- one_of(edificios_en_mi_barrio); 
    	    
			// Extract lightining index per neighborhood
			lightning_barrio <- my_barrio.lightning;
    		
            // Assign work in different neighborhood
			list<building> work_buildings_fuera <- work_building where !(each intersects my_barrio.shape);
		    working_place <- one_of(work_buildings_fuera);
		  
		    location <- any_location_in(living_place);	    		    
	    }
	    
	    // Randomly select some agents to start as insecure (initial seeding)
		ask nb_insecure_init among resident {
			is_insecure <- true;
			}
	    
	   // Compute proportion of insecure residents per neighborhood
		float inseguros_barrio(barrio b) {
		  int total <- count(resident where (each.my_barrio = b));
		  int inseguros <- count(resident where (each.my_barrio = b and each.is_insecure));
		  return (total > 0) ? (inseguros / total) : 0.0;
		}
	}
	
	// Update tracked global indicators every cycle
	reflex update_stats {
		avg_prediction <- mean(resident collect each.prediction);
		stddev_prediction <- standard_deviation(resident collect each.prediction);
		max_prediction <- max(resident collect each.prediction);
		avg_prediction_women <- mean(resident where (each.gender = 0) collect each.prediction);
	}
}




// ENVIRONMENTAL AGENTS
/* BARRIO (Neighborhood units). Each one includes: 
   - a crime perception score (loaded from map),
   - a simulated lighting score,
   - a visual aspect for map rendering. */
species barrio {
	string barrio_name;
    float real_crime_proxy;
    float lightning;
    
	// Assign attributes when created
    init {
		barrio_name <- self["BARRIO"];       // Name from shapefile attribute
        real_crime_proxy <- barrio_crime_scores[barrio_name]; // Load precomputed crime proxy (the one in map)
        lightning <- lightning_score[barrio_name]; // Simulated light availability (for future use)
    }
    
    // Visualization: barrio outlines with pink borders
    aspect base {
		draw shape color: # whitesmoke border: # pink width: 3;
    }
}


// ROAD: Represents segments of the road network
species road  {
	aspect base {
		draw shape color: # maroon width: 1.3;
	}
}


// PARQUES (parks and plazas). These are the base for "botellonero" groups
species parques  {
	string bldng_t; 
	
	init {
		bldng_t <- self["bldng_t"]; 	// Park type or classification from shapefile
  	}
	
	aspect base {
		draw shape color: # darkseagreen ;
	}
}


// BUILDING are imported from shp and categorized by function (residence, workplace, leisure)
species building {
    string type; 
	
    aspect base {
		if type = "residence" {
            draw  shape color: #powderblue border: #dimgray; // Moderately unsafe (Orange)
        } else if type = "work_place" {
            draw  shape color: #palevioletred border: #dimgray; // Neutral (Yellow)
        } else if type = "leisure" {
            draw  shape color: #peru border: #dimgray; // Moderately safe (Light Green)
        } else {
            draw  shape color: #dimgray border: #dimgray; // Very safe (Green)      
   		}
	}
}

 
/* BOTELLONERO: these represent informal youth gatherings typically held in parks 
   after dark. They only become visible during specific nighttime hours */
species botellonero {
	int group_id;
  	barrio my_ubi <- one_of(barrio);   // The barrio it belongs to
 	parques parque_ubi;  			   // The park used as gathering place
 	bool is_visible <- false;		   // Only visible at night
  	point centro_base;
  	float crime_level;             
  
 	init {
		location <- centro_base;	// Set initial position in the park
		crime_level <- my_ubi.real_crime_proxy; 
  	}
  
	reflex horario_botellon {
		int dia <- int(cycle / 24);  // Every 24 cycles it's a day
		int hora <- current_date.hour;
	
		// 7 days cycle: only visible first three days (0,1,2) and during night
		if ((dia mod 7) < ciclo_crimen_botellonero and (hora >= 20 or hora < 3)) {
			is_visible <- true;
		} else {
			is_visible <- false;
		}
	}

	// Visual display only when visible
	aspect base  {
  		if (is_visible) {
    		draw circle(60) color: #blueviolet border: #black;
  		}
	}
}


// CREATING RESIDENTS
species resident skills: [moving] {
	// data from the CSV
	int gender; 
    int nationality;
    string victimized;
    string barrio_res;
    string id;
    float gen_ins;
    int p7_8;
    int age;
    int p10_1;
    int p10_2;
    
    float gender_effect;
	float nationality_effect;
	float victimized_effect;
	float p7_8_effect;
	float darksens_b;
	float darksens_c;
	float p10_1_escaled;
	float p10_2_escaled;
	float darksens;
	
	// dynamic states 
	float prediction; // continuously recalculated predicted insecurity level
    bool is_insecure <- false; // whether prediction exceeds threshold
    
    // location and movement
    building living_place <- nil ;
    building working_place <- nil ; 
    building leisure_place <- one_of(all_leisure_buildings);  
    
    int start_work ;
    int end_work  ;
    float leisure_end_time <- 0.0; 
	float leisure_duration <- 0.0;
	
    string objective; // can be "working", "resting", or "leisure"
    point the_target <- nil ; // target destination for the current activity
    path my_path; // navigation path to reach target
    
    int botellonero_boost_until; // simulation step until which botellonero boost effect lasts 
	
	barrio my_barrio <- one_of(barrio where (each.barrio_name = self.barrio_res)); // stores actual crime proxy at current barrio (night adjustment)
	float lightning_barrio <- 0.0;
	float real_crime_proxy <- 0.0;
    
    
    // --- DAILY LIFE REFLEXES ---
	// Initial state control
	reflex safeguard_rest {
		// Ensures that residents don’t accidentally move early in the morning
		
			  // Si están trabajando pero ya pasó el horario máximo
			 // if objective = "working" and current_date.hour > max_work_end {
			   // objective <- "resting";
			    // the_target <- any_location_in (living_place);
			 // }

	  // If resting before minimum work time, clear any accidental target
		if objective = "resting" and int(current_date.hour) < min_work_start {
			the_target <- nil;
		}
	}
	  
	    
	// Start workday
    // When agent's work start hour arrives, update objective and set movement target to work
	reflex force_work when: floor(current_date.hour) = start_work and objective != "working" {
		objective <- "working";
		the_target <- any_location_in(working_place);
	}


  //  reflex time_to_go_home when: current_date.hour = end_work and objective = "working" {
//    objective <- "resting" ;
//	the_target <- any_location_in (living_place); 
//	}

 
 	// End workday: decide between leisure and going home
	reflex after_work when: floor(current_date.hour) = end_work and objective = "working" {
		if (rnd(0.0, 1.0) < (1 - probabilidad_ocio_fuera)) { // ← always go to leisure; change to 0.6 for 60% probability
			
			// Choose leisure if random draw is under probability
			objective <- "leisure";
	        leisure_duration <- rnd(3.0, 5.0); // Set a random leisure duration
	        leisure_end_time <- current_date.hour + leisure_duration; // Compute when it ends
			
			// Try to find leisure buildings within the same barrio
			if (rnd(0.0, 1.0) < 0.8) {
      			// Prefer leisure locations within the same barrio
				list<building> ocio_en_mi_barrio <- all_leisure_buildings where (each intersects my_barrio.shape);
				if (length(ocio_en_mi_barrio) > 0) {
					leisure_place <- one_of(ocio_en_mi_barrio);
				} else {
					// fallback: if there is no leisure building on its own neighborhood, goes to another one
					leisure_place <- one_of(all_leisure_buildings);
				}
			} else {
				// 20% en otro barrio aleatorio
				list<building> ocio_fuera <- all_leisure_buildings where (!(each intersects my_barrio.shape));
				if (length(ocio_fuera) > 0) {
					leisure_place <- one_of(ocio_fuera);
				} else {
					// fallback por seguridad
					leisure_place <- one_of(all_leisure_buildings);
				}
			}
	        the_target <- any_location_in(leisure_place);
	    } else {
	        // If not going for leisure, go home
	        objective <- "resting";
	        the_target <- any_location_in(living_place);
   	 	}	    
	}
        
    
 	// Finish leisure activity: transition from leisure back to rest when leisure ends
	reflex finish_leisure when: floor(current_date.hour) >= floor(leisure_end_time) and objective = "leisure" {
		objective <- "resting";
	    the_target <- any_location_in(living_place); // Go home
	}

 	// Fallback: if agent is still in leisure mode beyond expected time, force return home
	reflex stuck_after_leisure when: current_date.hour > leisure_end_time + 1 and objective = "leisure" {
		objective <- "resting";
		the_target <- any_location_in(living_place); // Force return home
	}

    // Main movement logic: walks agent toward target location using the graph
	reflex move when: the_target != nil {     	
		do goto target: the_target on: the_graph ; 
		if the_target = location {
		    the_target <- nil ;
		}
	}
	
	
    // INSECURITY CALCULATION
	reflex cal_pred {
    	// Step 1: compute base prediction using personal regression coefficients
	prediction <- gen_ins + gender_effect + nationality_effect + (victimized_effect * victimization_weight);
		

		// Step 2: check for nearby botelloneros
		list<botellonero> botelloneros_cerca <- botellonero  where (each.is_visible) at_distance insecure_distance;
			// if present, increase prediction score
		if (length(botelloneros_cerca) > 0) {
			botellonero_boost_until <- cycle + 2; // Store how long the boost should apply (here 2 hours)
		}

    	// Step 3: if still under the influence of botellonero presence, adjust prediction
		if (cycle < botellonero_boost_until) {
			float criminalidad_actual <- my_barrio.real_crime_proxy; // Current crime score in home barrio
			prediction <- prediction + (length(botelloneros_cerca) * p7_8_effect * (-criminalidad_actual)); // Apply boost effect
		}
		
		// Step 4–6: apply nighttime adjustments based on crime and lighting
		int h <- current_date.hour;
		if (h >= 20 or h < 7) {
		  // Step 4: penalize nighttime perception using crime score of home barrio
		  prediction <- prediction + (crime_weight * my_barrio.real_crime_proxy);
		
		  // Step 5–6: apply lighting effect depending on current location
		  barrio barrio_donde_esta <- one_of(barrio where (intersects(each.shape, self.location)));
		  if (barrio_donde_esta != nil and barrio_donde_esta = my_barrio) {
		    // If currently located in home barrio, apply detailed lighting effect
		    prediction <- prediction + (lightning_barrio * darksens_b);
		  } else if (barrio_donde_esta != nil and barrio_donde_esta != my_barrio) {
		    // If in a different barrio, apply generic sensitivity to darkness
		    prediction <- prediction + darksens_c;
		  }
		}
		
   		// Step 7: assign final label based on threshold
		is_insecure <- prediction > threshold_pred; // Adjust threshold as wanted
	}
    	
    	
	aspect base {
		if prediction <= 0.5 {
            draw  circle(38) color: #midnightblue border: #dimgray; // Very safe
        } else if prediction >  0.5 and prediction <= 1 {
            draw  circle(38) color: #coral border: #dimgray; // Neutral to moderately safe
        } else if prediction > 1 {
            draw  circle(38) color: #red border: #dimgray; // Moderately unsafe 
      
    }
}
}



// EXPERIMENT SET UP
experiment display_shape type: gui {
	
	/* ───────────────────────────────────────────────
     PARAMETERS:
     Control panel for key model values. Some sliders
     are useful during testing, while others (like
     nb_residents) are fixed due to preloaded CSV data.
  ─────────────────────────────────────────────── */
  
	parameter "Number of residents" var: nb_residents category: "resident" ; // Optional: remove if using fixed CSV sampling
	parameter "minimal speed" var: min_speed category: "resident" min: 0.1 #km/#h ;
	parameter "maximal speed" var: max_speed category: "resident" max: 5 #km/#h;
    
    parameter "Shapefile for the roads:" var: roads_shapefile category: "GIS" ;
    parameter "Shapefile for the buildings:" var: buildings_shapefile category: "GIS" ;
    
    parameter "Earliest hour to start work" var: min_work_start category: "resident" min: 2 max: 8;
    parameter "Latest hour to start work" var: max_work_start category: "resident" min: 8 max: 12;
    
    parameter "Earliest hour to end work" var: min_work_end category: "resident" min: 12 max: 16;
    parameter "Latest hour to end work" var: max_work_end category: "resident" min: 16 max: 23;
    
    parameter "Number of botellonero groups" var: nb_grupos_botellon category: "botellonero" ; 
    
    parameter "Threshold is insecure" var: threshold_pred category: "resident" min: -2.0 max: 2.0 step: 0.1;
    parameter "Prob. leisure outside own neighborhood" var: probabilidad_ocio_fuera category: "resident" min: 0.0 max: 1.0 step: 0.05;
    parameter "Nº of days botelloneros are visible" var: ciclo_crimen_botellonero category: "botellonero" min: 0 max: 7 step: 1;
	parameter "Crime weight" var: crime_weight <- 0.5  category: "contextual" min: 0.0 max: 1.0 step: 0.2;

  	// VISUAL DISPLAY 
    output {
    	// Spatial display of city layers and agents
		display pamplona_display type: 3d axes: false background: # whitesmoke {
			species barrio aspect: base;
            species road aspect: base;
            species building aspect: base;
            species parques aspect: base;
            species botellonero aspect: base;
            species resident aspect: base;            
      	}
      	
      	// Charts: objective states, prediction by barrio, insecurity level, safety levels
     	display chart_display refresh: every(10#cycles) {
     		
      		// Chart 1: Histogram of current activity (objective) distribution
 			chart "Resident objectif" type: histogram size: {0.5, 0.5} position: {0, 0.5}{
	     	data "Working" value: resident count (each.objective = "working") color: # palevioletred ;
	        data "Resting" value: resident count (each.objective = "resting") color: # steelblue ;
	        data "Leisure" value: resident count (each.objective = "leisure") color: # peru ;
	  		}

      		// Chart 2: Line series of average prediction by barrio over time
			chart "Mean prediction by barrio" type: series size: {0.5, 0.5} position: {0.5, 0.5} {
				  data "Iturrama" value: mean(resident where (each.barrio_res = "Iturrama") collect each.prediction);
				  data "San Juan/Donibane" value: mean(resident where (each.barrio_res = "San Juan/Donibane") collect each.prediction);
				  data "Casco Viejo/Alde Zaharra" value: mean(resident where (each.barrio_res = "Casco Viejo/Alde Zaharra") collect each.prediction);
				  data "Ensanche/Zabalgunea" value: mean(resident where (each.barrio_res = "Ensanche/Zabalgunea") collect each.prediction);
				  data "Milagrosa-Arrosadia" value: mean(resident where (each.barrio_res = "Milagrosa-Arrosadia") collect each.prediction);
				  data "Rochapea/Arrotxapea" value: mean(resident where (each.barrio_res = "Rochapea/Arrotxapea") collect each.prediction);
				  data "Mendillorri" value: mean(resident where (each.barrio_res = "Mendillorri") collect each.prediction);
				  data "Ermitagaña-Mendebaldea" value: mean(resident where (each.barrio_res = "Ermitagaña-Mendebaldea") collect each.prediction);
				  data "San Jorge-Sanduzelai" value: mean(resident where (each.barrio_res = "San Jorge-Sanduzelai") collect each.prediction);
				  data "Txantrea" value: mean(resident where (each.barrio_res = "Txantrea") collect each.prediction);
				  data "Etxabakoitz" value: mean(resident where (each.barrio_res = "Etxabakoitz") collect each.prediction);
				  data "Lezkairu" value: mean(resident where (each.barrio_res = "Lezkairu") collect each.prediction);
				  data "Buztintxuri-Euntzetxiki" value: mean(resident where (each.barrio_res = "Buztintxuri-Euntzetxiki") collect each.prediction);
				}
			
      		// Chart 3: Total number of insecure and secure residents
			chart "Residents classified as insecure (threshold-based)" type: series size: {0.5, 0.5} position: {0.0, 0.0}  {
				data "secure" value: nb_resident_not_insecure style: line color: #green;
				data "insecure" value: nb_resident_insecure style: line color: #red;
				}
			
      		// Chart 4: Safety levels grouped by prediction thresholds
			chart "Distribution of residents depending on safety level" type: histogram size: {0.5, 0.5} position: {0.5, 0.0} {
				data "<= 0.5 " value: resident count (each.prediction <= 0.5 ) color:#midnightblue;
				data "0.5 to 1" value: resident count ((each.prediction > 0.5) and (each.prediction <= 1)) color:#coral;
				data "> 1" value: resident count (each.prediction > 1) color:#red;	  
        		}
        	}		
   		// Monitors to track global states
	    monitor "Number of insecure people" value: nb_resident_insecure;
		monitor "Number of secure people" value: nb_resident_not_insecure;		
			
	}
}

			
// STOCHASTIC ANALYSIS
  // Repeats the model several times to evaluate variability in outputs.
  // Required to decide number of repetitions needed in other experiments.
experiment stoch type: batch  repeat: 153 until: cycle > 168 keep_simulations:false {
	output {
	  monitor "avg_prediction" value: mean(resident collect each.prediction);
	  monitor "stddev_prediction" value: standard_deviation(resident collect each.prediction);
	  monitor "max_prediction" value: max(resident collect each.prediction);
	  monitor "avg_prediction_women" value: mean(resident where (each.gender = 0) collect each.prediction);		  
	}
	
	method stochanalyse 
	outputs:["insecure_rate", "avg_prediction", "stddev_prediction", "max_prediction", "avg_prediction_women"] 
	report:"Results/stochanalysis.txt" results:"Results/stochanalysis.csv" sample:2;
} 


// OAT SENSITIVITY ANALYSIS			
  // Varies the crime weight parameter to test its effect on insecurity levels
experiment sens_crime_weight type: batch repeat: 80 keep_seed: true until: cycle > 168 {
	method exploration;
	parameter "Crime weight" var: crime_weight min: 0.0 max: 1.0 step: 0.2;
	int cpt <- 0;
	reflex saved_d {
		save [crime_weight,
		insecure_rate,
		mean(resident collect each.prediction),
		standard_deviation(resident collect each.prediction),
		max(resident collect each.prediction),
		mean(resident where (each.gender = 0) collect each.prediction)] to: "sens_crime_weight_summary" + cpt + ".csv" type: "csv";
		cpt <- cpt + 1;
	}
}


  // Tests the effect of the number of botellonero groups on perceived insecurity
experiment sens_botellon type: batch repeat: 80 keep_seed: true until: cycle > 168 {
	method exploration;
	parameter "Nº of botellonero groups" var: nb_grupos_botellon min: 3 max: 15 step: 3;
	int cpt <- 0;
	reflex saved_d {
		save [nb_grupos_botellon,
		insecure_rate,
		mean(resident collect each.prediction),
		standard_deviation(resident collect each.prediction),
		max(resident collect each.prediction),
		mean(resident where (each.gender = 0) collect each.prediction)] to: "sens_botellon_summary" + cpt + ".csv" type: "csv";
		cpt <- cpt + 1;
	}
}


  // Tests how increasing the probability of going out after work affects the model
experiment sens_ocio type: batch repeat: 80 keep_seed: true until: cycle > 168 {
	method exploration;
	parameter "Prob. leisure outside own neighborhood" var: probabilidad_ocio_fuera min: 0.1 max: 1.0 step: 0.2;
	int cpt <- 0;
	reflex saved_d {
		save [probabilidad_ocio_fuera,
		insecure_rate,
		mean(resident collect each.prediction),
		standard_deviation(resident collect each.prediction),
		max(resident collect each.prediction),
		mean(resident where (each.gender = 0) collect each.prediction)] to: "sens_ocio_summary" + cpt + ".csv" type: "csv";
		cpt <- cpt + 1;
	}
}


  // Adjusts the threshold for classifying someone as insecure
experiment sens_threshold type: batch repeat: 80 keep_seed: true until: cycle > 168 {
	method exploration;
	parameter "Population classified as insecure (threshold-based)" var: threshold_pred min: 0.0 max: 1.0 step: 0.2;
	int cpt <- 0;
	
	reflex saved_d {
		save [threshold_pred,
		insecure_rate,
		mean(resident collect each.prediction),
		standard_deviation(resident collect each.prediction),
		max(resident collect each.prediction),
		mean(resident where (each.gender = 0) collect each.prediction)] to: "sens_threshold_summary" + cpt + ".csv" type: "csv";
		cpt <- cpt + 1;
	}
}

experiment sens_victimization_weight type: batch repeat: 80 keep_seed: true until: cycle > 168 {
	method exploration;
	parameter "Victimization weight" var: victimization_weight min: 1 max: 4.0 step: 1.0;
	int cpt <- 0;
	reflex saved_d {
		save [victimization_weight,
		insecure_rate,
		mean(resident collect each.prediction),
		standard_deviation(resident collect each.prediction),
		max(resident collect each.prediction),
		mean(resident where (each.gender = 0) collect each.prediction)] to: "sens_victimization_summary" + cpt + ".csv" type: "csv";
		cpt <- cpt + 1;
	}
}


