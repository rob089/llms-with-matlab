classdef tollamaChat < matlab.unittest.TestCase
% Tests for ollamaChat

%   Copyright 2024 The MathWorks, Inc.

    properties(TestParameter)
        InvalidConstructorInput = iGetInvalidConstructorInput;
        InvalidGenerateInput = iGetInvalidGenerateInput;
        InvalidValuesSetters = iGetInvalidValuesSetters;
        ValidValuesSetters = iGetValidValuesSetters;
        StringInputs = struct('string',{"hi"},'char',{'hi'},'cellstr',{{'hi'}});
    end

    methods(Test)
        function simpleConstruction(testCase)
            bot = ollamaChat("mistral");
            testCase.verifyClass(bot,"ollamaChat");
        end

        function constructChatWithAllNVP(testCase)
            temperature = 0;
            topP = 1;
            stop = ["[END]", "."];
            systemPrompt = "This is a system prompt";
            timeout = 3;
            model = "mistral";
            chat = ollamaChat(model, systemPrompt, ...
                Temperature=temperature, TopP=topP, StopSequences=stop,...
                TimeOut=timeout);
            testCase.verifyEqual(chat.Temperature, temperature);
            testCase.verifyEqual(chat.TopP, topP);
            testCase.verifyEqual(chat.StopSequences, stop);
        end

        function doGenerate(testCase,StringInputs)
            chat = ollamaChat("mistral");
            response = testCase.verifyWarningFree(@() generate(chat,StringInputs));
            testCase.verifyClass(response,'string');
            testCase.verifyGreaterThan(strlength(response),0);
        end

        function doGenerateUsingSystemPrompt(testCase)
            chat = ollamaChat("mistral","You are a helpful assistant");
            response = testCase.verifyWarningFree(@() generate(chat,"Hi"));
            testCase.verifyClass(response,'string');
            testCase.verifyGreaterThan(strlength(response),0);
        end

        function generateOverridesProperties(testCase)
            import matlab.unittest.constraints.EndsWithSubstring
            chat = ollamaChat("mistral");
            text = generate(chat, "Please count from 1 to 10.", Temperature = 0, StopSequences = "4");
            testCase.verifyThat(text, EndsWithSubstring("3, "));
        end

        function extremeTopK(testCase)
            %% This should work, and it does on some computers. On others, Ollama
            %% receives the parameter, but either Ollama or llama.cpp fails to
            %% honor it correctly.
            testCase.assumeTrue(false,"disabled due to Ollama/llama.cpp not honoring parameter reliably");

            % setting top-k to k=1 leaves no random choice,
            % so we expect to get a fixed response.
            chat = ollamaChat("mistral",TopK=1);
            prompt = "Top-k sampling with k=1 returns a definite answer.";
            response1 = generate(chat,prompt);
            response2 = generate(chat,prompt);
            testCase.verifyEqual(response1,response2);
        end

        function extremeMinP(testCase)
            %% This should work, and it does on some computers. On others, Ollama
            %% receives the parameter, but either Ollama or llama.cpp fails to
            %% honor it correctly.
            testCase.assumeTrue(false,"disabled due to Ollama/llama.cpp not honoring parameter reliably");

            % setting min-p to p=1 means only tokens with the same logit as
            % the most likely one can be chosen, which will almost certainly
            % only ever be one, so we expect to get a fixed response.
            chat = ollamaChat("mistral",MinP=1);
            prompt = "Min-p sampling with p=1 returns a definite answer.";
            response1 = generate(chat,prompt);
            response2 = generate(chat,prompt);
            testCase.verifyEqual(response1,response2);
        end

        function extremeTfsZ(testCase)
            %% This should work, and it does on some computers. On others, Ollama
            %% receives the parameter, but either Ollama or llama.cpp fails to
            %% honor it correctly.
            testCase.assumeTrue(false,"disabled due to Ollama/llama.cpp not honoring parameter reliably");

            % setting tfs_z to z=0 leaves no random choice, but degrades to
            % greedy sampling, so we expect to get a fixed response.
            chat = ollamaChat("mistral",TailFreeSamplingZ=0);
            prompt = "Sampling with tfs_z=0 returns a definite answer.";
            response1 = generate(chat,prompt);
            response2 = generate(chat,prompt);
            testCase.verifyEqual(response1,response2);
        end

        function stopSequences(testCase)
            chat = ollamaChat("mistral",TopK=1);
            prompt = "Top-k sampling with k=1 returns a definite answer.";
            response1 = generate(chat,prompt);
            chat.StopSequences = "1";
            response2 = generate(chat,prompt);

            testCase.verifyEqual(response2, extractBefore(response1,"1"));
        end

        function seedFixesResult(testCase)
            %% This should work, and it does on some computers. On others, Ollama
            %% receives the parameter, but either Ollama or llama.cpp fails to
            %% honor it correctly.
            testCase.assumeTrue(false,"disabled due to Ollama/llama.cpp not honoring parameter reliably");

            chat = ollamaChat("mistral");
            response1 = generate(chat,"hi",Seed=1234);
            response2 = generate(chat,"hi",Seed=1234);
            testCase.verifyEqual(response1,response2);
        end

        function generateWithImages(testCase)
            import matlab.unittest.constraints.ContainsSubstring
            chat = ollamaChat("moondream");
            image_path = "peppers.png";
            emptyMessages = messageHistory;
            messages = addUserMessageWithImages(emptyMessages,"What is in the image?",image_path);

            % The moondream model is small and unreliable. We are not
            % testing the model, we are testing that we send images to
            % Ollama in the right way. So we just ask several times and
            % are happy when  one of the responses mentions "pepper" or 
            % "vegetable".
            text = arrayfun(@(~) generate(chat,messages), 1:5, UniformOutput=false);
            text = join([text{:}],newline+"-----"+newline);
            testCase.verifyThat(text,ContainsSubstring("pepper") | ContainsSubstring("vegetable"));
        end

        function streamFunc(testCase)
            function seen = sf(str)
                persistent data;
                if isempty(data)
                    data = strings(1, 0);
                end
                % Append streamed text to an empty string array of length 1
                data = [data, str];
                seen = data;
            end
            chat = ollamaChat("mistral", StreamFun=@sf);

            testCase.verifyWarningFree(@()generate(chat, "Hello world."));
            % Checking that persistent data, which is still stored in
            % memory, is greater than 1. This would mean that the stream
            % function has been called and streamed some text.
            testCase.verifyGreaterThan(numel(sf("")), 1);
        end

        function reactToEndpoint(testCase)
            testCase.assumeTrue(isenv("SECOND_OLLAMA_ENDPOINT"),...
                "Test point assumes a second Ollama server is running " + ...
                "and $SECOND_OLLAMA_ENDPOINT points to it.");
            chat = ollamaChat("qwen2:0.5b",Endpoint=getenv("SECOND_OLLAMA_ENDPOINT"));
            testCase.verifyWarningFree(@() generate(chat,"dummy"));
            % also make sure "http://" can be included
            chat = ollamaChat("qwen2:0.5b",Endpoint="http://" + getenv("SECOND_OLLAMA_ENDPOINT"));
            response = generate(chat,"some input");
            testCase.verifyClass(response,'string');
            testCase.verifyGreaterThan(strlength(response),0);
        end

        function doReturnErrors(testCase)
            testCase.assumeFalse( ...
                any(startsWith(ollamaChat.models,"abcdefghijklmnop")), ...
                "We want a model name that does not exist on this server");
            chat = ollamaChat("abcdefghijklmnop");
            testCase.verifyError(@() generate(chat,"hi!"), "llms:apiReturnedError");
        end

        function invalidInputsConstructor(testCase, InvalidConstructorInput)
            testCase.verifyError(@() ollamaChat("mistral", InvalidConstructorInput.Input{:}), InvalidConstructorInput.Error);
        end

        function invalidInputsGenerate(testCase, InvalidGenerateInput)
            chat = ollamaChat("mistral");
            testCase.verifyError(@() generate(chat,InvalidGenerateInput.Input{:}), InvalidGenerateInput.Error);
        end

        function invalidSetters(testCase, InvalidValuesSetters)
            chat = ollamaChat("mistral");
            function assignValueToProperty(property, value)
                chat.(property) = value;
            end

            testCase.verifyError(@() assignValueToProperty(InvalidValuesSetters.Property,InvalidValuesSetters.Value), InvalidValuesSetters.Error);
        end

        function validSetters(testCase, ValidValuesSetters)
            chat = ollamaChat("mistral");
            function assignValueToProperty(property, value)
                chat.(property) = value;
            end

            testCase.verifyWarningFree(@() assignValueToProperty(ValidValuesSetters.Property,ValidValuesSetters.Value));
        end

        function queryModels(testCase)
            % our test setup has at least mistral loaded
            models = ollamaChat.models;
            testCase.verifyClass(models,"string");
            testCase.verifyThat(models, ...
                matlab.unittest.constraints.IsSupersetOf("mistral"));
        end
    end
