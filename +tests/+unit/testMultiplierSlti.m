%% Requirements:
%  1. MultiplierSlti shall represent the multiplier for static, linear,
%        time-invariant uncertainties in discrete- or continuous-time.
%        See Section VI.B in "System Analysis via Integral Quadratic
%        Constraints" (Megretski and Rantzer, 1997)
%        See Section 5.3.1 in "Robust Stability and Performance Analysis
%        Based on Integral Quadratic Constraints" (Veenman, et al, 2016)
%  1.1 MultiplierSlti shall contain the filter, quad, and constraints such
%        that multiplier = filter' * quad * filter, and the constraints on
%        quad guarantee that the DeltaSlti uncertainty delta is within the 
%        set described by IQC(multiplier).
%  1.2 MultiplierSlti shall define a multiplier w/ the following structure:
%                                *                                  
%             /bnd Ψ(jw)   0    \    /q11 q12\   /bnd Ψ(jw)   0    \
%     Π(jw) = |                 |  . |       | . |                 |
%             \0           Ψ(jw)/    \q21 q22/   \0           Ψ(jw)/
%                   filter'             quad          filter
%        where the definition of block_realization (Ψ), and the constraints
%        on quad may be flexibly configured
%  1.2 MultiplierSlti shall have a default configuration, such that it may
%        be constructed with a DeltaSlti uncertainty as the only argument
%  1.3 MultiplierSlti shall be able to flexibly construct it's properties
%        under user input, allowing the following properties to vary 
%        according to user inputs:
%         constraints - by allowing kyp-based constraints for q11 and q12
%         block_realization - which can be explicitly given, or built from
%                             basis_realization
%         basis_realization - which can be explicitly given, or built from
%                             basis_function
%         basis_function - which can be explicitly given, or built from
%                             basis_length and basis_poles
%         basis_poles - which must reside in the unit circle or left-hand
%                       plane. complex poles must come in pairs. if
%                       basis_length > length(basis_poles) + 1, then
%                       basis_function contains increasing repititions of
%                       basis_poles(1,:)
%         basis_length

%%
%  Copyright (c) 2021 Massachusetts Institute of Technology 
%  SPDX-License-Identifier: GPL-2.0
%%

%% Test class for MultiplierSlti.
classdef testMultiplierSlti < matlab.unittest.TestCase
methods (Test)
function testDefaultConstructor(testCase)
    d = DeltaSlti('test');
    m = MultiplierSlti(d);

    % Standard property check
    verifyEqual(testCase, m.name,           d.name);
    verifyEqual(testCase, m.horizon_period, d.horizon_period)
    verifyEqual(testCase, m.upper_bound,    d.upper_bound);
    verifyEqual(testCase, m.dim_outin,      d.dim_out);

    % Check defaults
    verifyTrue(testCase, m.discrete)
    verifyTrue(testCase, m.constraint_q11_kyp)
    verifyFalse(testCase, m.constraint_q12_kyp)
    verifyEqual(testCase, m.basis_length, 2)
    verifyEqual(testCase, m.basis_poles, -0.5)
    verifyEqual(testCase, size(m.basis_function), [m.basis_length, 1])
    verifyEqual(testCase, size(m.basis_realization), [m.basis_length, 1])
    [~, U] = minreal(m.basis_realization);
    verifyEqual(testCase, U, eye(size(U, 1)));
    verifyEqual(testCase,...
                size(m.block_realization),...
                [m.basis_length * m.dim_outin, m.dim_outin])
end

function testUnequalBoundsError(testCase)
    ub = 1;
    lb = -2;
    verifyError(testCase, ...
                @() MultiplierSlti(DeltaSlti('test', 1, lb, ub)),...
                ?MException)
end

function testNoPoles(testCase)
    del = DeltaSlti('test');
    basis_length = 1;
    mult = MultiplierSlti(del, 'basis_length', basis_length);
    verifyEqual(testCase, mult.basis_length, basis_length)
    verifyEmpty(testCase, mult.basis_poles)
    
    basis_poles = [];
    mult = MultiplierSlti(del, 'basis_poles', basis_poles);
    verifyEqual(testCase, mult.basis_length, basis_length)
    verifyEmpty(testCase, mult.basis_poles)
end

