% patterns.pl — Canonical verb pattern registry
%
% Maps short pattern codes (used in kbase/sys/pat_net facts) to human-readable
% verb labels.  A code may cover multiple surface verbs (synonyms/variants).
% This file is the single source of truth for pattern abbreviations across all
% exercises and case studies.
%
% Format:  pattern(Code(), "verb_label")
%   Code  — 3-letter atom followed by () to match original SEMTEQ notation
%   label — canonical English verb string (lower-case)
%
% Additional classifications:
%   pattern_direction/2      — source | receptor | neutral object movement
%   pattern_workflow_gate/2  — gate-like patterns that set workflow access state

:- module(patterns, [
    pattern/2,          % +Code, ?Label
    pattern_atom/2,     % +Code, ?VerbAtom
    pattern_direction/2,
    pattern_workflow_gate/2,
    pattern_fundamental/2,  % +Code, ?Fundamental — Level-1 classification
    decision_gate_mode/2    % +Code, ?Mode — object_directed | action_directed
]).

:- use_module(cnl_ontology, [verb_pattern/2]).

pattern(lrn(), "learn").
pattern(rcv(),"receive").
pattern(rcv(),"clarify").
pattern(rcv(),"acquire").
pattern(gen(),"create").
pattern(gen(),"define").
pattern(gen(),"generate").
pattern(gen(),"re-create").
pattern(gen(),"recreate").
pattern(act(), "activate").
pattern(rvw(), "review").
pattern(mnt(), "monitor").
pattern(cmp(), "compare").
pattern(rcd(), "record").
pattern(sto(), "store").
pattern(isp(), "inspect").
pattern(auz(), "authorize").
pattern(cnf(),"confirm").
pattern(apr(),"approve").
pattern(dlv(),"deliver").
pattern(dlv(),"give").
pattern(dlv(),"bring").
pattern(ins(),"install").
pattern(rqs(),"request").
pattern(pik(),"pick up").
pattern(pik(),"pick_up").
pattern(pik(),"take").
pattern(pik(),"get").
pattern(snd(),"acknowledge").
pattern(snd(),"send").
pattern(snd(),"notify").
pattern(snd(),"explain").
pattern(mdf(),"simplify").
pattern(mdf(),"modify").
pattern(ord(),"order").
pattern(ofr(),"offer").
pattern(shp(),"ship").
pattern(znx(),"prepare for").
pattern(znx(),"expect").
pattern(xnx(),"idle").
pattern(pay(),"pay").
pattern(slc(),"select").
pattern(slc(),"choose").
pattern(pps(),"propose").
pattern(pps(),"declare").
pattern(plc(),"transfer").
pattern(plc(),"place").
pattern(cnn(),"connect").
pattern(cnn(),"link").
pattern(cnn(),"associate").
pattern(aut(),"authenticate").
pattern(shw(),"show").
pattern(stm(),"stream").
pattern(run(),"run").
pattern(rbt(),"reboot").
pattern(exp(),"export").
pattern(exp(),"duplicate").
pattern(imp(),"import").
pattern(has(),"has").

% ---------------------------------------------------------------------------
% Helper: lookup canonical atom used in action/7 Pattern slot from a code.
% This bridges the SEMTEQ code notation to the process_model.pl atom form.
% ---------------------------------------------------------------------------
pattern_atom(lrn(), learn).
pattern_atom(rcv(), receive).
pattern_atom(gen(), generate).
pattern_atom(act(), activate).
pattern_atom(rvw(), review).
pattern_atom(mnt(), monitor).
pattern_atom(cmp(), compare).
pattern_atom(rcd(), record).
pattern_atom(sto(), store).
pattern_atom(auz(), authorize).
pattern_atom(apr(), approve).
pattern_atom(dlv(), deliver).
pattern_atom(ins(), install).
pattern_atom(rqs(), request).
pattern_atom(snd(), send).
pattern_atom(snd(), notify).
pattern_atom(mdf(), modify).
pattern_atom(ofr(), offer).
pattern_atom(pay(), pay).
pattern_atom(slc(), select).
pattern_atom(plc(), transfer).
pattern_atom(cnn(), connect).
pattern_atom(aut(), authenticate).

