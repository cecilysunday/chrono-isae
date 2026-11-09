// =============================================================================
//
// Helper functions for reading and writing simulation data
//
// =============================================================================

#include "chrono_multicore/physics/ChSystemMulticore.h"
#include "chrono_thirdparty/filesystem/path.h"
#include "chrono/utils/ChUtilsInputOutput.h"

#include "ProjWriteData.h"

#include <fstream>
#include <iostream>
#include <vector>

#include <string.h>
#include <assert.h>
#include <memory.h>

#if (__cplusplus < 201703L)
	#define _SILENCE_EXPERIMENTAL_FILESYSTEM_DEPRECATION_WARNING
	#include <experimental/filesystem>
	namespace fs = std::experimental::filesystem;
#else
	#include <filesystem>
	namespace fs = std::filesystem;
#endif

using namespace chrono;
using namespace chrono::collision;



// Callback class for contact reporting needed to create force-chain plots
class ContactReporter : public ChContactContainer::ReportContactCallback {
public:
	ContactReporter(ChSystemMulticore* system) : sys(system) {
		csv << "Aid" << "Arad" << "Apos_x" << "Apos_y" << "Apos_z"
			<< "Bid" << "Brad" << "Bpos_x" << "Bpos_y" << "Bpos_z"
			<< "Acpt_x" << "Acpt_y" << "Acpt_z"
			<< "Bcpt_x" << "Bcpt_y" << "Bcpt_z"
			<< "overlap" << "r_eff"
			<< "planeXaxisX" << "planeXaxisY" << "planeXaxisZ"
			<< "planeYaxisX" << "planeYaxisY" << "planeYaxisZ"
			<< "planeZaxisX" << "planeZaxisY" << "planeZaxisZ"
			<< "force_x" << "force_y" << "force_z"
			<< "torque_x" << "torque_y" << "torque_z"
			<< std::endl;
	}

	void write(const std::string& filename) {
		csv.write_to_file(filename);
	}

private:
	virtual bool OnReportContact(const ChVector<>& pA,
								 const ChVector<>& pB,
								 const ChMatrix33<>& plane_coord,
								 const double& distance,
								 const double& eff_radius,
								 const ChVector<>& cforce,
								 const ChVector<>& ctorque,
								 ChContactable* modA,
								 ChContactable* modB) override {

		auto bodyA = static_cast<ChBody*>(modA);
		auto bodyB = static_cast<ChBody*>(modB);

		auto pmodelA = bodyA->GetCollisionModel();
		auto pmodelB = bodyB->GetCollisionModel();

		auto shapeA = pmodelA->GetShapes().at(0);
		auto shapeB = pmodelB->GetShapes().at(0);

		double radiusA = -1;
		double radiusB = -1;

		if (shapeA->GetType() == ChCollisionShape::Type::SPHERE) radiusA = pmodelA->GetShapeDimensions(0).at(0);;
		if (shapeB->GetType() == ChCollisionShape::Type::SPHERE) radiusB = pmodelB->GetShapeDimensions(0).at(0);;

		csv << bodyA->GetIdentifier() << radiusA << bodyA->GetPos().x() << bodyA->GetPos().y() << bodyA->GetPos().z();
		csv << bodyB->GetIdentifier() << radiusB << bodyB->GetPos().x() << bodyB->GetPos().y() << bodyB->GetPos().z();
		csv << pA << pB << distance << eff_radius;
		csv << plane_coord.Get_A_Xaxis() << plane_coord.Get_A_Yaxis() << plane_coord.Get_A_Zaxis();
		csv << cforce << ctorque;
		csv << std::endl;
		return true;  // continue parsing
	}

	ChSystemMulticore* sys;
	utils::CSV_writer csv;
};


int PrintContactInfo(ChSystemMulticoreSMC& msystem, const std::string& dpath, const double& time, const bool final) {
	std::string contact_file = dpath + "/contacts_" + std::to_string((float)time) + ".csv";
	if (final) contact_file = dpath + "/contacts_final.csv";

	auto creporter = chrono_types::make_shared<ContactReporter>(&msystem);
	msystem.GetContactContainer()->ReportAllContacts(creporter);
	creporter->write(contact_file);

	return 0;
}


