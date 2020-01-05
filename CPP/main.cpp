#include <iostream>
#include <mpi.h>

using namespace std;


int main(int argc, char** argv) {
	MPI_Init(&argc, &argv);

	int mpirank, mpisize;

	MPI_Comm_rank(MPI_COMM_WORLD, &mpirank);
	MPI_Comm_size(MPI_COMM_WORLD, &mpisize);

	cout << mpirank << endl;

	MPI_Finalize();

	return 0;
}