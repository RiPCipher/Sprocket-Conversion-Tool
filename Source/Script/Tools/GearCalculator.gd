extends MarginContainer

# Era CheckButtons
@onready var era_ww1: CheckButton = $Main/HBody/LeftPanel/EraAndStyle/VehicleEra/WW1/CheckButton
@onready var era_interwar: CheckButton = $Main/HBody/LeftPanel/EraAndStyle/VehicleEra/Interwar/CheckButton
@onready var era_earlywar: CheckButton = $Main/HBody/LeftPanel/EraAndStyle/VehicleEra/Earlywar/CheckButton
@onready var era_midwar: CheckButton = $Main/HBody/LeftPanel/EraAndStyle/VehicleEra/Midwar/CheckButton
@onready var era_latewar: CheckButton = $Main/HBody/LeftPanel/EraAndStyle/VehicleEra/Latewar/CheckButton

# Tuning Style CheckButtons
@onready var style_best_accel: CheckButton = $Main/HBody/LeftPanel/EraAndStyle/TuningStyle/BestAccel/CheckButton
@onready var style_favor_accel: CheckButton = $Main/HBody/LeftPanel/EraAndStyle/TuningStyle/FavorAccel/CheckButton
@onready var style_balanced: CheckButton = $Main/HBody/LeftPanel/EraAndStyle/TuningStyle/Balanced/CheckButton
@onready var style_favor_speed: CheckButton = $Main/HBody/LeftPanel/EraAndStyle/TuningStyle/FavorSpeed/CheckButton
@onready var style_best_speed: CheckButton = $Main/HBody/LeftPanel/EraAndStyle/TuningStyle/BestSpeed/CheckButton

# Configuration SpinBoxes
@onready var weight_spinbox: SpinBox = $Main/HBody/LeftPanel/Configuration/VehicleWeight/SpinBox
@onready var cylinder_size_spinbox: SpinBox = $Main/HBody/LeftPanel/Configuration/CylinderSize/SpinBox
@onready var cylinder_count_spinbox: SpinBox = $Main/HBody/LeftPanel/Configuration/CylinderCount/SpinBox
@onready var gear_count_spinbox: SpinBox = $Main/HBody/LeftPanel/Configuration/GearCount/SpinBox
@onready var sprocket_diameter_spinbox: SpinBox = $"Main/HBody/LeftPanel/Configuration/Sprocket Diameter/SpinBox"

# Output Labels
@onready var top_speed_kmh_label: Label = $Main/HBody/ScrollContainer/RightPanel/TopSpeedKMH
@onready var top_speed_mph_label: Label = $Main/HBody/ScrollContainer/RightPanel/TopSpeedMPH
@onready var upshift_label: Label = $Main/HBody/ScrollContainer/RightPanel/Upshift
@onready var downshift_label: Label = $Main/HBody/ScrollContainer/RightPanel/Downshift
@onready var right_panel: VBoxContainer = $Main/HBody/ScrollContainer/RightPanel
@onready var hseparator3: HSeparator = $Main/HBody/ScrollContainer/RightPanel/HSeparator3

# Gear label container
var gear_labels_container: VBoxContainer = null

# Era and Style button groups
var era_buttons: Array[CheckButton] = []
var style_buttons: Array[CheckButton] = []

func _ready() -> void:
	# Set up button groups
	era_buttons = [era_ww1, era_interwar, era_earlywar, era_midwar, era_latewar]
	style_buttons = [style_best_accel, style_favor_accel, style_balanced, style_favor_speed, style_best_speed]
	
	# Set defaults
	era_latewar.button_pressed = true
	style_favor_speed.button_pressed = true
	
	# Set default values for spinboxes
	weight_spinbox.value = 28.0
	cylinder_size_spinbox.value = 2.4
	cylinder_count_spinbox.value = 6
	gear_count_spinbox.value = 6
	sprocket_diameter_spinbox.value = 0.6
	
	for button in era_buttons:
		button.toggled.connect(_on_era_button_toggled.bind(button))
	
	for button in style_buttons:
		button.toggled.connect(_on_style_button_toggled.bind(button))
	
	# Connect SpinBox signals
	weight_spinbox.value_changed.connect(_on_input_changed)
	cylinder_size_spinbox.value_changed.connect(_on_input_changed)
	cylinder_count_spinbox.value_changed.connect(_on_input_changed)
	gear_count_spinbox.value_changed.connect(_on_input_changed)
	sprocket_diameter_spinbox.value_changed.connect(_on_input_changed)
	
	_create_gear_labels_container()
	_calculate_and_update()

