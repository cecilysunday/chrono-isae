// =============================================================================
//
// Helper functions to set simulation parameters by reading in a config file
//
// =============================================================================

#include "chrono_multicore/physics/ChSystemMulticore.h"
#include "chrono_thirdparty/filesystem/path.h"

#include "ProjConfig.h"

#include <iostream>
#include <fstream>
#include <vector>
#include <time.h> 
#include <string.h>

using namespace chrono;
using namespace chrono::collision;



void AddBoundingBox(ChSystemMulticoreSMC* msystem, const ConfigParameters& config, const double height) {
	// Limits of the bounding box assume that the container base is situated at (0, 0, -cp.cthichness/2)
	msystem->GetSettings()->collision.use_aabb_active = true;
	msystem->GetSettings()->collision.aabb_min = -1.0 * real3(config.clength_x / 2.0, config.clength_y / 2.0, config.cthickness);
	msystem->GetSettings()->collision.aabb_max = real3(config.clength_x / 2.0, config.clength_y / 2.0, height);

	return;
}


int SetSimulationMaterial(ConfigParameters& config) {
	// Create material for particle-particle interactions
	auto mat_pp = chrono_types::make_shared<ChMaterialSurfaceSMC>();
	mat_pp->SetYoungModulus(config.youngs);
	mat_pp->SetPoissonRatio(config.poisson);
	mat_pp->SetSfriction(config.mu_pp);
	mat_pp->SetKfriction(config.mu_pp);
	mat_pp->SetRollingFriction(config.mu_roll);
	mat_pp->SetSpinningFriction(config.mu_spin);
	mat_pp->SetRestitution(config.cor_pp);

	// Create material for particle-wall interactions
	auto mat_pw = chrono_types::make_shared<ChMaterialSurfaceSMC>();
	mat_pw->SetYoungModulus(config.youngs);
	mat_pw->SetPoissonRatio(config.poisson);
	mat_pw->SetSfriction(config.mu_pw);
	mat_pw->SetKfriction(config.mu_pw);
	mat_pw->SetRollingFriction(config.mu_roll);
	mat_pw->SetSpinningFriction(config.mu_spin);
	mat_pw->SetRestitution(config.cor_pw);

	// Define the adhesion case
	if (static_cast<int>(config.adhesion_model) == 0) {
		mat_pp->SetAdhesion(config.ad);
		mat_pw->SetAdhesion(config.ad);
	}
	else if (static_cast<int>(config.adhesion_model) == 1) {
		mat_pp->SetAdhesionMultDMT(config.ad);
		mat_pw->SetAdhesionMultDMT(config.ad);
	}
	else if (static_cast<int>(config.adhesion_model) == 2) {
		mat_pp->SetAdhesionSPerko(config.ad);
		mat_pw->SetAdhesionSPerko(config.ad);
	}
	else return -1;

	// Update the materials in the config structure
	config.mat_pp = mat_pp;
	config.mat_pw = mat_pw;

	return 0;
}


int SetSimulationParameters(ChSystemMulticoreSMC* msystem, ConfigParameters& config) {
	// Add a SMC material to be shared by all bodies
	if (SetSimulationMaterial(config) != 0) return -1;

	// Solver and integrator settings
	msystem->GetSettings()->solver.max_iteration_bilateral = config.max_itbilateral;
	msystem->GetSettings()->solver.tolerance = config.tolerance;

	msystem->GetSettings()->solver.min_roll_vel = config.min_roll_vel;
	msystem->GetSettings()->solver.min_spin_vel = config.min_spin_vel;

	msystem->GetSettings()->solver.contact_force_model = config.force_model;
	msystem->GetSettings()->solver.adhesion_force_model = config.adhesion_model;
	msystem->GetSettings()->solver.tangential_displ_mode = config.tandisp_model;

	// Collision detection parameters
	msystem->SetCollisionSystemType(config.collision_system);
	msystem->GetSettings()->collision.bins_per_axis = vec3(config.bpa_x, config.bpa_y, config.bpa_z);
	msystem->GetSettings()->collision.narrowphase_algorithm = config.narrowphase_type;

	// Set gravity and change the default charecteristic velocity value
	msystem->Set_G_acc(ChVector<>(config.grav_x, config.grav_y, config.grav_z));

	// Update mat properties for hooke and flores force models
	if (config.force_model == ChSystemSMC::ContactForceModel::Hooke || config.force_model == ChSystemSMC::ContactForceModel::Flores) {
		const double vmax = config.gvel;
		msystem->GetSettings()->solver.characteristic_vel = vmax;
	}

	return 0;
}