function testLongBasisOneRealPole(testCase)
    del = DeltaSlti('test');
    basis_length = 5;
    basis_poles = 0.6;
    mult = MultiplierSlti(del,...
                          'basis_length', basis_length,...
                          'basis_poles', basis_poles);

    verifyEqual(testCase, mult.basis_length, basis_length)

    verifyEqual(testCase,...
                mult.basis_function(1,1),...
                tf(1, 1, mult.basis_function.Ts));
    verifyEqual(testCase, length(mult.basis_function), basis_length)
    basis_function_zpk = zpk(mult.basis_function);
    for i = 2:basis_length
        verifyLessThan(testCase,...
                       abs(basis_function_zpk.P{i}' - ...
                           repmat(basis_poles, 1, i - 1)),...
                       1e-4 * ones(i - 1, 1))                               
    end            
end

function testLongBasisManyRealPoles(testCase)
    del = DeltaSlti('test');
    basis_length = 5;
    basis_poles = linspace(-.9, .9, basis_length - 1)';
    mult = MultiplierSlti(del,...
                          'basis_length', basis_length,...
                          'basis_poles', basis_poles);

    verifyEqual(testCase, mult.basis_length, basis_length)

    verifyEqual(testCase,...
                mult.basis_function(1,1),...
                tf(1, 1, mult.basis_function.Ts));
    verifyEqual(testCase, length(mult.basis_function), basis_length)
    bf_zpk = zpk(mult.basis_function);
    for i = 2:basis_length
        verifyLessThan(testCase,...
                       abs(bf_zpk.P{i} - basis_poles(i - 1)), 1e-4)                               
    end            
end

function testLongBasisOneComplexPairPoles(testCase)
    del = DeltaSlti('test');
    basis_length = 5;
    basis_poles = [.5 + .5i, .5 - .5i];
    mult = MultiplierSlti(del,...
                          'basis_length', basis_length,...
                          'basis_poles', basis_poles);

    verifyEqual(testCase, mult.basis_length, basis_length)

    verifyEqual(testCase,...
                mult.basis_function(1,1),...
                tf(1, 1, mult.basis_function.Ts));
    verifyEqual(testCase, length(mult.basis_function), basis_length)
    bf_zpk = zpk(mult.basis_function);
    for i = 2:basis_length
        verifyLessThan(testCase,...
                       abs(cplxpair(bf_zpk.P{i}') - ...
                           cplxpair(repmat(basis_poles, 1, i - 1))),...
                       1e-3 * ones(i - 1, 1))                             
    end            
end

function testBasisPoleErrors(testCase)
    del = DeltaSlti('test');
    basis_length = 3;
    basis_poles = linspace(-.3,-.1,basis_length)';
    verifyError(testCase, ...
                @() MultiplierSlti(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles),...
                ?MException,...
                ['Exception should be thrown for too many poles',...
                 'given the length (real poles, in discrete-time)'])

    basis_length = 5;
    verifyError(testCase, ...
                @() MultiplierSlti(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for too few poles',...
                 'given the length (real poles, in continuous-time)'])

    basis_length = 2;
    basis_poles = -1.2;
    verifyError(testCase, ...
                @() MultiplierSlti(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles),...
                ?MException,...
                ['Exception should be thrown for unstable poles',...
                 '(real poles, in discrete-time)'])

    basis_poles = 1.2;
    verifyError(testCase, ...
                @() MultiplierSlti(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for unstable poles',...
                 '(real poles, in continuous-time)'])

    basis_poles = [-.5 + 1.2i, -.5 - 1.2i];
    verifyError(testCase, ...
                @() MultiplierSlti(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles),...
                ?MException,...
                ['Exception should be thrown for unstable poles',...
                 '(complex poles, in discrete-time)'])

    basis_poles = [1.2i, -1.2i];
    verifyError(testCase, ...
                @() MultiplierSlti(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles),...
                ?MException,...
                ['Exception should be thrown for unstable poles',...
                 '(complex poles, in continuous-time)'])

    basis_poles = [.5i, -.4i];
    verifyError(testCase, ...
                @() MultiplierSlti(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles),...
                ?MException,...
                ['Exception should be thrown for non-conjugate',...
                 'pole pairs (in discrete-time)'])

    basis_poles = [-2 + .5i, -2 - .4i];
    verifyError(testCase, ...
                @() MultiplierSlti(del,...
                                   'basis_length', basis_length,...
                                   'basis_poles', basis_poles,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for non-conjugate',...
                 'pole pairs (in continuous-time)'])

end

function testSetBasisFunction(testCase)
    del = DeltaSlti('test');

    basis_ss = rss(4, 6, 1);
    basis_function = tf(basis_ss);
    while (~isstable(basis_function))
        basis_ss = rss(4, 6, 1);
        basis_function = tf(basis_ss);
    end            
    mult = MultiplierSlti(del,...
              'basis_function', basis_function,...
              'discrete', false);                  
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting basis_function, ',...
                 'basis_length should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting basis_function, ',...
                 'basis_poles should set empty (continuous-time)']);
    verifyEqual(testCase, mult.basis_function, basis_function)

    basis_ss = drss(4, 6, 1);
    basis_function = tf(basis_ss);
    while (~isstable(basis_function))
        basis_ss = drss(4, 6, 1);
        basis_function = tf(basis_ss);
    end            
    mult = MultiplierSlti(del,...
              'basis_function', basis_function);                  
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting basis_function, ',...
                 'basis_length should set empty (discrete-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting basis_function, ',...
                 'basis_poles should set empty (discrete-time)']);
    verifyEqual(testCase, mult.basis_function, basis_function)
