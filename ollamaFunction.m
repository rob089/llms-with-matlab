classdef ollamaFunction
%ollamaFunction   Define a function
%
%   FUNC = ollamaFunction(NAME, DESCRIPTION) creates an Ollama function
%   object with the specified name and description.
%
%   ollamaFunction Functions:
%       ollamaFunction - Define a function.
%       addParameter   - Add parameter to the function.
%
%   ollamaFunction Properties:
%       FunctionName   - Name of the function.
%       Description    - Description of the function.
%       Parameters     - Parameters of function.
%
%   Example:
%     % Create an Ollama function object
%     func = ollamaFunction("editDistance", "Find edit distance between two strings or documents");
%
%     % Add two parameters with type and description
%     func = addParameter(func, "str1", type="string", description="Source string.");
%     func = addParameter(func, "str2", type="string", description="Target string.");

% Created 2024 R. Schregle
% Originated of openAIFunction with Copyright 2023 The MathWorks, Inc.
    
    properties
        Parameters = struct()
    end

    properties(SetAccess=private)
        %FUNCTIONNAME   Name of the function.
        FunctionName

        %DESCRIPTION   Description of the function.
        Description

        %PARAMETERS   Parameters of function.
        
    end

    methods
        function this = ollamaFunction(name, description)
            arguments
                name (1,1) {mustBeNonzeroLengthText}
                description {llms.utils.mustBeTextOrEmpty} = []
            end

            this.FunctionName = name;
            this.Description = description;
        end

        function this = addParameter(this, parameterName, propertyName, propertyValue, nvp)
            %addParameter   Add parameter to the function
            %
            %   FCN = addParameter(FCN,paramName,propName1,value1, ..., propNameN,valueN)
            %   adds the specified parameter and corresponding property names and values to the
            %   function signature. The property names must be 
            %   "type", "description", or "enum".
            %   The values depend on the property name:
            %   - Values corresponding to "type" must be any combination of "string",
            %   "number", "integer", "object", "array", "boolean", "null".
            %   - Values corresponding to "description" must be a string scalar.
            %   - Value corresponging to "enum" must be string vectors.
            %
            %   FCN = addParameter(__,RequiredParameter=TF), specifies
            %   if the parameter is a required parameter.
            %
            %   FCN = addParameter(__,type="array", itemsType="number", minItems=X, maxItems=X), 
            %   specifies the size of the 1D-array.
            %
            %   Example:
            %   % Create an Ollama function object
            %   f = ollamaFunction("editDistance", "Find edit distance between two strings or documents");
            %
            %   % Add two parameters with type and description
            %   f = addParameter(f,"str1","type","string","description","Source string.");
            %   f = addParameter(f,"str2","type","string" ,"description","Target string.");


            arguments
                this (1,1) ollamaFunction
                parameterName (1,1) {mustBeNonzeroLengthText, mustBeValidVariableName}
            end
            arguments(Repeating)
                propertyName (1,1) {mustBeNonzeroLengthText, mustBeMember(propertyName, {'type', 'enum', 'description'})}
                propertyValue (1,:) {mustBeNonzeroLengthText, validatePropertyValue(propertyValue, propertyName)}
            end
            arguments
                nvp.RequiredParameter (1,1) logical = true
                nvp.itemsType         (1,1) {mustBeMember(nvp.itemsType, {'number', 'integer', 'boolean'})} = "number"
                nvp.minItems          (1,1) uint32 = 3
                nvp.maxItems          (1,1) uint32 = 3
            end

            if isfield(this.Parameters,parameterName)
                error("llms:parameterMustBeUnique", ...
                    llms.utils.errorMessageCatalog.getMessage("llms:parameterMustBeUnique", parameterName));
            end

            properties = struct();

            % Properties are optional
            if ~isempty(propertyName)
                for i=1:length(propertyName)
                    properties.(propertyName{i}) = propertyValue{i};

                end
            end

            % Check if array
            if isfield(properties, "type") && properties.type == "array"
                % At this time, only 1D-arrays can be created
                properties.items = struct("type", string(nvp.itemsType));
                properties.minItems = nvp.minItems;
                properties.maxItems = nvp.maxItems;
            end

            this.Parameters.(parameterName) = properties;
            this.Parameters.(parameterName).required = nvp.RequiredParameter;
        end
    end

    methods(Hidden)
        function funStruct = encodeStruct(this)
            %encodeStruct   Encode the function object as a struct

            funStruct = struct();
            funStruct.name = this.FunctionName;

            if ~isempty(this.Description)
                funStruct.description = this.Description;
            end

            funStruct.parameters = struct();

            % The API requires type="object"
            funStruct.parameters.type = "object";

            funStruct.parameters.properties = struct();
            
            requiredArguments = [];
            parameterNames = string(fieldnames(this.Parameters));
            for i=1:length(parameterNames)
                parameterStruct = this.Parameters.(parameterNames(i));

                if parameterStruct.required
                    requiredArguments = [requiredArguments,parameterNames(i)]; %#ok
                end

                % "required" should not be a property when sending to the api
                parameterStruct = rmfield(parameterStruct,"required");

                % "array" need "items"
                % if isfield(parameterStruct, "type") && parameterStruct.type == "array"
                %     parameterStruct.items = struct();
                %     parameterStruct.items.type
                % end

                % enum needs to be encoded as array
                if isfield(parameterStruct, "enum") && numel(parameterStruct.enum)==1
                    parameterStruct.enum = {parameterStruct.enum};
                end

                funStruct.parameters.properties.(parameterNames(i)) = parameterStruct;
            end

            % Only create the "required" field if there are required arguments
            if ~isempty(requiredArguments)
                funStruct.parameters.required = requiredArguments;
                if numel(requiredArguments)==1
                    % This will force jsonencode to see "required" as an array
                    funStruct.parameters.required = {funStruct.parameters.required};
                end           
            end
        end
    end
end

function mustBeValidVariableName(value)
if ~isvarname(value)
    error("llms:mustBeVarName", llms.utils.errorMessageCatalog.getMessage("llms:mustBeVarName"));
end
end

function validatePropertyValue(value,name)
switch(name)
    case "type"
        validatePropertyType(value);
    case "description"
        validatePropertyDescription(value);
    case "enum"
        validatePropertyEnum(value);
end
end

function validatePropertyType(value)
validValues = ["string", "number", "integer", "object", "array", "boolean", "null"];
mustBeMember(value, validValues);
end

function validatePropertyDescription(value)
mustBeTextScalar(value) 
end

function validatePropertyEnum(value)
if ~llms.utils.isUnique(value)
    error("llms:mustBeUnique", llms.utils.errorMessageCatalog.getMessage("llms:mustBeUnique"));
end
end