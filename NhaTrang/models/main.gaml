model main

import "Traffic.gaml"

global {
	float step <- 1.0 #s;
	list<road> open_roads;
	float player_size_GAMA <- 20.0;

    string images_dir <- "../images/";
    list<rgb> pal <- palette([#green, #yellow, #orange, #red]);
    map<rgb, string> legends <- [
        color_car::"Cars",
        color_EVs::"ElecCars",
        color_road::"Roads",
        color_closed::"Closed Roads",
        color_lake::"Rivers & Lakes"
    ];
    rgb color_car <- #lightblue;
    rgb color_EVs <- #cyan;
    rgb color_road <- #lightgray;
    rgb color_closed <- #mediumpurple;
    rgb color_lake <- rgb(165, 199, 238, 255);

	// Initialization 
	string resources_dir <- "../includes/";
	int cars <- 1000;
	int elecars <- 500;
	int close_road <- 0;

	init {
		create road from: shape_file(resources_dir + "line.shp");
		loop r over: road {
			if (!r.oneway) {
				create road with: (shape: polyline(reverse(r.shape.points)), name: r.name, type: r.type, s1_closed: r.s1_closed, s2_closed: r.s2_closed);
			} }
		create charging_station from: shape_file(resources_dir + "output_shapefile.shp");

//		do update_road_scenario(0);
		do update_car_population(cars);
		do update_elecar_population(elecars);
	}

	action update_elecar_population (int new_number) {
		int delta <- length(elecar) - new_number;
		if (delta > 0) {
			ask delta among elecar {
				do unregister;
				do die;
			}

		} else if (delta < 0) {
			create elecar number: -delta;
		}

	}

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
	action update_EV_population (int percent) {
    int total_cars <- length(car);
    int target_ev_count <- int(percent * total_cars / 100);

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


	
    action update_road_scenario (int scenario) {
        open_roads <- scenario = 1 ? road where !each.s1_closed : (scenario = 2 ? road where !each.s2_closed : list(road));

        list<road> closed_roads <- road - open_roads;
        ask open_roads {
            closed <- false;
        }

        ask closed_roads {
            closed <- true;
        }

        ask agents of_generic_species vehicle {
            do unregister;
            if (current_road in closed_roads) {
                do die;
            }
        }
        ask agents of_generic_species vehicle {
            do select_target_path;
        }
    }
}
experiment "Run me" autorun: true {
	float maximum_cycle_duration <- 0.15;
	parameter "Cars" category: "Param" var: cars slider: true min: 0 max: 2000 {
		ask world {
			do update_car_population(cars);
		}

	}
	parameter "Motorbike" category: "Param" var: elecars slider: true min: 0 max: 2000 {
		ask world {
			do update_elecar_population(elecars);
		}

	}

	parameter "Closed Road" category: "Param" var: close_road slider: true min: 0 max: 2 {
		ask world {
			do update_road_scenario(close_road);
		}

	}

	output {
		display Computer virtual: false type: 3d toolbar: true background: #black axes: false {
			species road {
				draw self.shape + 4 color: closed ? color_closed : color_road;
			}
			species charging_station {
    			draw shape at: location color: #yellow size: 20 border: #black;
			}
			
			agents "Vehicles" value: (agents of_generic_species (vehicle)) where (each.current_road != nil) {
				draw rectangle(vehicle_length * 5, lane_width * num_lanes_occupied * 5) at: shift_pt color: type = CAR ? color_car : color_EVs rotate: self.heading;
			}

		}

	}

}

