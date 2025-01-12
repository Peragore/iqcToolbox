%% Requirements:
%  1. DeltaDlti shall be defined by it's name, in/out dimensions, and
%      upper bound.
%  2. Upon construction, and when queried by user, it shall display the
%      information described in (1).
%
%  3. If dimension and/or bound information is not provided by the user, by
%      default the object shall be 1 x 1, with an upper bound of 1.
%  4. If the user only provides the name and one dimension, by default both
%      dimensions shall match the user input and the object shall have an
%      upper bound of 1.
%
%  4. If the user provides no name, or the name is not a string, DeltaDlti 
%      shall throw an exception
%  5. If the user provides an in/out dimension that is not a natural number
%      DeltaDlti shall throw an exception
%
%  6. If the user provides an upper bound less than 0, DeltaDlti shall 
%      throw an exception
%  8. If the user provides +/- inf or Nan for the upper bound, DeltaDlti
%      shall throw an exception
%
%  9. DeltaDlti shall ensure that upper_bound, dim_in, and dim_out are
%       constant arrays (i.e., the operator is time-invariant)
%  10.DeltaDlti shall ensure that it's properties are consistent with its
%      current horizon_period property
%  10.DeltaDlti shall be capable of changing it's properties to match a
%      newly input horizon_period, as long as the new horizon_period is
%      consistent with the prior horizon_period
%
%  11.DeltaDlti shall return the necessary mappings and DeltaDlti
%      object to be used for normalizing an LFT with a DeltaDlti
%      uncertainty.

%%
%  Copyright (c) 2021 Massachusetts Institute of Technology 
%  SPDX-License-Identifier: GPL-2.0
%%

%% Test class for DeltaDlti.
classdef testDeltaDlti < matlab.unittest.TestCase

methods (TestMethodSetup)
function seedAndReportRng(testCase)
    seed = floor(posixtime(datetime('now')));
    rng('default');
    rng(seed);
    diagnose_str = ...
        sprintf(['Random inputs may be regenerated by calling: \n',...
                 '>> rng(%10d) \n',...
                 'before running the remainder of the test''s body'],...
                seed);
    testCase.onFailure(@() fprintf(diagnose_str));
end    
end
    
methods (Test)
function testFullConstructor(testCase)
    name = 'test';
    dim_out = 3;
    dim_in = 2;
    upper_bound = 10.0;
    delta_dlti = DeltaDlti(name, dim_out, dim_in, upper_bound);
    verifyEqual(testCase, delta_dlti.name, name)
    verifyEqual(testCase, delta_dlti.dim_in, dim_in)
    verifyEqual(testCase, delta_dlti.dim_out, dim_out)
    verifyEqual(testCase, delta_dlti.upper_bound, upper_bound)
end

function testOneArgConstructor(testCase)
    name = 'test';
    delta_dlti = DeltaDlti(name);
    verifyEqual(testCase, delta_dlti.name, name)
    verifyEqual(testCase, delta_dlti.dim_in, 1)
    verifyEqual(testCase, delta_dlti.dim_out, 1)
    verifyEqual(testCase, delta_dlti.upper_bound, 1.0)
end

function testTwoArgConstructor(testCase)
    name = 'test';
    dim_outin = 7;
    delta_dlti = DeltaDlti(name, dim_outin);
    verifyEqual(testCase, delta_dlti.name, name)
    verifyEqual(testCase, delta_dlti.dim_in, dim_outin)
    verifyEqual(testCase, delta_dlti.dim_out, dim_outin)
    verifyEqual(testCase, delta_dlti.dim_in, delta_dlti.dim_out)
    verifyEqual(testCase, delta_dlti.upper_bound, 1.0)
end

function testThreeArgConstructor(testCase)
    name = 'test';
    dim_out = 7;
    dim_in = 10;
    delta_dlti = DeltaDlti(name, dim_out, dim_in);
    verifyEqual(testCase, delta_dlti.name, name)
    verifyEqual(testCase, delta_dlti.dim_in, dim_in)
    verifyEqual(testCase, delta_dlti.dim_out, dim_out)
    verifyEqual(testCase, delta_dlti.upper_bound, 1.0)
end

