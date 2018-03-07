% mutliwall_modelV02
% Motley-Keenan (COST 231 Model) & Free Space Path Loss
% Author: Salaheddin Hosseinzadeh (hosseinzadeh.88@gmail.com)
% Created on: 18.02.2016
% Last revision: 30.01.2017
% Notes:
%   - Mind the Command Window while running the code, you'll be asked for inputs
%   - All lines should be straight lines for this to work! (no curves)
%   - Meshing method is not completed, only use meshingMethod = 2 
%   - Attenuation is calculated in dB atm!
%   - To assign attenuation to walls change "wallAtt" in line 72-77 ...
%   - This code uses imoverlay.mat, by Steven L. Eddins. 
%   - This code uses bresenham.mat, by Aaron Wetzler.
%   - Version 01.
%   - This code requires (imoverlay.m),(shortestPath.m),
%   (autoWallDetection.m), (bresenham.m) to be present in MATLAB path
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Instructions!
% - Make sure all the aforementioned files are in the MATLAB path.
% - Run muiltiwall_modelV01.mat (this file), you have to chose an image of
% the structure blueprint. For the multiwall model to work, walls should
% all be presented by straight lines. Soon you will be asked to choose 2
% points on the blue print. You have to select 2 points that lies on the
% walls otherwise it keeps asking you to choose again. After this it show
% you the wall you selected. Next you need to provide the actual size of
% the wall you selected in real world. This is to calibrate the image.
% - Next you will be asked to locate the Transmitter (Tx) by clicking on it's
% location in the picture.
% - You should get the result, depending on the mesh size you specified in
% the Initilization.
% - You can get a RSSI estimation if you know the transmission
% power, and antenna gains, roughly. Otherwise you can set the TxPower,
% antenna gains and antennaLoss to 0 and get the path loss (attenuation) only.
% 

%% INITIALIZATION  
clear all
clc

% addedd to propiation.m
% lightVel                = 3e8;      % Light velocity (m/s).
% freq                    = 865.2e6;  % Hz
 demoMode                = 0;        % Showes further details if 1  
% 
% TxPower                 = 0;        % dBm or dB
% antennaLoss             = 0;        % dB
% TxAntennaGain           = 0 + antennaLoss ; % Gain of Transmitting antenna
% RxAntennaGain           = TxAntennaGain;    % Gain of Receiving antenna
% 
% % Multi-Wall Model Parameters
% d0Cost231               = 1;      % Multi-wall model reference distance

% for distance calculator
meshNode.vert.num       = 30;             % Number of probs in the structure increase for better accuracy
meshNode.horz.num       = 30;


