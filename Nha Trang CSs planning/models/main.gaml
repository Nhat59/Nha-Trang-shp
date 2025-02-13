model main

import "Traffic.gaml"

global {
	   int charging_stations <- 0;
	   
	   action clear_data {
        // Remove all roads
        ask road {
            do die;
        }
        // Remove all cars
        ask car {
            do die;
        }
        // Remove all electric vehicles
        ask private_ev {
            do die;
        }
        ask taxi_ev {
            do die;
        }
        // Remove all charging stations
        ask charging_station {
            do die;
        }
        // Reset global variables
        open_roads <- []; // Clear the list of open roads
        road_network <- nil; // Clear the road network graph
        write "All data cleared.";
    }



	float step <- 1.0 #s;
	list<road> open_roads;
	float player_size_GAMA <- 20.0;
	//geometry shape <- envelope(resources_dir + "output_shapefile.shp");
	//geometry form <- envelope(resources_dir + "output_shapefile.shp");
	

	string images_dir <- "../images/";
	list<rgb> pal <- palette([#green, #yellow, #orange, #red]);
	map<rgb, string> legends <- [
		color_car::"Cars",
		color_road::"Roads",
		color_lake::"Rivers & Lakes",
		color_private::"Private EVs"	
	];
	rgb color_car <- #red;
	rgb color_private <- #cyan;
	rgb color_taxi <- #yellow;
	rgb color_road <- #black;
	rgb color_lake <- rgb(165, 199, 238, 255);
	rgb color_inner_building <- rgb(100, 100, 100);
	rgb color_outer_building <- rgb(60, 60, 60);
	rgb color_charging_station <- #yellow;  // Example for charging stations
	

	// Initialization
	string resources_dir <- "../includes/";
	shape_file buildings_shape_file <- shape_file(resources_dir + "test_building.shp");
	geometry shape <- envelope(buildings_shape_file);
	int cars <- 100;
	int elecars <- 50;
	int total_cars <- cars + elecars;
	float percents <- elecars / total_cars;
	int motos <- 0;
	init {
		// Load roads
		do clear_data;
		create road from: shape_file(resources_dir + "test_road.shp");
		loop r over: road {
				create road with: (shape: polyline(reverse(r.shape.points)), name: r.name, type: r.type);
		}
		create building from: shape_file(buildings_shape_file);
		ask road {
			agent ag <- building closest_to self;
			float dist <- ag = nil ? 8.0 : max(min(ag distance_to self - 5.0, 8.0), 2.0);
			num_lanes <- int(dist / lane_width);
			capacity <- 1 + (num_lanes * shape.perimeter / 3);
		}
	
		open_roads <- list(road);
		
		create charging_station from: shape_file(resources_dir + "test_cs.shp");
		do update_road(0);
		write "intersection " + length(intersection);
		//write "Số lượng charging_station đã đọc: " + length(charging_station);
//		loop r over: charging_station{
//			write "type: " + r.closest_intersection;		
//		}
//		ask charging_station{
//			closest_intersection <- intersection closest_to self;
//		}
//		loop r over: charging_station{
//			r.closest_intersection <- intersection closest_to r;
//			//write "type: " + r.closest_intersection.location;
//		}
		do update_car_population(cars);
		do update_EV_population(percents);
		
		// Update populations
		
		
//		loop r over: charging_station{
//			write "type: " + r.closest_intersection.location;		
//		}
		
//		loop r over: charging_station{
//			write "type: " + r.closest_intersection.location;		
//		}
//		ask agents of_generic_species vehicle {
//			do select_target_path;
//		} 
		
	}

//	action update_elecar_population (int new_number) {
//		int delta <- length(elecar) - new_number;
//		if (delta > 0) {
//			ask delta among elecar {
//				do unregister;
//				do die;
//			}
//		} else if (delta < 0) {
//			create elecar number: -delta;
//		}
//	}
//	action update_motorbike_population (int new_number) {
//		int delta <- length(motorbike) - new_number;
//		if (delta > 0) {
//			ask delta among motorbike {
//				do unregister;
//				do die;
//			}
//
//		} else if (delta < 0) {
//			create motorbike number: -delta;
//		}
//
//	}
	action update_car_population (int new_number) {
		int delta <- length(car) - new_number;
		if (delta > 0) {
			ask delta among car {
				do unregister;
				do die;
			}
		} else if (delta < 0) {
			create car number: -delta;
		}		
	}
	action update_EV_population (float percent) {
    int target_ev_count <- int(percent * total_cars);

    int target_private_ev <- int(target_ev_count / 2);
    int target_taxi_ev <- target_ev_count - target_private_ev;

    int current_private_ev <- length(private_ev);
    int delta_private_ev <- target_private_ev - current_private_ev;

    if (delta_private_ev > 0) {
        create private_ev number: delta_private_ev;
    } else if (delta_private_ev < 0) {
        ask (-delta_private_ev) among private_ev {
            do die;
        }
    }

    int current_taxi_ev <- length(taxi_ev);
    int delta_taxi_ev <- target_taxi_ev - current_taxi_ev;

    if (delta_taxi_ev > 0) {
        create taxi_ev number: delta_taxi_ev;
    } else if (delta_taxi_ev < 0) {
        ask (-delta_taxi_ev) among taxi_ev {
            do die;
        }
    }
}
	action update_road (int scenario){

		ask building {
			closest_intersection <- nil;
		}
		ask charging_station {
			closest_intersection <- nil;
		}
		

		ask intersection {
			do die;
		}

		graph g <- as_edge_graph(open_roads);
		loop pt over: g.vertices {
			create intersection with: (shape: pt);
		}

		ask building {
			closest_intersection <- intersection closest_to self;
		}
		ask agents of_generic_species charging_station  {
			closest_intersection <- intersection closest_to self;
		}
//		ask charging_station  {
//			closest_intersection <- intersection closest_to self;
//		}
		ask road {
			vehicle_ordering <- nil;
		}
		//build the graph from the roads and intersections
		road_network <- as_driving_graph(open_roads, intersection) with_shortest_path_algorithm #FloydWarshall;
		//geometry road_geometry <- union(open_roads accumulate (each.shape));
		ask agents of_generic_species vehicle {
			do select_target_path;
		} 
	}
	
}

experiment "Run me" autorun: true{
	
	float maximum_cycle_duration <- 0.15;
	parameter "Cars" category: "Param" var: cars slider: true min: 0 max: 2000 {
		ask world {
			do update_car_population(cars);
		}
	}
	parameter "ElectricVehi" category: "Param" var: elecars slider: true min: 0 max: 2000 {
		ask world {
			do update_EV_population(percents);
		}
	}
    //parameter "Additional Charging Station" category: "Param" var: charging_stations slider: true min: 0 max: 5 {}
	
//	parameter "Motorbike" category: "Param" var: motos slider: true min: 0 max: 2000 {
//		ask world {
//			do update_motorbike_population(motos);
//		}
//
//	}
//	
	output {
		display Computer virtual: false type: 3d toolbar: true background: #white axes: false {
			species road {
				draw self.shape + 4 color: color_road;
			}
		species car {
       		draw rectangle(vehicle_length * 5, lane_width * num_lanes_occupied * 5) at: location color: color_car;
    	}
    	species private_ev {
        	draw rectangle(vehicle_length * 5, lane_width * num_lanes_occupied * 5) at: location color: color_private;
    	}
    	species taxi_ev {
        	draw rectangle(vehicle_length * 5, lane_width * num_lanes_occupied * 5) at: location color: color_taxi;
    	}
    	species building {
				draw self.shape color: color_outer_building;
			}
    	species charging_station aspect: base;
   		species intersection;
   		
   		
   		//species intersection aspect: base;
//		agents "Vehicles" value: (agents of_generic_species (vehicle)) where (each.current_road != nil) {
//				draw rectangle(vehicle_length * 10, lane_width * num_lanes_occupied * 5) at: shift_pt color: type = CAR ? color_car : color_EVs rotate: self.heading;
//			}
		}
	}

}
