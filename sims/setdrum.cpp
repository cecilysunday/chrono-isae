// =============================================================================
// PROJECT CHRONO - http://projectchrono.org
//  
// Copyright (c) 2014 projectchrono.org
// All rights reserved.
//
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file at the top level of the distribution and at
// http://projectchrono.org/license-chrono.txt.
//
// =============================================================================
// Authors: Cecily Sunday
// =============================================================================
//
// Fill a rotating drum - create a particle cloud inside of the drum,
// give each particle in the cloud an initial velocity in a random direction,
// and let the particles settle under gravity. The drum is held fixed.
//
// Additional notes:
// - Gravity aligned with z-axis
// - Drum axis of rotation aligned with the y-axis and centered at the origin
// - Drum inner diameter = clength_x = clength_z, drum inner width = clength_y
// - The cylindrical wall of the drum is made up of a ring of spheres
// - Walls have negetive ID numbers (ID < 0)
// - Particles have positive ID numbers (ID >= 0)
//
// TO DO:
// - Particle size in drum should be radius = cp.grad * 0.99
//
// =============================================================================

// Header and include files
#include "chrono_multicore/physics/ChSystemMulticore.h"
#include "chrono/utils/ChUtilsInputOutput.h"

#include "ProjConfig.h"
#include "ProjCalcs.h"
#include "ProjWriteData.h"
#include "ProjProc.h"

#include <random>

// If IRRLICHT is enabled, add irrlicht headers and namespaces
#ifdef CHRONO_IRRLICHT
#include <irrlicht.h>
#include "chrono_irrlicht/ChVisualSystemIrrlicht.h"
using namespace chrono::irrlicht;
#endif

// Other namespace declatartions
using namespace chrono;
using namespace chrono::collision;



// Geometric properties of the drum, derived from the config file values
typedef struct DrumGeometry {
	double crad = 0.0;		/// Radius of the drum particle-ring (measured to the center of the ring particles)
	double crado = 0.0;		/// Drum outer radius
	double ciw = 0.0;		/// Inner width of drum
	double sftw = 0.0;		/// Shift between particle-ring layers along the drum axis
	int numd = 0;			/// Number of particles needed to construct one layer of the particle-ring
	int numw = 0;			/// Number of particle-ring layers needed to preserve ciw
} DrumGeometry;


int SetDrumGeometry(DrumGeometry* drum, const ConfigParameters& cp) {
	// Estimate the radius of the drum particle-ring needed to preserve the drum inner diameter
	double crad = cp.clength_x / 2.0 + cp.grad;

	drum->sftw = 2.0 * cp.grad * sin(CH_C_PI / 3.0);
	drum->numd = (int)round(CH_C_PI / asin(cp.grad / crad));
	drum->numw = (int)round((cp.clength_y - 2.0 * cp.grad) / drum->sftw + 1.0);

	// Actual radius of the particle-ring, outer radius, and inner width of the drum
	drum->crad = cp.grad / sin(CH_C_PI / drum->numd);
	drum->crado = drum->crad + cp.grad;
	drum->ciw = (drum->numw - 1.0) * drum->sftw + 2.0 * cp.grad;

	return 0;
}


void AddSphere(int id, ChSystemMulticoreSMC* msystem, const ConfigParameters& cp,
	double radius, ChVector<> pos, ChVector<> init_v) {
	// Calculate derived parameters
	double mass = cp.grho * (4.0 / 3.0) * CH_C_PI * Pow(radius, 3.0);
	ChVector<> inertia = 0.4 * mass * Pow(radius, 2.0) * ChVector<>(1, 1, 1);

	// Create a spherical body. Set parameters and collision model
	auto body = std::shared_ptr<ChBody>(msystem->NewBody());
	body->SetIdentifier(id);
	body->SetMass(mass);
	body->SetPos(pos);
	body->SetRot(QUNIT);
	body->SetPos_dt(init_v);
	body->SetWvel_par(VNULL);
	body->SetInertiaXX(inertia);
	body->SetBodyFixed(false);
	body->SetCollide(true);

	body->GetCollisionModel()->ClearModel();
	utils::AddSphereGeometry(body.get(), cp.mat_pp, radius);
	body->GetCollisionModel()->BuildModel();

	// Attach a color to the sphere
	#ifdef CHRONO_IRRLICHT
	auto mvisual = chrono_types::make_shared<ChSphereShape>();
	mvisual->GetSphereGeometry().rad = radius;
	mvisual->SetColor(ChColor(0.0f, 0.28f, 0.67f));
	body->AddVisualShape(mvisual);
	#endif

	// Add the sphere to the system
	msystem->AddBody(body);
}


