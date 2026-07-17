class_name Gear
extends RefCounted

enum Era { WWI, INTERWAR, EARLYWAR, MIDWAR, LATEWAR }
enum TuningStyle { BEST_ACCEL = 1, FAVOR_ACCEL, BALANCED, FAVOR_SPEED, BEST_SPEED }

## Result container for gear calculations
class GearCalculationResult:
	var gear_ratios: Array[float] = []
	var top_speed_kmh: float = 0.0
	var top_speed_mph: float = 0.0
	var upshift_rpm: float = 0.0
	var downshift_rpm: float = 0.0

## Get era-specific configuration values
static func get_era_config(era: Era) -> Dictionary:
	match era:
		Era.WWI:
			return { "resistance": 4.0, "base_rpm": 1500, "power_mod": 0.2333 }
		Era.INTERWAR:
			return { "resistance": 3.0, "base_rpm": 2700, "power_mod": 0.586 }
		Era.EARLYWAR:
			return { "resistance": 1.5, "base_rpm": 3100, "power_mod": 0.72 }
		Era.MIDWAR:
			return { "resistance": 1.25, "base_rpm": 3800, "power_mod": 0.92 }
		Era.LATEWAR:
			return { "resistance": 1.0, "base_rpm": 4000, "power_mod": 1.0 }
		_:
			return { "resistance": 1.0, "base_rpm": 4000, "power_mod": 1.0 }

static func calculate_gears(
	weight_tons: float,
	cylinder_count: int,
	cylinder_displacement_liters: float,
	sprocket_diameter_meters: float,
	gear_count: int,
	era: Era = Era.LATEWAR,
	tuning_style: TuningStyle = TuningStyle.FAVOR_SPEED,
	climb_angle_degrees: float = 80.0
) -> GearCalculationResult:
	
	var result = GearCalculationResult.new()
	var config = get_era_config(era)
	
	var hp = cylinder_count * 40.0 * config.power_mod * pow(cylinder_displacement_liters, 0.7)
	var max_rpm = round(config.base_rpm * pow(cylinder_displacement_liters, -0.3) * 1.112)
	# Apply tuning style adjustment
	var style_adjustment = (5 - int(tuning_style)) * 0.08
	hp = hp - (hp * style_adjustment)
	
	# Calculate top speed
	var top_speed = (13.666 * pow(hp, 0.501)) / (pow(config.resistance, 0.8) * pow(weight_tons, 0.5))
	result.top_speed_kmh = snappedf(top_speed, 0.1)
	result.top_speed_mph = snappedf(top_speed * 0.621371, 0.1)  # Convert km/h to mph
	
	# Calculate final gear
	var final_gear = (60.0 * PI * max_rpm * sprocket_diameter_meters * 10.0) / (12.5 * 10000.0 * top_speed)
	final_gear = snappedf(final_gear, 0.01)
	
	# Calculate first gear
	var torque = (9.5492 / max_rpm) * 746.0 * hp
	var angle_rad = deg_to_rad(climb_angle_degrees)
	var gear1 = (0.11 * (sprocket_diameter_meters / 2.0) * (1000.0 * weight_tons) * 9.81 * sin(angle_rad)) / torque
	gear1 = snappedf(gear1, 0.01)
	
	# clamp gear1 if in range
	if gear1 > 20.0 and gear1 < 32.5:
		gear1 = 20.0
	
	# Calculate intermediate gears
	if gear_count == 1:
		result.gear_ratios = [final_gear]
	else:
		result.gear_ratios.resize(gear_count)
		result.gear_ratios[0] = gear1
		result.gear_ratios[gear_count - 1] = final_gear
		
		if gear_count > 2:
			var rat_in = pow(gear1 / final_gear, 1.0 / pow(gear_count, 1.25))
			var k_value = log(gear1 / final_gear / rat_in) / log(gear_count / rat_in)
			
			for i in range(1, gear_count - 1):
				var gear_i = gear1 / (pow(rat_in, 1.0 - k_value) * pow(i + 1, k_value))
				result.gear_ratios[i] = snappedf(gear_i, 0.01)
	
	# Calculate shift points
	var ideal_rpm = round(config.base_rpm * pow(cylinder_displacement_liters, -0.3) * 1.01)
	result.upshift_rpm = ideal_rpm
	
	if gear_count > 1:
		var gear1_ratio = result.gear_ratios[0]
		var gear2_ratio = result.gear_ratios[1]
		result.downshift_rpm = round(ideal_rpm / (gear1_ratio / gear2_ratio))
	else:
		result.downshift_rpm = ideal_rpm * 0.7
	
	return result