ChSystemSMC::ContactForceModel force_to_enum(const std::string& str) {
	if (str == "hooke") return ChSystemSMC::ContactForceModel::Hooke;
	else if (str == "hertz") return ChSystemSMC::ContactForceModel::Hertz;
	else if (str == "plaincoulomb") return ChSystemSMC::ContactForceModel::PlainCoulomb;
	else if (str == "flores") return ChSystemSMC::ContactForceModel::Flores;
	else fprintf(stderr, "WARNING: Could not map desired force model. Reset to HERTZ model.\n");
	return  ChSystemSMC::ContactForceModel::Hertz;

}


ChSystemSMC::AdhesionForceModel adhesion_to_enum(const std::string& str) {
	if (str == "constant") return ChSystemSMC::AdhesionForceModel::Constant;
	else if (str == "dmt") return ChSystemSMC::AdhesionForceModel::DMT;
	else if (str == "perko") return ChSystemSMC::AdhesionForceModel::Perko;
	else fprintf(stderr, "WARNING: Could not map desired cohesion model. Reset to CONSTANT model.\n");
	return  ChSystemSMC::AdhesionForceModel::Constant;
}


ChSystemSMC::TangentialDisplacementModel tandisp_to_enum(const std::string& str) {
	if (str == "none") return ChSystemSMC::TangentialDisplacementModel::None;
	else if (str == "onestep") return ChSystemSMC::TangentialDisplacementModel::OneStep;
	else if (str == "multistep") return ChSystemSMC::TangentialDisplacementModel::MultiStep;
	else fprintf(stderr, "WARNING: Could not map desired force model. Reset to MultiStep model.\n");
	return ChSystemSMC::TangentialDisplacementModel::MultiStep;
}


ChCollisionSystemType collision_to_enum(const std::string& str) {
	if (str == "chrono") return ChCollisionSystemType::CHRONO;
	else fprintf(stderr, "WARNING: Only the CHRONO model has been validated at this time. Reset to CHRONO model.\n");
	return  ChCollisionSystemType::CHRONO;
}


ChNarrowphase::Algorithm narrowphase_to_enum(const std::string& str) {
	if (str == "hybrid") return ChNarrowphase::Algorithm::HYBRID;
	else fprintf(stderr, "WARNING: Could not map desired narrowphase model. Reset to HYBRID model.\n");
	return ChNarrowphase::Algorithm::HYBRID;
}


const std::string enum_to_string(const ChSystemSMC::ContactForceModel& model) {
	if (static_cast<int>(model) == 0) return "hooke";
	else if (static_cast<int>(model) == 1) return "hertz";
	else if (static_cast<int>(model) == 2) return "plaincoulomb";
	else if (static_cast<int>(model) == 3) return "flores";
	return  "WARNING: Could not map model enum to string";
}


const std::string enum_to_string(const ChSystemSMC::AdhesionForceModel& model) {
	if (static_cast<int>(model) == 0) return "constant";
	else if (static_cast<int>(model) == 1) return "dmt";
	else if (static_cast<int>(model) == 2) return "perko";
	return  "WARNING: Could not map model enum to string";
}


const std::string enum_to_string(const ChSystemSMC::TangentialDisplacementModel& model) {
	if (static_cast<int>(model) == 0) return "none";
	else if (static_cast<int>(model) == 1) return "onestep";
	else if (static_cast<int>(model) == 2) return "multistep";
	return  "WARNING: Could not map model enum to string";
}


const std::string enum_to_string(const ChCollisionSystemType& model) {
	if (static_cast<int>(model) == 1) return "chrono";
	return  "WARNING: Could not map model enum to string";
}


const std::string enum_to_string(const ChNarrowphase::Algorithm& model) {
	if (static_cast<int>(model) == 2) return "hybrid";
	return  "WARNING: Could not map model enum to string";
}


