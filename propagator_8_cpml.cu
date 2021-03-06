
#include <stdio.h>              //manipulacion de ficheros, lectura-escritura ficheros, scandf-printf
#include <stdlib.h>             //Conversion de tipos de datos, memoria dinamica, abs
#include <string.h>             //Uso de memcpy principalmente
#include <math.h>		//funciones matemáticas

#define TILE_WIDTH_X 32
#define TILE_WIDTH_Y 32
#define PI 3.141592653589793
#define left ((ix-1) + Nx*iz)		//Izquierda
#define top  (ix + Nx*(iz-1))		//Arriba
#define center (ix + Nx*iz)		//Centro	
#define bottom (ix + Nx*(iz+1))		//Abajo
#define right  ((ix+1) + Nx*iz)		//Derecha


// A = Presente
// B = Pasado
// C = Futuro

//DEVICE CODE - Kernel1
__global__ void kernel_lap(float *lap, float *A, int nx, int ny, float dh){

	int ix=threadIdx.x + blockIdx.x*blockDim.x;
	int iy=threadIdx.y + blockIdx.y*blockDim.y;

	int tid = ix + iy*nx;

	if(ix > 3 && ix < nx-4 && iy > 3 && iy< ny-4){
		lap[tid] =((-1./560)*(A[ tid - 4 ] + A[tid + 4] + A[tid + 4*nx ] + A[tid -4*nx]) + 
			    (8./315)*(A[ tid - 3 ] + A[tid + 3] + A[tid + 3*nx ] + A[tid -3*nx]) + 
			     (-1./5)*(A[ tid - 2 ] + A[tid + 2] + A[tid + 2*nx ] + A[tid -2*nx]) + 
			      (8./5)*(A[ tid - 1 ] + A[tid + 1] + A[tid + 1*nx ] + A[tid -1*nx]) +
				(-205./36)*(A[tid]))/(dh*dh);
				__syncthreads();
	}

}

__global__ 
void get_CPML_x(float *a_x, float *b_x, int CPMLimit, float R, float VelMax, int Nx, float dt, float dh, float frec){

	int ix = threadIdx.x + blockDim.x * blockIdx.x;    // Indice vector

	float Lx = CPMLimit*dh;
	float d0 = -3*log(R)/(2*Lx);
	a_x[ix] = 0;
	b_x[ix] = 0;
	

	if (ix<CPMLimit+1)	//Left CPML
	{
		b_x[ix] = exp(-( (d0 * VelMax * (((CPMLimit-ix)*dh)/Lx) * (((CPMLimit-ix)*dh)/Lx)) + (PI * frec * (Lx - ((CPMLimit-ix)*dh))/Lx))*dt);
		__syncthreads();
		a_x[ix] = (d0 * VelMax * (((CPMLimit-ix)*dh)/Lx) * (((CPMLimit-ix)*dh)/Lx)) * ( b_x[ix] - 1 ) / ( (d0 * VelMax * (((CPMLimit-ix)*dh)/Lx) * (((CPMLimit-ix)*dh)/Lx)) + (PI * frec * (Lx - ((CPMLimit-ix)*dh))/Lx));
		__syncthreads();
                __syncthreads();		
	}

	if (ix>(Nx-CPMLimit-1) && ix<Nx)	//Right CPML
	{
		b_x[ix] = exp(-( (d0 * VelMax * (((ix-Nx+CPMLimit+1)*dh)/Lx) * (((ix-Nx+CPMLimit+1)*dh)/Lx)) + (PI * frec * (Lx - ((ix-Nx+CPMLimit+1)*dh))/Lx) )*dt);
		__syncthreads();
		a_x[ix] = (d0 * VelMax * (((ix-Nx+CPMLimit+1)*dh)/Lx) * (((ix-Nx+CPMLimit+1)*dh)/Lx)) * ( b_x[ix] - 1 ) / ( (d0 * VelMax * (((ix-Nx+CPMLimit+1)*dh)/Lx) * (((ix-Nx+CPMLimit+1)*dh)/Lx)) + (PI * frec * (Lx - ((ix-Nx+CPMLimit+1)*dh))/Lx) );
		__syncthreads();
                __syncthreads();		
	}

}