std::pair<size_t, size_t> FillDrum(ChSystemMulticoreSMC* msystem, const ConfigParameters& cp, const DrumGeometry& drum) {
	// Get start index of particle list
	int id = 0;
	std::pair<size_t, size_t> glist;
	glist.first = msystem->Get_bodylist().size();

	// Create a air-gap margin value and determine the margin radius of each particle
	double marg = cp.gmarg * 2.5;
	double margrad = cp.grad * (1.0 + marg);

	// Outer ring of the particle cloud, with margin
	double orad = drum.crad - 2.0 * margrad;

	// Calculate offsets required for constructing the particle cloud
	double sft_xz = 2.0 * margrad * cos(CH_C_PI / 3.0);								/// shift in x pos between particle centers, within a layer
	double sft_zz = 2.0 * margrad * sin(CH_C_PI / 3.0);								/// shift in z pos between particle centers, within a layer
	double sft_xy = margrad;														/// shift in x pos of reference particle between layers
	double sft_zy = -margrad * tan(CH_C_PI / 6.0);									/// shift in z pos of reference particle between layers
	double sft_yy = margrad * Sqrt(4.0 - (1.0 / Pow(cos(CH_C_PI / 6.0), 2.0)));		/// shift between layers along the drum axis

	// Set the max number of particles along the X, Y, and Z axis
	double numx = floor(drum.crad / (2.0 * margrad));
	double numy = round((cp.clength_y - 2.0 * margrad) / sft_yy + 1);
	double numz = floor((5.0 / 3.0) * drum.crad / sft_zz);

	// Create a generator for computing random sphere radius values that follow a normal distribution
	auto seed = std::chrono::system_clock::now().time_since_epoch().count();
	std::default_random_engine generator((unsigned int)seed);
	std::normal_distribution<double> distribution(cp.grad, cp.gmarg / 4.0);

	// Construct a particle cloud in the bottom of the drum, starting from the front (+y) face of the drum
	ChVector<> pos_ref = ChVector<>(0.0, drum.ciw / 2.0 - margrad, -orad);
	for (int iy = 0; iy < numy; ++iy) {
		int add_sft = iy % 2;
		double posy = -sft_yy * iy;

		for (int iz = 1; iz < numz; ++iz) {
			// Set the position of the first particle in the row
			double posx = sft_xy * add_sft + sft_xz * (iz % 2);
			double posz = sft_zy * add_sft + sft_zz * iz;

			ChVector<> posi = pos_ref + ChVector<>(posx, posy, posz);

			// Add the first particle in the row
			AddSphere(id++, msystem, cp, distribution(generator), posi, ChRandomXYZ(cp.gvel));

			// Add particles to the left and right of the first particle until the drum limits are reached
			double xlim = Sqrt(Pow(orad, 2.0) - Pow(posz - marg - orad, 2.0));
			for (int ix = 1; ix < numx; ++ix) {
				ChVector<> posr = posi + ChVector<>(2.0 * sft_xz * ix, 0, 0);
				ChVector<> posl = posi - ChVector<>(2.0 * sft_xz * ix, 0, 0);

				if (posr.x() <= xlim) AddSphere(id++, msystem, cp, distribution(generator), posr, ChRandomXYZ(cp.gvel));
				if (posl.x() >= -xlim) AddSphere(id++, msystem, cp, distribution(generator), posl, ChRandomXYZ(cp.gvel));
				if (posr.x() > xlim && posl.x() < -xlim) break;
			}
		}
	}

	// Get the end index of the particle list and return
	glist.second = msystem->Get_bodylist().size() - 1;
	return glist;
}


