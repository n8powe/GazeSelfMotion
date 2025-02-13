function CreateTrainingDataFromEXRData()
    clear all;
    close all;
    %% If false, this will run divergence instead. 
    runCurl = true;
    visualizeCurl = false;
    
    %emptyData = {'Trial', 'Environment', 'Condition', 'EnvironmentCondition',  'Curl', 'CenterCurl', 'Divergence', 'CenterDivergence'}
    
    %videoFolderPath = 'abbVids/';
    
    %videoList = dir(fullfile(videoFolderPath, "*.mp4"));

    %FixationFilePath = 'gazeRecording/abb/gazeframedata.csv';
    
%fixationData = readtable(FixationFilePath);
    %fixationFrames = fixationData.frameidx;

    useFixationData = false;

    %% Add divergence to this analysis. DOne

    centerSize = 15;
    bigCenterSize = 15;

    lastFrame = zeros(1080,1920,3);
    prevTrial = NaN;

    ofSampleRate = 15;

    verticalFOV=89;
    horizontalFOV = 120;

    ofHeight = size(lastFrame, 1)/ofSampleRate;%72;
    ofWidth = size(lastFrame, 2)/ofSampleRate;%128;

    horizontalDegPerPixel = ofWidth/horizontalFOV;
    verticalDegPerPixel = ofHeight/verticalFOV;

    verticalWindowFOV = verticalDegPerPixel*centerSize*2
    horizontalWindowFOV = horizontalDegPerPixel*centerSize*2
    
    

    subject_id_list = ["nvp","nvp7","nvp8", "nvp10", "nvp9", "yjo2"];%, "nvp4", "nvp3", "nvp2", "nvp"];

    num = 1;
    %mkdir("TrainingLabels")
    mkdir("TrainingData2")
    for sub_id=subject_id_list
        subject_id = sub_id;
        velocityTable = {'ImageName', 'dx', 'dy', 'dz', 'rx', 'ry', 'rz'};
        mkdir(strcat('D://TrainingData/', subject_id));
        mkdir(strcat('D://TrainingLabels/', subject_id))
        if runCurl
    
            dataPath = strcat('vrWalkingdata/frameRecording/', sub_id, '/');
            allRawDataPath = strcat('vrWalkingdata/VRWalkingRaw/',sub_id,'/data.csv');
            fixationData = strcat('vrWalkingdata/fixationRecording/',sub_id,'/gazeframedata.csv');

            %fixData = readtable(fixationData);
        
            image = dir(fullfile(dataPath, "*.png"));
    
            emptyData = {'Subject', 'Trial', 'Environment', 'Condition', 'EnvironmentCondition',  'Curl', 'CenterCurl', 'BigCenterCurl', 'Divergence', 'CenterDivergence', 'BigCenterDiv', 'Frame', 'FrameProp', 'Fixation', 'Ground', 'LowerCurl', 'UpperCurl', 'FrameNumber'};
    
    
        else
        
        
            dataPath = '/Volumes/Seagate Portable Drive/testOutput/Divergence/';
        
            image = dir(fullfile(dataPath, "*.png"));
    
            emptyData = {'Trial', 'Environment', 'Condition', 'EnvironmentCondition',  'Divergence', 'CenterDiv'};
    
        end
        
        frameNumberTrial = 1;

        previousSubjectName = 'Null';
        previousTrial = 'NaN';
        previousTrialString = 'NaN';
        previousFrame = 0;
        previousImage = lastFrame;
        firstFrame = 1;%findFirstFrameForSubjectData(image, subject_id, dataPath);
        rawDataPath = allRawDataPath;%findRawDataPath(sub_id, allRawDataPath);

        rawData = readtable(rawDataPath);
        rotatedList = [];
        for t = unique(rawData.trialNum)'
            trialData = rawData(rawData.trialNum==t, :);
            trialData = rotateCamera(trialData);
            rotatedList = [rotatedList ; trialData];
        end
        rawData2 = rotatedList;

    
        for i=firstFrame:length(image)
            currImageName = strcat(dataPath, image(i).name);
    
            currImageNameSplit = split(currImageName, '/');
    
            currImageName2 = currImageNameSplit(4);
            
            currImageNameSplit = split(currImageName2, '_');
            currTrial = currImageNameSplit(2);
            splitTrialNum = split(currTrial, 'l');
            currTrialNumber = splitTrialNum(2);
            currTrialString = currTrialNumber

            if mod(str2double(currTrialNumber)+1, 2)==0
                modifier = 1;
            else
                modifier = -1;
            end
            
            
            currTrialNumber = str2double(currTrialNumber{1});
    
            frameName = currImageNameSplit(3);
            frameNameSplitAtE = split(frameName, 'e');
            frameNameSplitAtPeriod = split(frameNameSplitAtE(2), '.');
            frameNumber = str2double(frameNameSplitAtPeriod(1))+1;
    
            subjectName = currImageNameSplit(1);
    
            currSubjectName = subjectName;
            trialData = rawData(rawData.trialNum==currTrialNumber, :);
            filt_avg = ones(1,4)/4;
            trialData.Camera_PosX = conv(trialData.Camera_PosX, filt_avg, 'same');
            trialData.Camera_PosY = conv(trialData.Camera_PosY, filt_avg, 'same');
            trialData.Camera_PosZ = conv(trialData.Camera_PosZ, filt_avg, 'same');

            trialData.Camera_RotX = conv(trialData.Camera_RotX, filt_avg, 'same');
            trialData.Camera_RotY = conv(trialData.Camera_RotY, filt_avg, 'same');
            trialData.Camera_RotZ = conv(trialData.Camera_RotZ, filt_avg, 'same');
            
            trialData.GazeTarget_PosX = conv(trialData.GazeTarget_PosX, filt_avg, 'same');
            trialData.GazeTarget_PosY = conv(trialData.GazeTarget_PosY, filt_avg, 'same');
            trialData.GazeTarget_PosZ = conv(trialData.GazeTarget_PosZ, filt_avg, 'same');

            condition = trialData.condition(1)
            
            
            if ~strcmp(currSubjectName, previousSubjectName)
                %rawDataPath = findRawDataPath(subjectName{1}, allRawDataPath);
        
                rawDdfdfdfata = 0;%readtable(rawDataPath);



                %if strcmp(condition, "Control")
                %    "Saving image"
                %else
                %    break
                %end
    
                %fixationData = readtable(strcat('prismoutTest/fixationRecording/',subjectName{1},'/gazeframedata.csv'));
            else
                'NewSubject';
            end
    
            previousSubjectName = currSubjectName;
    
            fixation_bool = 1;%sum(fixationData.frameidx==frameNumber);

            
            
            if fixation_bool==1 %&& strcmp(condition, 'Control')
                if ~strcmp(previousTrialString, currTrialString)
                    mkdir(strcat('ResnetTraining3/', subject_id, '/', currTrialString))
                    %mkdir(strcat('TrainingData/', subject_id, '/', currTrialString))
                    
                    if frameNumberTrial > 2
                        dataTable = cell2table(cellstr(velocityTable(2:end,:)), 'VariableNames',velocityTable(1,:));
                        writetable(dataTable, strcat('ResnetTraining3/', subject_id, '/', previousTrialString, '/','labels.csv'))
                    end
                    velocityTable = {'ImageName', 'dx', 'dy', 'dz', 'rx', 'ry', 'rz', 'gdx','gdy','gdz', 'SaccadeFlag'};
                end
                firstFixationFrameBool = (frameNumber-1)~=previousFrame; 
                if currTrialNumber > prevTrial
                    frameNumberTrial = 1;
                end
                
                if useFixationData
                    if any(fixationFrames == frameNumber)
                        fixationBool = 1;
                    else
                        fixationBool = 0;
                    end
                else
                   fixationBool = NaN;
                end

                groundBool = findTrialMaxGazeDistance(frameNumberTrial, currTrialNumber, rawData);
                prevFrameData = rawData(frameNumber, :);
                if frameNumber + 1 > size(rawData,1)
                    break
                end
                currFrameData = rawData(frameNumber+1, :);
                dt = 1.0/90.0;
                
                positions = [prevFrameData.Camera_PosX(1), prevFrameData.Camera_PosZ(1), prevFrameData.Camera_PosY(1);
                    currFrameData.Camera_PosX(1), currFrameData.Camera_PosZ(1), currFrameData.Camera_PosY(1)];

                orientations_euler = [prevFrameData.Camera_RotX(1), prevFrameData.Camera_RotY(1), prevFrameData.Camera_RotZ(1);
                    currFrameData.Camera_RotX(1), currFrameData.Camera_RotY(1), currFrameData.Camera_RotZ(1)];
                
                %vels = compute_velocity_in_head_frame(positions, orientations_euler, [dt, dt], 'xzy');
                local_velocity = compute_velocity_in_head_frame(positions, orientations_euler, [dt, dt], 'xzy');%calculate_local_velocity(positions, orientations_euler, [dt, dt]);
                agns = compute_angular_velocity(orientations_euler, dt, 'zyx');

                fixationB = 0;%abs(ismember(frameNumber-1, fixData.frameidx)-1);
                % Plot velocity vectors along the trajectory
                
                % Current position of the head
                pos = positions(1, :);
                
                dx = local_velocity(1)*1;%abs(currFrameData.Camera_PosX(1) - prevFrameData.Camera_PosX(1))/dt;
                dy = local_velocity(2);%(currFrameData.Camera_PosY(1) - prevFrameData.Camera_PosY(1))/dt;
                dz = local_velocity(3)*1;%modifier*(currFrameData.Camera_PosZ(1) - prevFrameData.Camera_PosZ(1))/dt;
                %rx = agns(1);%(currFrameData.Camera_RotX(1) - prevFrameData.Camera_RotX(1))/dt;
                %ry = agns(2);%(currFrameData.Camera_RotY(1) - prevFrameData.Camera_RotY(1))/dt;
                %rz = agns(3);%(currFrameData.Camera_RotZ(1) - prevFrameData.Camera_RotZ(1))/dt;

                gaze_positions = [prevFrameData.GazeTarget_PosX(1), prevFrameData.GazeTarget_PosY(1), prevFrameData.GazeTarget_PosZ(1);
                    currFrameData.GazeTarget_PosX(1), currFrameData.GazeTarget_PosY(1), currFrameData.GazeTarget_PosZ(1)];

                angular_velocities = computeAngularVelocityGaze(gaze_positions, positions, [dt, dt]);

                % % Velocity vector at this position
                vel = [dx, dy, dz];
                gdx = angular_velocities(1);
                gdy = angular_velocities(2);
                gdz = angular_velocities(3);
                % if frameNumber>10
                %     subplot(1,4,1);
                %     plot([1:11],rawData.Camera_PosX((frameNumber-5):(frameNumber+5)), 'ro')
                %     hold on
                %     plot([1:11], rawData.Camera_PosY((frameNumber-5):(frameNumber+5)), 'bo')
                %     hold off;
                %     hold on;
                %     plot([1:11], rawData.Camera_PosZ((frameNumber-5):(frameNumber+5))+180, 'go')
                %     hold off
                %     ylim([0,2])
                % end
                % 
                % if frameNumber>10
                %     subplot(1,4,2);
                %     plot([1:11],rawData.Camera_RotX((frameNumber-5):(frameNumber+5)), 'ro')
                %     hold on;
                %     plot([1:11], rawData.Camera_RotY((frameNumber-5):(frameNumber+5)), 'bo')
                %     hold off;
                %     hold on;
                %     plot([1:11], rawData.Camera_RotZ((frameNumber-5):(frameNumber+5)), 'go')
                %     hold off
                %     ylim([-5,365])
                % end
                % 
                % subplot(1,4,3);
                % plot(1, vel(1), 'ro')
                % hold on;
                % plot(1, vel(3), 'bo')
                % hold off;
                % hold on;
                % plot(1, vel(2), 'go')
                % hold off
                % ylim([-1,1])
                % % 
                % % Scale velocity vector for visualization (optional)
                % scale_factor = 1.5;
                % vel = vel * scale_factor;
                % subplot(2,2,1);
                % plot3(positions(1, 1), positions(1, 2), positions(1, 3), 'bo-', 'LineWidth', 1.5, 'MarkerSize', 5);
                % legend('Head Trajectory');
                % hold on;
                % % Plot velocity vector as a quiver (arrow)
                % quiver3(pos(1), pos(2), pos(3), vel(1), vel(2), vel(3), 0, 'r', 'LineWidth', 1.5, 'MaxHeadSize', 0.5);
                % hold off;
                % xlim([-8,8]);
                % ylim([-8,8]);
                % zlim([-8,8]);
                % xlabel("X")
                % ylabel("Y")
                % zlabel("Z")
                % view(0, 90);
                % 
                % 
                % subplot(2,2,3);
                % plot3(positions(1, 1), positions(1, 2), positions(1, 3), 'bo-', 'LineWidth', 1.5, 'MarkerSize', 5);
                % legend('Head Trajectory');
                % hold on;
                % % Plot velocity vector as a quiver (arrow)
                % quiver3(pos(1), pos(2), pos(3), vel(1), vel(2), vel(3), 0, 'r', 'LineWidth', 1.5, 'MaxHeadSize', 0.5);
                % hold off;
                % xlim([-8,8]);
                % ylim([-8,8]);
                % zlim([-8,8]);
                % xlabel("X")
                % ylabel("Y")
                % zlabel("Z")
                % view(90, 0);
                % 
                % subplot(2,2,4);
                % plot3(positions(1, 1), positions(1, 2), positions(1, 3), 'bo-', 'LineWidth', 1.5, 'MarkerSize', 5);
                % legend('Head Trajectory');
                % hold on;
                % % Plot velocity vector as a quiver (arrow)
                % quiver3(pos(1), pos(2), pos(3), vel(1), vel(2), vel(3), 0, 'r', 'LineWidth', 1.5, 'MaxHeadSize', 0.5);
                % hold off;
                % xlim([-8,8]);
                % ylim([-8,8]);
                % zlim([-8,8]);
                % xlabel("X")
                % ylabel("Y")
                % zlabel("Z")
                % view(0, 0);
                % drawnow;
                % 
                % 
                % dx = vels(1);%abs(currFrameData.Camera_PosX(1) - prevFrameData.Camera_PosX(1))/dt;
                % dy = vels(2);%(currFrameData.Camera_PosY(1) - prevFrameData.Camera_PosY(1))/dt;
                % dz = vels(3);%modifier*(currFrameData.Camera_PosZ(1) - prevFrameData.Camera_PosZ(1))/dt;
                rx = agns(1);%(currFrameData.Camera_RotX(1) - prevFrameData.Camera_RotX(1))/dt;
                ry = agns(2);%(currFrameData.Camera_RotY(1) - prevFrameData.Camera_RotY(1))/dt;
                rz = agns(3);%(currFrameData.Camera_RotZ(1) - prevFrameData.Camera_RotZ(1))/dt;

                frameLabels = [currImageName2, dx, dy, dz, rx, ry, rz, gdx, gdy, gdz, fixationB];
                
                velocityTable = [velocityTable; frameLabels];

                if mod(num, 1)==0

                    dataTable = cell2table(cellstr(velocityTable(2:end,:)), 'VariableNames',velocityTable(1,:));
                    writetable(dataTable, strcat('ResnetTraining3/', subject_id, '/', currTrialString, '/','labels.csv'))
                end

                
        
            %     [ii, a] = exrread(currImageName);
            %     rg = squeeze(ii(:,:,1:2));
            %     gray = rg(:,:,2);
            %     red = gray~=rg(:,:,1);
            % 
            %     rgb = gray;
            % 
            % %     rgb(red) = 1;
            %     rgb(:,:,1) = squeeze(rg(:,:,1));
            %     rgb(:,:,2) = gray;
            %     rgb(:,:,3) = gray;
                rgb = imread(currImageName);
                rgb = imresize(rgb, [64, 64]);
                % 
                % 
                % subplot(1,4,4)
                imwrite(rgb, strcat('ResnetTraining3/', subject_id, '/', currTrialString, '/', currImageName2, '.jpeg'));
                % imshow(rgb)
                % hold off;
                % drawnow;
                % motion.x = -ii(:,:,3);
                % motion.y = a;
                % 
                % if(length(lastFrame) > 1)
                %     thisFrame = lastFrame(:,:,1)~=rgb(:,:,1);
                %     motion.x = motion.x.*thisFrame;
                %     motion.y = motion.y.*thisFrame;
                %     thisFrame = lastFrame;
                % end
                % 
                % 
                % ii = rgb2gray(ii);
                % %opflow = opticalFlow(motion.x(1:ofSampleRate:end, 1:ofSampleRate:end),motion.y(1:ofSampleRate:end, 1:ofSampleRate:end));
                % %[x,y] = meshgrid(1:size(opflow.Vx,2),1:size(opflow.Vx,1));
                % 
                % if previousTrial~=currTrialNumber
                %     opticalFlowFB = opticalFlowFarneback();
                %     flowFB = estimateFlow(opticalFlowFB, ii);
                % else
                %     flowFB = estimateFlow(opticalFlowFB, ii);
                % end
                % 
                % opflow = flowFB;
                % [x,y] = meshgrid(1:size(opflow.Vx,2),1:size(opflow.Vx,1));
                % div = divergence(x(1:ofSampleRate:end, 1:ofSampleRate:end),y(1:ofSampleRate:end, 1:ofSampleRate:end),opflow.Vx(1:ofSampleRate:end, 1:ofSampleRate:end),opflow.Vy(1:ofSampleRate:end, 1:ofSampleRate:end));
                % [curlz, cav] = curl(x(1:ofSampleRate:end, 1:ofSampleRate:end),y(1:ofSampleRate:end, 1:ofSampleRate:end),opflow.Vx(1:ofSampleRate:end, 1:ofSampleRate:end),opflow.Vy(1:ofSampleRate:end, 1:ofSampleRate:end));
                % 
                % horOFShape = size(curlz, 2);
                % 
                % currImage = cav;
                % 
                % 
                % previousTrial = currTrialNumber;
                % 
                % H = size(currImage, 2);
                % W = size(currImage, 1);
                % 
                % halfH = H/2;
                % halfW = W/2;
                % 
                % upperH = halfH+centerSize;
                % lowerH = halfH-centerSize;
                % 
                % upperW = halfW+centerSize;
                % lowerW = halfW-centerSize;
                % 
                % bigupperH = halfH+bigCenterSize;
                % biglowerH = halfH-bigCenterSize;
                % 
                % bigupperW = halfW+bigCenterSize;
                % biglowerW = halfW-bigCenterSize;
                % 
                % % if ~visualizeCurl
                % %     imagesc(cav);
                % %     colorbar;
                % %     clim([-0.25 0.25])
                % %     pos = [lowerH, lowerW, centerSize*2, centerSize*2];
                % %     rectangle('Position',pos,'EdgeColor','r')
                % %     drawnow;
                % % end
                % 
                % [environment, condition] = findEnvironmentAndCondition(currTrialNumber, rawData);
                % 
                % environmentCondition = strcat(environment, condition);
                % 
                % %currImage = 255 - currImage;
                % %currImage(:,:,3) = -currImage(:,:,3);
                % %currImage(:,:,1) = NaN;
                % %imagesc(cav*10000);
                % %drawnow;
                % 
                % 
                % currCurl = mean( cav(:));
                % 
                % centerImage = currImage(lowerW:upperW, lowerH:upperH, :);
                % bigCenterImage = currImage(biglowerW:bigupperW, biglowerH:bigupperH);
                % lowerImage = currImage(:, 1:halfH);
                % upperImage = currImage(:, halfH:end);
                % bigCenterCurl = mean(bigCenterImage(:));
                % centerCurl = mean(centerImage(:));
                % lowerCurl = mean(lowerImage(:));
                % upperCurl = mean(upperImage(:));
                % 
                % currDiv = mean(div(:));
                % 
                % centerDivImage = div(lowerW:upperW, lowerH:upperH);
                % centerDiv = mean(centerDivImage(:));
                % bigCenterDivImage = div(biglowerW:bigupperW, biglowerH:bigupperH);
                % bigcenterDiv = mean(bigCenterDivImage(:));
                % 
                % 
                % if ~strcmp(currSubjectName, previousSubjectName) && ~strcmp('Null', previousSubjectName)
                %     dataTable = cell2table(emptyData(2:end,:), 'VariableNames',emptyData(1,:));
                % 
                %    propVector = findFrameProportion(dataTable);
                % 
                %    dataTable.FrameProp = propVector;
                % 
                % 
                % 
                % 
                %    writetable(dataTable, strcat(previousSubjectName{1}, 'allavgcurldata.csv'))
                %    emptyData = [];
                % 
                % end
                % 
                % previousSubjectName = currSubjectName;
                % 
                % currData = [subjectName, currTrialNumber, environment, condition, environmentCondition, currCurl, centerCurl, bigCenterCurl, currDiv, centerDiv, bigcenterDiv, frameNumberTrial, 0, fixationBool, groundBool, lowerCurl, upperCurl, frameNumber];
                % 
                % if firstFixationFrameBool~=1
                %     emptyData = [emptyData; currData];
                % else
                %     "skipping first fixation frame."
                % end
                % 
                %lastFrame = rgb;
                 
        
                size(emptyData)
        
                prevTrial = currTrialNumber;

                previousFrame = frameNumber;
        
                frameNumberTrial = frameNumberTrial + 1

                num = num + 1;

                previousTrialString = currTrialString;
                previousTrial = currTrialNumber;
    
            else
    
                'Not fixation. Skipping.'
    
            end
    
    
        end
    
       %dataTable = cell2table(cellstr(emptyData(2:end,:)), 'VariableNames',emptyData(1,:));
    
       %propVector = findFrameProportion(dataTable);
    
       %dataTable.FrameProp = propVector;
    
        
        %strcat(subject_id, 'allavgcurldata.csv')
        %if runCurl
        %    writetable(dataTable, strcat(subject_id, 'allavgcurldatatest.csv'))    
        %else
        %    writetable(dataTable, strcat(subject_id, 'allavgdivergencedata.csv'))
        %end
        dataTable = cell2table(cellstr(velocityTable(2:end,:)), 'VariableNames',velocityTable(1,:));
        writetable(dataTable, strcat('TrainingResnet/',subjectName,'labels.csv'))
    end

    %(centerSize/horOFShape)*90
    %(bigCenterSize/horOFShape)*90
    %dataTable = cell2table(cellstr(velocityTable(2:end,:)), 'VariableNames',velocityTable(1,:));
    %writetable(dataTable, strcat('labels.csv'))