end

function invalidValuesSetters = iGetInvalidValuesSetters

invalidValuesSetters = struct( ...
    "InvalidTemperatureType", struct( ...
        "Property", "Temperature", ...
        "Value", "2", ...
        "Error", "MATLAB:invalidType"), ...
    ...
    "InvalidTemperatureSize", struct( ...
        "Property", "Temperature", ...
        "Value", [1 1 1], ...
        "Error", "MATLAB:expectedScalar"), ...
    ...
    "TemperatureTooLarge", struct( ...
        "Property", "Temperature", ...
        "Value", 20, ...
        "Error", "MATLAB:notLessEqual"), ...
    ...
    "TemperatureTooSmall", struct( ...
        "Property", "Temperature", ...
        "Value", -20, ...
        "Error", "MATLAB:expectedNonnegative"), ...
    ...
    "InvalidTopPType", struct( ...
        "Property", "TopP", ...
        "Value", "2", ...
        "Error", "MATLAB:invalidType"), ...
    ...
    "InvalidTopPSize", struct( ...
        "Property", "TopP", ...
        "Value", [1 1 1], ...
        "Error", "MATLAB:expectedScalar"), ...
    ...
    "TopPTooLarge", struct( ...
        "Property", "TopP", ...
        "Value", 20, ...
        "Error", "MATLAB:notLessEqual"), ...
    ...
    "TopPTooSmall", struct( ...
        "Property", "TopP", ...
        "Value", -20, ...
        "Error", "MATLAB:expectedNonnegative"), ...
    ...
    "MinPTooLarge", struct( ...
        "Property", "MinP", ...
        "Value", 20, ...
        "Error", "MATLAB:notLessEqual"), ...
    ...
    "MinPTooSmall", struct( ...
        "Property", "MinP", ...
        "Value", -20, ...
        "Error", "MATLAB:expectedNonnegative"), ...
    ...
    "WrongTypeStopSequences", struct( ...
        "Property", "StopSequences", ...
        "Value", 123, ...
        "Error", "MATLAB:validators:mustBeNonzeroLengthText"), ...
    ...
    "WrongSizeStopNonVector", struct( ...
        "Property", "StopSequences", ...
        "Value", repmat("stop", 4), ...
        "Error", "MATLAB:validators:mustBeVector"), ...
    ...
    "EmptyStopSequences", struct( ...
        "Property", "StopSequences", ...
        "Value", "", ...
        "Error", "MATLAB:validators:mustBeNonzeroLengthText"));
