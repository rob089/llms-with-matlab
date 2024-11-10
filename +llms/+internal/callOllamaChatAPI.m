function [text, message, response] = callOllamaChatAPI(model, messages, functions, nvp)
% This function is undocumented and will change in a future release

%callOllamaChatAPI Calls the Ollama™ chat completions API.
%
%   MESSAGES and FUNCTIONS should be structs matching the json format
%   required by the Ollama Chat Completions API.
%   Ref: https://github.com/ollama/ollama/blob/main/docs/api.md
%
%   More details on the parameters: https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values
%
%   Example
%
%   model = "mistral";
%
%   % Create messages struct
%   messages = {struct("role", "system",...
%       "content", "You are a helpful assistant");
%       struct("role", "user", ...
%       "content", "What is the edit distance between hi and hello?")};
%
%   % Send a request
%   [text, message] = llms.internal.callOllamaChatAPI(model, messages)

%   Copyright 2023-2024 The MathWorks, Inc.
% Edited 2024 R. Schregle

arguments
    model
    messages
    functions
    nvp.ToolChoice
    nvp.Temperature
    nvp.TopP
    nvp.MinP
    nvp.TopK
    nvp.TailFreeSamplingZ
    nvp.StopSequences
    nvp.MaxNumTokens
    nvp.ResponseFormat
    nvp.Seed
    nvp.TimeOut
    nvp.StreamFun
    nvp.Endpoint
end

URL = nvp.Endpoint + "/api/chat";
if ~startsWith(URL,"http")
    URL = "http://" + URL;
end

% The JSON for StopSequences must have an array, and cannot say "stop": "foo".
% The easiest way to ensure that is to never pass in a scalar …
if isscalar(nvp.StopSequences)
    nvp.StopSequences = [nvp.StopSequences, nvp.StopSequences];
end

parameters = buildParametersCall(model, messages, functions, nvp);

[response, streamedText] = llms.internal.sendRequestWrapper(parameters,[],URL,nvp.TimeOut,nvp.StreamFun);

% If call errors, "choices" will not be part of response.Body.Data, instead
% we get response.Body.Data.error
if response.StatusCode=="OK"
    % Outputs the first generation
    if isempty(nvp.StreamFun)
        message = response.Body.Data.message;
    else
        message = struct("role", "assistant", ...
            "content", streamedText);
        %TODO 
    end
    if isfield(message, "tool_calls")
        text = "";
        for i = 1:numel(message.tool_calls)
            if ~isfield(message.tool_calls(i), "id")
                message.tool_calls(i).id = "call_" + string(response.Body.Data.created_at); % Ollama doesnt return ID but later checks expect this
            end
            if ~isfield(message.tool_calls(i), "type")
                message.tool_calls(i).type = "function"; % Ollama doesnt return type but later checks expect this
            end
        
            message.tool_calls(i).function.arguments = jsonencode(message.tool_calls(i).function.arguments); % Ollama returns struct already but OpenAI doesnt
        end
    else
        text = string(message.content);
    end
else
    text = "";
    message = struct();
end
end

function parameters = buildParametersCall(model, messages, functions, nvp)
% Builds a struct in the format that is expected by the API, combining
% MESSAGES, FUNCTIONS and parameters in NVP.

parameters = struct();
parameters.model = model;
parameters.messages = messages;

parameters.stream = ~isempty(nvp.StreamFun);

if ~isempty(functions)
    parameters.tools = functions;
end

if ~isempty(nvp.ToolChoice)
    parameters.tool_choice = nvp.ToolChoice;
end

options = struct;
if ~isempty(nvp.Seed)
    options.seed = nvp.Seed;
end

dict = mapNVPToParameters;

nvpOptions = keys(dict);
for opt = nvpOptions.'
    if isfield(nvp, opt) && ~isempty(nvp.(opt)) && ~isequaln(nvp.(opt),Inf)
        options.(dict(opt)) = nvp.(opt);
    end
end

parameters.options = options;
end

function dict = mapNVPToParameters()
dict = dictionary();
dict("Temperature") = "temperature";
dict("TopP") = "top_p";
dict("MinP") = "min_p";
dict("TopK") = "top_k";
dict("TailFreeSamplingZ") = "tfs_z";
dict("StopSequences") = "stop";
dict("MaxNumTokens") = "num_predict";
end