end

function df = detect_saccades_from_gaze(df, gaze_columns, time_column, threshold_rad_per_sec)
    % Detects saccades based on angular velocity of 3D gaze location.
    %
    % Parameters:
    %   df: Table containing gaze data and timestamps.
    %   gaze_columns: Cell array of column names for {GazeX, GazeY, GazeZ}.
    %   time_column: Column name for the timestamps.
    %   threshold_rad_per_sec: Threshold for angular velocity (in radians per second).
    %
    % Returns:
    %   df: Table with an added 'Saccade' column (logical).
    
    % Extract gaze vectors and timestamps
    gaze_vectors = table2array(df(:, gaze_columns));
    time_deltas = [0; diff(table2array(df(:, time_column)))];  % Time differences in seconds
    
    % Normalize gaze vectors
    gaze_norms = sqrt(sum(gaze_vectors.^2, 2));  % Norm of each vector
    normalized_gaze = bsxfun(@rdivide, gaze_vectors, gaze_norms);  % Normalize gaze vectors
    
    % Initialize angular velocity
    angular_velocity = zeros(height(df), 1);
    
    % Compute angular velocity between consecutive frames
    for i = 2:height(df)
        dot_product = dot(normalized_gaze(i, :), normalized_gaze(i - 1, :));
        dot_product = max(-1.0, min(1.0, dot_product));  % Clamp to [-1, 1] to avoid numerical errors
        angle = acos(dot_product);  % Angle in radians
        angular_velocity(i) = angle / time_deltas(i);
    end
    
    % Mark saccades
    df.Saccade = angular_velocity > threshold_rad_per_sec;