__global__ 
void get_CPML_z(float *a_z, float *b_z, int CPMLimit, float R, float VelMax,  int Nz, float dt, float dh, float frec){
	
	//dh = dx; Notacion
	int iz = threadIdx.x + blockDim.x * blockIdx.x;    // Indice vector

	float Lz = CPMLimit*dh;
	float d0 = -3*log(R)/(2*Lz);

	//Inicializando valores de CPML
	a_z[iz] = 0;
	b_z[iz] = 0;

	if (iz>(Nz-CPMLimit-1) && iz<Nz)	//bottom CPML
	{
		b_z[iz] = exp(-( (d0 * VelMax * (((iz-Nz+CPMLimit+1)*dh)/Lz) * (((iz-Nz+CPMLimit+1)*dh)/Lz)) + (PI * frec * (Lz - ((iz-Nz+CPMLimit+1)*dh))/Lz) )*dt);
		__syncthreads();
		a_z[iz] = (d0 * VelMax * (((iz-Nz+CPMLimit+1)*dh)/Lz) * (((iz-Nz+CPMLimit+1)*dh)/Lz)) * ( b_z[iz] - 1 ) / ( (d0 * VelMax * (((iz-Nz+CPMLimit+1)*dh)/Lz) * (((iz-Nz+CPMLimit+1)*dh)/Lz)) + (PI * frec * (Lz - ((iz-Nz+CPMLimit+1)*dh))/Lz) );
		__syncthreads();
	}

}

__global__ 
void PSI(float *A, float *a_x, float *b_x, float *a_z, float *b_z, float *Psi_x, float *Psi_z, int CPMLimit, int Nx, int Nz, float dh){

	int ix = threadIdx.x + blockDim.x * blockIdx.x;		// Row  of  the  A matrix
	int iz = threadIdx.y + blockDim.y * blockIdx.y;		// Column of the A matrix
	int tid = ix + iz*Nx;


	if(ix > 3 && ix < Nx-4 && iz > 3 && iz< Nz-4)
	{
    // Primera derivada de segundo orden centrada
  /*    
		Psi_x[tid] = Psi_x[tid]*b_x[ix] + a_x[ix]*( (-1./2)*A[tid-1] + (1./2)*A[tid+1])/(2*dh);
		Psi_z[tid] = Psi_z[tid]*b_z[iz] + a_z[iz]*( (-1./2)*A[tid-Nx]  + (1./2)*A[tid+Nx])/(2*dh);
  */  
    // Primera derivada de octavo orden centrada
		
	Psi_x[tid] = Psi_x[tid]*b_x[ix] + a_x[ix]*( (1./280.)*A[tid-4] - (4./105.)*A[tid-3] + (1./5.)*A[tid-2] - (4./5.)*A[tid-1] + (4./5.)*A[tid+1] + (-1./5.)*A[tid+2] + (4./105.)*A[tid+3] + (-1./280.)*A[tid+4] )/(dh);
		__syncthreads();	  

	Psi_z[tid] = Psi_z[tid]*b_z[iz] + a_z[iz]*( (1./280.)*A[tid-4*Nx] + (-4./105.)*A[tid-3*Nx] + (1./5.)*A[tid-2*Nx] + (-4./5.)*A[tid-1*Nx] + (4./5.)*A[tid+1*Nx] + (-1./5.)*A[tid+2*Nx] + (4./105.)*A[tid+3*Nx] + (-1./280.)*A[tid+4*Nx] )/(dh);
		__syncthreads();	  
  }
}