function testDeltaToMultiplier(testCase)
    name = 'test';
    delta_dlti = DeltaDlti(name);
    default_mult = deltaToMultiplier(delta_dlti);
    verifyEqual(testCase, default_mult.discrete, true)
    
    is_discrete = false;
    continuous_mult = deltaToMultiplier(delta_dlti, 'discrete', is_discrete);
    verifyEqual(testCase, continuous_mult.discrete, is_discrete)
    
    is_discrete = true;
    discrete_mult = deltaToMultiplier(delta_dlti, 'discrete', is_discrete);
    verifyEqual(testCase, discrete_mult.discrete, is_discrete)
end

function testHorizonPeriod(testCase)
   name = 'test';
   delta_dlti = DeltaDlti(name);
   assertEqual(testCase, delta_dlti.horizon_period, [0, 1])
   
   % Resetting horizon_period and making sure it fits for all properties
   horizon_period2 = [4, 7];
   delta_dlti.horizon_period = horizon_period2;
   delta_dlti = matchHorizonPeriod(delta_dlti);
   verifyEqual(testCase, delta_dlti.horizon_period, horizon_period2)
   
   % Resetting horizon_period and making sure it fits for all properties
   horizon_period3 = [3, 2];
   delta_dlti = matchHorizonPeriod(DeltaDlti(name), horizon_period3);
   verifyEqual(testCase, delta_dlti.horizon_period, horizon_period3)   
end

function testFailedHorizonPeriod(testCase)
   name = 'test';
   delta_dlti = DeltaDlti(name);
   assertEqual(testCase, delta_dlti.horizon_period, [0, 1])
   
   % Resetting horizon_period and making sure it fits for all properties
   horizon_period2 = [4, 7];
   delta_dlti.horizon_period = horizon_period2;
   delta_dlti = matchHorizonPeriod(delta_dlti);
   
   % Resetting horizon_period and incorrectly trying to force a fit with
   % other properties
   horizon_period3 = [5, 3];
   horizon_period3 = commonHorizonPeriod([horizon_period2; horizon_period3]);
   delta_dlti.horizon_period = horizon_period3;
   verifyError(testCase, @() matchHorizonPeriod(delta_dlti), ?MException)
end

function testFailedName(testCase)
    verifyError(testCase, @() DeltaDlti(), ?MException)
    verifyError(testCase, @() DeltaDlti(1), ?MException)
end

function testFailedDimension(testCase)
    verifyError(testCase, @() DeltaDlti('test', -2), ?MException)
    verifyError(testCase, @() DeltaDlti('test', 2.2), ?MException)
end

function testFailedBounds(testCase)
    verifyError(testCase, @() DeltaDlti('test', 1, 1, -0.1), ?MException)
    verifyError(testCase, @() DeltaDlti('test', 1, 1, inf), ?MException)
    verifyError(testCase, @() DeltaDlti('test', 1, 1, nan), ?MException)
    verifyError(testCase, @() DeltaDlti('test', 1, 1, []), ?MException)
end

function testNormalization(testCase)
    for i = 1:10
        % Create original and normalized LFTs
        dim_out = randi([1, 10]);
        dim_in = randi([1, 10]);
        upper_bound = 10 * rand;
        del = DeltaDlti('test',dim_out, dim_in, upper_bound);
        lft = Ulft.random('num_deltas', 1, 'req_deltas', {del});
        lft_n = normalizeLft(lft);
        
        % Check correctness 
        % a-matrix
        expected_a = lft.a{1} * upper_bound;
        verifyLessThan(testCase, max(abs(lft_n.a{1} - expected_a)), 1e-5)
        % b-matrix
        expected_b = lft.b{1} * upper_bound;
        verifyLessThan(testCase, max(abs(lft_n.b{1} - expected_b)), 1e-5)
        % delta
        expected_delta = DeltaDlti('test', dim_out, dim_in, 1);
        verifyEqual(testCase, lft_n.delta.deltas{1}, expected_delta);
    end
end
end
end

%%  CHANGELOG
% Sep. 28, 2021 (v0.6.0)
% Aug. 26, 2021 (v.0.5.0): Initial release - Micah Fry (micah.fry@ll.mit.edu)