end


function trialData = rotateCamera(trialData)
    trialNumber = trialData.trialNum(1);

    filterSize = 10;
    filter_ = ones(1, filterSize) / filterSize;
    
    IS_EVEN = ~mod(trialNumber,2);
    startPos = [trialData.Camera_PosX(1), trialData.Camera_PosY(1), trialData.Camera_PosZ(1)];
    endPos = [trialData.Camera_PosX(end), trialData.Camera_PosY(end), trialData.Camera_PosZ(end)];
    u = [0,1];
    v = (startPos - endPos);
    changeFromBeginningToEnd = v;
    d = norm(startPos-endPos);
    v = v(1:2:3);
    v = v/norm(v);
    CosTheta = max(min(dot(u,v)/(norm(u)*norm(v)),1),-1);
    theta = -real(acosd(CosTheta));
    RotationMatrixEven = [cosd(theta+180) -sind(theta+180); sind(theta+180) cosd(theta+180)];
    RotationMatrixOdd = [cosd(theta) -sind(theta); sind(theta) cosd(theta)];
    numFrames = length(trialData.trialNum);
    normTime = (1:numFrames)/numFrames;

    if IS_EVEN
        PosHead = [trialData.Camera_PosX, trialData.Camera_PosZ] * RotationMatrixEven;
        headX = PosHead(:,1);
        headY = PosHead(:,2);
        angHead = trialData.Camera_RotY - mean(trialData.Camera_RotY(1:10)) + 90;

        PosRightFoot = [trialData.RightFoot_PosX, trialData.RightFoot_PosZ] * RotationMatrixEven;
        RightFootX = PosRightFoot(:,1);
        RightFootY = PosRightFoot(:,2);

        PosLeftFoot = [trialData.LeftFoot_PosX, trialData.LeftFoot_PosZ] * RotationMatrixEven;
        LeftFootX = PosLeftFoot(:,1);
        LeftFootY = PosLeftFoot(:,2);
        
    else
        PosHead = [trialData.Camera_PosX, trialData.Camera_PosZ] * RotationMatrixOdd;
        headX = PosHead(:,1);
        headY = PosHead(:,2);
        angHead = (trialData.Camera_RotY- mean(trialData.Camera_RotY(1:10)))+90;

        PosRightFoot = [trialData.RightFoot_PosX, trialData.RightFoot_PosZ] * RotationMatrixOdd;
        RightFootX = PosRightFoot(:,1);
        RightFootY = PosRightFoot(:,2);

        PosLeftFoot = [trialData.LeftFoot_PosX, trialData.LeftFoot_PosZ] * RotationMatrixOdd;
        LeftFootX = PosLeftFoot(:,1);
        LeftFootY = PosLeftFoot(:,2);
    end
    trialData.Camera_PosX = headX - headX(1);
    trialData.Camera_PosZ = headY - headY(1);
    
    %trialData.LeftFoot_PosX = LeftFootX - LeftFootX(1);
    %trialData.LeftFoot_PosZ = LeftFootY - LeftFootY(1);
    %trialData.RightFoot_PosX = RightFootX - RightFootX(1);
    %trialData.RightFoot_PosZ = RightFootY - RightFootY(1);
