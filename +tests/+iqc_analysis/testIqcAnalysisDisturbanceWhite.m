%% Requirements:
%  1. IQC analysis shall be capable of producing worst-case upper-bounds on
%     uncertain-systems which have disturbances constrained to be banded white
%     signals.
%  2. IQC analysis should generally show a reduction of the performance value 
%     of LFTs that are not all-pass filters
%  3. IQC analysis should show little impact on the performance value when the 
%     LFT is an all-pass filter.


%%
%  Copyright (c) 2021 Massachusetts Institute of Technology 
%  SPDX-License-Identifier: GPL-2.0
%%

%% Test class for IQC analysis with Constant Disturbances
classdef testIqcAnalysisDisturbanceWhite < matlab.unittest.TestCase

methods (TestMethodSetup)
function seedAndReportRng(testCase)
    seed = floor(posixtime(datetime('now')));
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
function testComparisonToH2Norm(testCase)
    rng(1) 
    % Create a scalar TF
    dim_outin = 1;
    g = drss(1, dim_outin, dim_outin);
    g.a = g.a * 0.9;
    g = g * 10 / norm(g);
    g_lft = toLft(g);
    % Add white noise disturbance to LFT
    g_lft_dis = g_lft.addDisturbance({DisturbanceBandedWhite('d')});
    % Make poles for multiplier
    num_poles = 15;
    poles = linspace(-.9, .9, num_poles);
    mult = MultiplierBandedWhite(g_lft_dis.disturbance.disturbances{1},...
                                 dim_outin,...
                                 logical(g.Ts),...
                                 'poles', poles);
    options = AnalysisOptions('verbose', false, 'lmi_shift', 1e-6);
    % Analyze system with disturbance characterization
    result = iqcAnalysis(g_lft_dis,...
                         'analysis_options', options,...
                         'multipliers_disturbance', mult);
    
    % performance should be close to (but never less than) h2 norm
    norm_h2 = norm(g, 2);
    diff_perf = abs(norm_h2 - result.performance) / norm_h2;
    testCase.assertTrue(result.valid)
    testCase.verifyGreaterThan(result.performance, norm_h2)
    testCase.verifyLessThan(diff_perf, 1e-2)
    
    % Repeat last test with block diagonal mimo
    g = blkdiag(drss(1, dim_outin, dim_outin),...
                drss(1, dim_outin, dim_outin),...
                drss(1, dim_outin, dim_outin));
    g.a = g.a * 0.9;
    g = g * 10 / norm(g);
    g_lft = toLft(g);
    g_lft_dis = g_lft.addDisturbance({DisturbanceBandedWhite('1', {1}),...
                                      DisturbanceBandedWhite('2', {2}),...
                                      DisturbanceBandedWhite('3', {3})});
    num_poles = 11;
    poles = linspace(-.9, .9, num_poles);
    mults = cellfun(@(d) MultiplierBandedWhite(d, 3, true, 'poles', poles),...
                    g_lft_dis.disturbance.disturbances);
    result = iqcAnalysis(g_lft_dis,...
                         'analysis_options', options,...
                         'multipliers_disturbance', mults);
    max_norm_h2 = max([norm(g(1, 1)), norm(g(2, 2)), norm(g(3, 3))]);
    diff_perf = abs(max_norm_h2 - result.performance) / max_norm_h2;
    testCase.assertTrue(result.valid)
    testCase.verifyGreaterThan(result.performance, max_norm_h2)
    testCase.verifyLessThan(diff_perf, 1e-2)
end

function testHighPassFilter(testCase)
    [z, p, k] = butter(5, .5, 'high');
    g = ss(zpk(z, p, k, -1));
    g_lft = toLft(g);
    options = AnalysisOptions('verbose', false, 'lmi_shift', 1e-6);
    result_no_dis = iqcAnalysis(g_lft, 'analysis_options', options);
    testCase.assertTrue(result_no_dis.valid)
    % Performance must drop significantly with white noise characterization
    g_lft_dis = g_lft.addDisturbance({DisturbanceBandedWhite('d')});
    % Make poles for multiplier
    num_poles = 15;
    poles = linspace(-.9, .9, num_poles);
    mult = MultiplierBandedWhite(g_lft_dis.disturbance.disturbances{1},...
                                 size(g_lft, 1),...
                                 logical(g.Ts),...
                                 'poles', poles);
    % Analyze system with disturbance characterization
    result = iqcAnalysis(g_lft_dis,...
                         'analysis_options', options,...
                         'multipliers_disturbance', mult);
    testCase.assertTrue(result.valid)
    testCase.verifyLessThan(result.performance, result_no_dis.performance*0.75)