int WriteParameterFile(const ConfigParameters& config) {
	const std::string ofile = config.proj_path + "/system_params.txt";
	std::ofstream param_file(ofile);
	param_file
		<< "\n" << "## Project information"
		<< "\n" << "proj_config " << config.proj_config
		<< "\n" << "proj_setdir " << config.proj_setdir
		<< "\n" << "proj_type " << config.proj_type
		<< "\n" << "proj_container " << config.proj_container
		<< "\n" << "proj_intruder " << config.proj_intruder
		<< "\n" << "proj_date " << config.proj_date
		<< "\n" << "proj_time " << config.proj_time
		<< "\n" << "proj_units " << config.proj_units
		<< "\n"
		<< "\n" << "## Material properties shared by all bodies"
		<< "\n" << "youngs " << config.youngs
		<< "\n" << "poisson " << config.poisson
		<< "\n" << "mu_pp " << config.mu_pp
		<< "\n" << "mu_pw " << config.mu_pw
		<< "\n" << "mu_roll " << config.mu_roll
		<< "\n" << "mu_spin " << config.mu_spin
		<< "\n" << "cor_pp " << config.cor_pp
		<< "\n" << "cor_pw " << config.cor_pw
		<< "\n" << "ad " << config.ad
		<< "\n"
		<< "\n" << "## Geometric properties of the container"
		<< "\n" << "clength_x " << config.clength_x
		<< "\n" << "clength_y " << config.clength_y
		<< "\n" << "clength_z " << config.clength_z
		<< "\n" << "cthickness " << config.cthickness
		<< "\n" << "cmass " << config.cmass
		<< "\n"
		<< "\n" << "## Geometric properties of the granular surface material"
		<< "\n" << "gdia " << config.gdia
		<< "\n" << "gmarg " << config.gmarg
		<< "\n" << "grho " << config.grho
		<< "\n" << "gvel " << config.gvel
		<< "\n" << "gmass " << config.gmass
		<< "\n"
		<< "\n" << "## Geometric properties of the intruder"
		<< "\n" << "ilength_x " << config.ilength_x
		<< "\n" << "ilength_y " << config.ilength_y
		<< "\n" << "ilength_z " << config.ilength_z
		<< "\n" << "imass " << config.imass
		<< "\n" << "ivel " << config.ivel
		<< "\n" << "iwvel " << config.iwvel
		<< "\n"
		<< "\n" << "## Simulation run-time parameters"
		<< "\n" << "grav_x " << config.grav_x
		<< "\n" << "grav_y " << config.grav_y
		<< "\n" << "grav_z " << config.grav_z
		<< "\n" << "time_step " << config.time_step
		<< "\n" << "time_loop " << config.time_loop
		<< "\n" << "time_save " << config.time_save
		<< "\n" << "sim_duration " << config.sim_duration
		<< "\n"
		<< "\n" << "## Simulation solver and collision detection parameters"
		<< "\n" << "force_model " << enum_to_string(config.force_model)
		<< "\n" << "adhesion_model " << enum_to_string(config.adhesion_model)
		<< "\n" << "tandisp_model " << enum_to_string(config.tandisp_model)
		<< "\n" << "collision_system " << enum_to_string(config.collision_system)
		<< "\n" << "narrowphase_algorithm " << enum_to_string(config.narrowphase_type)
		<< "\n" << "tolerance " << config.tolerance
		<< "\n" << "min_roll_vel " << config.min_roll_vel
		<< "\n" << "min_spin_vel " << config.min_spin_vel
		<< "\n" << "max_itbilateral " << config.max_itbilateral
		<< "\n" << "bpa_x " << config.bpa_x
		<< "\n" << "bpa_y " << config.bpa_y
		<< "\n" << "bpa_z " << config.bpa_z;
	param_file.close();

	return 0;
}