__global__ 
void kernel_propaga(float *lap, float *A, float *B, int nx, int nz, float *source, float *c, float *traza, float *P, float *dP, int it, int sx, int sz, int borde, float dt, float *a_z, float *a_x, float *b_z, float *b_x, float *Psi_x, float *Psi_z, float *Z_x, float *Z_z, float *temp, float dh, int modo){

	int ix=threadIdx.x + blockIdx.x*blockDim.x;
	int iy=threadIdx.y + blockIdx.y*blockDim.y;
	int tid  = ix + iy*nx;
	float G  = c[tid]*c[tid]*dt*dt;

  
	if(ix > 3 && ix < nx-4 && iy > 3 && iy< nz-4){
    // Calculo de las derivadas de psi

     // Primera derivada de segundo orden central

     //temp[tid]=((-1./2)*Psi_x[tid-1] + (1./2)*Psi_x[tid+1])/(2*dh) + ((-1./2)*Psi_z[tid-nx] + (1./2)*Psi_z[tid+nx])/(2*dh); 
     // Primera derivada octavo orden central
    temp[tid]=( (1./280)*Psi_x[tid-4] + (-4./105)*Psi_x[tid-3] + (1./5)*Psi_x[tid-2] + (-4./5)*Psi_x[tid-1] 
	     + (4./5)*Psi_x[tid+1] + (-1./5)*Psi_x[tid+2] + (4./105)*Psi_x[tid+3] + (-1./280)*Psi_x[tid+4] )/(dh) 
	     + ( (1./280)*Psi_z[tid-4*nx] +  (-4./105)*Psi_z[tid-3*nx] + (1./5)*Psi_z[tid-2*nx] + (-4./5)*Psi_z[tid-1*nx] 
	     + (4./5)*Psi_z[tid+1*nx] + (-1./5)*Psi_z[tid+2*nx] + (4./105)*Psi_z[tid+3*nx] + (-1./280)*Psi_z[tid+4*nx] )/(dh); 
    __syncthreads();
    
// Calculo de los zetas

    // Derivadas de segundo orden
    // Z_x[tid]=b_x[ix]*Z_x[tid] + a_x[ix]*( (A[tid+1] -2*A[tid] + A[tid-1])/(dh*dh) + ((-1./2)*Psi_x[tid-1] + (1./2)*Psi_x[tid+1])/dh);
    // Z_z[tid]=b_z[iy]*Z_z[tid] + a_z[iy]*( (A[tid-nx] -2*A[tid] + A[tid+nx])/(dh*dh) +  ((-1./2)*Psi_z[tid-nx] + (1./2)*Psi_z[tid+nx])/dh);

    // Derivadas de octavo orden
    Z_x[tid]=b_x[ix]*Z_x[tid] + a_x[ix]*( ( (-1./560)*A[tid-4] + (8./315)*A[tid-3] + (-1./5)*A[tid-2] + (8./5)*A[tid-1] + (-205./72)*A[tid] + (8./5)*A[tid+1] + (-1./5)*A[tid+2] + (8./315)*A[tid+3] + (-1./560)*A[tid+4] )/(dh*dh) + ((1./280)*Psi_x[tid-4] + (-4./105)*Psi_x[tid-3] + (1./5)*Psi_x[tid-2] + (-4./5)*Psi_x[tid-1] + (4./5)*Psi_x[tid+1] + (-1./5)*Psi_x[tid+2] + (4./105)*Psi_x[tid+3] + (-1./280)*Psi_x[tid+4] )/(dh*dh));
    __syncthreads();
    
    Z_z[tid]=b_z[iy]*Z_z[tid] + a_z[iy]*( ( (-1./560)*A[tid-4*nx] + (8./315)*A[tid-3*nx] + (-1./5)*A[tid-2*nx] + (8./5)*A[tid-1*nx] + (-205./72)*A[tid] + (8./5)*A[tid+1*nx] + (-1./5)*A[tid+2*nx] + (8./315)*A[tid+3*nx] + (-1./560)*A[tid+4*nx] )/(dh*dh) + ((1./280)*Psi_z[tid-4*nx] + (-4./105)*Psi_z[tid-3*nx] + (1./5)*Psi_z[tid-2*nx] + (-4./5)*Psi_z[tid-1*nx] + (4./5)*Psi_z[tid+1*nx] + (-1./5)*Psi_z[tid+2*nx] + (4./105)*Psi_z[tid+3*nx] + (-1./280)*Psi_z[tid+4*nx] )/(dh*dh));
    __syncthreads();
    
  }

	//if(ix<nx-1 && iy<nz-1){
	if(ix > 3 && ix < nx-4 && iy > 3 && iy< nz-4 ){
 		B[tid]=2*A[tid] - B[tid] + G*( lap[tid] + Z_x[tid] + Z_z[tid] + temp[tid]);
		__syncthreads();
	}

	if(ix < nx && iy< nz){
//		if(it<Nt){
			if(ix==(sx-1+4) && iy==(sz-1+4)){
				A[tid] = A[tid] + source[it];
				__syncthreads();
			}
//		}

	if(modo==1 || modo==3 ){
		P[tid+nx*nz*it]=B[tid];
	  __syncthreads();
	}
	if(modo==2 || modo==3 ){
		dP[tid+nx*nz*it]=c[tid]*c[tid]*(lap[tid] + Z_x[tid] + Z_z[tid] + temp[tid]);
	  __syncthreads();
	}
	if(ix>=borde && ix< nx-borde && iy==sz-1+4){
		traza[(ix-borde)+it*(nx-2*borde)]=B[tid];
	__syncthreads();
	}
	}
	__syncthreads();
}
// A = Presente
// B = Pasado
// C = Futuro
//HOST CODE
int main(){
 cudaDeviceReset();
  //variables host
	
	int borde=20;
  	int nx=210;
	int ny=71;
	int modo=1;
	int it;
	int nt;
	int sx = ceil(nx/2);
	int sz = 6;
  	float VelMax=4700;
	float R=100e-6;
	float frec=3;
	float tend=1.0;
	float dt=0.001; 
	float dh=25;
	float  *A_d, *B_d, *Pt_d, *Pt_h, *P_d, *P_h, *dP_d, *dP_h, *s_h, *s_d, *v_d, *v_h, *A_x, *A_z, *B_x, *B_z, *lap, *temp, *temp1, *Psi_x, *Psi_z, *Z_x, *Z_z;
	FILE *source, *model_ori;

	nt= ceil(tend/dt);

	Pt_h = (float *)calloc((nx-2*borde)*nt,sizeof(float));
	v_h  = (float *)calloc(nx*ny,sizeof(float));
	s_h  = (float *)calloc(nt,sizeof(float));
	P_h  = (float *)calloc(nx*ny*nt,sizeof(float));
	dP_h = (float *)calloc(nx*ny*nt,sizeof(float));

  //variables y memory allocation en device
	cudaMalloc(&Pt_d,(nx-2*borde)*nt*sizeof(float));
        cudaMalloc(&A_d, nx*ny*sizeof(float));
        cudaMalloc(&B_d, nx*ny*sizeof(float));
        cudaMalloc(&P_d, nx*ny*nt*sizeof(float));
        cudaMalloc(&dP_d, nx*ny*nt*sizeof(float));
        cudaMalloc(&s_d, nt*sizeof(float));
        cudaMalloc(&v_d, nx*ny*sizeof(float));
        cudaMalloc(&lap, nx*ny*sizeof(float));
        cudaMalloc(&Psi_x, nx*ny*sizeof(float));
        cudaMalloc(&Psi_z, nx*ny*sizeof(float));
        cudaMalloc(&Z_x, nx*ny*sizeof(float));
        cudaMalloc(&Z_z, nx*ny*sizeof(float));
        cudaMalloc(&temp1, nx*ny*sizeof(float));

        cudaMalloc(&A_x, nx*sizeof(float));
        cudaMalloc(&A_z, ny*sizeof(float));
        cudaMalloc(&B_x, nx*sizeof(float));
        cudaMalloc(&B_z, ny*sizeof(float));
      	
        cudaMemset(A_d,0,nx*ny*sizeof(float));
      	cudaMemset(B_d,0,nx*ny*sizeof(float));
      	cudaMemset(lap,0,nx*ny*sizeof(float));
        cudaMemset(Psi_x,0,nx*ny*sizeof(float));
        cudaMemset(Psi_z,0,nx*ny*sizeof(float));
        cudaMemset(Z_x,0,nx*ny*sizeof(float));
        cudaMemset(Z_z,0,nx*ny*sizeof(float));
        cudaMemset(temp1,0,nx*ny*sizeof(float));

        cudaMemset(A_x,0,nx*sizeof(float));
        cudaMemset(A_z,0,ny*sizeof(float));
        cudaMemset(B_x,0,nx*sizeof(float));
        cudaMemset(B_z,0,ny*sizeof(float));


	//Leer y condicionar archivos fuente 
        source = fopen ("Fuente.bin","rb");
        fread(s_h,nt*sizeof(float),1,source);
        printf("\nDatos de fuente cargados...\n");
        fclose(source);

        //Leer y condicionar archivos modelo original
        model_ori = fopen ("Modelo_ori.bin","rb");
        fread(v_h,nx*ny*sizeof(float),1,model_ori);
        printf("\nDatos de modelo original cargados...\n");
        fclose(model_ori);
	
	//Enviando informacion necesaria a la GPU
        cudaMemcpy(v_d, v_h, nx*ny*sizeof(float), cudaMemcpyHostToDevice);
        cudaMemcpy(s_d, s_h, nt*sizeof(float), cudaMemcpyHostToDevice);
	

        //ejecución Kernel
        dim3 dimGrid_M(ceil((nx) / (float)TILE_WIDTH_X) , ceil((ny) / (float)TILE_WIDTH_Y));
        dim3 dimBlock_M(TILE_WIDTH_X , TILE_WIDTH_Y);

      	dim3 dimGrid_Vx(ceil((nx) / (float)TILE_WIDTH_X));
        dim3 dimBlock_Vx(TILE_WIDTH_X);

      	dim3 dimGrid_Vz(ceil((ny) / (float)TILE_WIDTH_Y));
        dim3 dimBlock_Vz(TILE_WIDTH_Y);

        get_CPML_x<<<dimGrid_Vx, dimBlock_Vx>>>(A_x, B_x, borde, R, VelMax, nx, dt, dh, frec);
        get_CPML_z<<<dimGrid_Vz, dimBlock_Vz>>>(A_z, B_z, borde, R, VelMax, ny, dt, dh, frec);

	for (it=0;it<nt;it++){
		printf("Voy en el paso temporal %d \n",it+1);
          
          PSI<<<dimGrid_M, dimBlock_M>>>(A_d, A_x, B_x, A_z, B_z, Psi_x, Psi_z, borde, nx, ny, dh);
          kernel_lap<<<dimGrid_M, dimBlock_M>>>(lap,A_d,nx,ny,dh); //#blocks=dimGrid, #threads=dimBlock
          kernel_propaga<<<dimGrid_M, dimBlock_M>>>(lap,A_d,B_d,nx,ny,s_d,v_d,Pt_d,P_d,dP_d,it,sx,sz,borde,dt,A_z,A_x,B_z,B_x,Psi_x,Psi_z,Z_x,Z_z,temp1,dh,modo); //#blocks=dimGrid,
          temp = A_d;
          A_d = B_d;
          B_d = temp;
	}
	
	if(modo==1 || modo==3){
	
        	cudaMemcpy(P_h, P_d, nx*ny*nt*sizeof(float), cudaMemcpyDeviceToHost);
	}
	
	if(modo==2 || modo==3){

        	cudaMemcpy(dP_h, dP_d, nx*ny*nt*sizeof(float), cudaMemcpyDeviceToHost);
	}

        cudaMemcpy(Pt_h, Pt_d, (nx-2*borde)*nt*sizeof(float), cudaMemcpyDeviceToHost);
        //---------------------------------------
        // Guarda informacion -----------------------
	// Trazas
	source=fopen("Trazas.bin","wb");
	fwrite(Pt_h,sizeof(float),(nx-2*borde)*nt,source);
	fclose(source);
	free(Pt_h);
	cudaFree(Pt_d);
	// Frente de Onda
	source=fopen("Frentedeonda.bin","wb");
	fwrite(P_h,sizeof(float),nx*ny*nt,source);
	fclose(source);
	free(P_h);
	cudaFree(P_d);

	// Derivad Frente de Onda 
	source=fopen("DerivadaFrentedeOnda.bin","wb");
	fwrite(dP_h,sizeof(float),nx*ny*nt,source);
	fclose(source);
	free(dP_h);
	cudaFree(dP_d);

	// Liberamos resto de punteros
	// Host
  	free(s_h);
	free(v_h);
	// Device
	cudaFree(A_d);
	cudaFree(B_d);
	cudaFree(lap);
	cudaFree(s_d);
	cudaFree(v_d);
	cudaFree(A_x);
	cudaFree(A_z);
	cudaFree(B_x);
	cudaFree(B_z);
	cudaFree(Psi_x);
	cudaFree(Psi_z);
	cudaFree(Z_x);
	cudaFree(Z_z);

	printf("\n Creo que Termine ....\n");

 cudaDeviceReset();
  return 0;
}
