# CUDA_propagation

This is the already compiled version. There is a .cu file that has to be compiled using Nvidia CUDA-C compiler nvcc and then executed:

$ nvcc propagator_8_cpml.cu
$ ./a.out

This procedure uses a seismic source (Fuente.bin) and velocity model (Modelo_ori.bin) to generate the propagation field (Frentedeonda.bin) and seismic traces (Trazas.bin), it also computes the derivative of the wavefield (DerivadaFrentedeOnda.bin).

The results.m file can be executed in matlab for visualization purposes. It shows the source, the model and the propagation.

Enjoy!