int WriteConfigFile(const ConfigParameters &config) {
	const std::string ofile = config.proj_path + "/config_set.txt";
	std::ofstream config_file(ofile);
	config_file
		<< "\n" << "## Project information"
		<< "\n" << "proj_type " << config.proj_type
		<< "\n" << "proj_container " << config.proj_container
		<< "\n" << "proj_units " << config.proj_units
		<< "\n"
		<< "\n" << "## Material properties shared by all bodies"
		<< "\n" << "youngs " << config.youngs
		<< "\n" << "poisson " << config.poisson
		<< "\n" << "mu_pp " << config.mu_pp
		<< "\n" << "mu_pw " << config.mu_pw
		<< "\n" << "mu_roll " << config.mu_roll
		<< "\n" << "mu_spin " << config.mu_spin
		<< "\n" << "cor_pp " << config.cor_pp
		<< "\n" << "cor_pw " << config.cor_pw
		<< "\n" << "ad " << config.ad
		<< "\n"
		<< "\n" << "## Geometric properties of the container"
		<< "\n" << "clength_x " << config.clength_x
		<< "\n" << "clength_y " << config.clength_y
		<< "\n" << "clength_z " << config.clength_z
		<< "\n" << "cthickness " << config.cthickness
		<< "\n" << "cmass " << config.cmass
		<< "\n"
		<< "\n" << "## Geometric properties of the granular surface material"
		<< "\n" << "gdia " << config.gdia
		<< "\n" << "gmarg " << config.gmarg
		<< "\n" << "grho " << config.grho
		<< "\n" << "gvel " << config.gvel
		<< "\n"
		<< "\n" << "## Simulation run-time parameters"
		<< "\n" << "grav_x " << config.grav_x
		<< "\n" << "grav_y " << config.grav_y
		<< "\n" << "grav_z " << config.grav_z
		<< "\n" << "time_step " << config.time_step
		<< "\n" << "time_loop " << config.time_loop
		<< "\n" << "time_save " << config.time_save
		<< "\n" << "sim_duration " << config.sim_duration
		<< "\n"
		<< "\n" << "## Simulation solver and collision detection parameters"
		<< "\n" << "force_model " << enum_to_string(config.force_model)
		<< "\n" << "adhesion_model " << enum_to_string(config.adhesion_model);
	config_file.close();

	return 0;
}


int CreateOutputPath(ConfigParameters* config, const std::string &datestr, const std::string &timestr) {
	// If the project-container folder does not already exist, create it
	const std::string proj_dir = (std::string) PROJECT_DATA_DIR + "/" + config->proj_type;
	auto proj_path = filesystem::path(proj_dir);

	if (!proj_path.exists()) filesystem::create_directory(proj_path);
	if (!proj_path.exists()) return -1;

	// Determine the final output path
	std::string outdir = proj_dir + "/" + datestr + "_" + timestr;

	// Create the output directory and set the output path in the param struct 
	auto out_path = filesystem::path(outdir);
	filesystem::create_directory(out_path);

	if (!out_path.exists()) return -1;
	else config->proj_path = outdir;

	// Set the Chrono and Project data paths so that the infor can be accessed by other functions
	SetChronoDataPath(CHRONO_DATA_DIR);
	SetChronoOutputPath(config->proj_path);

	return 0;
}


int ComputeDerivedStuctValues(ConfigParameters* config, const std::string& datestr, const std::string& timestr) {
	// Add high-level projet information
	config->proj_date = datestr;
	config->proj_time = timestr;

	// Add additional grain properties
	config->grad = config->gdia / 2.0;
	config->gmass = config->grho * (4.0 / 3.0) * CH_C_PI * Pow(config->grad, 3.0);

	// Determine bin size based on a 3 object per axis standard - assumes z-up orientation
	config->bpa_x = (int)std::ceil(config->clength_x / config->gdia / 3.0);
	config->bpa_y = (int)std::ceil(config->clength_y / config->gdia / 3.0);
	config->bpa_z = (int)std::ceil(config->clength_z / config->gdia / 3.0);

	// Add a parameter to describe the radius of a cylindrical container
	if (config->proj_container == "cyl") {
		if (config->clength_x != config->clength_y) {
			fprintf(stderr, "\nERR: For a cylindrical container, clength_x must equal clength_y in the configuration file.\n");
			return -1;
		}
		else config->clength_r = config->clength_x / 2.0;
	}
	else if (config->proj_container == "drum") {
		if (config->clength_x != config->clength_z) {
			fprintf(stderr, "\nERR: For a drum container, clength_x must equal clength_z in the configuration file.\n");
			return -1;
		}
		else config->clength_r = config->clength_x / 2.0;
	}

	// Determine the radius of a cylindrical intruder
	if (config->proj_intruder == "cyl") {
		if (config->ilength_x != config->ilength_y && config->ilength_x != config->ilength_z) {
			fprintf(stderr, "\nERR: For a cylindrical intruder, ilength_x must equal either ilength_y or ilength_z in the configuration file.\n");
			return -1;
		}
		else config->ilength_r = config->ilength_x / 2.0;
	}

	// Determine the radius of a spherical intruder
	if (config->proj_intruder == "sph") {
		if (config->ilength_x != config->ilength_y || config->ilength_x != config->ilength_z) {
			fprintf(stderr, "\nERR: For a spherical intruder, ilength_x must equal ilength_y and ilength_z in the configuration file.\n");
			return -1;
		}
		else config->ilength_r = config->ilength_x / 2.0;
	}

	return 0;
}