size_t CountStateBinObjects(const std::string& fname) {
	// Locate the and open final state data file. Return if file not found.
	if (!filesystem::path(fname).exists()) return -1;
	std::ifstream bin_in(fname, std::ios::binary | std::ios::in);

	// Count the total instances of ParticleData types in the file
	ParticleData data;
	unsigned long long int struct_size = sizeof(ParticleData);
	size_t num_objects = 0;
	while (bin_in.read((char*)&data, struct_size)) {
		++num_objects;
	}

	return num_objects;
}


int ImportStateBin(ParticleData* data, const std::string &fname) {
	// Locate the and open final state data file. Return if file not found.
	if (!filesystem::path(fname).exists()) return -1;
	std::ifstream bin_in(fname, std::ios::binary | std::ios::in);

	// Loop through final_state.bin and the store objects in a data data array
	size_t i = 0;
	ParticleData datai;
	unsigned long long int struct_size = sizeof(ParticleData);
	while (bin_in.read((char*)&datai, struct_size)) {
		data[i].id = datai.id;
		data[i].time = datai.time;
		data[i].radius = datai.radius;
		data[i].collision_state = datai.collision_state;
		data[i].pos_x = datai.pos_x;
		data[i].pos_y = datai.pos_y;
		data[i].pos_z = datai.pos_z;
		data[i].rot_0 = datai.rot_0;
		data[i].rot_1 = datai.rot_1;
		data[i].rot_2 = datai.rot_2;
		data[i].rot_3 = datai.rot_3;
		data[i].vel_x = datai.vel_x;
		data[i].vel_y = datai.vel_y;
		data[i].vel_z = datai.vel_z;
		data[i].rot_vel_x = datai.rot_vel_x;
		data[i].rot_vel_y = datai.rot_vel_y;
		data[i].rot_vel_z = datai.rot_vel_z;
		data[i].acc_x = datai.acc_x;
		data[i].acc_y = datai.acc_y;
		data[i].acc_z = datai.acc_z;
		data[i].rot_acc_x = datai.rot_acc_x;
		data[i].rot_acc_y = datai.rot_acc_y;
		data[i].rot_acc_z = datai.rot_acc_z;
		data[i].force_x = datai.force_x;
		data[i].force_y = datai.force_y;
		data[i].force_z = datai.force_z;
		data[i].torque_x = datai.torque_x;
		data[i].torque_y = datai.torque_y;
		data[i].torque_z = datai.torque_z;
	
		++i;
	}

	return 0;
}

int WriteCsvHeader(const std::string &fname) {
	if (!filesystem::path(fname).exists()) {
		std::ofstream csv_out(fname);
		csv_out << "body_id, time, radius, collision_map,"
				<< "pos_x, pos_y, pos_z,"
				<< "rot_0, rot_1, rot_2, rot_3,"
				<< "vel_x, vel_y, vel_z,"
				<< "rot_vel_x, rot_vel_y, rot_vel_z,"
				<< "acc_x, acc_y, acc_z,"
				<< "rot_acc_x, rot_acc_y, rot_acc_z,"
				<< "force_x, force_y, force_z,"
				<< "torque_x, torque_y, torque_z\n";
		csv_out.close();
	}

	if (!filesystem::path(fname).exists()) return -1;
	return 0;
}


std::vector<std::string> GetFileList(const std::string& path, bool bin_only) {
	std::vector<std::string> file_list;
	std::string ext = ".bin";

	try {
		// Check if given path exists and points to a directory
		if (fs::exists(path) && fs::is_directory(path)) {
			// Create a Recursive Directory Iterator object and points to the start and end of directory
			fs::recursive_directory_iterator iter(path);
			fs::recursive_directory_iterator end;

			// Iterate though directory and store all .bin filetypes in listOfFiles
			while (iter != end) {
				if (bin_only) {
					if (iter->path().extension().string() == ext) {
						file_list.push_back(iter->path().string());
					}
				}
				else {
					file_list.push_back(iter->path().string());
				}
				// Increment the iterator to point to next entry in recursive iteration
				std::error_code ec;
				iter.increment(ec);
				if (ec) {
					std::cerr << "Error While Accessing : " << iter->path().string() << " :: " << ec.message() << '\n';
				}
			}
		}
	}
	catch (std::system_error& e) {
		std::cerr << "Exception :: " << e.what();
	}

	return file_list;
}