end


function testLowPassFilter(testCase)
    [z, p, k] = butter(5, .5, 'low');
    g = ss(zpk(z, p, k, -1));
    g_lft = toLft(g);
    options = AnalysisOptions('verbose', false, 'lmi_shift', 1e-6);
    result_no_dis = iqcAnalysis(g_lft, 'analysis_options', options);
    testCase.assertTrue(result_no_dis.valid)
    % Performance must drop significantly with white noise characterization
    g_lft_dis = g_lft.addDisturbance({DisturbanceBandedWhite('d')});
    % Make poles for multiplier
    num_poles = 15;
    poles = linspace(-.9, .9, num_poles);
    mult = MultiplierBandedWhite(g_lft_dis.disturbance.disturbances{1},...
                                 size(g_lft, 1),...
                                 logical(g.Ts),...
                                 'poles', poles);
    % Analyze system with disturbance characterization
    result = iqcAnalysis(g_lft_dis,...
                         'analysis_options', options,...
                         'multipliers_disturbance', mult);
    testCase.assertTrue(result.valid)
    testCase.verifyLessThan(result.performance, result_no_dis.performance*0.75)
end

function testNoEffectForMemoryless(testCase)
    % Generate uncertain memoryless object
    rct_object = zeros(3);
    for i = 1:2
        var = randatom('ureal');
        base = rand(3);
        base(base < .5) = 0;
        base(base >= .5) = 1;
        rct_object = rct_object + var * base;
    end  
    rct_object = uss(rct_object);
    rct_result = wcgain(rct_object);
    testCase.assumeTrue(isfinite(rct_result.LowerBound))
    testCase.assumeTrue(isfinite(rct_result.UpperBound))
    lft = rctToLft(rct_object);
    lft = lft + zeros(3, 1) * DeltaDelayZ() * zeros(1, 3);
    options = AnalysisOptions('verbose', false, 'lmi_shift', 1e-6);
    % IQC analysis will coincide with wcgain
    result = iqcAnalysis(lft, 'analysis_options', options);
    testCase.assertTrue(result.valid)
    testCase.verifyGreaterThan(result.performance, rct_result.LowerBound * .99)
    testCase.verifyLessThan(result.performance, rct_result.UpperBound * 1.01)
    
    lft_dis = lft.addDisturbance({DisturbanceBandedWhite('first', {1}),...
                                  DisturbanceBandedWhite('second', {2}),...
                                  DisturbanceBandedWhite('third', {3})});
    num_poles = 11;
    poles = linspace(-.9, .9, num_poles);
    mults = cellfun(@(d) MultiplierBandedWhite(d, 3, true, 'poles', poles),...
                    lft_dis.disturbance.disturbances);
    result_dis = iqcAnalysis(lft_dis,...
                             'analysis_options', options,...
                             'multipliers_disturbance', mults);
    testCase.assertTrue(result.valid)
    diff_perf = abs(result.performance - result_dis.performance);
    testCase.verifyLessThan(diff_perf / result.performance, 1e-3)
end

function testIndependentOfHorizonPeriod(testCase)
    % Analyze any system
    g = drss(3, 1, 1);
    g.a = g.a * 0.9;
    g_lft = toLft(g);
    g_lft_dis = g_lft.addDisturbance({DisturbanceBandedWhite('d', {1})});
    options = AnalysisOptions('verbose', false, 'lmi_shift', 1e-6);
    % Get baseline result
    result = iqcAnalysis(g_lft_dis, 'analysis_options', options);
    testCase.assertTrue(result.valid)
    % New horizon_period
    new_hp = [randi([0, 10]), randi([1, 10])];
    g_lft_hp = g_lft_dis.matchHorizonPeriod(new_hp);
    result_hp = iqcAnalysis(g_lft_hp, 'analysis_options', options); 
    testCase.assertTrue(result.valid)
    diff_perf = abs(result.performance - result_hp.performance);
    testCase.verifyLessThan(diff_perf / result.performance, 1e-3)
end
end
end

%%  CHANGELOG
% Nov. 23, 2021: Added after v0.6.0 - Micah Fry (micah.fry@ll.mit.edu)