func _create_gear_labels_container() -> void:
	gear_labels_container = VBoxContainer.new()
	gear_labels_container.set("theme_override_constants/separation", 3)
	
	# Insert before HSeparator3
	var separator_index = hseparator3.get_index()
	right_panel.add_child(gear_labels_container)
	right_panel.move_child(gear_labels_container, separator_index)

func _on_era_button_toggled(toggled_on: bool, button: CheckButton) -> void:
	if toggled_on:
		for era_button in era_buttons:
			if era_button != button:
				era_button.button_pressed = false
		_calculate_and_update()

func _on_style_button_toggled(toggled_on: bool, button: CheckButton) -> void:
	if toggled_on:
		for style_button in style_buttons:
			if style_button != button:
				style_button.button_pressed = false
		_calculate_and_update()

func _on_input_changed(_value: float) -> void:
	_calculate_and_update()

func _get_selected_era() -> Gear.Era:
	if era_ww1.button_pressed:
		return Gear.Era.WWI
	elif era_interwar.button_pressed:
		return Gear.Era.INTERWAR
	elif era_earlywar.button_pressed:
		return Gear.Era.EARLYWAR
	elif era_midwar.button_pressed:
		return Gear.Era.MIDWAR
	else:
		return Gear.Era.LATEWAR

func _get_selected_tuning_style() -> Gear.TuningStyle:
	if style_best_accel.button_pressed:
		return Gear.TuningStyle.BEST_ACCEL
	elif style_favor_accel.button_pressed:
		return Gear.TuningStyle.FAVOR_ACCEL
	elif style_balanced.button_pressed:
		return Gear.TuningStyle.BALANCED
	elif style_favor_speed.button_pressed:
		return Gear.TuningStyle.FAVOR_SPEED
	else:
		return Gear.TuningStyle.BEST_SPEED

func _calculate_and_update() -> void:
	var weight = weight_spinbox.value
	var cylinder_size = cylinder_size_spinbox.value
	var cylinder_count = int(cylinder_count_spinbox.value)
	var gear_count = int(gear_count_spinbox.value)
	var sprocket_diameter = sprocket_diameter_spinbox.value
	var era = _get_selected_era()
	var tuning_style = _get_selected_tuning_style()
	
	if weight <= 0 or cylinder_size <= 0 or cylinder_count <= 0 or gear_count <= 0 or sprocket_diameter <= 0:
		_clear_outputs()
		return
	
	var result = Gear.calculate_gears(
		weight,
		cylinder_count,
		cylinder_size,
		sprocket_diameter,
		gear_count,
		era,
		tuning_style
	)
	
	top_speed_kmh_label.text = "Top Speed (km/h): %.1f" % result.top_speed_kmh
	top_speed_mph_label.text = "Top Speed (mph): %.1f" % result.top_speed_mph
	upshift_label.text = "Upshift: %.0f RPM" % result.upshift_rpm
	downshift_label.text = "Downshift: %.0f RPM" % result.downshift_rpm
	
	_update_gear_labels(result.gear_ratios)

func _update_gear_labels(gear_ratios: Array[float]) -> void:
	for child in gear_labels_container.get_children():
		child.queue_free()
	
	for i in range(gear_ratios.size()):
		var label = Label.new()
		label.text = "Gear %d: %.2f" % [i + 1, gear_ratios[i]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gear_labels_container.add_child(label)

func _clear_outputs() -> void:
	top_speed_kmh_label.text = "Top Speed (km/h): --"
	top_speed_mph_label.text = "Top Speed (mph): --"
	upshift_label.text = "Upshift: -- RPM"
	downshift_label.text = "Downshift: -- RPM"
	
	for child in gear_labels_container.get_children():
		child.queue_free()