end

function testBasisFunctionErrors(testCase)
    del = DeltaSlti('test');

    basis_function = tf(zpk([], 0.5, 1));
    verifyError(testCase,...
                @() MultiplierSlti(del,...
                                   'basis_function', basis_function,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable basis_function (continuous-time)'])

    basis_function = tf(zpk([], -1.1, 1, []));
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'basis_function', basis_function),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable basis_function (discrete-time)'])

    basis_function = tf(drss(randi(4), randi(4), 2));
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'basis_function', basis_function),...
                ?MException,...
                ['Exception should be thrown for providing a tf',...
                 'whose width is greater than 1'])

    basis_function = tf(drss(1));
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'basis_function', basis_function,...
                                  'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'discrete-time tf to a continuous-time multiplier'])

    basis_function = tf(rss(1));
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'basis_function', basis_function),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'continuous-time tf to a discrete-time multiplier'])                     
end

function testSetBasisRealization(testCase)
    del = DeltaSlti('test');

    basis_realization = rss(4, 6, 1);
    while (~isstable(basis_realization))
        basis_realization = rss(4, 6, 1);
    end            
    mult = MultiplierSlti(del,...
              'basis_realization', basis_realization,...
              'discrete', false);                  
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting basis_realization, ',...
                 'basis_length should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting basis_realization, ',...
                 'basis_poles should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_function,...
                ['When independently setting basis_realization, ',...
                 'basis_function should set empty (continuous-time)']);

    verifyEqual(testCase, mult.basis_realization, basis_realization)

    basis_realization = drss(4, 6, 1);
    while (~isstable(basis_realization))
        basis_realization = drss(4, 6, 1);
    end            
    mult = MultiplierSlti(del,...
              'basis_realization', basis_realization);                  
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting basis_realization, ',...
                 'basis_length should set empty (discrete-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting basis_realization, ',...
                 'basis_poles should set empty (discrete-time)']);
    verifyEmpty(testCase,...
                mult.basis_function,...
                ['When independently setting basis_realization, ',...
                 'basis_function should set empty (discrete-time)']);

    verifyEqual(testCase, mult.basis_realization, basis_realization)
end        

function testBasisRealizationErrors(testCase)
    del = DeltaSlti('test');

    br = ss(0.5, 1, 1, 0);
    verifyError(testCase,...
                @() MultiplierSlti(del,...
                                   'basis_realization', br,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable basis_realization (continuous-time)'])

    br = ss(-1.2, 1, 1, 0, []);
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'basis_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable basis_realization (discrete-time)'])

    br = drss(randi(4), randi(4), 2);
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'basis_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing a tf',...
                 'whose width is greater than 1'])

    br = drss(1);
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'basis_realization', br,...
                                  'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'discrete-time tf to a continuous-time multiplier'])

    br = rss(1);
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'basis_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'continuous-time tf to a discrete-time multiplier'])                      
end        

