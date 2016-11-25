clc
close all
clear all

%% Before the propagation

% Model characteristics

Nx = 210;
Nz = 71;

borde = 30;
capa  = 9;

dz = 25; 
dx = dz;

X = dx*(0:Nx-1)/1000;
Z = dz*(0:Nz-1)/1000;

fid=fopen('Modelo_ori.bin','rb');
model=fread(fid,'single');
fclose(fid);
model = vec2mat(model,Nx);

figure,
imagesc(X,Z,model)
caxis([1500 4600])
ylabel('Depth [km]')
xlabel('Distance [km]')
title('Marmousi Model')

% Experiment characteristics

tEnd=1.0; % 2.5 - 3.7
dt=0.001; % 4e-3 - 2e-3
t = 0:dt:tEnd-dt; 
frec=3; % 3Hz
Nt=length(t);  

% Creacion de la fuente
a = (pi*frec)^2; 
t0 = 0.5;           %anterior 1 actual 0.5
g_s = -2*a*(t-t0).*exp(-a*(t-t0).^2);
g_s = g_s';

g = g_s;
plot(t,g_s)

fid=fopen('Fuente.bin','wb');
fwrite(fid,g,'single');
fclose(fid);


fid=fopen('Fuente.bin','rb');
source=fread(fid,'single');
fclose(fid);

figure,
plot(t,source)
xlabel('Time [s]')
ylabel('Amplitude')
title('Seismic Source - 3 Hz')

%%  After the propagation


fid=fopen('Frentedeonda.bin','rb');
wave=fread(fid,'single');
fclose(fid);

wave = reshape(wave,[Nx Nz Nt]);

for i=1:1000
   imagesc(model+10*wave(:,:,i)')
   caxis([1500 4600])
   pause(0.005)
end