int ConvertBinToCsv(const std::string& path) {
	// Get a list of all bin files in the given directory
	vector<std::string> file_list = GetFileList(path, true);

	// Revise the file list to convert only the essential files
	// if (file_list.size() > 3) {
	//  vector<std::string> temp_list = { *file_list.begin(), *(file_list.end() - 2), *(file_list.end() - 1) };
	//	file_list = temp_list;
	//}

	// Link the file extension types to the data structure type
	std::string bin_ext = ".bin";
	std::string csv_ext = ".csv";

	// Loop through the list of bin files and convert to csv
	int count = 0;
	for (std::vector<std::string>::iterator i = file_list.begin(); i != file_list.end(); ++i) {
		// Create the csv file stream. Get the file name by copying the bin name and changing the extention
		std::string bin_name = *i;

		size_t ext_start = bin_name.find(bin_ext);
		if (ext_start != std::string::npos) {
			std::string temp = bin_name.erase(ext_start, bin_ext.length());

			std::string csv_name = temp + csv_ext;
			if (filesystem::path(csv_name).exists()) filesystem::path(csv_name).remove_file();
			if (WriteCsvHeader(csv_name) != 0) return -1;

			// Read particle info from the bin file and write to the csv file, struct by struct
			ParticleData data;
			std::ifstream bin_in(*i, std::ios::binary | std::ios::in);
			std::ofstream csv_out(csv_name, std::ofstream::out | std::ofstream::app);

			unsigned long long int struct_size = sizeof(ParticleData);
			while (bin_in.read((char*)&data, struct_size)) {
				csv_out << data.id << ","
						<< data.time << ","
						<< data.radius << ","
						<< data.collision_state << ","
						<< data.pos_x << ","
						<< data.pos_y << ","
						<< data.pos_z << ","
						<< data.rot_0 << ","
						<< data.rot_1 << ","
						<< data.rot_2 << ","
						<< data.rot_3 << ","
						<< data.vel_x << ","
						<< data.vel_y << ","
						<< data.vel_z << ","
						<< data.rot_vel_x << ","
						<< data.rot_vel_y << ","
						<< data.rot_vel_z << ","
						<< data.acc_x << ","
						<< data.acc_y << ","
						<< data.acc_z << ","
						<< data.rot_acc_x << ","
						<< data.rot_acc_y << ","
						<< data.rot_acc_z << ","
						<< data.force_x << ","
						<< data.force_y << ","
						<< data.force_z << ","
						<< data.torque_x << ","
						<< data.torque_y << ","
						<< data.torque_z << "\n";
			}
			csv_out.close();
			count++;
		}
	}

	return count;
}


int WriteSystemStats(const SystemData& stats, const std::string& path) {
	const std::string fname = path + "/system_stats.txt";
	std::ofstream stats_out(fname);
	stats_out << "\n" << "## Project run-time statistics"
		<< "\n" << "num_walls " << (int)stats.num_walls
		<< "\n" << "num_particles " << (int)stats.num_particles
		<< "\n" << "num_shapes " << (int)stats.num_shapes
		<< "\n" << "sim_timestep " << stats.sim_timestep
		<< "\n" << "sim_duration " << stats.sim_duration
		<< "\n" << "sim_iterations " << stats.sim_duration / stats.sim_timestep
		<< "\n" << "sim_cpu " << stats.timer_total_sim / (stats.sim_duration * stats.num_shapes / stats.sim_timestep)
		<< "\n" << "timer_total_sim " << stats.timer_total_sim
		<< "\n" << "timer_total_collision " << stats.timer_total_collision
		<< "\n" << "timer_broad_collision " << stats.timer_broad_collision
		<< "\n" << "timer_narrow_collision " << stats.timer_narrow_collision
		<< "\n" << "timer_custom_collision " << stats.timer_custom_collision
		<< "\n" << "timer_other_collision " << stats.timer_total_collision - (stats.timer_broad_collision + stats.timer_narrow_collision + stats.timer_custom_collision)
		<< "\n" << "timer_total_update " << stats.timer_total_update
		<< "\n" << "timer_total_advance " << stats.timer_total_advance
		<< "\n" << "timer_calcf_advance " << stats.timer_calcf_advance
		<< "\n" << "timer_total_other " << stats.timer_total_sim - (stats.timer_total_collision + stats.timer_total_update + stats.timer_total_advance);
	stats_out.close();

	if (!filesystem::path(fname).exists()) return -1;
	return 0;
}