int MapParameters(ConfigParameters& config, const std::vector<std::string>& parsed_line) {
	const std::string param = parsed_line.at(0);
	const std::string val = parsed_line.at(1);

	if (param == "proj_config") config.proj_config = val;
	else if (param == "proj_setdir") config.proj_setdir = val;
	else if (param == "proj_type"){
		 if (config.proj_type == "NA") config.proj_type = val;
	}
	else if (param == "proj_container") {
		if (val != "box" && val != "cyl" && val != "drum") {
			fprintf(stderr, "\nERR: The configuration file contains an invalid container geometry! Container must be a box or a cyl.\n");
			return -1;
		}
		else if (config.proj_container != "NA" && config.proj_container != val) {
			fprintf(stderr, "\nERR: The current configuration file does not contain the same container geometry as the specified config_set file.\n");
			return -1;
		}
		else config.proj_container = val;
	}
	else if (param == "proj_units") {
		if (config.proj_units != "NA" && config.proj_units != val) {
			fprintf(stderr, "\nERR: The new configuration file does not contain the same units as the specified config_set file!\n");
			return -1;
		}
		else config.proj_units = val;
	}
	else if (param == "proj_intruder") config.proj_intruder = val;
	else if (param == "proj_date") config.proj_date = val;
	else if (param == "proj_time") config.proj_time = val;

	else if (param == "youngs") config.youngs = std::stof(val);
	else if (param == "poisson") config.poisson = std::stof(val);
	else if (param == "mu_pp") config.mu_pp = std::stof(val);
	else if (param == "mu_pw") config.mu_pw = std::stof(val);
	else if (param == "mu_roll") config.mu_roll = std::stof(val);
	else if (param == "mu_spin") config.mu_spin = std::stof(val);
	else if (param == "cor_pp") config.cor_pp = std::stof(val);
	else if (param == "cor_pw") config.cor_pw = std::stof(val);
	else if (param == "ad") config.ad = std::stof(val);

	else if (param == "clength_x") config.clength_x = std::stod(val);
	else if (param == "clength_y") config.clength_y = std::stod(val);
	else if (param == "clength_z") config.clength_z = std::stod(val);
	else if (param == "cthickness") config.cthickness = std::stod(val);
	else if (param == "cmass") config.cmass = std::stod(val);

	else if (param == "gdia") config.gdia = std::stod(val);
	else if (param == "gmarg") config.gmarg = std::stod(val);
	else if (param == "grho") config.grho = std::stod(val);
	else if (param == "gvel") config.gvel = std::stod(val);
	else if (param == "gmass") config.gmass = std::stod(val);

	else if (param == "ilength_x") config.ilength_x = std::stod(val);
	else if (param == "ilength_y") config.ilength_y = std::stod(val);
	else if (param == "ilength_z") config.ilength_z = std::stod(val);
	else if (param == "imass") config.imass= std::stod(val);
	else if (param == "ivel") config.ivel = std::stod(val);
	else if (param == "iwvel") config.iwvel = std::stod(val);

	else if (param == "grav_x") config.grav_x = std::stod(val);
	else if (param == "grav_y") config.grav_y = std::stod(val);
	else if (param == "grav_z") config.grav_z = std::stod(val);
	else if (param == "time_step") config.time_step = std::stod(val);
	else if (param == "time_loop") config.time_loop = std::stod(val);
	else if (param == "time_save") config.time_save = std::stod(val);
	else if (param == "sim_duration") config.sim_duration = std::stod(val);

	else if (param == "force_model") config.force_model = force_to_enum(val);
	else if (param == "adhesion_model") config.adhesion_model = adhesion_to_enum(val);
	else if (param == "tandisp_model") config.tandisp_model = tandisp_to_enum(val);
	else if (param == "collision_system") config.collision_system = collision_to_enum(val);
	else if (param == "narrowphase_algorithm") config.narrowphase_type = narrowphase_to_enum(val);
	else if (param == "tolerance") config.tolerance = std::stod(val);
	else if (param == "min_roll_vel") config.min_roll_vel = std::stod(val);
	else if (param == "min_spin_vel") config.min_spin_vel = std::stod(val);
	else if (param == "max_itbilateral") config.max_itbilateral = (uint)std::stoi(val);
	else if (param == "bpa_x") config.bpa_x = std::stoi(val);
	else if (param == "bpa_y") config.bpa_y = std::stoi(val);
	else if (param == "bpa_z") config.bpa_z = std::stoi(val);
	else {
		fprintf(stderr, "\nERR: Error mapping configuration parameters! Could not match the '%s' input to a ConfigParameter type.\n", param.c_str());
		return -1;
	}

	return 0;
}


