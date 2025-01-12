%% Requirements:
%  1. DisturbanceConstantWindow shall be defined by it's name, the input
%      channels of interest, the time-instances when the signal is constant, 
%      the horizon_period of the channels and time-window
%  2. Upon construction, and when queried by user, it shall display the
%      information described in (1).
%
%  3. If channel information is not provided by the user, by
%      default the disturbance shall apply to all channels (chan_in = {[]}),
%      the window shall be [0], and the horizon_period shall be [0, 1]. This
%      will produce the trivial zero-signal.
%
%  4. If the user provides no name, DisturbanceConstantWindow shall throw an 
%      exception
%  5. If the user provides a channel that has more than one cell-entries,
%      DisturbanceConstantWindow shall throw an exception
%  6. If the user provides a window and horizon_period that are
%      inconsistent with each other, DisturbanceConstantWindow shall throw an
%      exception
%  7. If the user provides a window with duplicate time indices,
%      DisturbanceConstantWindow shall throw an exception
%  8. If the user provides a window that bridges the non-periodic and periodic
%      portions of the horizon_period, DisturbanceConstantWindow shall throw
%      an error, unless contradicted by the variable "override"
%  9. If the user provides a window that bridges the last time instance of a
%      period with the first time instance of the next period, 
%      DisturbanceConstantWindow shall throw an error, unless the window
%      fills the entire horizon_period, in which the trivial zero-signal will be
%      specified.
%
%  10. DisturbanceConstantWindow shall ensure that it's properties are consistent 
%      with its current horizon_period property
%  11. DisturbanceConstantWindow shall be capable of changing it's properties to 
%      match a newly input horizon_period, as long as the new 
%      horizon_period is consistent with the prior horizon_period
%
%  12. DisturbanceConstantWindow shall be capable of generating a
%      MultiplierConstantWindow from a DisturbanceConstantWindow object

%%
%  Copyright (c) 2021 Massachusetts Institute of Technology 
%  SPDX-License-Identifier: GPL-2.0
%%

%% Test class for DisturbanceConstantWindow and MultiplierConstantWindow.
classdef testDisturbanceConstantWindow < matlab.unittest.TestCase
    
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
function testDisturbanceFullConstructor(testCase)
    name = 'd';
    chan_in = {2};
    window = [1:3];
    horizon_period = [3, 1];
    override = true;
    d = DisturbanceConstantWindow(name,...
                                  chan_in,...
                                  window,...
                                  horizon_period,...
                                  override);
    testCase.verifyEqual(d.name, 'd')
    testCase.verifyEqual(d.chan_in, repmat(chan_in, 1, sum(horizon_period)))
    testCase.verifyEqual(d.window, window)
    testCase.verifyEqual(d.horizon_period, horizon_period)
    testCase.verifyEqual(d.override, override)
end

function testFourArgConstructor(testCase)
    name = 'd';
    chan_in = {[1;3]};
    window = 3;
    horizon_period = [2, 2];
    d = DisturbanceConstantWindow(name, chan_in, window, horizon_period);
    testCase.verifyEqual(d.name, 'd')
    testCase.verifyEqual(d.chan_in, repmat(chan_in, 1, sum(horizon_period)))
    testCase.verifyEqual(d.window, window)
    testCase.verifyEqual(d.horizon_period, horizon_period)
    testCase.verifyEqual(d.override, false)
end

function testOneArgConstructor(testCase)
    name = 'd';
    d = DisturbanceConstantWindow(name);
    testCase.verifyEqual(d.name, 'd')
    testCase.verifyEqual(d.chan_in, {[]})
    testCase.verifyEqual(d.window, 1)
    testCase.verifyEqual(d.horizon_period, [0, 1])
    testCase.verifyEqual(d.override, true)
end