int WriteBinFile(ParticleData** data, const std::string& fname, const size_t& num_bodies, const int& index) {
	// Iterate through the 2D data array and write the ParticleDate at each index to the binary file
	unsigned long long int struct_size = sizeof(ParticleData);
	std::ofstream bin_out(fname, std::ios::binary | std::ios::app);
	for (int j = 0; j < index; ++j) {
		for (size_t i = 0; i < num_bodies; ++i) {
			bin_out.write((char*)&data[i][j], struct_size);
		}
	}
	bin_out.close();

	// Return -1 if the file did not get created properly 
	if (!filesystem::path(fname).exists()) return -1;
	return 0;
}


int StoreData(const ChSystemMulticoreSMC& msystem, ParticleData** data, const size_t& num_particles, const size_t& start_list, const int& index) {
	size_t id = start_list;
	// Do for all particles in the system
	for (size_t i = 0; i < num_particles; ++i) {
		// Get the body and the body shape, assuming that there is only one object per collision model
		const std::shared_ptr<ChBody> body = msystem.Get_bodylist().at(id);

		auto pmodel = body->GetCollisionModel();
		auto shape = pmodel->GetShapes().at(0);
		double radius = -1;

		switch (shape->GetType()) {
		case ChCollisionShape::Type::SPHERE:
			radius = pmodel->GetShapeDimensions(0).at(0); // radius
			break;
		case ChCollisionShape::Type::BOX:
			radius = pmodel->GetShapeDimensions(0).at(0) * 2.0; // length along x axis
			break;
		case ChCollisionShape::Type::CYLINDER:
			radius = pmodel->GetShapeDimensions(0).at(0); // x radius
			break;
		}

		// Add all other object information to the data structure
		data[i][index].id = body->GetIdentifier();
		data[i][index].time = msystem.GetChTime();
		data[i][index].radius = radius;
		data[i][index].collision_state = msystem.data_manager->host_data.ct_body_map[id];
		data[i][index].pos_x = body->GetPos().x();
		data[i][index].pos_y = body->GetPos().y();
		data[i][index].pos_z = body->GetPos().z();
		data[i][index].rot_0 = body->GetRot().e0();
		data[i][index].rot_1 = body->GetRot().e1();
		data[i][index].rot_2 = body->GetRot().e2();
		data[i][index].rot_3 = body->GetRot().e3();
		data[i][index].vel_x = body->GetPos_dt().x();
		data[i][index].vel_y = body->GetPos_dt().y();
		data[i][index].vel_z = body->GetPos_dt().z();
		data[i][index].rot_vel_x = body->GetWvel_par().x();
		data[i][index].rot_vel_y = body->GetWvel_par().y();
		data[i][index].rot_vel_z = body->GetWvel_par().z();
		data[i][index].acc_x = body->GetPos_dtdt().x();
		data[i][index].acc_y = body->GetPos_dtdt().y();
		data[i][index].acc_z = body->GetPos_dtdt().z();
		data[i][index].rot_acc_x = body->GetWacc_par().x();
		data[i][index].rot_acc_y = body->GetWacc_par().y();
		data[i][index].rot_acc_z = body->GetWacc_par().z();
		data[i][index].force_x = msystem.GetBodyContactForce(body).x; // system->GetContactContainer()->ComputeContactForces();, object->GetContactForce() ? 
		data[i][index].force_y = msystem.GetBodyContactForce(body).y;
		data[i][index].force_z = msystem.GetBodyContactForce(body).z;
		data[i][index].torque_x = msystem.GetBodyContactTorque(body).x;
		data[i][index].torque_y = msystem.GetBodyContactTorque(body).y;
		data[i][index].torque_z = msystem.GetBodyContactTorque(body).z;

		++id;
	}

	return 0;
}


