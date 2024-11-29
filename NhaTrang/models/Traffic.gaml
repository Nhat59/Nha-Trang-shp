model traffic

global {
	string CAR <- "car";
	string EVS <- "elecar";
	string OUT <- "outArea";	
	graph road_network;
	float lane_width <- 0.1;
}


species intersection schedules: [] skills: [intersection_skill] {}

species charging_station {
	    point location <- one_of(shape).location; 
    int capacity <- 5;
    list<vehicle> charging_vehicles <- [];   
}

species road  skills: [road_skill]{
	string type;
	bool oneway;
	bool s1_closed;
	bool s2_closed;
	int num_lanes <- 4;
	bool closed;
	float capacity ;
	int nb_vehicles <- length(all_agents) update: length(all_agents);
	float speed_coeff <- 1.0 min: 0.1 update: 1.0 - (nb_vehicles/ capacity);
	init {
		 capacity <- 1 + (num_lanes * shape.perimeter/3);
	}
}


species car parent: vehicle {
	float vehicle_length <-rnd(4.0,5.0) #m;
	int num_lanes_occupied <-2;
	float max_speed <-rnd(50,70) #km / #h;
		
}

species elecar parent: vehicle {
    float vehicle_length <- float(rnd(4.0, 5.0)) #m;
    int num_lanes_occupied <- 2;
    float max_speed <- float(rnd(50, 60)) #km / #h;

    bool needs_charging <- false;             
    charging_station target_station <- nil;  
    float battery_level <- float(rnd(30, 100));      
    float charge_rate <- 5.0;                 

    reflex check_battery when: battery_level < 20 and !needs_charging {
        target_station <- one_of(charging_station); 
        needs_charging <- true;
        do compute_path graph: road_network target: target_station; 
    }

    reflex charge when: target_station != nil and location = target_station.location and needs_charging {
        battery_level <- min(battery_level + charge_rate, 100);  // Recharge battery

        if (battery_level = 100) {  // Fully charged
            needs_charging <- false;                         // Charging complete
            target_station <- nil;                           // Reset the target station
            do select_target_path;                           // Resume normal movement
        }
    }

    reflex consume_battery when: battery_level > 0 and !needs_charging {
        battery_level <- max(battery_level - rnd(0.1, 0.5), 0); // Deplete battery as the car moves
    }
}

species private_ev parent: elecar {
	point home_location <- road(one_of(road)).location + {rnd(-10, 10), rnd(-10, 10)};

    reflex choose_random_target when: at_home {
        target <- road(one_of(charging_station)); 
        at_home <- false;
        do compute_path graph: road_network target: target;
    }

    reflex move when: final_target != nil {
        do drive;
        if (final_target = nil) {
            at_home <- true;
            location <- home_location; 
        }
    }
}


species taxi_ev parent: elecar {
    reflex continuous_movement {
        if (final_target = nil) {
            target <- one_of(road); 
            do compute_path graph: road_network target: target;
        }
        do drive;
    }
}




species vehicle skills:[driving] {
	string type;
	road target;
	point shift_pt <- location ;	
	bool at_home <- true;
	
	bool is_ev<-false;
	
	init {
		
		proba_respect_priorities <- 0.0;
		proba_respect_stops <- [1.0];
		proba_use_linked_road <- 0.0;

		lane_change_limit <- 2;
		linked_lane_limit <- 0; 
        location <- one_of(road).shape.location; // Start at a random road
	}

	action select_target_path {
	    	target <- one_of(road);
	    if (target = nil) {
	        write "No roads available!";
	        return; // Exit the action if no roads exist
	    }
	    location <- (road closest_to self).location;
	    if (location = nil) {
	        write "No nearby roads for agent at: " + self.location;
	        return; // Exit the action if no road is close enough
	    }
	    do compute_path graph: road_network target: target; 
}

	
	reflex choose_path when: final_target = nil  {
		do select_target_path;
	}
	
	reflex move when: final_target != nil {
		do drive;
		if (final_target = nil) {
			do unregister;
			at_home <- true;
			location <- target.location;
		} else {
			shift_pt <-compute_position();
		}
		
	}
	
	
	point compute_position {
		if (current_road != nil) {
			float dist <- (road(current_road).num_lanes - lowest_lane -
				mean(range(num_lanes_occupied - 1)) - 0.5) * lane_width;
			if violating_oneway {
				dist <- -dist;
			}
		 	
			return location + {cos(heading + 90) * dist/10, sin(heading + 90) * dist/10};
		} else {
			return {0, 0};
		}
	}	
	
}
