extends Node
class_name Messages

static var test = {
	"test": {
		"title": "It Works!",
		"body": "Yep it sure does work man"
	}
}

static var file_errors = {
	"unknown": {
		"title": "Error",
		"body": "An unknown error occurred"
	},
	"ngons": {
		"title": "N-Gons Detected in File",
		"body": "This OBJ file contains [COUNT] polygon(s) with more than 4 sides (n-gons).\n\nIf converted, Sprocket will not be able to load the blueprint file.\n\nPlease use a 3D modeling tool to triangulate the problematic face or remove it before attempting conversion."
	}
}

static var file_access_errors = {
	"not_found": {
		"title": "File Not Found",
		"body": "File not found: [FILENAME]"
	},
	"bad_drive": {
		"title": "Invalid Drive",
		"body": "Invalid drive or path: [FILEPATH]"
	},
	"bad_path": {
		"title": "Invalid Path",
		"body": "Invalid file path: [FILEPATH]"
	},
	"no_permission": {
		"title": "Permission Denied",
		"body": "Permission denied when trying to [ACTION]: [FILENAME]"
	},
	"already_in_use": {
		"title": "File In Use",
		"body": "File is already in use by another application: [FILENAME]"
	},
	"cant_open": {
		"title": "Cannot Open File",
		"body": "Cannot open file: [FILENAME]"
	},
	"cant_write": {
		"title": "Cannot Write File",
		"body": "Cannot write to file (check permissions): [FILENAME]"
	},
	"cant_read": {
		"title": "Cannot Read File",
		"body": "Cannot read file (check permissions): [FILENAME]"
	},
	"unrecognized": {
		"title": "Unrecognized Format",
		"body": "File format not recognized: [FILENAME]"
	},
	"corrupt": {
		"title": "File Corrupted",
		"body": "File appears to be corrupted: [FILENAME]"
	},
	"missing_dependencies": {
		"title": "Missing Dependencies",
		"body": "File has missing dependencies: [FILENAME]"
	},
	"unexpected_eof": {
		"title": "Unexpected End of File",
		"body": "Unexpected end of file: [FILENAME]"
	},
	"out_of_memory": {
		"title": "Out of Memory",
		"body": "Not enough memory to process file: [FILENAME]"
	},
	"unknown": {
		"title": "File Error",
		"body": "Unknown file error (code [ERROR_CODE]) when trying to [ACTION]: [FILENAME]"
	},
	"empty_path": {
		"title": "Invalid Path",
		"body": "File path is empty"
	},
	"directory_not_found": {
		"title": "Directory Not Found",
		"body": "Directory does not exist: [FILEPATH]"
	}
}
