function [Influence, FlowMap] = MULTIFLOW(DEMprefill, p)

% [Influence, FlowMap] = MULTIFLOW(DEMprefill, p)
%
% MULTIFLOW creates and returns an Influence map for a DEM. Influence
% is dispersed across the DEM from a single vent location according to 
% the multi-slope flow algorithm. TopoToolbox is used to fill holes in the
% DEM and to disperse teh flow. The flow size is limited by an emperical
% function of the form : log10(Influence) > a*L^b - c where L (km) is the 
% distance from the vent location. 
%
% Topotoolbox is freely distributed by
% Wolfgang Schwanghart and can be downloaded from 
% https://topotoolbox.wordpress.com/download/. This code was tested with
% version 2.2, which was the most recent release as of 2-1-19. Additional 
% information can be found in "Schwanghart, W., Scherler, D. (2014): 
% TopoToolbox 2 � MATLAB-based software for topographic analysis and 
% modeling in Earth surface sciences. Earth Surface Dynamics, 2, 1-7. 
% DOI: 10.5194/esurf-2-1-2014." 
%
% Inputs -------------------
%    DEMprefill: MxN rectangular array of elevation ("holes" or topographic
%         lows do not need to be filled) 
%    p is a parameter file, which includes 
%         p.a: coefficient from threshold function 
%         p.b: exponent from threshold function 
%         p.c: intercept from threshold function 
%         p.VentLocations: [x y] pixel locations 
%         p.dx: (grid resolution)
% Outputs ------------------
%     Influence: MxN rectangular array of Influence. 
%     FlowMap: MxN rectangular array of map showing where flow is predicted
%         to occur for the parameters p.a, p.b, and p.c. 
%
% -------------------------------------------------------------------------
% Copyright (C) 2018- Paul Richardson and Leif Karlstrom 
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the 
% Free Software Foundation. You should have received a copy of the GNU 
% General Public License along with this program.  If not, see 
% http://www.gnu.org/licenses.
% -------------------------------------------------------------------------

% - - - - - - - - - - - - - calculate influence - - - - - - - - - - - - - -
[M, N] = size(DEMprefill); % M x N : Y-dimension x X-dimension
% fill DEM w/TopoToolbox
DEMtopo = GRIDobj(1:N,1:M,DEMprefill);
DEMf = fillsinks(DEMtopo);
clear DEMtopo;
% calculate drainage directions
FD = FLOWobj(DEMf,'multi');
% spread flow from single location 
W0 = zeros(size(DEMf.Z));
W0(p.VentLocation(2), p.VentLocation(1)) = 1; 
InfluenceNewUD = flowacc(FD,flipud(W0));
% extract Influence and flip back to original orientation
Influence = flipud(InfluenceNewUD.Z);

% - - - - - - - - - - - - - apply threshold - - - - - - - - - - - - - - - -
% x and y pixel distance from vent 
[X, Y] = meshgrid(1:N, 1:M);
X_dist = X - p.VentLocation(1);
Y_dist = Y - p.VentLocation(2);
% Calculate distance from vent to each pixel 
DISTANCE = sqrt(X_dist.^2 + Y_dist.^2)*p.dx/1000;
% threshold
INFLUENCE_THRESHOLD = p.a*(DISTANCE.^p.b) - p.c;
INFLUENCE_THRESHOLD(INFLUENCE_THRESHOLD> 0) = 0;    
MARKERMAP = ones(M, N);  
FlowMap = MARKERMAP.*(log10(Influence) > INFLUENCE_THRESHOLD);     

% - - - - - - - - - - - exclude disconnected strands - - - - - - - - - - -
FlowMap = bwlabel(FlowMap,8);
% The flow is defined as the group of connected pixels with the largest 
% area. Disclaimer: Scenarios may exist where the algorithm chooses the 
% wrong set of neighboring pixels as the flow. For all DEMs (natural and 
% synthetic) tested with this algorithm, the correct flow was defined. 
Largest = 1; 
LargestValue = 1; 
% make sure that the largest flow is selected 
for jj = 1:max(FlowMap(:))
    FlowMapTest = FlowMap;
    FlowMapTest(FlowMapTest~=jj) = 0;
    FlowMapTest(FlowMapTest==jj) = 1;
    if sum(FlowMapTest(:)) > LargestValue
        Largest = jj;
        LargestValue = sum(FlowMapTest(:));
    end
end
% exclude everything else    
FlowMap(FlowMap~=Largest) = 0; 
FlowMap(FlowMap~=0) = 1;


