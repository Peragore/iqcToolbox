%% Requirements:
%  1. addPerformance shall take a cell array of performances and append the
%      provided performances to the performances that are already present 
%      in the given LFT.
%  2. An error shall be thrown if addPerformance attempts to add a 
%      performance which is not consistent with the given LFT. 
%     Inconsistent performances:
%       - specify signal channels which exceed the size of the LFT
%       - share names with other performances but are not equivalent to 
%         those performances

%%
%  Copyright (c) 2021 Massachusetts Institute of Technology 
%  SPDX-License-Identifier: GPL-2.0
%%

%% Test class for Ulft.
classdef testUlftAddPerformance < matlab.unittest.TestCase

methods (TestMethodSetup)
function seedAndReportRng(testCase)
    seed = floor(posixtime(datetime('now')));
    rng('default');
    rng(seed);
    diagnose_str = ...
        sprintf(['If this test generates random inputs, those inputs',...
                 ' may be regenerated by calling: \n',...
                 '>> rng(%10d) \n',...
                 'before running the remainder of the test''s body'],...
                seed);
    testCase.onFailure(@() fprintf(diagnose_str));
end    
end
    
methods (Test)
    
function testAddPerformancesToNoPerformances(testCase) 
    chars = ['A':'Z', 'a':'z', '0':'9'];
    for i = 1:10
        % Create lft and performances
        lft = Ulft.random();
        num_performance = randi([1, 5]);
        performances = cell(1, num_performance);
        for j = 1 : num_performance 
            name = chars(randi(length(chars), [1, 5]));
            performances{j} = PerformanceL2Induced(name);
        end
        lft_added = lft.addPerformance(performances);
        lft_correct = Ulft(lft.a, lft.b, lft.c, lft.d, lft.delta,...
                           'horizon_period', lft.horizon_period,...
                           'performance', performances);
        
        assertEqual(testCase, lft.performance.names, {'default_l2'})
        
        % Check addition of performances
        verifyEqual(testCase, lft_added, lft_correct)
        
        % Check that adding different performances creates different LFTs
        lft_wrong = addPerformance(lft, {PerformanceL2Induced('another')});
        verifyNotEqual(testCase, lft_wrong, lft_correct)
    end
end

function testAddDuplicatePerformances(testCase) 
    chars = ['A':'Z', 'a':'z', '0':'9'];
    for i = 1:10
        % Create lft and performances
        lft = Ulft.random();
        num_performance = randi([1, 5]);
        performances = cell(1, num_performance);
        for j = 1 : num_performance 
            name = chars(randi(length(chars), [1, 5]));
            performances{j} = PerformanceL2Induced(name);
        end
        lft = lft.addPerformance(performances);
        seq_perf = SequencePerformance(performances);
        seq_perf = matchHorizonPeriod(seq_perf, lft.horizon_period);
        lft_duplicate = lft.addPerformance(seq_perf.performances);
        
        % Check that duplicate performances are unified
        verifyEqual(testCase, lft_duplicate, lft)
    end
end

function testAddPerformancesToPerformances(testCase) 
    chars = ['A':'Z', 'a':'z', '0':'9'];
    for i = 1:10
        % Create lft and performances
        lft = Ulft.random();
        num_performance = 2 * randi([1, 3]);
        performances = cell(1, num_performance);
        for j = 1 : num_performance 
            name = chars(randi(length(chars), [1, 5]));
            performances{j} = PerformanceL2Induced(name);
        end
        orig_inds = 1 : num_performance / 2;
        add_inds = (num_performance / 2) + 1 : num_performance;
        lft = Ulft(lft.a, lft.b, lft.c, lft.d, lft.delta,...
                           'horizon_period', lft.horizon_period,...
                           'performance', performances(orig_inds));
        lft_added = lft.addPerformance(performances(add_inds));
        lft_correct = Ulft(lft.a, lft.b, lft.c, lft.d, lft.delta,...
                           'horizon_period', lft.horizon_period,...
                           'performance', performances);
        
        % Check addition of performances
        verifyEqual(testCase, lft_added, lft_correct)
    end
end

function testErrorAddingUnequalPerformances(testCase) 
    for i = 1:10
        chan = {};
        gain = [];
        % Create lfts with nearly equivalent performances
        horizon_period1 = [randi([1, 5]), randi([2, 5])];
        lft = Ulft.random('horizon_period', horizon_period1);
        perf1 = PerformanceL2Induced('a', chan, chan, gain, horizon_period1);
        lft1 = Ulft(lft.a, lft.b, lft.c, lft.d, lft.delta,...
                    'horizon_period', lft.horizon_period,...
                    'performance', perf1); 
        
        horizon_period2 = horizon_period1 - 1;
        lft = Ulft.random('horizon_period', horizon_period2);
        perf2 = PerformanceL2Induced('a', chan, chan, gain, horizon_period2);
        lft2 = Ulft(lft.a, lft.b, lft.c, lft.d, lft.delta,...
                    'horizon_period', lft.horizon_period,...
                    'performance', perf2);
                
        horizon_period3 = [0, 1];
        lft = Ulft.random('horizon_period', horizon_period3);
        perf3 = PerformanceL2Induced('a', chan, chan, gain, horizon_period3);
        lft3 = Ulft(lft.a, lft.b, lft.c, lft.d, lft.delta,...
                    'horizon_period', lft.horizon_period,...
                    'performance', perf3);
            
        % Check that error is thrown when unequal performances are added
        verifyError(testCase, @() addPerformance(lft1, {perf2}), ?MException)
        verifyError(testCase, @() addPerformance(lft1, {perf3}), ?MException)
        verifyError(testCase, @() addPerformance(lft3, {perf1}), ?MException)
    end
end

function testErrorAddPerformanceBadChannels(testCase)
    for i = 1:10
        lft = Ulft.random();
        [dim_out, dim_in]  = size(lft);
        dim_out = dim_out(1);
        dim_in  = dim_in(1);
        % This performance has too many channels
        perf_bad_out = PerformanceL2Induced('a',...
                                           {[1 : 2 : dim_out, dim_out + 1]'},...
                                           {});
        perf_bad_in = PerformanceL2Induced('a',...
                                           {},...
                                           {[1 : 2 : dim_in, dim_in + 1]'});
                                       
        % Try to add to an LFT
        verifyError(testCase, @() addPerformance(lft, {perf_bad_out}), ?MException)
        verifyError(testCase, @() addPerformance(lft, {perf_bad_in}), ?MException)
    end
end
    
end
end

%%  CHANGELOG
% Sep. 28, 2021 (v0.6.0)
% Aug. 26, 2021 (v.0.5.0): Initial release - Micah Fry (micah.fry@ll.mit.edu)