int ArchiveSingleBody(const ChSystemMulticoreSMC& msystem, const std::string& path, const size_t& index) {
	// Generate the filename
	std::string ext = ".bin";
	const std::string bin_name = path + "/state_single_body" + ext;

	// Create a dynamically allocated 2D array to hold the particle info
	ParticleData** data = new ParticleData * [1];
	data[0] = new ParticleData[1];
	memset(data[0], 0, sizeof(ParticleData));

	// Store and write the particle info
	if (StoreData(msystem, data, 1, index, 0) != 0) return -1;
	if (WriteBinFile(data, bin_name, 1, 1) != 0) return -1;

	// Delete the dynamically allocated 2D array and return
	delete[] data[0];
	delete[] data;

	return 0;
}


int ArchiveState(const ChSystemMulticoreSMC& msystem, const SystemData& stats, const std::string& path,
	const size_t& num_bodies, const size_t& start_index, const double& time, bool final) {
	// Generate a file name based on simulation time
	std::string fname, strtime;
	std::string ext = ".bin";

	if (time < 10.0) strtime = "0" + std::to_string((float)time);
	else strtime = std::to_string((float)time);

	if (final) fname = "/state_final";
	else fname = "/state_" + strtime;

	const std::string bin_name = path + fname + ext;

	// Create a dynamically allocated 2D array to hold the particle info
	ParticleData** data = new ParticleData * [num_bodies];
	for (size_t i = 0; i < num_bodies; ++i) {
		data[i] = new ParticleData[1];
		memset(data[i], 0, sizeof(ParticleData));
	}

	// Store and write the particle info
	if (StoreData(msystem, data, num_bodies, start_index, 0) != 0) return -1;
	if (WriteBinFile(data, bin_name, num_bodies, 1) != 0) return -1;

	// Delete the dynamically allocated 2D array and return
	for (size_t i = 0; i < num_bodies; ++i) {
		delete[] data[i];
	}
	delete[] data;

	// If archiving the final state, print the system stats as well
	if (final) if (WriteSystemStats(stats, path) != 0) return -1;

	return 0;
}


void IncrementTimerTotals(const ChSystemMulticoreSMC& msystem, SystemData* stats, const double& time) {
	stats->sim_duration = time;
	stats->timer_total_sim += msystem.GetTimerStep();
	stats->timer_total_collision += msystem.GetTimerCollision();
	stats->timer_broad_collision += msystem.GetTimerCollisionBroad();
	stats->timer_narrow_collision += msystem.GetTimerCollisionNarrow();
	stats->timer_custom_collision += msystem.data_manager->system_timer.GetTime("collision_custom");
	stats->timer_total_update += msystem.GetTimerUpdate();
	stats->timer_total_advance += msystem.GetTimerAdvance();
	stats->timer_calcf_advance += msystem.GetTimerProcessContact();
}


size_t GetNumShapes(const ChSystemMulticoreSMC& msystem) {
	size_t num_shapes = 0;
	size_t num_bodies = msystem.Get_bodylist().size();

	for (size_t i = 0; i < num_bodies; ++i) {
		const std::shared_ptr<ChBody> body = msystem.Get_bodylist().at(i);
		num_shapes += body->GetCollisionModel().get()->GetShapes().size();
	}

	return num_shapes;
}


int SetSystemStats(SystemData& mstats, const ChSystemMulticoreSMC& msystem, const double& timestep,
	const std::pair<size_t, size_t>& wlist, const std::pair<size_t, size_t>& glist) {
	// Get the number of walls and number particles in the system
	mstats.num_walls = wlist.second - wlist.first + 1;
	mstats.num_particles = glist.second - glist.first + 1;

	// num_bodies = num_walls + num_particles, but num_shapes includes every collision object a unique ID
	mstats.num_bodies = mstats.num_walls + mstats.num_particles;
	mstats.num_shapes = GetNumShapes(msystem);

	// Add the timestep to the stats file as a reference
	mstats.sim_timestep = timestep;

	// Print the number of walls, particles, and shapes in the system just for info
	GetLog() << "\nNumber of walls: " << mstats.num_walls;
	GetLog() << "\nNumber of particles: " << mstats.num_particles;
	GetLog() << "\nNumber of shapes: " << mstats.num_shapes << "\n\n";

	return 0;
}