end

function validSetters = iGetValidValuesSetters
validSetters = struct(...
    "SmallTopNum", struct( ...
        "Property", "TopK", ...
        "Value", 2));
    % Currently disabled because it requires some code reorganization
    % and we have higher priorities ...
    % "ManyStopSequences", struct( ...
    %     "Property", "StopSequences", ...
    %     "Value", ["1" "2" "3" "4" "5"]));
end

function invalidConstructorInput = iGetInvalidConstructorInput
invalidConstructorInput = struct( ...
    "InvalidResponseFormatValue", struct( ...
        "Input",{{"ResponseFormat", "foo" }},...
        "Error", "MATLAB:validators:mustBeMember"), ...
    ...
    "InvalidResponseFormatSize", struct( ...
        "Input",{{"ResponseFormat", ["text" "text"] }},...
        "Error", "MATLAB:validation:IncompatibleSize"), ...
    ...
    "InvalidStreamFunType", struct( ...
        "Input",{{"StreamFun", "2" }},...
        "Error", "MATLAB:validators:mustBeA"), ...
    ...
    "InvalidStreamFunSize", struct( ...
        "Input",{{"StreamFun", [1 1 1] }},...
        "Error", "MATLAB:validation:IncompatibleSize"), ...
    ...
    "InvalidTimeOutType", struct( ...
        "Input",{{"TimeOut", "2" }},...
        "Error", "MATLAB:validators:mustBeReal"), ...
    ...
    "InvalidTimeOutSize", struct( ...
        "Input",{{"TimeOut", [1 1 1] }},...
        "Error", "MATLAB:validation:IncompatibleSize"), ...
    ...
    "WrongTypeSystemPrompt",struct( ...
        "Input",{{ 123 }},...
        "Error","MATLAB:validators:mustBeTextScalar"),...
    ...
    "WrongSizeSystemPrompt",struct( ...
        "Input",{{ ["test"; "test"] }},...
        "Error","MATLAB:validators:mustBeTextScalar"),...
    ...
    "InvalidTemperatureType",struct( ...
        "Input",{{ "Temperature" "2" }},...
        "Error","MATLAB:invalidType"),...
    ...
    "InvalidTemperatureSize",struct( ...
        "Input",{{ "Temperature" [1 1 1] }},...
        "Error","MATLAB:expectedScalar"),...
    ...
    "TemperatureTooLarge",struct( ...
        "Input",{{ "Temperature" 20 }},...
        "Error","MATLAB:notLessEqual"),...
    ...
    "TemperatureTooSmall",struct( ...
        "Input",{{ "Temperature" -20 }},...
        "Error","MATLAB:expectedNonnegative"),...
    ...
    "InvalidTopPType",struct( ...
        "Input",{{  "TopP" "2" }},...
        "Error","MATLAB:invalidType"),...
    ...
    "InvalidTopPSize",struct( ...
        "Input",{{  "TopP" [1 1 1] }},...
        "Error","MATLAB:expectedScalar"),...
    ...
    "TopPTooLarge",struct( ...
        "Input",{{  "TopP" 20 }},...
        "Error","MATLAB:notLessEqual"),...
    ...
    "TopPTooSmall",struct( ...
        "Input",{{ "TopP" -20 }},...
        "Error","MATLAB:expectedNonnegative"),...I
    ...
    "MinPTooLarge",struct( ...
        "Input",{{  "MinP" 20 }},...
        "Error","MATLAB:notLessEqual"),...
    ...
    "MinPTooSmall",struct( ...
        "Input",{{ "MinP" -20 }},...
        "Error","MATLAB:expectedNonnegative"),...I
    ...
    "WrongTypeStopSequences",struct( ...
        "Input",{{ "StopSequences" 123}},...
        "Error","MATLAB:validators:mustBeNonzeroLengthText"),...
    ...
    "WrongSizeStopNonVector",struct( ...
        "Input",{{ "StopSequences" repmat("stop", 4) }},...
        "Error","MATLAB:validators:mustBeVector"),...
    ...
    "EmptyStopSequences",struct( ...
        "Input",{{ "StopSequences" ""}},...
        "Error","MATLAB:validators:mustBeNonzeroLengthText"));
end

function invalidGenerateInput = iGetInvalidGenerateInput
emptyMessages = messageHistory;
validMessages = addUserMessage(emptyMessages,"Who invented the telephone?");

invalidGenerateInput = struct( ...
        "EmptyInput",struct( ...
            "Input",{{ [] }},...
            "Error","llms:mustBeMessagesOrTxt"),...
        ...
        "InvalidInputType",struct( ...
            "Input",{{ 123 }},...
            "Error","llms:mustBeMessagesOrTxt"),...
        ...
        "EmptyMessages",struct( ...
            "Input",{{ emptyMessages }},...
            "Error","llms:mustHaveMessages"),...
        ...
        "InvalidMaxNumTokensType",struct( ...
            "Input",{{ validMessages  "MaxNumTokens" "2" }},...
            "Error","MATLAB:validators:mustBeNumericOrLogical"),...
        ...
        "InvalidMaxNumTokensValue",struct( ...
            "Input",{{ validMessages  "MaxNumTokens" 0 }},...
            "Error","MATLAB:validators:mustBePositive"));
end