function testMixingNonperiodicAndPeriodicTimesteps(testCase)
    % Should throw an error without override (because window includes periodic and non-periodic portions)
    window = [1:2];
    horizon_period = [2, 2];
    bad_d = @()DisturbanceConstantWindow('d', {[]}, window, horizon_period);
    testCase.verifyError(bad_d,...
                         'DisturbanceConstantWindow:DisturbanceConstantWindow')
    
    % Now with override, it will make a window that has a periodic portion
    override = true;
    d = DisturbanceConstantWindow('d', {[]}, window, horizon_period, override);
    dim_in = ones(1, sum(d.horizon_period));
    m = MultiplierConstantWindow(d, dim_in);
    q_class = cellfun(@class, m.quad.q, 'UniformOutput', false);
    q_true = {'double', 'sdpvar', 'sdpvar', 'double'};
    testCase.verifyEqual(q_class, q_true)
    
    % Periodicity can be seen by extending the horizon
    extend_horizon = 2;
    new_hp = d.horizon_period + [extend_horizon, 0];
    d = d.matchHorizonPeriod(new_hp);
    dim_in = ones(1, sum(d.horizon_period));
    m = MultiplierConstantWindow(d, dim_in);
    q_class = cellfun(@class, m.quad.q, 'UniformOutput', false);
    q_true = {'double', 'sdpvar', 'sdpvar', 'double', 'sdpvar', 'double'};
    testCase.verifyEqual(q_class, q_true)    
end

function testMatchHorizonPeriodCorrectness(testCase)
    horizon_period = [2, 5];
    window = [1, 2, 4];
    override = true;
    d = DisturbanceConstantWindow('dis', {[]}, window, horizon_period,override);
    dim_in = ones(1, sum(horizon_period));
    mult = MultiplierConstantWindow(d, dim_in);
    q_class = cellfun(@class, mult.quad.q, 'UniformOutput', false);
    q_true = {'double', 'sdpvar',...  % Non-periodic portion
              'sdpvar', 'double', 'sdpvar', 'double', 'double'}; % Periodic portion
    % Establish correctness before changing horizon_period
    testCase.assertEqual(q_class, q_true)
    
    new_hp = [6, 10];
    d_new_hp = d.matchHorizonPeriod(new_hp);
    dim_in = ones(1, sum(new_hp));
    mult = MultiplierConstantWindow(d_new_hp, dim_in);
    q_class = cellfun(@class, mult.quad.q, 'UniformOutput', false);
    q_true = {'double', 'sdpvar', 'sdpvar', 'double', 'sdpvar', 'double',...  % Non-periodic portion
              'double', 'sdpvar', 'double', 'sdpvar', 'double', 'double', 'sdpvar', 'double', 'sdpvar', 'double'}; % Periodic portion
    testCase.verifyEqual(q_class, q_true)
end

function testFullWindow(testCase)
    horizon_period = [0, 1];
    window = 1;
    override = true;
    d = DisturbanceConstantWindow('d', {[]}, window, horizon_period, override);
    dim_lft_in = ones(1, sum(horizon_period));
    m = MultiplierConstantWindow(d, dim_lft_in);
    % Check correct structure of multiplier
    testCase.verifyClass(m.quad.q{1}, 'sdpvar')
        
    horizon_period = [0, 2];
    window = 1:2;
    override = true;
    d = DisturbanceConstantWindow('d', {[]}, window, horizon_period, override);
    dim_lft_in = ones(1, sum(horizon_period));
    m = MultiplierConstantWindow(d, dim_lft_in);
    testCase.verifyClass(m.quad.q{1}, 'sdpvar')
    testCase.verifyClass(m.quad.q{2}, 'sdpvar')
end

function testBadConstructorCalls(testCase)
    testCase.verifyError(@() DisturbanceConstantWindow(),...
                         'DisturbanceConstantWindow:DisturbanceConstantWindow')
    testCase.verifyError(@() DisturbanceConstantWindow('d', {[]}),...
                         'DisturbanceConstantWindow:DisturbanceConstantWindow')
end

function testDisplayDisturbance(testCase)
    lft = toLft(eye(2));
    horizon_period = [3, 5];    
    lft = lft.matchHorizonPeriod(horizon_period);
    d1 = DisturbanceConstantWindow('d1', {1}, 4:6, horizon_period);
    d2 = DisturbanceConstantWindow('d2', {2}, 1:2, horizon_period);
    % Add disturbances and display
    lft = lft.addDisturbance({d1, d2})
end

function testBadDeltaToMultiplierCall(testCase)
    d = DisturbanceConstantWindow('d');
    testCase.verifyError(@()d.disturbanceToMultiplier,...
                         'DisturbanceConstantWindow:disturbanceToMultiplier')
end