% ---------------------------------------------------------------------------
% Object movement direction for each pattern code.
% Direction ∈ {source, receptor, neutral}
%   source   — the actor is the origin/provider of the object
%              (the object leaves the actor toward another party)
%   receptor — the actor gains/receives the object
%              (the object enters the actor from another party)
%   neutral  — the actor acts on the object without transferring it
%              (transform, execute, confirm, etc.)
% Used to accelerate action-ordering inference: a source event must precede
% the corresponding receptor event for the same object.
% ---------------------------------------------------------------------------
pattern_direction(lrn(), receptor).   % learner acquires knowledge/info
pattern_direction(rcv(), receptor).   % receiver gets the object
pattern_direction(gen(), source).     % generator creates/provides the object
pattern_direction(act(), neutral).    % activation changes workflow state in place
pattern_direction(rvw(), neutral).    % review evaluates in place
pattern_direction(mnt(), neutral).    % monitoring observes in place
pattern_direction(cmp(), neutral).    % comparison evaluates in place
pattern_direction(rcd(), neutral).    % recording captures state without transfer
pattern_direction(sto(), neutral).    % storing keeps object within controlled inventory
pattern_direction(isp(), neutral).    % inspection verifies current state
pattern_direction(auz(), neutral).    % authorization is a gate state, not transfer
pattern_direction(cnf(), neutral).    % confirmation — no object transfer
pattern_direction(apr(), neutral).    % approval — no object transfer
pattern_direction(dlv(), source).     % deliverer sends the object
pattern_direction(ins(), receptor).   % installer places object into target
pattern_direction(rqs(), receptor).   % requester tries to obtain
pattern_direction(pik(), receptor).   % picker-up gains the object
pattern_direction(snd(), source).     % sender dispatches the object
pattern_direction(mdf(), neutral).    % modifier transforms in place
pattern_direction(ord(), receptor).   % orderer requests to receive
pattern_direction(ofr(), source).     % offerer proposes/provides option
pattern_direction(shp(), source).     % shipper dispatches goods
pattern_direction(znx(), neutral).    % expectation / preparation
pattern_direction(xnx(), neutral).    % idle — no action
pattern_direction(pay(), receptor).   % payer gives money, receives goods/service
pattern_direction(slc(), neutral).    % selection — no transfer
pattern_direction(pps(), source).     % proposer issues declaration
pattern_direction(plc(), source).     % transfer moves object to recipient
pattern_direction(cnn(), neutral).    % connect — relational, no transfer
pattern_direction(aut(), neutral).    % authenticate — verification only
pattern_direction(shw(), source).     % show provides information/view
pattern_direction(stm(), source).     % stream continuously sends data
pattern_direction(run(), neutral).    % run executes — no object transfer
pattern_direction(rbt(), neutral).    % reboot — no object transfer
pattern_direction(exp(), source).     % export/duplicate provides output
pattern_direction(imp(), receptor).   % import receives from external source
pattern_direction(has(), neutral).    % structural/ontological membership

% ---------------------------------------------------------------------------
% Workflow gate classification for patterns whose outcome controls whether an
% object or permission becomes available for downstream steps.
% GateType ∈ {decision_gate, authorization_gate}
%   decision_gate     — explicit approve/confirm style branching
%   authorization_gate — access grant/deny branching
% These predicates are orthogonal to pattern_direction/2: a gate is about
% workflow state control, not physical object movement.
% ---------------------------------------------------------------------------
pattern_workflow_gate(cnf(), decision_gate).      % confirm => approved/rejected
pattern_workflow_gate(apr(), decision_gate).      % approve => approved/rejected
pattern_workflow_gate(aut(), authorization_gate). % authenticate => granted/denied
pattern_workflow_gate(auz(), authorization_gate). % authorize => granted/denied

% ---------------------------------------------------------------------------
% Level-1 fundamental pattern classification
% Delegates to cnl_ontology:verb_pattern/2 via the pattern_atom/2 bridge.
% Fundamental ∈ {creation, destruction, movement, info_processing,
%                process_control, perception, decision_gate}
%
% Summary table (code → fundamental):
%   gen() → creation        exp() → creation        pps() → creation
%   snd() → movement        dlv() → movement        shp() → movement
%   plc() → movement        shw() → movement        stm() → movement
%   ofr() → movement        rqs() → movement        rcv() → movement
%   ins() → movement        pik() → movement        ord() → movement
%   imp() → movement        pay() → movement
%   rvw() → info_processing mnt() → info_processing cmp() → info_processing
%   isp() → info_processing rcd() → info_processing sto() → info_processing
%   mdf() → info_processing slc() → info_processing cnn() → info_processing
%   has() → info_processing
%   act() → process_control run() → process_control rbt() → process_control
%   znx() → process_control xnx() → process_control
%   cnf() → decision_gate   apr() → decision_gate   auz() → decision_gate
%   aut() → decision_gate
%   lrn() → perception
% ---------------------------------------------------------------------------

%! pattern_fundamental(+Code, ?Fundamental:atom) is nondet.
%  Maps a pattern code (e.g. gen()) to its Level-1 fundamental via cnl_ontology.
%  Fails if the pattern atom has no verb_pattern/2 entry in the ontology.
pattern_fundamental(Code, Fundamental) :-
    pattern_atom(Code, Atom),
    verb_pattern(Atom, Fundamental).

%! decision_gate_mode(+Code, ?Mode:atom) is semidet.
%  Mode ∈ {object_directed, action_directed}.
%  object_directed  — the gate outcome attaches a disposition to the Object
%                     (confirm, approve, authorize, authenticate).
%  action_directed  — the gate outcome modifies the process plan itself
%                     (cancel, postpone, escalate, skip, defer).
%  Delegates to cnl_ontology:decision_gate_mode/2 via the pattern_atom/2 bridge.
decision_gate_mode(Code, Mode) :-
    pattern_atom(Code, Atom),
    cnl_ontology:decision_gate_mode(Atom, Mode).