function testSetBlockRealization(testCase)
    dim_del = 3;
    del = DeltaSlti('test',dim_del);

    block_realization = drss(4, 6, dim_del);
    while (~isstable(block_realization))
        block_realization = drss(4, 6, dim_del);
    end            
    mult = MultiplierSlti(del,...
              'block_realization', block_realization);
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting block_realization, ',...
                 'basis_length should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting block_realization, ',...
                 'basis_poles should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_function,...
                ['When independently setting block_realization, ',...
                 'basis_function should set empty (continuous-time)'])
    verifyEmpty(testCase,...
                mult.basis_realization,...
                ['When independently setting block_realization, ',...
                 'basis_realization should set empty (continuous-time)'])

    verifyEqual(testCase, mult.block_realization, block_realization)

    block_realization = rss(4, 6, dim_del);
    while (~isstable(block_realization))
        block_realization = rss(4, 6, dim_del);
    end            
    mult = MultiplierSlti(del,...
              'block_realization', block_realization,...
              'discrete', false);                  
    verifyEmpty(testCase,...
                mult.basis_length,...
                ['When independently setting block_realization, ',...
                 'basis_length should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_poles,...
                ['When independently setting block_realization, ',...
                 'basis_poles should set empty (continuous-time)']);
    verifyEmpty(testCase,...
                mult.basis_function,...
                ['When independently setting block_realization, ',...
                 'basis_function should set empty (continuous-time)'])
    verifyEmpty(testCase,...
                mult.basis_realization,...
                ['When independently setting block_realization, ',...
                 'basis_realization should set empty (continuous-time)'])

    verifyEqual(testCase, mult.block_realization, block_realization)            

end        

function testBlockRealizationErrors(testCase)
    del = DeltaSlti('test');

    br = ss(0.5, 1, 1, 0);
    verifyError(testCase,...
                @() MultiplierSlti(del,...
                                   'block_realization', br,...
                                   'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable block_realization (continuous-time)'])

    br = ss(-1.2, 1, 1, 0, []);
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'block_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing',...
                 ' unstable block_realization (discrete-time)'])

    br = drss(1);
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'block_realization', br,...
                                  'discrete', false),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'discrete-time tf to a continuous-time multiplier'])

    br = rss(1);
    verifyError(testCase,...
                @()MultiplierSlti(del,...
                                  'block_realization', br),...
                ?MException,...
                ['Exception should be thrown for providing a ',...
                 'continuous-time tf to a discrete-time multiplier'])                      

    del = DeltaSlti('test', 3);
    br = drss(randi(4), randi(4), 4);
%     verifyError(testCase,...
%                 @()MultiplierSlti(del,...
%                                   'block_realization', br),...
%                 ?MException,...
%                 ['Exception should be thrown for providing a tf',...
%                  'whose width is greater than delta.dim_out'])                     
end       

function testConstraintParameters(testCase)
    del = DeltaSlti('test');
    constraint_q11_kyp = false;
    mult = MultiplierSlti(del, 'constraint_q11_kyp', constraint_q11_kyp);
    verifyEqual(testCase, mult.constraint_q11_kyp, constraint_q11_kyp);
    
    constraint_q12_kyp = true;
    mult = MultiplierSlti(del, 'constraint_q12_kyp', constraint_q12_kyp);
    verifyEqual(testCase, mult.constraint_q12_kyp, constraint_q12_kyp);
end

function testDeltaWithNonTrivialHorizonPeriod(testCase)
    % This test would have failed before addressing the fix for hotfix-022
    % The MultiplierSlti constructor must be able to accept DeltaSlti which
    % have horizon_periods that are not [0, 1].
    del = DeltaSlti('test');
    new_horizon_period = [3, 4];
    % Set delta to non-trivial horizon_period
    del = matchHorizonPeriod(del, new_horizon_period);
    mult = MultiplierSlti(del);
    verifyEqual(testCase, mult.dim_outin, del.dim_out)
    verifyEqual(testCase, mult.upper_bound, del.upper_bound)
    verifyEqual(testCase, mult.horizon_period, del.horizon_period)
end

function testFilterLft(testCase)
    del = DeltaSlti('test');
    mult = MultiplierSlti(del);
    filter = mult.filter_lft;
    verifyEqual(testCase, filter.a{1}, mult.filter.a{1});
    verifyEqual(testCase, filter.b{1}, [mult.filter.b1{1}, mult.filter.b2{1}])
    verifyEqual(testCase, filter.c{1}, [mult.filter.c1{1}; mult.filter.c2{1}])
    verifyEqual(testCase, filter.d{1}, [mult.filter.d11{1}, mult.filter.d12{1};
                                        mult.filter.d21{1}, mult.filter.d22{1}])
    verifyEqual(testCase, filter.horizon_period, mult.horizon_period)
end

function testTimeVaryingMultiplier(testCase)
    % This test would have failed before addressing the fix for hotfix-007
    del = DeltaSlti('test');
    horizon_period = [2, 5];
    del = del.matchHorizonPeriod(horizon_period);
    mult = MultiplierSlti(del); % This command would have failed in construction
end
end
end

%%  CHANGELOG
% Sep. 28, 2021 (v0.6.0)
% Aug. 26, 2021 (v.0.5.0): Initial release - Micah Fry (micah.fry@ll.mit.edu)