function testMultiplierConstructor(testCase)
    name = 'd';
    chan_in = {2};
    window = [1:3];
    horizon_period = [3, 1];
    override = true;
    d = DisturbanceConstantWindow(name,...
                                  chan_in,...
                                  window,...
                                  horizon_period,...
                                  override);              
    dim_in_lft = 2 * ones(1, sum(horizon_period));
    m = MultiplierConstantWindow(d, dim_in_lft);
    testCase.verifyEqual(m.name, 'd')
    testCase.verifyEqual(m.chan_in, repmat(chan_in, 1, sum(horizon_period)))
    testCase.verifyEqual(m.window, window)
    testCase.verifyEqual(m.horizon_period, horizon_period)    
    testCase.verifyEqual(m.dim_in, dim_in_lft)
    % The following verification would have failed prior to hotfix-010
    testCase.verifyEqual(m.filter_lft.d, repmat({[0, -1]}, 1, sum(horizon_period)))
end

function testMultiplierBadConstructionCall(testCase)
    testCase.verifyError(@() MultiplierConstantWindow([], []),...
                         ?MException)
end

function testTimeVaryingQuad(testCase)
    g = drss(3);
    g.a = g.a * 0.9;
    lft = toLft(g);
    % Extend lft to be time-varying
    horizon_period = [0, 20];
    lft = lft.matchHorizonPeriod(horizon_period);
    % Create a disturbance which is constant for all time (therefore, 0)
    dis = DisturbanceConstantWindow('d',...
                                    {[]},...
                                    1:(horizon_period(2) - 1),...
                                    horizon_period);
    lft = lft.addDisturbance({dis});
    options = AnalysisOptions('verbose', false, 'lmi_shift', 1e-6);
    % The upper bound using time-varying quads
    result_lower = iqcAnalysis(lft, 'analysis_options', options);
    testCase.assertTrue(result_lower.valid)
    quads = cellfun(@double, result_lower.multipliers_disturbance.quad.q,...
                    'UniformOutput', false);
    testCase.verifyEqual(quads{1}, 0)
    testCase.verifyFalse(all(cellfun(@(q) isequal(q, quads{2}), quads(2:end))))
    
    dis = lft.disturbance.disturbances{1};
    dim_in = size(lft, 2);
    mult = MultiplierConstantWindow(dis, dim_in, 'quad_time_varying', false);
    % Generate results forcing quad to be time-invariant (should be greater than result_lower)
    result_qti = iqcAnalysis(lft,...
                             'analysis_options', options,...
                             'multipliers_disturbance', mult);
    testCase.assertTrue(result_qti.valid)
    quads_ti = cellfun(@double, result_qti.multipliers_disturbance.quad.q,...
                    'UniformOutput', false);
    testCase.verifyEqual(quads_ti{1}, 0)
    testCase.verifyTrue(all(cellfun(@(q) isequal(q, quads_ti{2}), quads_ti(2:end))))
end

function testMultiplierConstructionWithChannelGreaterThanTwo(testCase)
    % This test would have failed previous to hotfix-010
    % Although the Multiplier could be correctly constructed with a disturbance
    % channel of all or 1, it constructed the wrong multiplier for all other
    % channel specifications (also see method testMultiplierConstructor)
    name = 'd';
    chan_floor = 3;
    dim_max = 6;
    dim_in = randi([chan_floor, dim_max]);
    chan_in = unique(randi([chan_floor, dim_in], [dim_in + 1 - chan_floor, 1]));
    window = 1;
    horizon_period = [0, 1];
    override = true;
    d = DisturbanceConstantWindow(name,...
                                  {chan_in},...
                                  window,...
                                  horizon_period,...
                                  override);              
    dim_in_lft = dim_in * ones(1, sum(horizon_period));
    m = MultiplierConstantWindow(d, dim_in_lft);
    testCase.verifyEqual(m.name, 'd')
    testCase.verifyEqual(m.chan_in, repmat({chan_in}, 1, sum(horizon_period)))
    testCase.verifyEqual(m.window, window)
    testCase.verifyEqual(m.horizon_period, horizon_period)    
    testCase.verifyEqual(m.dim_in, dim_in_lft)
    d_matrix = zeros(length(chan_in), dim_in);
    for i = 1:length(chan_in)
        d_matrix(i, chan_in(i)) = -1;
    end
    testCase.verifyEqual(m.filter_lft.d,...
                         repmat({d_matrix}, 1, sum(horizon_period)))
end
end
end

%%  CHANGELOG
% Nov. 18, 2021: Added after v0.6.0 - Micah Fry (micah.fry@ll.mit.edu)