end

function local_velocity = calculate_local_velocity(positions, euler_angles, dt)
    % calculate_local_velocity calculates the local frame velocity of a tracked point
    % given position, yaw angle (Euler angles), and dt (time interval).
    %
    % Inputs:
    %   positions     - Nx3 matrix of positions [x, y, z] at each timestamp
    %   euler_angles  - Nx3 matrix of Euler angles [pitch, yaw, roll] in degrees
    %   dt            - Pre-calculated time difference (scalar or vector)
    %
    % Output:
    %   local_velocity - (N-1)x3 matrix of velocity vectors in the local frame

    % Initialize the local velocity matrix
    local_velocity = zeros(size(positions, 1) - 1, 3);
    
    % Loop over frames to calculate velocity in the local frame
    for i = 1:size(positions, 1) - 1
        % Calculate difference in position
        delta_position = positions(i+1, :) - positions(i, :);
        
        % Calculate global velocity
        global_velocity = delta_position / dt(i);
        
        % Extract the yaw angle and convert to radians
        yaw = deg2rad(euler_angles(i, 3)); % Assuming yaw is the rotation around the vertical (Z) axis
        
        % Create 2D rotation matrix for yaw angle (rotation in the X-Y plane)
        R_yaw = [cos(yaw), -sin(yaw); sin(yaw), cos(yaw)];
        
        % Rotate only the X and Y components of the global velocity
        xy_velocity = R_yaw * global_velocity(1:2)'; % Apply rotation to X-Y components
        
        % Combine rotated X-Y velocity with unchanged Z velocity
        local_velocity(i, :) = [xy_velocity', global_velocity(3)];
    end
end

% function local_velocity = calculate_local_velocity(positions, euler_angles, timestamps)
%     % calculate_local_velocity calculates the local frame velocity of a tracked point
%     % given position, orientation (Euler angles), and timestamps.
%     %
%     % Inputs:
%     %   positions     - Nx3 matrix of positions [x, y, z] at each timestamp
%     %   euler_angles  - Nx3 matrix of Euler angles [roll, pitch, yaw] in degrees
%     %   timestamps    - Nx1 vector of timestamps in seconds
%     %
%     % Output:
%     %   local_velocity - (N-1)x3 matrix of velocity vectors in the local frame
% 
%     % Initialize the local velocity matrix
%     local_velocity = zeros(size(positions, 1) - 1, 3);
% 
%     % Loop over frames to calculate velocity in the local frame
%     for i = 1:size(positions, 1) - 1
%         % Calculate difference in position
%         delta_position = positions(i+1, :) - positions(i, :);
% 
%         % Calculate time difference
%         delta_t = timestamps(i);
% 
%         % Calculate global velocity
%         global_velocity = delta_position / delta_t;
% 
%         % Convert Euler angles to radians for MATLAB’s rotation functions
%         roll = deg2rad(euler_angles(i, 2));
%         pitch = deg2rad(euler_angles(i, 1));
%         yaw = deg2rad(euler_angles(i, 3));
% 
%         % Create rotation matrix from Euler angles (ZYX order: yaw-pitch-roll)
%         R = angle2dcm(yaw, pitch, roll, 'ZYX');
% 
%         % Adjust so that:
%         % - Forward is always along positive z-axis
%         % - Left is negative along the x-axis, and right is positive along x-axis
%         % - Up is positive along the y-axis, down is negative along y-axis
%         %local_velocity(i, :) = local_velocity_in_global_frame * [1, 0, 0; 0, 1, 0; 0, 0, 1];
% 
%         % Transform global velocity to the local frame
%         local_velocity(i, :) = (R' * global_velocity')';
% 
%         %local_velocity(i, :) = local_velocity * [1, 0, 0; 0, 1, 0; 0, 0, 1];
%     end
% end

function head_velocities = compute_velocity_in_head_frame(positions, orientations_euler, time_stamps, euler_order)
    % Computes the velocity in the head's frame of reference given position data, 
    % Euler angles for orientation, and timestamps.
    %
    % positions - Nx3 matrix of 3D positions in the world frame
    % orientations_euler - Nx3 matrix of Euler angles (in radians) for orientation in the world frame
    % time_stamps - Nx1 vector of timestamps corresponding to each position
    % euler_order - String specifying the order of Euler rotations (e.g., 'xyz')
    %
    % Returns:
    % head_velocities - (N-1)x3 matrix of velocity vectors in the head frame of reference

    % Initialize head velocity matrix
    num_positions = size(positions, 1);
    head_velocities = zeros(num_positions - 1, 3);

    % Loop through each position to compute velocities in the head frame
    for i = 1:num_positions - 1
        % Calculate the world-frame velocity vector
        delta_position = positions(i + 1, :) - positions(i, :);
        delta_time = time_stamps(i);
        world_velocity = delta_position / delta_time;
        
        % Convert Euler angles to a rotation matrix
        rotation_matrix = eul2rotm(orientations_euler(i, :), euler_order);
        
        % Transform world velocity to head frame by applying the inverse rotation
        head_velocity = rotation_matrix' * world_velocity';  % Equivalent to R^-1 * v
        head_velocities(i, :) = head_velocity';
    end
end

function angular_velocities = computeAngularVelocityGaze(gaze_positions, eye_positions, time_intervals)
    % Compute angular velocity of the eye given moving gaze and eye positions in world coordinates.
    %
    % Parameters:
    % - gaze_positions: Nx3 matrix of gaze positions in 3D.
    % - eye_positions: Nx3 matrix of eye positions in 3D.
    % - time_intervals: (N-1)x1 vector of time differences between samples.
    %
    % Returns:
    % - angular_velocities: (N-1)x3 matrix containing angular velocities.

    % Calculate gaze vectors (normalized direction from eye to gaze point)
    gaze_vectors = gaze_positions - eye_positions;
    gaze_vectors = gaze_vectors ./ vecnorm(gaze_vectors, 2, 2); % Normalize rows to unit vectors

    num_intervals = size(gaze_vectors, 1) - 1;
    angular_velocities = zeros(num_intervals, 3);

    for i = 1:num_intervals
        % Current and next gaze vectors
        g_t = gaze_vectors(i, :);
        g_next = gaze_vectors(i + 1, :);

        % Time interval
        delta_t = time_intervals(i);

        % Compute derivative of gaze vector
        dg_dt = (g_next - g_t) / delta_t;

        % Compute angular velocity using cross product
        omega = cross(g_t, dg_dt);

        % Store angular velocity
        angular_velocities(i, :) = omega;
    end
end

function angular_velocity = compute_angular_velocity(euler_angles, time_stamps, euler_order)
    % Computes the angular velocity of the head in radians per second.
    %
    % euler_angles - Nx3 matrix of Euler angles (in degrees) for orientation in the world frame
    % time_stamps - Nx1 vector of timestamps
    % euler_order - String specifying the order of Euler rotations (e.g., 'XYZ')
    %
    % Returns:
    % angular_velocity - (N-1)x3 matrix of angular velocity vectors (radians per second)

    num_orientations = size(euler_angles, 1);
    angular_velocity = zeros(num_orientations - 1, 3);

    for i = 1:num_orientations - 1
        % Convert two consecutive Euler angles to quaternions
        q1 = eul2quat(euler_angles(i, :), euler_order);
        q2 = eul2quat(euler_angles(i + 1, :), euler_order);

        % Compute the quaternion difference
        q_diff = quatmultiply(q2, quatinv(q1));

        % Convert the quaternion difference to axis-angle representation
        axang = quat2axang(q_diff); % axang is a 1x4 array: [axis_x, axis_y, axis_z, angle]

        % Extract the axis (first 3 components) and angle (4th component)
        axis = axang(1:3);
        angle = axang(4);
        
        % Calculate the time difference
        delta_time = time_stamps(i);

        % Angular velocity vector (angle divided by time, multiplied by axis)
        angular_velocity(i, :) = (angle / delta_time) * axis;
    end
end


function [environment, condition] = findEnvironmentAndCondition(currTrialNumber, rawData)


    trialData = rawData(rawData.trialNum == currTrialNumber, :);

    condition = trialData.condition(1);
    condition = condition{1};
    environment = trialData.environment(1);
    environment = environment{1};



end

function propVector = findFrameProportion(table_)

    numTrials = [unique(table_.Trial)+1]';

    propVector = [];
    for i=numTrials
        
        trialTable = table_(table_.Trial==(i-1), :);

        trialProportionVector = trialTable.Frame/trialTable.Frame(end);

        propVector = [propVector; trialProportionVector];


    end

end

function groundBool = findTrialMaxGazeDistance(currFrame, currTrial, currRawData)

    currRawData = currRawData(currRawData.trialNum==currTrial,:);

    if currFrame > size(currRawData,1)
        currFrame = size(currRawData,1);
        currTrial
        'Why this wrong....'
    end

    

    endPositionX = currRawData.Camera_PosX(end); % Switched to absolute value because of change in direction. Distance should be the same. 
    endPositionZ = currRawData.Camera_PosZ(end);

    startPositionX = currRawData.Camera_PosX(1); % Switched to absolute value because of change in direction. Distance should be the same. 
    startPositionZ = currRawData.Camera_PosZ(1);

    currGazePosX = currRawData.GazeTarget_PosX(currFrame);
    currGazePosZ = currRawData.GazeTarget_PosZ(currFrame);

    if startPositionX < endPositionX
        if currGazePosX < (endPositionX)
            groundBool = 1;
        else
            groundBool = 0;
        end
    else
        if currGazePosX > (endPositionX)
            groundBool = 1;
        else
            groundBool = 0;
        end
    end


end

function rawDataPath = findRawDataPath(subjectName, allRawDataPath)
    rawDataPath = 0;

    
    d = dir(allRawDataPath);
    % remove all files (isdir property is 0)
    dfolders = d([d(:).isdir]) ;
    % remove '.' and '..' 
    allFolders = dfolders(~ismember({dfolders(:).name},{'.','..'}));
    
    allFolderNames = {allFolders.name};

    for name=allFolderNames
        currentFolder = name{1};

        configFile = strcat(allRawDataPath, currentFolder, '/config.csv');
        
        if ~strcmp(currentFolder(1), 's')
            configData = readtable(configFile).Properties.VariableNames;
    
            nameCheck = configData(2);
            nameCheck = nameCheck{1}; % Something wrong here. 
        else
            configData = readtable(configFile);
            nameCheck = configData.Subject(1);
            nameCheck = nameCheck{1};
            
        end

        if strcmp(subjectName, nameCheck)
            nameCheck
            rawDataPath = strcat(allRawDataPath, currentFolder, '/data.csv');
            break
        end

    end


end

function firstFrame = findFirstFrameForSubjectData(image, subjectName, dataPath)
    firstFrame = 'NaN';
    for i=1:length(image)
        currImageName = strcat(dataPath, image(i).name);

        currImageNameSplit = split(currImageName, '/');

        currImageName2 = currImageNameSplit(2);
        
        currImageNameSplit = split(currImageName2, '_');

        frameSubjectName = currImageNameSplit(1);

        if strcmp(frameSubjectName, subjectName)
            firstFrame = i;
            break
        end

    end


end