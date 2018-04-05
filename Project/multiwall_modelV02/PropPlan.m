classdef PropPlan
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        floorMesh
        pathUnit
        thinFloorPlanBW
        floorPlanGray 
        wallAt
        TxGridCentre
        Rxr
        Rxc
    end
    
    
   methods
        function obj = add(obj,floorMesh, pathUnit,thinFloorPlanBW,floorPlanGray, wallAt, TxGridCentre)
            %SOLUTION Construct an instance of this class
            %   Detailed explanation goes here
            
            obj.floorMesh = floorMesh;
            obj.pathUnit = pathUnit;
            obj.thinFloorPlanBW = thinFloorPlanBW;
            obj.floorPlanGray = floorPlanGray;
            obj.wallAt = wallAt;
            obj.TxGridCentre = TxGridCentre;
            [obj.Rxr,obj.Rxc] = find(floorMesh == 1); % finding the nodes 
        end
   end
end