int ImportConfigFile(ConfigParameters* config, const std::string &cfile) {
	// Open config file. Exit if the config file was not located.
	std::ifstream file(cfile);
	if (!file) {
		fprintf(stderr, "\nERR: Configuration file does not exist!\n");
		return -1;
	}
	
	// Iterate through the config file and map the text into a ConfigParams structure
	std::string line;
	while (std::getline(file, line)) {
		// Ignore empy line or lines that start with #. Otherwise, parse words.
		if (line.empty()) continue;
		if (!line.rfind("#", 0)) continue;

		// Parse each line into a vector of words
		std::vector<std::string> parsed_line;
		std::vector<std::string> parsed_word;

		char* cline = const_cast<char*>(line.c_str());
		char* delim = strtok(cline, " ");
		while (delim != NULL) {
			std::string parsed_word(delim);
			parsed_line.push_back(parsed_word);
			delim = strtok(NULL, " ");
		}
		if (parsed_line.size() != 2) return -1;
	
		// Add the elements of the configuration file to the ConfigParameter structure
		if (MapParameters(*config, parsed_line) != 0) return -1;
	}

	return 0;
}


int InitializeSimulation(ConfigParameters* config, const std::string &cfile) {
	// Import the initial configuration file
	if (ImportConfigFile(config, cfile) != 0) return -1;

	// If a file is provided for proj_setparams, import the remaining configuration parameters
	if (config->proj_setdir != "NA") {
		std::string sfile = config->proj_setdir + "/config_set.txt";
		if (ImportConfigFile(config, sfile) != 0) return -2;
	}
	
	// Set the correct name in the ConfigParameters struct for the original configuration file
	config->proj_config = cfile;

	// Add the current date and time to the param struct. Required for setting the output data paths.
	time_t rawtime;
	struct tm* timeinfo;
	char datestr[100];
	char timestr[100];
	
	time(&rawtime);
	timeinfo = localtime(&rawtime);

	strftime(datestr, sizeof(datestr), "%y%m%d", timeinfo);
	strftime(timestr, sizeof(timestr), "%H%M%S", timeinfo);

	// Calculate the derived config params and add them to the param struct
	if (ComputeDerivedStuctValues(config, datestr, timestr) != 0) return -3;
	
	// Create the output data directory and store the output path in the param struct
	if (CreateOutputPath(config, datestr, timestr) != 0) return -4;
	
	// Save a copy of the old config file to the data output directory
	if (WriteConfigFile(*config) != 0) return -5;
	
	// Write all of the simulation parameters to the data output directory
	if (WriteParameterFile(*config) != 0) return -6;
	
	return 0;
}


char* GetConfigFile(int argc, char* argv[]) {
	char* cfile;
	try {
		if (argc >= 2) cfile = argv[1];
		else throw 42;
	}
	catch (int) {
		fprintf(stderr, "\nERR: Please provide the location of a configuration file. \n");
		exit(EXIT_FAILURE);
	}
	return cfile;
}