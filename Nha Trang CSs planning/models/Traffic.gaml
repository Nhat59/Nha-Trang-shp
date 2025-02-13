model traffic

global {
	string CAR <- "car";
	string EVS <- "elecar";
	graph road_network;
	float lane_width <- 1.0;
}

species intersection schedules: [] skills: [intersection_skill] {

	aspect base {
		draw circle(40) color: #green;
	}
	//intersection closest_intersection <- intersection closest_to self;	
}

species charging_station {
	intersection closest_intersection <- intersection closest_to self;
	int capacity <- 10; // Maximum number of vehicles that can charge at a time
	list<elecar> charging_vehicles; // Vehicles currently charging
	list<elecar> waiting_queue; // Queue of vehicles waiting to charge
	int served_customer <- 0;

	aspect base {
		draw circle(30) color: #purple;
	}

	action add_to_queue (elecar ev) {
		waiting_queue << ev;
	}

	action process_queue {
		if (!empty(waiting_queue)) {
			elecar next_vehicle <- waiting_queue[0];
			remove next_vehicle from: waiting_queue;
			ask next_vehicle {
				do start_charging;
			}

		}

	}

	bool check_in_queue (vehicle ev) {
		return ev in waiting_queue;
	}

}

species road skills: [road_skill] {
	string type;
	//	bool oneway;
	//	bool s1_closed;
	//	bool s2_closed;
	int num_lanes <- 4;
	//	bool closed;
	float capacity;
	int nb_vehicles -> length(all_agents);
	float speed_coeff <- 1.0 min: 0.1 update: 1.0 - (nb_vehicles / capacity);

	init {
		capacity <- 1 + (num_lanes * shape.perimeter / 3);
	}

}

species vehicle skills: [driving] {
	string type;
	building target;
	point shift_pt <- location;
	bool at_home <- true;
	building temp_target <- nil;
	bool is_ev <- false;

	init {
		proba_respect_priorities <- 0.0;
		proba_respect_stops <- [1.0];
		proba_use_linked_road <- 0.0;
		lane_change_limit <- 2;
		linked_lane_limit <- 0;
		location <- one_of(building).location; // Start at a random intersection
	}

	action select_target_path {
		target <- one_of(building);
		write target.location;
		write target.closest_intersection;
		location <- (intersection closest_to self).location;
		do compute_path graph: road_network target: target.closest_intersection;
	}

	reflex choose_path when: final_target = nil { // bug khung bug dien // aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
		do select_target_path;
	}

	reflex move when: final_target != nil {
		do drive;
		if (final_target = nil) {
			do unregister;
			at_home <- true;
			location <- target.location;
		} else {
			shift_pt <- compute_position();
		}

	}

	point compute_position {
		if (current_road != nil) {
			float dist <- (road(current_road).num_lanes - lowest_lane - mean(range(num_lanes_occupied - 1)) - 0.5) * lane_width;
			if violating_oneway {
				dist <- -dist;
			}

			return location + {cos(heading + 90) * dist / 10, sin(heading + 90) * dist / 10};
		} else {
			return {0, 0};
		}

	}

}

species car parent: vehicle {
	float vehicle_length <- rnd(4.0, 5.0) #m;
	int num_lanes_occupied <- 2;
	float max_speed <- rnd(5) #m / #s;
}

species elecar parent: vehicle {
	float vehicle_length <- float(rnd(4.0, 5.0)) #m;
	int num_lanes_occupied <- 2;
	float max_speed <- float(20) #m / #s;
	bool needs_charging <- false;
	charging_station current_station <- nil;
	list<charging_station> all_stations;
	point target_station;
	bool is_charging <- false;
	float battery_level <- float(rnd(70, 100));
	float charge_rate <- 1.0;

	//reflex check_battery when: battery_level < 30 and needs_charging = false{
	reflex choose_path when: final_target = nil and !needs_charging {
		do select_target_path;
	}

	reflex move when: final_target != nil and battery_level > 0.0 {
		if (!is_charging) {
			do drive;
			// Check if need charging
			if (battery_level < 30.0 and current_station = nil) {
				needs_charging <- true;
				do select_charging_station;
			}

			// Try to start charging if near station
			//            if (current_station != nil and final_target) {
			//                do start_charging;
			//            }
			shift_pt <- compute_position();
		}

	}

	action select_charging_station {
		temp_target <- target;
		current_station <- all_stations with_min_of (each distance_to self);
		if (current_station != nil) {
			do compute_path graph: road_network target: current_station.closest_intersection;
		} else {
			write ""+self+" khong tim thay charging station";
		}

	}

	reflex charge when: current_station != nil and final_target = nil and needs_charging {
		temp_target <- target;
		do start_charging;
	}

	action start_charging {
		ask current_station {
			if (length(charging_vehicles) < capacity) {
				charging_vehicles << myself;
				ask myself {
					is_charging <- true;
				}

			} else {
				do add_to_queue(myself);
			}

		}

	}

	reflex charging when: is_charging {
		battery_level <- min(100.0, battery_level + charge_rate / 100);
		if (battery_level >= 100.0) {
			do stop_charging;
		}

	}

	action stop_charging {
		is_charging <- false;
		needs_charging <- false;
		ask current_station {
			remove myself from: charging_vehicles;
			do process_queue();
			served_customer <- served_customer + 1;
			write myself.location + served_customer;
		}

		current_station <- nil;
	}

	//   reflex charge when: target_station != nil and location = target_station.location and needs_charging {
	//    	 if (!charging) {
	//            // Notify the station of arrival
	//            ask target_station {
	//                // do handle_arrival(self);
	//            } 
	//        	}
	//        if (charging) {
	//            // Charge the battery
	//            battery_level <- min(battery_level + charge_rate, 100);  
	//            
	//            if (battery_level = 100) {
	//                // Charging complete
	//                needs_charging <- false;                         
	//                target_station <- nil;                          
	//                charging <- false;
	//
	//                // Notify the station of departure
	//                ask target_station {
	//                   // do handle_departure(self);
	//                }
	//
	//                do select_target_path;                           
	//        }
	//    	}
	//    
	//    }
	action select_target_path {
		if temp_target = nil {
			target <- one_of(building);
		} else {
			target <- temp_target;
			temp_target <- nil;
		}

		write target.location;
		write target.closest_intersection;
		location <- (intersection closest_to self).location;
		do compute_path graph: road_network target: target.closest_intersection;
	}

	reflex consume_battery when: battery_level > 0.0 and is_charging = false {
		battery_level <- max(battery_level - rnd(0.01, 0.03), 0); // Deplete battery as the car moves
	}

}

species private_ev parent: elecar {
//	building home_location <- one_of(building);
//
//    reflex choose_random_target when: at_home {
//        target <- one_of(building); 
//        at_home <- false;
//        do compute_path graph: road_network target: target;  
//  	}

}

species taxi_ev parent: elecar {
//    reflex continuous_movement {
//        if (final_target = nil) {
//            target <- one_of(building); 
//            do compute_path graph: road_network target: target;
//        }
//        do drive;
//   }
//	
}

species building schedules: [] {
	intersection closest_intersection <- intersection closest_to self.location;
	string type;
	int pollution_index;
}