std::pair<size_t, size_t> AddDrum(ChSystemMulticoreSMC* msystem, const ConfigParameters& cp, const DrumGeometry& drum) {
	// Get start index of the wall list
	int id = 0;
	std::pair<size_t, size_t> wlist;
	wlist.first = msystem->Get_bodylist().size();

	// Angle between spheres on the drum particle-ring
	double theta = 2.0 * asin(cp.grad / drum.crad);

	// Positions of the stator and rotor plates along the drum axis
	double hthick = cp.cthickness / 2.0;
	double pfrnt = (drum.ciw + cp.cthickness) / 2.0;
	double pback = -pfrnt;
	double pstat = -(drum.ciw + 3.0 * cp.cthickness) / 2.0;

	// ADD STATOR (fixed body behind the back plate, used to anchor the drum motor in the 'run' sim)
	auto stator = std::shared_ptr<ChBody>(msystem->NewBody());
	stator->SetIdentifier(--id);
	stator->SetMass(cp.cmass);
	stator->SetPos(VNULL);
	stator->SetRot(QUNIT);
	stator->SetBodyFixed(true);
	stator->SetCollide(true);

	stator->GetCollisionModel()->ClearModel();
	utils::AddCylinderGeometry(stator.get(), cp.mat_pw, drum.crado / 4.0, hthick, ChVector<>(0, pstat, 0), QUNIT, false);
	stator->GetCollisionModel()->BuildModel();

	msystem->AddBody(stator);

	// ADD ROTOR PLATES (includes back plate and front plate)
	auto rotor = std::shared_ptr<ChBody>(msystem->NewBody());
	rotor->SetIdentifier(--id);
	rotor->SetMass(cp.cmass);
	rotor->SetPos(VNULL);
	rotor->SetRot(QUNIT);
	rotor->SetBodyFixed(true);
	rotor->SetCollide(true);

	rotor->GetCollisionModel()->ClearModel();
	utils::AddCylinderGeometry(rotor.get(), cp.mat_pw, drum.crado, hthick, ChVector<>(0, pfrnt, 0), QUNIT, false);
	utils::AddCylinderGeometry(rotor.get(), cp.mat_pw, drum.crado, hthick, ChVector<>(0, pback, 0), QUNIT, false);
	rotor->GetCollisionModel()->BuildModel();

	msystem->AddBody(rotor);

	// ADD ROTOR PARTICLE RING (particle-wall contacts use particle-particle material properties)
	auto pring = std::shared_ptr<ChBody>(msystem->NewBody());
	pring->SetIdentifier(--id);
	pring->SetMass(cp.gmass);
	pring->SetPos(VNULL);
	pring->SetRot(QUNIT);
	pring->SetBodyFixed(true);
	pring->SetCollide(true);

	pring->GetCollisionModel()->ClearModel();
	for (int i = 0; i < drum.numd; ++i) {
		for (int j = 0; j < drum.numw; ++j) {
			double posx = drum.crad * sin(theta * i + (theta / 2.0) * (j % 2));
			double posy = drum.ciw / 2.0 - cp.grad - drum.sftw * j;
			double posz = drum.crad * cos(theta * i + (theta / 2.0) * (j % 2));
			utils::AddSphereGeometry(pring.get(), cp.mat_pp, cp.grad, ChVector<>(posx, posy, posz), QUNIT, false);

			#ifdef CHRONO_IRRLICHT
			auto mvisual = chrono_types::make_shared<ChSphereShape>();
			mvisual->GetSphereGeometry().rad = cp.grad;
			mvisual->SetColor(ChColor(0.1f, 0.1f, 0.1f));
			pring->AddVisualShape(mvisual, ChFrame<>(ChVector<>(posx, posy, posz)));
			#endif
		}
	}
	pring->GetCollisionModel()->BuildModel();

	msystem->AddBody(pring);

	// Attach a color to the stator and back plate. The front plate is left invisible so that the particles can be seen.
	#ifdef CHRONO_IRRLICHT
	auto svisual = chrono_types::make_shared<ChCylinderShape>();
	svisual->GetCylinderGeometry().rad = drum.crado / 4.0;
	svisual->GetCylinderGeometry().p1 = ChVector<>(0, pstat + hthick, 0);
	svisual->GetCylinderGeometry().p2 = ChVector<>(0, pstat - hthick, 0);
	svisual->SetColor(ChColor(0.1f, 0.1f, 0.1f));
	stator->AddVisualShape(svisual);

	auto rvisual = chrono_types::make_shared<ChCylinderShape>();
	rvisual->GetCylinderGeometry().rad = drum.crado;
	rvisual->GetCylinderGeometry().p1 = ChVector<>(0, pback + hthick, 0);
	rvisual->GetCylinderGeometry().p2 = ChVector<>(0, pback - hthick, 0);
	rvisual->SetColor(ChColor(0.35f, 0.85f, 0.15f));
	rotor->AddVisualShape(rvisual);
	#endif

	// Find and return index range of full wall list
	wlist.second = msystem->Get_bodylist().size() - 1;
	return wlist;
}