% Wall Detection Parameters (Change them wiselt if walls are not correctly detected)
thetaRes = 0.1;                   % Resolution of the Hough Transform Space (don't make it smaller than 0.1)
minWallLength = 15;               % Minimum length of the walls in pixel
fillGap = 5;                     % Gap between walls

%Wall Attenuation Coefficient Assignment dB
% Manually Assign Attenuation factors to each particular wall based on it's
% intensity dynamic range (change plot mode in autoWallDetection to 1 to
% see the intesity of each wall.
wallAt = zeros(255,1);
wallAt(200:end) = 6;
wallAt(254) = 5.5;
wallAt(253) = 6;
wallAt(252) = 6;
wallAt(255) = round(sum(wallAt)./sum(wallAt>0));  % This is for intersecting walls, just leave it as it is

% Added vars for UWE work
%-------------------------------------------
noOfTx = 0;     % defalt is set to 0 will be changed at prompt later

% needed for AI algorithm
fitness = -100; 

% calculate scale of diagram
pathLength = 15; % meters
pathPixels = 110; % pixles or  
pathUnit = pathLength./pathPixels; %pathUnit = meter per pixel

%% Reading the image
% Converts the images into a 2D array that indicates
% floorPlan = 0 for wall, 255 for non-wall
% floorPlanBW = 0/False for non-wal, 1/true for wall
try
    [fileName,filePath] = uigetfile('*.*');
catch
end
floorPlan = imread([filePath,fileName]);
floorPlanBW = ~im2bw(floorPlan);



% adjusting the image if required
try
    [co,bi] = imhist(floorPlanBW);
    
    if bi(1) == 0 && co(1) > co(2)
        floorPlanBW = ~floorPlanBW; % complements the image if not in correct form so that the structure will be in Black in case it's not
    end
catch
end

originalFloorPlan = floorPlanBW; % At this point, Structure in Original Image and floorPlanBW is in black

% Optional delation of the image to make wall selection easier
floorPlanBW = ~imdilate(~floorPlanBW,strel('disk',2));
% figure
% imshow(floorPlanBW,'InitialMagnification',100);
% title('Floor Plan');


%% Creating Grid for placement

% TxGrid hold the start and end cooridantes of the 
GridSize = 10;
TxGrid = zeros(2, 2, GridSize, GridSize);

% Centre of grid squares using the starting x,y cordinates 
%TxGrid =  zeros(10); % needs a 4D array holding 2 sets of co ords top left and bottom right:([0,0],[10,10]), ([0,10],[10,20])
tempX = size(floorPlanBW,1)./GridSize;
tempY = size(floorPlanBW,2)./GridSize;

for i =1:GridSize   
    for i2 = 1:GridSize                       
        TxGrid(1,1,i2,i) = tempX.*(i-1);
        TxGrid(1,2,i2,i) = tempY.*(i2-1);
        TxGrid(2,1,i2,i) = tempX.*(i);
        TxGrid(2,2,i2,i) = tempY.*(i2);            
    end     
end


TxGridCentre =  zeros(1,2,GridSize,GridSize); % holds centre co-ord for each gridl
for i =1:GridSize
    for i2 = 1:GridSize
        TxGridCentre(1,1,i2,i) =  TxGrid(1,1,i2,i) + (tempX./2);
        TxGridCentre(1,2,i2,i) = TxGrid(1,2,i2,i) + (tempY./2);        
    end
end


 %% Plan Calibration
 % commented out to remove the need to adjust size of map to allow for fair
 % comparisions
% % Getting 2 points from image for calibration
% disp('Select two points from walls to calibrate the plan!'); 
% while 1
%     disp('Select the 1st point')
%     try
%         [r,c] = ginput(1); % get points one by one. Check each to be a- hit not miss
%         R(1,1)= round(r);
%         C(1,1) = round(c);
%     catch
%     end
%     if ~floorPlanBW(C(1,1),R(1,1))
%         break % if its a hit it stops
%     end
% end
% 
% while 1
%     disp('Select the 2nd point')
%     [r,c] = ginput(1); % get points one by one. Check each to be a- hit not miss
%     R(2,1) = round(r);
%     C(2,1) = round(c);
%     if ~floorPlanBW(C(2,1),R(2,1)) % detects if point hit wall
%         break % if its a hit it stops
%     end
% end
% % Finding shortest path betweent the two points
% calibPath = shortestPath(imcomplement(floorPlanBW),R,C);
% P = imoverlay(floorPlanBW,calibPath,[0,1,0]);
% 
% % Calibrating pixel per meter
% pathPixels = sum(sum(calibPath));
% pathLength = input('Length of calibration path in meters: ');
% 
% pathUnit = pathLength./pathPixels; %pathUnit = meter per pixel

%% Meshing the Floor Plan
% Mesh is where plot points are added to the image to to help loss
% calculations
floorMesh = zeros(size(floorPlanBW));

mesh.vert.spacing = pathUnit .* size(floorPlanBW,1) ./ meshNode.vert.num; % node spacing meters
mesh.horz.spacing = pathUnit .* size(floorPlanBW,2) ./ meshNode.horz.num; % node spacing meters
floorMesh(floor(linspace(1,size(floorPlanBW,1),meshNode.vert.num)),...
    floor(linspace(1,size(floorPlanBW,2),meshNode.horz.num))) = 1;


[floorPlanGray,countedWalls] = autoWallDetection(~originalFloorPlan,wallAt,demoMode,thetaRes,minWallLength,fillGap); % Detecting all the walls Generates floorPlanGray where different wall are index coded in the gray image

%% Locating The Transmitter.
% 
bestTX = 1;
[Rxr,Rxc] = find(floorMesh == 1); 
lossdB = zeros(size(Rxr,1),1);
lossdB(:) = -1000;
bestAvg = sum(lossdB./bestTX);
for t1 = 1:20
    noOfTx = randi([1,10]);%4;% input('How many transmitters: ');
    rand= randi([1,10],noOfTx,2);

    tableA =  zeros(noOfTx,2);
    %
    for i = 1:noOfTx
         tableA(i,:) = [TxGridCentre(:,2,rand(i,1),rand(i,2)),TxGridCentre(:,1,rand(i,1),rand(i,2))];
    end

   % disp(tableA);
    % End point of the Algorithm 
    [tempFitness,tempLossdB] = prop(tableA,floorMesh,pathUnit,originalFloorPlan,floorPlanGray,wallAt,noOfTx);

    % crude fitness score 
    % currently this will just pick the higest amoun of Tx 
    % need to add boundries for acceptable level this
   % tempAvgPerTxFitnessPLUS = sum(tempLossdB./(noOfTx));
    tempPlus = (tempFitness - noOfTx).*(noOfTx);
     fitAvg = fitness./bestTX;
    disp("Current fitness = " + tempFitness + "      no of TX = " + noOfTx  + "         tempPlus = " + tempPlus + "         fitAvg = " + fitAvg); % + "       current TX avg = " + tempAvgPerTxFitness);
 %   if tempAvgPerTxFitness > bestAvg

 tempMinus = (tempFitness - 3)./noOfTx;

    if  tempPlus > fitAvg
        fitness = tempFitness;
        bestTX = noOfTx;
    %    bestAvg = tempAvgPerTxFitness;
        lossdB = tempLossdB;
        bestCoords = tableA;
        BestTempPlus = tempPlus;
    end
end % t1 GA example
disp("final solution " + fitness + "      number of TX " + bestTX + "         BesttempPlus = " + BestTempPlus);
    
%% Applying color map    
% smallFSPLImage = mesh map values from transmission point
smallFSPLImage = (reshape(lossdB,meshNode.vert.num, meshNode.horz.num));
% FSPLFullImage -db level for value of singal on the map. 
FSPLFullImage = (imresize(smallFSPLImage,[size(floorPlan,1),size(floorPlan,2)],'method','cubic'));
% Converts to a num 0.0-1.0 high is the strongest signal
FSPLFullImage = mat2gray(FSPLFullImage);
figure('Name','Path loss method ');
z = imoverlay(FSPLFullImage,~originalFloorPlan,[0,0,0]);
imshow(rgb2gray(z))
colormap(gca,'jet');


for i = 1:7
    colorbarLabels(i) = min(lossdB) + i .* ((max(lossdB)-min(lossdB))./7);
end    
colorbar('YTickLabel',num2str(int32(colorbarLabels')));
% text(Txc,Txr,'belh2','Color','Black','FontSize',12);
text(bestCoords(:,1),bestCoords(:,2),'Tx','Color','Black','FontSize',12);
title('Multi-Wall Path Loss Model (dB)');

%%%%%%%%%%%%%%%%5  REFERENCES  %%%%%%%%%%
% http://uk.mathworks.com/matlabcentral/fileexchange/28190-bresenham-optimized-for-matlab/content/bresenham.m