int main(int argc, char* argv[]) {
	// Print Chrono version to userlog
	GetLog() << "Copyright (c) 2017 projectchrono.org\nChrono version: " << CHRONO_VERSION << "\n";

	// Get the location of the config file from user input
	const std::string cfile = GetConfigFile(argc, argv);

	// Initialize simulation. Import parameters from the config file and set input/output directories.
	ConfigParameters cp;
	if (int err = InitializeSimulation(&cp, cfile) != 0) {
		fprintf(stderr, "\nERR: Error configuring simulation at return %i\n", err);
		return -1;
	}

	// Create a Multicore SMC system and set the system parameters
	ChSystemMulticoreSMC msystem;
	if (SetSimulationParameters(&msystem, cp) != 0) {
		fprintf(stderr, "\nERR: Error setting simulation parameters\n");
		return -1;
	}

	// Calculate the geometric properties of the drum
	DrumGeometry drum;
	if (SetDrumGeometry(&drum, cp) != 0) {
		fprintf(stderr, "\nERR: Error setting drum geometry\n");
		return -1;
	}

	// Add the drum and grains to the simulation. The drum is fixed for the 'set' sim.
	std::pair<size_t, size_t> wlist = AddDrum(&msystem, cp, drum);
	std::pair<size_t, size_t> glist = FillDrum(&msystem, cp, drum);

	// Create an object to track certain system info and stats
	SystemData mstats;
	if (SetSystemStats(mstats, msystem, cp.time_step, wlist, glist) != 0) {
		fprintf(stderr, "\nERR: Error setting system stats\n");
		return -1;
	}

	// Create and configure the irrlicht visualizer
	#ifdef CHRONO_IRRLICHT
	auto application = chrono_types::make_shared<ChVisualSystemIrrlicht>();
	application->AttachSystem(&msystem);
	application->SetWindowSize(800, 600);
	application->SetWindowTitle("DRUM_SET");
	application->SetCameraVertical(CameraVerticalDir::Z);
	application->Initialize();
	application->AddTypicalLights();
	application->AddSkyBox();
	application->AddCamera(ChVector<>(0, cp.clength_x * 2, 0), ChVector<>(0, 0, 0));
	application->AddLight(ChVector<>(0, cp.clength_x * 2, cp.clength_z), cp.clength_z * 2);
	#endif

	// Set the soft run-time parameters
	double time = 0.0;
	double time_loop = cp.time_loop;
	double time_save = cp.time_save;

	// Iterate through the simulation until the time limit is reached.
	while (time < cp.sim_duration) {
		// Start irrlicht visualization scene
		#ifdef CHRONO_IRRLICHT
		application->BeginScene();
		application->Render();
		application->GetDevice()->run();
		application->EndScene();
		#endif

		// Calculate dynamics for (cp.time_loop / time_step) continuous steps
		while (time < time_loop) {
			msystem.DoStepDynamics(cp.time_step);
			time += cp.time_step;

			IncrementTimerTotals(msystem, &mstats, time);
			if (time > cp.sim_duration) break;
		}
		time_loop = time - cp.time_step + cp.time_loop;

		// Save and write data every (cp.time_save / time_step) steps (particles only, not walls)
		if (time > time_save) {
			if (ArchiveState(msystem, mstats, cp.proj_path, mstats.num_particles, glist.first, time) != 0) {
				fprintf(stderr, "\nERR: Error archiving run-time data \n");
				return -1;
			}
			time_save += cp.time_save;
		}

		// Calculate the average kinetic energy of all particles. If the max particle vel < threshold, exit the loop.
		if (CalcAverageKE(msystem, cp.proj_path, mstats.num_particles, glist.first, time, 1)) break;
	}

	// Export the final state data for all bodies in the system
	if (ArchiveState(msystem, mstats, cp.proj_path, mstats.num_bodies, wlist.first, time, true) != 0) {
		fprintf(stderr, "\nERR: Error archiving final state data \n");
		return -1;
	}

	// Post-process step 1: convert select binaries to .csv format
	if (ConvertBinaries(cp.proj_path) != 0) {
		fprintf(stderr, "\nERR: Could not convert binary files.\n");
		return -1;
	}

	return 0;
}
