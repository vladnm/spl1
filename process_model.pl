% Process Model - Top-level integration and testing module

:- module(process_model, [
    % Core ordering
    order_process/2,
    order_process/3,
    explain_ordering_failure/2,
    % Pattern classification
    action_pattern/2,
    causal_link/4,
    role_transition/4,
    requires_role/2,
    delivery_pattern/1,
    intake_pattern/1,
    lifecycle_stage/2,
    % Object lifecycle
    object_lifecycle_pattern/3,
    track_object_states/2,
    detect_missing_object_creation/2,
    infer_creation_action/3,
    object_state/2,
    % Gap analysis
    detect_object_existence_gaps/2,
    detect_object_access_gaps/2,
    build_actor_inventory/2,
    detect_missing_roles/2,
    detect_missing_actions/2,
    insert_action/3,
    % Knowledge / memory trace
    build_knowledge_trace/2,
    build_agent_memory_trace/2,
    verify_process_knowledge/2,
    cnl_physical_informational_reference/1,
    % Workflow gate recovery
    detect_workflow_gate_recovery_notes/2,
    detect_unreachable_workflow_gate_actions/2,
    % Process repair
    repair_process/2,
    repair_process_once/3,
    % Print / debug utilities
    print_numbered_process/2,
    print_repaired_process/2,
    print_knowledge_trace/1,
    debug_action/1,
    % Structured process actions
    flatten_process_actions/2,
    % Testable internal utilities (exported for test coverage)
    same_traceable_object/2,
    comparable_transition_value/1,
    extract_object_from_result/2,
    gap_resolved_by_future_action/3,
    effective_step_precedes/3,
    effective_object_sequence/3,
    process_start_step/2,
    build_object_sequence_edges/2,
    build_aux_actor_edges/2,
    build_temporal_ordering_edges/2,
    build_lifecycle_edges/2,
    build_compositional_ordering_edges/2,
    build_actor_serialisation_edges/2,
    resolve_conflicting_edges/2,
    priority_topo_sort_full/3,
    score_topo_candidate/4
]).

:- use_module(library(clpfd)).
:- use_module(library(lists)).
:- use_module(natural_language_parser).
:- use_module(process_ontology).
:- use_module('../data/patterns', [
    pattern/2,
    pattern_atom/2,
    pattern_direction/2,
    pattern_workflow_gate/2
]).
:- use_module('../data/cnl_ontology').
:- use_module('../data/transition_signatures', [transition_signature/3, transition_slot_map/4, transition_context/4, transition_context_count/3]).
:- use_module('../data/location_ontology', [
    location/3,
    location_type/2,
    location_actor/2,
    physical_location/1,
    virtual_location/1,
    aux_object_actor/2,
    aux_object_location/2,
    pattern_precondition/2,
    pattern_postcondition/2
]).
:- use_module('../data/time_ontology', [
    pattern_duration/2,
    duration_precedes/2,
    patterns_duration_ordered/2,
    temporal_constraint/4,
    aux_object_time/2,
    aux_object_time_bound/2,
    pattern_is_instant/1,
    pattern_is_slow/1
]).
:- use_module('../data/agent_classes', [agent_class/2]).
:- use_module('../data/object_ontology', [hasPart/2, hasPartTransitive/2]).

% ---------------------------------------------------------------------------
% CNL Ontology startup: log version and run consistency check
% ---------------------------------------------------------------------------

%! cnl_ontology_startup is det.
%  Runs at module load time.  Logs the loaded ontology version and checks
%  that every pattern atom in data/patterns.pl has a corresponding
%  verb_pattern/2 entry in data/cnl_ontology.pl.  Logs a warning for any
%  unmatched code so gaps are visible in the session output without aborting.
cnl_ontology_startup :-
    cnl_ontology_version(V),
    format("~n--- CNL ONTOLOGY LOADED  version: ~w ---~n", [V]),
    cnl_ontology_consistency_check.

%! cnl_ontology_consistency_check is det.
%  Verifies that every pattern atom from data/patterns.pl has a
%  verb_pattern/2 mapping in data/cnl_ontology.pl.
cnl_ontology_consistency_check :-
    findall(Atom, pattern_atom(_, Atom), RawAtoms),
    sort(RawAtoms, Atoms),
    findall(A, (member(A, Atoms), \+ verb_pattern(A, _)), Unmatched),
    (   Unmatched = []
    ->  writeln("CNL ontology consistency check: PASS — all pattern atoms mapped.")
    ;   format("CNL ontology consistency check: WARNING — unmapped pattern atoms: ~w~n",
               [Unmatched])
    ).

:- initialization(cnl_ontology_startup, now).

%! test_process_model is det.
%  Comprehensive test of process modeling with object lifecycle tracking.
test_process_model :-
    writeln('========================================'),
    writeln('PROCESS MODEL TEST WITH LIFECYCLE TRACKING'),
    writeln('========================================'),
    
    % Test scenario: incomplete process with missing object creation
    Actions = [
        % Missing creation of 'message' - should be detected and inferred
        action(a1, send, alice, email_system, message, bob, 'message:sent'),
        action(a2, receive, bob, email_client, message, '', 'message:received'),
        action(a3, review, bob, text_editor, message, '', 'message:reviewed'),
        action(a4, delete, bob, email_client, message, '', 'message:deleted')
    ],
    
    writeln('--- ORIGINAL ACTIONS (INCOMPLETE) ---'),
    maplist(debug_action, Actions),
    
    writeln(''),
    writeln('--- DETECTING MISSING OBJECT CREATIONS ---'),
    detect_missing_object_creation(Actions, MissingCreations),
    (MissingCreations \= [] ->
        writeln('Missing object creations detected:'),
        maplist(print_missing_creation, MissingCreations)
    ;   writeln('No missing object creations detected')
    ),
    
    writeln(''),
    writeln('--- TRACKING OBJECT LIFECYCLE STATES ---'),
    track_object_states(Actions, ObjectStates),
    maplist(print_object_state, ObjectStates),
    
    writeln(''),
    writeln('--- ENHANCED PROCESS ORDERING ---'),
    order_process(Actions, Ordered, Status),
    ( Status = success(_) ->
        print_numbered_process(Ordered, 1),
        writeln(''),
        writeln('--- LIFECYCLE ANALYSIS OF ORDERED PROCESS ---'),
        analyze_process_lifecycle(Ordered)
    ;   explain_ordering_failure(Status, Message),
        format('Enhanced ordering failed: ~w~n', [Message]),
        writeln('Enhanced ordering failed - trying debug...'),
        debug_ordering_failure(Actions)
    ).

%! debug_ordering_failure(+Actions:list) is det.
%  Debugs why process ordering failed.
debug_ordering_failure(Actions) :-
    order_process(Actions, _Ordered, Status),
    (   Status = failure(_),
        explain_ordering_failure(Status, Message) ->
        format('Failure reason: ~w~n', [Message])
    ;   true
    ),
    writeln('Debug: Detecting missing creations...'),
    detect_missing_object_creation(Actions, MissingCreations),
    length(MissingCreations, NumMissing),
    format('  Found ~w missing creations~n', [NumMissing]),
    
    writeln('Debug: Extracting inferred actions...'),
    extract_inferred_actions(MissingCreations, InferredActions),
    length(InferredActions, NumInferred),
    format('  Generated ~w inferred actions~n', [NumInferred]),
    
    writeln('Debug: Building enhanced graph...'),
    append(Actions, InferredActions, AllActions),
    (catch(build_enhanced_causal_graph(AllActions, Graph), Error,
           (format('Error building graph: ~w~n', [Error]), fail)) ->
        length(Graph, NumEdges),
        format('  Graph built with ~w edges~n', [NumEdges])
    ;   writeln('  Failed to build graph')
    ).

%! print_missing_creation(+MissingCreation:compound) is det.
%  Pretty prints a missing creation detection.
print_missing_creation(missing_creation(ObjectId, FirstAction, InferredAction)) :-
    FirstAction = action(FirstId, FirstPattern, _, _, _, _, _),
    InferredAction = action(_InfId, InfPattern, InfActor, InfTool, _, _, _),
    format('  Object ~w: first used in ~w (~w), inferred creation: ~w by ~w using ~w~n',
           [ObjectId, FirstId, FirstPattern, InfPattern, InfActor, InfTool]).

%! print_object_state(+ObjectState:compound) is det.
%  Pretty prints object state history.
print_object_state(object_state(ObjectId, States)) :-
    format('  Object ~w: ', [ObjectId]),
    print_state_history(States),
    nl.

%! print_state_history(+States:list) is det.
%  Prints a sequence of object states.
print_state_history([]).
print_state_history([state(Stage, Action, Actor)|Rest]) :-
    format('~w(~w,~w)', [Stage, Action, Actor]),
    (Rest \= [] -> format(' -> ', []) ; true),
    print_state_history(Rest).

%! analyze_process_lifecycle(+OrderedActions:list) is det.
%  Analyzes the lifecycle compliance of an ordered process.
analyze_process_lifecycle(Actions) :-
    track_object_states(Actions, _),
    findall(ObjectId, object_state(ObjectId, _), Objects),
    maplist(analyze_object_lifecycle, Objects).

%! analyze_object_lifecycle(+ObjectId:atom) is det.
%  Analyzes the lifecycle of a single object.
analyze_object_lifecycle(ObjectId) :-
    object_state(ObjectId, States),
    extract_stages(States, Stages),
    format('  ~w: lifecycle = ~w', [ObjectId, Stages]),
    (valid_lifecycle(Stages) ->
        format(' ✓ Valid~n', [])
    ;   format(' ✗ Invalid lifecycle sequence~n', [])
    ).

%! extract_stages(+States:list, -Stages:list) is det.
%  Extracts just the lifecycle stages from state history.
extract_stages([], []).
extract_stages([state(Stage, _, _)|Rest], [Stage|RestStages]) :-
    extract_stages(Rest, RestStages).

%! valid_lifecycle(+Stages:list) is semidet.
%  Checks if a sequence of lifecycle stages is valid.
%  Valid sequences: creation -> transformation* -> destruction?
valid_lifecycle([]).
valid_lifecycle([creation]).
valid_lifecycle([creation|Rest]) :-
    valid_transformation_sequence(Rest).

%! valid_transformation_sequence(+Stages:list) is semidet.
%  Validates transformation and destruction sequence.
valid_transformation_sequence([]).
valid_transformation_sequence([transformation|Rest]) :-
    valid_transformation_sequence(Rest).
valid_transformation_sequence([destruction]).
valid_transformation_sequence([destruction|Rest]) :-
    \+ member(creation, Rest),
    \+ member(transformation, Rest).

% ============================================================================
% SEMANTIC ROLE MODEL
% ============================================================================

% Action representation: action(Id, Pattern, Actor, Tool, Object, AuxObject, Result)
%
% Semantic role definitions:
% - Id: unique identifier
% - Pattern: semantic pattern name (send, receive, create, modify, etc.)
% - Actor: entity performing the action (WHO does it)
% - Tool: instrument/means used (HOW/WITH WHAT - can be actor themselves)
% - Object: primary entity being acted upon (WHAT is affected)
% - AuxObject: secondary entity - recipient, source, location (TO/FROM/WHERE)
% - Result: outcome as "object:state" (e.g., "message:sent", "document:approved")
%
% Example queries:
%   ?- action(a1, send, alice, email_system, message, bob, 'message:sent').
%   ?- action(a2, receive, bob, email_system, message, alice, 'message:received').

% ============================================================================
% SEMANTIC ROLE TRANSITIONS
% ============================================================================

%! role_transition(+Pattern1:atom, +Role1:atom, +Pattern2:atom, +Role2:atom) is det.
%  Defines how semantic roles transform between action patterns.
%  Used for process flow analysis and action chaining.
%
%  Example query:
%    ?- role_transition(send, actor, receive, AuxObject).
%    AuxObject = aux_object.
role_transition(send, actor, receive, aux_object).
role_transition(send, aux_object, receive, actor).
role_transition(send, object, receive, object).
role_transition(send, tool, receive, tool).

% Create-modify-approve transitions
role_transition(create, result, modify, object).
role_transition(modify, result, approve, object).
role_transition(approve, result, send, object).

% Tool consistency across actions
role_transition(_, tool, _, tool).

% ============================================================================
% ACTION PATTERNS
% ============================================================================

%! action_pattern(+Pattern:atom, +Description:string) is det.
%  Defines semantic action patterns with their natural language descriptions.
%
%  Example query:
%    ?- action_pattern(send, Description).
%    Description = 'Actor sends Object to AuxObject using Tool'.
action_pattern(send, 'Actor sends Object to AuxObject using Tool').
action_pattern(receive, 'Actor receives Object from AuxObject using Tool').
action_pattern(create, 'Actor creates Object using Tool from/with AuxObject').
action_pattern(modify, 'Actor modifies Object using Tool at AuxObject').
action_pattern(approve, 'Actor approves Object using Tool').
action_pattern(review, 'Actor reviews Object using Tool').
action_pattern(validate, 'Actor validates Object using Tool against AuxObject').
action_pattern(delete, 'Actor deletes Object using Tool').
action_pattern(transform, 'Actor transforms Object into Result using Tool').
action_pattern(authorize, 'Actor authorizes Object using Tool').
action_pattern(compile, 'Actor compiles Object using Tool').
action_pattern(execute, 'Actor executes Object using Tool').
action_pattern(deploy, 'Actor deploys Object using Tool to AuxObject').
action_pattern(test, 'Actor tests Object using Tool with AuxObject').
action_pattern(implement, 'Actor implements Object using Tool from AuxObject').
action_pattern(design, 'Actor designs Object using Tool').
action_pattern(analyze, 'Actor analyzes Object using Tool').
action_pattern(think, 'Actor thinks about Object (actor is tool)').
action_pattern(move, 'Actor moves Object using Tool to AuxObject').
action_pattern(place, 'Actor places Object using Tool at AuxObject').

% Additional business-relevant action patterns from WordNet analysis
action_pattern(schedule, 'Actor schedules Object using Tool at AuxObject').
action_pattern(plan, 'Actor plans Object using Tool based on AuxObject').
action_pattern(configure, 'Actor configures Object using Tool for AuxObject').
action_pattern(build, 'Actor builds Object using Tool from AuxObject').
action_pattern(integrate, 'Actor integrates Object using Tool with AuxObject').
action_pattern(backup, 'Actor backs up Object using Tool to AuxObject').
action_pattern(restore, 'Actor restores Object using Tool from AuxObject').
action_pattern(document, 'Actor documents Object using Tool in AuxObject').
action_pattern(version, 'Actor versions Object using Tool in AuxObject').
action_pattern(research, 'Actor researches Object using Tool via AuxObject').
action_pattern(prototype, 'Actor prototypes Object using Tool from AuxObject').
action_pattern(negotiate, 'Actor negotiates Object using Tool with AuxObject').
action_pattern(estimate, 'Actor estimates Object using Tool based on AuxObject').
action_pattern(monitor, 'Actor monitors Object using Tool via AuxObject').
action_pattern(optimize, 'Actor optimizes Object using Tool for AuxObject').
action_pattern(maintain, 'Actor maintains Object using Tool at AuxObject').
action_pattern(update, 'Actor updates Object using Tool with AuxObject').
action_pattern(install, 'Actor installs Object using Tool at AuxObject').
action_pattern(debug, 'Actor debugs Object using Tool to find AuxObject').
action_pattern(merge, 'Actor merges Object using Tool with AuxObject').
action_pattern(commit, 'Actor commits Object using Tool to AuxObject').
action_pattern(rollback, 'Actor rolls back Object using Tool to AuxObject').
action_pattern(select, 'Actor selects Object using Tool from AuxObject').
action_pattern(order, 'Actor orders Object using Tool from AuxObject').
action_pattern(notify, 'Actor notifies AuxObject about Object using Tool').
action_pattern(pickup, 'Actor picks up Object using Tool from AuxObject').
action_pattern(deliver, 'Actor delivers Object using Tool to AuxObject').
action_pattern(connect, 'Actor connects Object using Tool to AuxObject').
action_pattern(display, 'Actor displays Object using Tool to AuxObject').
action_pattern(stream, 'Actor streams Object using Tool to AuxObject').
action_pattern(request, 'Actor requests Object using Tool from AuxObject').
action_pattern(reboot, 'Actor reboots Object using Tool').
action_pattern(authenticate, 'Actor authenticates Object using Tool with AuxObject').
action_pattern(publish, 'Actor publishes Object using Tool to AuxObject').
action_pattern(archive, 'Actor archives Object using Tool in AuxObject').

% ============================================================================
% OBJECT LIFECYCLE PATTERNS
% ============================================================================

%! object_lifecycle_pattern(+Pattern:atom, +Stage:atom, +Description:string) is det.
%  Defines patterns that correspond to different stages of object lifecycle.
%  
%  Stages:
%  - creation: Object comes into existence
%  - transformation: Object changes state/form but continues to exist
%  - destruction: Object ceases to exist or becomes unusable
%
%  Example queries:
%    ?- object_lifecycle_pattern(create, Stage, Desc).
%    Stage = creation, Desc = 'Object is brought into existence'.
%
%    ?- object_lifecycle_pattern(Pattern, creation, _).
%    Pattern = create ; Pattern = generate ; Pattern = build ; ...

% CREATION PATTERNS - Object comes into existence
object_lifecycle_pattern(create, creation, 'Object is brought into existence').
object_lifecycle_pattern(generate, creation, 'Object is automatically produced').
object_lifecycle_pattern(build, creation, 'Object is constructed from components').
object_lifecycle_pattern(construct, creation, 'Object is assembled systematically').
object_lifecycle_pattern(manufacture, creation, 'Object is produced industrially').
object_lifecycle_pattern(produce, creation, 'Object is created as output').
object_lifecycle_pattern(make, creation, 'Object is crafted or formed').
object_lifecycle_pattern(establish, creation, 'Object is set up or founded').
object_lifecycle_pattern(initialize, creation, 'Object is set to initial state').
object_lifecycle_pattern(instantiate, creation, 'Object instance is created').
object_lifecycle_pattern(allocate, creation, 'Object resources are assigned').
object_lifecycle_pattern(spawn, creation, 'Object is created as subprocess').
object_lifecycle_pattern(fork, creation, 'Object is created by duplication').
object_lifecycle_pattern(clone, creation, 'Object is created as exact copy').
object_lifecycle_pattern(write, creation, 'Object (text/data) is authored').
object_lifecycle_pattern(compose, create, 'Object is created by composition').
object_lifecycle_pattern(draft, creation, 'Object is created as preliminary version').
object_lifecycle_pattern(prepare, creation, 'Object is created through preparation').

% TRANSFORMATION PATTERNS - Object changes but continues to exist
object_lifecycle_pattern(modify, transformation, 'Object is altered while maintaining identity').
object_lifecycle_pattern(transform, transformation, 'Object changes form or structure').
object_lifecycle_pattern(convert, transformation, 'Object is changed to different format').
object_lifecycle_pattern(adapt, transformation, 'Object is adjusted to new requirements').
object_lifecycle_pattern(update, transformation, 'Object is brought to current state').
object_lifecycle_pattern(edit, transformation, 'Object content is changed').
object_lifecycle_pattern(revise, transformation, 'Object is improved or corrected').
object_lifecycle_pattern(refactor, transformation, 'Object structure is reorganized').
object_lifecycle_pattern(optimize, transformation, 'Object performance is improved').
object_lifecycle_pattern(enhance, transformation, 'Object capabilities are expanded').
object_lifecycle_pattern(upgrade, transformation, 'Object is improved to newer version').
object_lifecycle_pattern(downgrade, transformation, 'Object is reverted to older version').
object_lifecycle_pattern(migrate, transformation, 'Object is moved to new environment').
object_lifecycle_pattern(translate, transformation, 'Object is converted to different language').
object_lifecycle_pattern(encode, transformation, 'Object is converted to encoded form').
object_lifecycle_pattern(decode, transformation, 'Object is converted from encoded form').
object_lifecycle_pattern(compress, transformation, 'Object size is reduced').
object_lifecycle_pattern(decompress, transformation, 'Object is expanded from compressed form').
object_lifecycle_pattern(encrypt, transformation, 'Object is secured through encryption').
object_lifecycle_pattern(decrypt, transformation, 'Object is recovered from encrypted form').
object_lifecycle_pattern(merge, transformation, 'Object is combined with other objects').
object_lifecycle_pattern(split, transformation, 'Object is divided into parts').
object_lifecycle_pattern(normalize, transformation, 'Object is standardized to normal form').
object_lifecycle_pattern(validate, transformation, 'Object correctness is verified').
object_lifecycle_pattern(approve, transformation, 'Object status changes to approved').
object_lifecycle_pattern(reject, transformation, 'Object status changes to rejected').
object_lifecycle_pattern(sign, transformation, 'Object receives digital signature').
object_lifecycle_pattern(compile, transformation, 'Object (source) is converted to executable').
object_lifecycle_pattern(parse, transformation, 'Object is analyzed and structured').
object_lifecycle_pattern(format, transformation, 'Object appearance is standardized').
object_lifecycle_pattern(repair, transformation, 'Object defects are corrected').
object_lifecycle_pattern(restore, transformation, 'Object is returned to previous state').

% DESTRUCTION PATTERNS - Object ceases to exist or becomes unusable
object_lifecycle_pattern(delete, destruction, 'Object is removed from existence').
object_lifecycle_pattern(remove, destruction, 'Object is taken away or eliminated').
object_lifecycle_pattern(destroy, destruction, 'Object is completely eliminated').
object_lifecycle_pattern(erase, destruction, 'Object traces are completely removed').
object_lifecycle_pattern(purge, destruction, 'Object is thoroughly eliminated').
object_lifecycle_pattern(expire, destruction, 'Object becomes invalid due to time').
object_lifecycle_pattern(terminate, destruction, 'Object execution is ended').
object_lifecycle_pattern(kill, destruction, 'Object process is forcibly ended').
object_lifecycle_pattern(abort, destruction, 'Object operation is cancelled').
object_lifecycle_pattern(cancel, destruction, 'Object is revoked or invalidated').
object_lifecycle_pattern(discard, destruction, 'Object is thrown away as unwanted').
object_lifecycle_pattern(retire, destruction, 'Object is withdrawn from active use').
object_lifecycle_pattern(obsolete, destruction, 'Object becomes outdated and unusable').
object_lifecycle_pattern(deprecate, destruction, 'Object is marked for future removal').
object_lifecycle_pattern(uninstall, destruction, 'Object is removed from system').
object_lifecycle_pattern(deallocate, destruction, 'Object resources are released').
object_lifecycle_pattern(free, destruction, 'Object memory/resources are released').
object_lifecycle_pattern(close, destruction, 'Object connection/session is ended').
object_lifecycle_pattern(disconnect, destruction, 'Object link is severed').
object_lifecycle_pattern(logout, destruction, 'Object session is terminated').
object_lifecycle_pattern(shutdown, destruction, 'Object system is powered down').
object_lifecycle_pattern(cleanup, destruction, 'Object temporary data is removed').
object_lifecycle_pattern(archive, destruction, 'Object is moved to inactive storage').

% Additional transformation patterns from parser testing
object_lifecycle_pattern(select, transformation, 'Object is chosen from available options').
object_lifecycle_pattern(order, transformation, 'Object is arranged or requested').
object_lifecycle_pattern(notify, transformation, 'Object state change is communicated').
object_lifecycle_pattern(pickup, transformation, 'Object is physically collected').
object_lifecycle_pattern(deliver, transformation, 'Object is transported to destination').
object_lifecycle_pattern(connect, transformation, 'Object is linked to another entity').
object_lifecycle_pattern(display, transformation, 'Object is made visible/accessible').
object_lifecycle_pattern(stream, transformation, 'Object is transmitted continuously').
object_lifecycle_pattern(request, transformation, 'Object is solicited or demanded').
object_lifecycle_pattern(reboot, transformation, 'Object is restarted or refreshed').
object_lifecycle_pattern(authenticate, transformation, 'Object is verified or validated').

%! lifecycle_stage(+Pattern:atom, ?Stage:atom) is det.
%  Convenience predicate to get the lifecycle stage of an action pattern.
%
%  Example query:
%    ?- lifecycle_stage(create, Stage).
%    Stage = creation.
%  Primary clause: patterns registered as 'creation' in cnl_ontology are
%  resolved data-driven.  This supersedes hard-coded creation entries in
%  object_lifecycle_pattern/3 for all CNL-registered pattern codes.
lifecycle_stage(P, creation) :-
    is_creation(P), !.
%  Fallback: surface verbs from the natural language parser (not in the CNL
%  registry) resolve via the hand-authored object_lifecycle_pattern/3 table.
lifecycle_stage(Pattern, Stage) :-
    object_lifecycle_pattern(Pattern, Stage, _).

% ============================================================================
% REQUIRED SEMANTIC ROLES
% ============================================================================

%! requires_role(+Pattern:atom, +Role:atom) is det.
%  Defines which semantic roles are required for each action pattern.
%
%  Example query:
%    ?- requires_role(send, Role).
%    Role = actor ;
%    Role = object ;
%    Role = tool ;
%    Role = aux_object ;
%    Role = result.
requires_role(Pattern, actor) :- action_pattern(Pattern, _).
requires_role(Pattern, object) :-
    member(Pattern, [send, receive, create, modify, approve, review, validate,
                     delete, transform, compile, execute, deploy, test,
                     implement, design, analyze, think, move, place,
                     schedule, plan, configure, build, integrate, backup, restore,
                     document, version, research, prototype, negotiate, estimate,
                     monitor, optimize, maintain, update, install, debug,
                     merge, commit, rollback, publish, archive]).
requires_role(Pattern, tool) :- action_pattern(Pattern, _).
requires_role(Pattern, aux_object) :-
    member(Pattern, [send, receive, deploy, test, move, place, schedule,
                     configure, backup, restore, document, version, research,
                     prototype, negotiate, estimate, monitor, optimize,
                     maintain, update, install, debug, merge, commit,
                     rollback, publish, archive]).
requires_role(Pattern, result) :- action_pattern(Pattern, _).

% ============================================================================
% CAUSAL LINKS AND PROBABILITIES
% ============================================================================

%! causal_link(+Pattern1:atom, +Pattern2:atom, +RoleFlow:compound, +Probability:float) is det.
%  Defines causal links between action patterns with semantic role flow and transition probabilities.
%
%  Example query:
%    ?- causal_link(create, modify, Flow, Prob).
%    Flow = flow(result, object),
%    Prob = 0.7.
causal_link(create, modify, flow(result, object), 0.7).
causal_link(create, review, flow(result, object), 0.8).
causal_link(create, send, flow(result, object), 0.6).
causal_link(modify, review, flow(result, object), 0.75).
causal_link(modify, approve, flow(result, object), 0.65).
causal_link(review, modify, flow(result, object), 0.5).
causal_link(review, approve, flow(result, object), 0.8).
causal_link(approve, send, flow(result, object), 0.85).
causal_link(send, receive, flow(result, object), 0.95).
causal_link(receive, review, flow(result, object), 0.7).
causal_link(receive, modify, flow(result, object), 0.6).
causal_link(validate, approve, flow(result, object), 0.8).
causal_link(design, implement, flow(result, object), 0.85).
causal_link(implement, test, flow(result, object), 0.9).
causal_link(test, deploy, flow(result, object), 0.85).
causal_link(compile, execute, flow(result, object), 0.9).
causal_link(analyze, design, flow(result, object), 0.75).

% Additional causal links from WordNet-filtered business processes
% High-priority business workflow patterns (0.8-0.95)
causal_link(schedule, execute, flow(result, object), 0.85).
causal_link(plan, execute, flow(result, object), 0.8).
causal_link(plan, schedule, flow(result, object), 0.82).
causal_link(configure, deploy, flow(result, object), 0.85).
causal_link(build, test, flow(result, object), 0.9).
causal_link(integrate, test, flow(result, object), 0.85).
causal_link(backup, restore, flow(result, object), 0.95).
causal_link(document, review, flow(result, object), 0.8).
causal_link(version, deploy, flow(result, object), 0.8).

% Medium-priority workflow patterns (0.6-0.75)
causal_link(research, design, flow(result, object), 0.7).
causal_link(research, plan, flow(result, object), 0.65).
causal_link(prototype, test, flow(result, object), 0.7).
causal_link(negotiate, approve, flow(result, object), 0.65).
causal_link(estimate, plan, flow(result, object), 0.6).
causal_link(monitor, analyze, flow(result, object), 0.7).
causal_link(optimize, deploy, flow(result, object), 0.65).

% Software development specific patterns (0.75-0.9)
causal_link(debug, test, flow(result, object), 0.8).
causal_link(merge, build, flow(result, object), 0.85).
causal_link(commit, merge, flow(result, object), 0.75).
causal_link(commit, build, flow(result, object), 0.8).
causal_link(rollback, restore, flow(result, object), 0.9).
causal_link(install, configure, flow(result, object), 0.85).
causal_link(update, test, flow(result, object), 0.8).
causal_link(publish, deploy, flow(result, object), 0.88).

% Maintenance and documentation patterns (0.5-0.7)
causal_link(maintain, update, flow(result, object), 0.6).
causal_link(archive, document, flow(result, object), 0.5).
causal_link(validate, document, flow(result, object), 0.65).

% -----------------------------------------------------------------------
% Windows Anytime Upgrade domain (2009 case study)
%   Original 5 patterns: simplify, receive, pay, activate, install
%   Inferred bridges:    send (receive←send), learn (pay←learn),
%                        run (install←run),   generate (learn←generate),
%                        transfer (simplify←transfer)
% -----------------------------------------------------------------------
% Distribution / delivery chain
causal_link(transfer,  simplify,  flow(result, object), 0.70). % w10→w1
causal_link(simplify,  send,      flow(result, object), 0.80). % w1→w6
causal_link(send,      receive,   flow(result, object), 0.95). % w6→w2  (also in general section)
% Payment / commerce chain
causal_link(receive,   generate,  flow(result, object), 0.60). % w2→w9
causal_link(generate,  learn,     flow(result, object), 0.90). % w9→w7
causal_link(generate,  pay,       flow(result, object), 0.70). % w9→w3 (bridge: receive→pay)
causal_link(learn,     pay,       flow(result, object), 0.90). % w7→w3
% Software installation chain
causal_link(pay,       run,       flow(result, object), 0.80). % w3→w8
causal_link(run,       install,   flow(result, object), 0.90). % w8→w5
causal_link(install,   activate,  flow(result, object), 0.95). % w5→w4
% Bridge pairs used by find_bridge_pattern in single-step gap detection
causal_link(simplify,  receive,   flow(result, object), 0.65). % bridge via send
causal_link(receive,   pay,       flow(result, object), 0.55). % bridge via learn
causal_link(pay,       install,   flow(result, object), 0.60). % bridge via run

% Cross-pattern connections for comprehensive workflow
causal_link(design, prototype, flow(result, object), 0.75).
causal_link(analyze, research, flow(result, object), 0.7).
causal_link(execute, monitor, flow(result, object), 0.7).
causal_link(deploy, monitor, flow(result, object), 0.8).
causal_link(approve, schedule, flow(result, object), 0.75).

% ============================================================================
% OBJECT LIFECYCLE TRACKING
% ============================================================================

%! object_state(+ObjectId:atom, +State:compound) is det.
%  Represents the state of an object throughout its lifecycle.
%  State is represented as state(Stage, Action, Actor) where:
%  - Stage: creation | transformation | destruction  
%  - Action: the action that put object in this state
%  - Actor: who performed the action
%
%  This is a dynamic predicate that gets asserted during process analysis.
:- dynamic object_state/2.

%! process_goal(?ProcessId, ?Agent, ?Object, ?State) is nondet.
%  Structured process goal declarations contributed by process library files
%  via the multifile mechanism (e.g., process_model:process_goal(sales, ...)).
%  build_process_goal_edges/2 calls this directly as a right-boundary ordering
%  anchor (§4.13 of the CNL Publication Draft).
:- multifile process_goal/4.
:- dynamic   process_goal/4.

%! process_subgoal(?ProcessId, ?SubGoalId, ?PrerequisiteStepPattern, ?Justification) is nondet.
%  Declares a named sub-goal and identifies which step results (Result atoms)
%  must be achieved before the sub-goal's downstream steps can begin.
%
%  SubGoalId:     a unique atom identifying this sub-goal in the process
%  PrerequisiteStepPattern: a Result atom pattern matched via same_traceable_object/2
%                 against action Results.  Any step producing a Result that
%                 matches is a prerequisite for every step consuming the sub-goal's
%                 output.
%  Justification: same vocabulary as process_step_precedes/4.
%
%  The engine's build_subgoal_ordering_edges/2 translates these declarations
%  into weight-1.0 edges from all prerequisite steps to all steps that are
%  tagged as dependent on the sub-goal via process_subgoal_consumer/3.
:- multifile process_subgoal/4.
:- dynamic   process_subgoal/4.

%! process_subgoal_consumer(?ProcessId, ?SubGoalId, ?ConsumePattern) is nondet.
%  Declares that a step whose Result matches ConsumePattern is a CONSUMER of
%  the named sub-goal — i.e., it cannot begin until all sub-goal prerequisites
%  have been satisfied.
:- multifile process_subgoal_consumer/3.
:- dynamic   process_subgoal_consumer/3.

%! object_sequence(?ObjA:atom, before, ?ObjB:atom) is nondet.
%  Declares that ObjA is semantically available (created, received, or delivered)
%  BEFORE ObjB in the process domain.  This is a domain-ontological fact that
%  cannot be derived from pattern-level causal links, transition signatures,
%  or lifecycle constraints alone — it encodes knowledge about the ORDER in
%  which objects become available across independent sub-chains.
%
%  Semantics: every step whose primary Object slot matches ObjA must precede
%  every step whose primary Object slot matches ObjB.
%
%  Weight 0.97 in build_object_sequence_edges/2 — above temporal constraints
%  (0.95) so this wins conflict resolution for cross-object pairs where generic
%  backward edges (send→receive at 0.95) would otherwise dominate.
%
%  Two scopes:
%   - Universal (declared here in process_model.pl): hold across all domains
%     where both objects appear.
%   - Process-specific (declared in process library files via multifile):
%     encode checkout UX conventions, legal ordering, etc.
%
%  Justification term (optional 4-arity form):
%    object_sequence(A, before, B, Justification)
%  Uses the same vocabulary as process_step_precedes/4.
:- multifile object_sequence/3.
:- dynamic   object_sequence/3.
:- multifile object_sequence/4.
:- dynamic   object_sequence/4.

%! effective_object_sequence(?ObjA:atom, before, ?ObjB:atom) is nondet.
%  Unified accessor: covers both 3-arity and 4-arity forms.
effective_object_sequence(A, before, B) :- object_sequence(A, before, B).
effective_object_sequence(A, before, B) :- object_sequence(A, before, B, _).

%! process_step_precedes(?ProcessId, ?StepIdA, ?StepIdB) is nondet.
%  Explicit process-level sequencing constraint declared in process library files.
%  Asserts that step StepIdA must always come before StepIdB in the process
%  timeline, independent of any transition signature or causal link.
%  Contributes weight-1.0 edges in build_enhanced_causal_graph/2.
%
%  3-arity form (legacy / location-not-yet-annotated):
%    process_step_precedes(ProcessId, StepA, StepB)
%
%  4-arity form with justification (preferred — makes the constraint auditable
%  and enables automatic migration toward derived location/time constraints):
%    process_step_precedes(ProcessId, StepA, StepB, Justification)
%
%  Justification vocabulary:
%    location_convergence(LocA, LocB)  — both steps converge at the same
%                                        physical actor/location pair
%    temporal_bound(Pattern, Bound)    — temporal_constraint/4 bound applies
%    business_convention(Reason)       — domain-specific ordering convention
%    legal_requirement(Ref)            — regulatory or contractual ordering
%    goal_prerequisite(SubGoalId)      — required before a named sub-goal
%    object_composition(Part, Whole)   — Part must exist before Whole is used
:- multifile process_step_precedes/3.
:- dynamic   process_step_precedes/3.
:- multifile process_step_precedes/4.
:- dynamic   process_step_precedes/4.

%! process_start_step(?ProcessId, ?StepId) is nondet.
%  Declares the canonical first step of a process.  Loaded from process library
%  files via multifile.  When the priority topo sort starts (LastId=none),
%  a declared start step scores 10 — above all other source-node tie-breakers —
%  so it is always chosen first regardless of shuffled input order.
:- multifile process_start_step/2.
:- dynamic   process_start_step/2.

%! effective_step_precedes(?ProcessId, ?StepA, ?StepB) is nondet.
%  Unified accessor: true when either the 3-arity or 4-arity form declares
%  StepA precedes StepB in ProcessId.  Used by build_process_step_precedes_edges/2.
effective_step_precedes(P, A, B) :- process_step_precedes(P, A, B).
effective_step_precedes(P, A, B) :- process_step_precedes(P, A, B, _).

%! track_object_states(+Actions:list, -ObjectStates:list) is det.
%  Analyzes a list of actions and tracks the lifecycle states of all objects.
%  Returns a list of object_state(ObjectId, StateHistory) facts.
%
%  Example query:
%    ?- track_object_states([action(a1,create,alice,tool,doc,'',doc_v1),
%                           action(a2,modify,bob,editor,doc_v1,'',doc_v2)], States).
%    States = [object_state(doc, [state(creation,a1,alice)]),
%              object_state(doc_v1, [state(creation,a1,alice)]),
%              object_state(doc_v2, [state(transformation,a2,bob)])].
track_object_states(Actions, ObjectStates) :-
    % Clear previous states
    retractall(object_state(_, _)),
    % Process each action
    maplist(process_action_for_objects, Actions),
    % Collect all object states
    findall(object_state(Obj, States), 
            (object_state(Obj, States), States \= []), 
            ObjectStates).

%! process_action_for_objects(+Action:compound) is det.
%  Processes a single action to update object states.
%  
%  For each object mentioned in the action (Object, AuxObject, Result):
%  - Determines the lifecycle stage based on action pattern
%  - Updates the object's state history
process_action_for_objects(action(Id, Pattern, Actor, _Tool, Object, AuxObject, Result)) :-
    % Determine lifecycle stage for this pattern
    (lifecycle_stage(Pattern, Stage) -> true ; Stage = transformation),
    
    % Update object state (main object being acted upon)
    (Object \= '', Object \= 'unspecified' ->
        update_object_state(Object, state(Stage, Id, Actor))
    ; true),
    
    % Update auxiliary object state (if involved)
    (AuxObject \= '', AuxObject \= 'unspecified' ->
        update_object_state(AuxObject, state(Stage, Id, Actor))
    ; true),
    
    % Update result object state (if it's a new object)
    (Result \= '', Result \= 'unspecified', Result \= Object ->
        update_object_state(Result, state(creation, Id, Actor))
    ; true).

%! update_object_state(+ObjectId:atom, +NewState:compound) is det.
%  Updates the state history of an object.
%  If object doesn't exist yet, creates new state list.
%  Otherwise appends to existing state history.
update_object_state(ObjectId, NewState) :-
    (retract(object_state(ObjectId, CurrentStates)) ->
        append(CurrentStates, [NewState], UpdatedStates)
    ;   UpdatedStates = [NewState]
    ),
    asserta(object_state(ObjectId, UpdatedStates)).

%! detect_missing_object_creation(+Actions:list, -MissingCreations:list) is det.
%  Detects objects that are used but never created in the given action list.
%  Returns a list of missing_creation(ObjectId, FirstUsageAction, InferredCreation).
%
%  Example query:
%    ?- detect_missing_object_creation([action(a1,send,alice,email,message,bob,'')], Missing).
%    Missing = [missing_creation(message, a1, action(generated_id,write,alice,editor,message,'',message))].
detect_missing_object_creation(Actions, MissingCreations) :-
    track_object_states(Actions, _),
    findall(missing_creation(ObjectId, FirstAction, InferredAction),
            (find_uncreated_object(Actions, ObjectId, FirstAction),
             infer_creation_action(ObjectId, FirstAction, InferredAction)),
            MissingCreations).

%! find_uncreated_object(+Actions:list, -ObjectId:atom, -FirstUsageAction:compound) is nondet.
%  Finds objects that are used but have no creation action.
%  Succeeds for each such object, returning the first action that uses it.
find_uncreated_object(Actions, ObjectId, FirstAction) :-
    % Find an object that is used in the process
    member(Action, Actions),
    action_uses_object(Action, ObjectId),
    % Check that this object is never created in any action
    \+ object_has_creation_action(Actions, ObjectId),
    % Keep only the first usage to avoid duplicate inferred creations
    first_object_usage(Actions, ObjectId, FirstAction),
    Action == FirstAction.

%! first_object_usage(+Actions:list, +ObjectId:atom, -FirstAction:compound) is semidet.
%  Finds the first action in the process that uses ObjectId.
first_object_usage([Action|_], ObjectId, Action) :-
    action_uses_object(Action, ObjectId), !.
first_object_usage([_|Rest], ObjectId, FirstAction) :-
    first_object_usage(Rest, ObjectId, FirstAction).

%! action_uses_object(+Action:compound, ?ObjectId:atom) is nondet.
%  True if Action uses ObjectId as Object or AuxObject (but not as Result).
%  Enhanced to extract base object names and filter out actors/people.
action_uses_object(action(_, _, Actor, _, Object, AuxObject, _), ObjectId) :-
    (   % Check main object (not the actor)
        (Object \= '', Object \= 'unspecified', Object \= Actor,
         \+ is_person_name(Object),
         extract_base_object_name(Object, ObjectId))
    ;   % Check auxiliary object (not the actor, and only if it's not a person)
        (AuxObject \= '', AuxObject \= 'unspecified', AuxObject \= Actor,
         \+ is_person_name(AuxObject),
         extract_base_object_name(AuxObject, ObjectId))
    ).

%! is_person_name(+Name:atom) is semidet.
%  Heuristic to detect if a name refers to a person/actor rather than an object.
is_person_name(Name) :-
    atom_string(Name, NameStr),
    (   % Common person names
        member(NameStr, ["alice", "bob", "charlie", "dave", "eve", "frank", 
                        "grace", "henry", "ivan", "jane", "kate", "larry",
                        "mary", "nancy", "oscar", "paul", "queen", "robert",
                        "susan", "tom", "ursula", "victor", "wendy", "xavier",
                        "yvonne", "zachary"])
    ;   % Pattern: single word starting with capital letter (common name pattern)
        atom_length(Name, Len), Len =< 15,
        atom_codes(Name, [FirstCode|RestCodes]),
        FirstCode >= 65, FirstCode =< 90,  % Capital letter
        \+ member(46, RestCodes),          % No dots (not file extension)
        \+ member(95, RestCodes)           % No underscores (not variable name)
    ).

%! extract_base_object_name(+ObjectRef:atom, -BaseName:atom) is det.
%  Extracts base object name from references like "object:state" -> "object".
extract_base_object_name(ObjectRef, BaseName) :-
    atom(ObjectRef),
    (atomic_list_concat([BaseName, _State], ':', ObjectRef) -> true ; BaseName = ObjectRef).

%! object_has_creation_action(+Actions:list, +ObjectId:atom) is semidet.
%  True if ObjectId is created by some action in the list.
%  Enhanced to consider base object names.
object_has_creation_action(Actions, ObjectId) :-
    member(action(_, Pattern, _, _, Object, _, Result), Actions),
    lifecycle_stage(Pattern, creation),
    (   % Check if this action creates the object as result
        (Result \= '', Result \= 'unspecified',
         extract_base_object_name(Result, ObjectId))
    ;   % Check if this action creates the object directly
        (Object \= '', Object \= 'unspecified',
         extract_base_object_name(Object, ObjectId))
    ).

%! infer_creation_action(+ObjectId:atom, +FirstUsageAction:compound, -InferredAction:compound) is det.
%  Infers a plausible creation action for an uncreated object.
%  Uses heuristics based on object type and first usage context.
%
%  Example:
%    Object "message" first used in "send" -> infer "write" action
%    Object "document" first used in "review" -> infer "create" action
infer_creation_action(ObjectId, FirstUsageAction, InferredAction) :-
    FirstUsageAction = action(_, Pattern, Actor, Tool, _Object, _AuxObject, _Result),
    
    % Generate unique ID for inferred action
    atom_concat('inferred_', ObjectId, BaseId),
    gensym(BaseId, InferredId),
    
    % Determine creation pattern based on object type and first usage
    infer_creation_pattern(ObjectId, Pattern, CreationPattern),
    
    % Determine creator (usually same as first user, but can be inferred)
    infer_creator(ObjectId, Actor, Pattern, Creator),
    
    % Determine creation tool
    infer_creation_tool(ObjectId, CreationPattern, Tool, CreationTool),
    
    % Build inferred action
    InferredAction = action(InferredId, CreationPattern, Creator, CreationTool, 
                           ObjectId, 'unspecified', ObjectId).

%! infer_creation_pattern(+ObjectId:atom, +FirstUsagePattern:atom, -CreationPattern:atom) is det.
%  Infers the most likely creation pattern based on object name and first usage.
infer_creation_pattern(ObjectId, FirstUsage, CreationPattern) :-
    atom_string(ObjectId, ObjectStr),
    (   % Text/document objects
        (sub_string(ObjectStr, _, _, _, "message") ; 
         sub_string(ObjectStr, _, _, _, "text") ;
         sub_string(ObjectStr, _, _, _, "document") ;
         sub_string(ObjectStr, _, _, _, "letter") ;
         sub_string(ObjectStr, _, _, _, "email")) ->
        CreationPattern = write
    ;   % Code/software objects  
        (sub_string(ObjectStr, _, _, _, "code") ;
         sub_string(ObjectStr, _, _, _, "program") ;
         sub_string(ObjectStr, _, _, _, "script") ;
         sub_string(ObjectStr, _, _, _, "software")) ->
        CreationPattern = develop
    ;   % Data/file objects
        (sub_string(ObjectStr, _, _, _, "data") ;
         sub_string(ObjectStr, _, _, _, "file") ;
         sub_string(ObjectStr, _, _, _, "record")) ->
        CreationPattern = generate
    ;   % Reports/analysis objects
        (sub_string(ObjectStr, _, _, _, "report") ;
         sub_string(ObjectStr, _, _, _, "analysis") ;
         sub_string(ObjectStr, _, _, _, "summary")) ->
        CreationPattern = prepare
    ;   % Modification context → object must have come from somewhere external
        member(FirstUsage, [simplify, modify, transform, adapt, update, refactor]) ->
        CreationPattern = transfer
    ;   % Receive context → a prior send/deliver must exist
        member(FirstUsage, [receive, accept, take, get, acquire]) ->
        CreationPattern = send
    ;   % Distribution/version objects → external transfer
        (sub_string(ObjectStr, _, _, _, "distribution") ;
         sub_string(ObjectStr, _, _, _, "version") ;
         sub_string(ObjectStr, _, _, _, "release") ;
         sub_string(ObjectStr, _, _, _, "package")) ->
        CreationPattern = transfer
    ;   % Payment / pricing objects — must be generated first
        (sub_string(ObjectStr, _, _, _, "payment") ;
         sub_string(ObjectStr, _, _, _, "price") ;
         sub_string(ObjectStr, _, _, _, "key")) ->
        CreationPattern = generate
    ;   % Based on first usage pattern (send/deliver → something was written first)
        member(FirstUsage, [send, deliver]) ->
        CreationPattern = write
    ;   member(FirstUsage, [review, approve, validate]) ->
        CreationPattern = create
    ;   member(FirstUsage, [execute, run, deploy]) ->
        CreationPattern = build
    ;   % Default creation pattern
        CreationPattern = create
    ).

%! infer_creator(+ObjectId:atom, +FirstUser:atom, +FirstUsagePattern:atom, -Creator:atom) is det.
%  Infers who likely created the object based on first user and usage pattern.
infer_creator(_ObjectId, FirstUser, FirstUsage, Creator) :-
    (   % For communication objects, sender usually creates
        member(FirstUsage, [send, deliver, forward]) ->
        Creator = FirstUser
    ;   % For review/approval, creator is usually different
        member(FirstUsage, [review, approve, validate]) ->
        Creator = 'unspecified_author'
    ;   % Default: first user is likely creator
        Creator = FirstUser
    ).

%! infer_creation_tool(+ObjectId:atom, +CreationPattern:atom, +ContextTool:atom, -CreationTool:atom) is det.
%  Infers the most appropriate tool for creating the object.
infer_creation_tool(_ObjectId, CreationPattern, ContextTool, CreationTool) :-
    (   CreationPattern = write ->
        CreationTool = text_editor
    ;   CreationPattern = develop ->
        CreationTool = ide
    ;   CreationPattern = generate ->
        CreationTool = generator
    ;   CreationPattern = build ->
        CreationTool = build_system
    ;   CreationPattern = create ->
        (ContextTool \= '', ContextTool \= 'unspecified' ->
            CreationTool = ContextTool
        ;   CreationTool = 'creation_tool'
        )
    ;   CreationTool = 'unspecified_tool'
    ).

% ============================================================================
% PROCESS ORDERING
% ============================================================================

%! order_process(+UnorderedActions:list, -OrderedActions:list) is det.
%  Orders actions based on causal links and semantic role flow.
%
%  Example query:
%    ?- order_process([action(a2,review,...), action(a1,create,...)], Ordered).
%    Ordered = [action(a1,create,...), action(a2,review,...)].
%! order_process(+UnorderedActions:list, -OrderedActions:list) is det.
%  Orders actions based on causal links, semantic role flow, and object lifecycle.
%  Falls back to simple ordering if enhanced ordering fails.
order_process(Actions, Ordered) :-
    order_process(Actions, Ordered, Status),
    (   Status = success(enhanced) ->
        true
    ;   Status = success(simple_fallback) ->
        writeln('Warning: Enhanced ordering failed, using simple ordering'),
        true
    ).

%! order_process(+UnorderedActions:list, -OrderedActions:list, -Status:term) is det.
%  Orders actions and returns structured success/failure information.
%  Status = success(enhanced) | success(simple_fallback) | failure(Reason)
order_process(Actions, Ordered, Status) :-
    (   unsatisfiable_workflow_gate_conflict(Actions, Conflict) ->
        Ordered = [],
        Status = failure(workflow_gate_conflict(Conflict))
    ;   enhanced_order_process(Actions, EnhancedOrdered),
        validate_workflow_gate_sequence(EnhancedOrdered) ->
        Ordered = EnhancedOrdered,
        Status = success(enhanced)
    ;   simple_order_process(Actions, SimpleOrdered),
        validate_workflow_gate_sequence(SimpleOrdered) ->
        Ordered = SimpleOrdered,
        Status = success(simple_fallback)
    ;   workflow_gate_violation(Actions, Violation) ->
        Ordered = [],
        Status = failure(workflow_gate_violation(Violation))
    ;   Ordered = [],
        Status = failure(ordering_unsatisfied)
    ).

%! explain_ordering_failure(+Failure:term, -Message:string) is det.
%  Converts structured ordering failures into a readable explanation.
explain_ordering_failure(failure(workflow_gate_conflict(
    workflow_gate_conflict(GateId, UseId, Actor, Object, State))), Message) :-
    format(string(Message),
           'Ordering failed: action ~w leaves ~w in terminal gate state ~w for actor ~w, so action ~w cannot use it.',
           [GateId, Object, State, Actor, UseId]).
explain_ordering_failure(failure(workflow_gate_violation(
    workflow_gate_violation(ActionId, Actor, Object, State))), Message) :-
    format(string(Message),
           'Ordering failed: action ~w tries to use ~w for actor ~w while the latest gate state is ~w.',
           [ActionId, Object, Actor, State]).
explain_ordering_failure(failure(ordering_unsatisfied),
                         'Ordering failed: no valid action order satisfies the current lifecycle and gate constraints.').

%! detect_workflow_gate_recovery_notes(+Actions:list, -Notes:list) is det.
%  Emits actionable notes for negative decision-gate outcomes.
%  If an initiating actor can be inferred, the note tells the caller to route
%  control back to that actor via notification for revision/resubmission.
%  Otherwise it explicitly states that no recovery owner could be inferred.
detect_workflow_gate_recovery_notes(Actions, Notes) :-
    findall(Note,
            ( workflow_gate_repair_plan(Actions, Recovery),
              format_workflow_gate_recovery_note(Recovery, Note)
            ),
            RawNotes),
    sort(RawNotes, Notes).

%! detect_unreachable_workflow_gate_actions(+Actions:list, -ActionIds:list) is det.
%  Collects action ids that remain unreachable because a terminal gate state
%  blocks access and no recovery owner can be inferred.
detect_unreachable_workflow_gate_actions(Actions, ActionIds) :-
    gated_objects(Actions, GatedObjects),
    findall(ActionId,
            unreachable_workflow_gate_action(Actions, GatedObjects, ActionId),
            RawIds),
    sort(RawIds, ActionIds).

workflow_gate_repair_plan(Actions,
                          gate_repair(GateId, UseId, GatePattern, GateActor,
                                      Initiator, Object, State, retry_possible)) :-
    member(GateAction, Actions),
    GateAction = action(GateId, GatePattern, GateActor, _GateTool,
                        _GateObject, _GateAux, _GateResult),
    workflow_gate_action(GateAction, GateObject, decision_gate, GateState),
    terminal_workflow_gate_state(GateState),
    first_conflicting_gate_use(Actions, GateId, GateActor, GateObject, UseId),
    \+ recovered_workflow_gate_before_use(Actions, GateId, GateActor, GateObject, UseId),
    infer_gate_recovery_owner(Actions, GateId, GateActor, GateObject, Initiator),
    Object = GateObject,
    State = GateState.
workflow_gate_repair_plan(Actions,
                          gate_repair(GateId, UseId, GatePattern, GateActor,
                                      none, Object, State, no_recovery_owner)) :-
    member(GateAction, Actions),
    GateAction = action(GateId, GatePattern, GateActor, _GateTool,
                        _GateObject, _GateAux, _GateResult),
    workflow_gate_action(GateAction, GateObject, decision_gate, GateState),
    terminal_workflow_gate_state(GateState),
    first_conflicting_gate_use(Actions, GateId, GateActor, GateObject, UseId),
    \+ recovered_workflow_gate_before_use(Actions, GateId, GateActor, GateObject, UseId),
    \+ infer_gate_recovery_owner(Actions, GateId, GateActor, GateObject, _),
    Object = GateObject,
    State = GateState.

first_conflicting_gate_use(Actions, GateId, GateActor, GateObject, UseId) :-
    append(_, [action(GateId, _, _, _, _, _, _)|AfterGate], Actions),
    first_conflicting_gate_use_in_suffix(AfterGate, GateActor, GateObject, UseId).

first_conflicting_gate_use_in_suffix([Action|_], GateActor, GateObject, UseId) :-
    Action = action(UseId, UsePattern, GateActor, _, UseObject, UseAux, _),
    use_requires_object_access(UsePattern),
    object_matches_gate(GateObject, UseObject, UseAux), !.
first_conflicting_gate_use_in_suffix([_|Rest], GateActor, GateObject, UseId) :-
    first_conflicting_gate_use_in_suffix(Rest, GateActor, GateObject, UseId).

recovered_workflow_gate_before_use(Actions, GateId, GateActor, GateObject, UseId) :-
    actions_between(Actions, GateId, UseId, Between),
    reverse(Between, ReverseBetween),
    member(RecoveryAction, ReverseBetween),
    RecoveryAction = action(_, _, GateActor, _, _, _, _),
    workflow_gate_action(RecoveryAction, RecoveryObject, _GateType, RecoveryState),
    same_traceable_object(GateObject, RecoveryObject),
    usable_workflow_gate_state(RecoveryState), !.

usable_workflow_gate_state(approved).
usable_workflow_gate_state(authenticated).

actions_between(Actions, StartId, EndId, Between) :-
    append(_, [action(StartId, _, _, _, _, _, _)|AfterStart], Actions),
    take_actions_before(AfterStart, EndId, Between).

take_actions_before([], _, []).
take_actions_before([action(EndId, _, _, _, _, _, _)|_], EndId, []) :- !.
take_actions_before([Action|Rest], EndId, [Action|Before]) :-
    take_actions_before(Rest, EndId, Before).

infer_gate_recovery_owner(Actions, GateId, GateActor, GateObject, Initiator) :-
    append(BeforeGate, [action(GateId, _, _, _, _, _, _)|_], Actions),
    reverse(BeforeGate, ReverseBefore),
    ( member(action(_, request, Initiator, _Tool, RequestObject, GateActor, _Result),
             ReverseBefore),
      Initiator \= GateActor,
            Initiator \= external_agent,
      same_traceable_object(GateObject, RequestObject)
    ; member(action(_, Pattern, Initiator, _Tool, InitObject, InitAux, InitResult),
             ReverseBefore),
      Initiator \= GateActor,
            Initiator \= external_agent,
      gate_recovery_owner_pattern(Pattern),
      ( object_matches_gate(GateObject, InitObject, InitAux)
      ; extract_object_from_result(InitResult, ResultObject),
        same_traceable_object(GateObject, ResultObject)
      )
    ), !.

gate_recovery_owner_pattern(review).
gate_recovery_owner_pattern(modify).
gate_recovery_owner_pattern(validate).
gate_recovery_owner_pattern(create).
gate_recovery_owner_pattern(generate).
gate_recovery_owner_pattern(prepare).
gate_recovery_owner_pattern(design).
gate_recovery_owner_pattern(plan).

format_workflow_gate_recovery_note(
    gate_repair(GateId, _UseId, _GatePattern, GateActor, Initiator, Object, State,
                retry_possible),
    Note) :-
    format(string(Note),
           'Decision gate ~w set ~w to ~w by ~w. Notify ~w, branch to review/resubmission, and retry the gate before downstream use continues.',
           [GateId, Object, State, GateActor, Initiator]).
format_workflow_gate_recovery_note(
    gate_repair(GateId, UseId, _GatePattern, GateActor, none, Object, State,
                no_recovery_owner),
    Note) :-
    format(string(Note),
           'Decision gate ~w set ~w to ~w by ~w. Action ~w remains unreachable because no initiating actor could be inferred for recovery.',
           [GateId, Object, State, GateActor, UseId]).

unreachable_workflow_gate_action(Actions, GatedObjects, ActionId) :-
    unreachable_workflow_gate_action_seq(Actions, GatedObjects, [], Actions, ActionId).

unreachable_workflow_gate_action_seq([Action|Rest], GatedObjects, Memory, Actions,
                                     ActionId) :-
    Action = action(Id, Pattern, ActionActor, _, ActionObject, _Aux, _Result),
    ( workflow_gate_action(Action, GateObject, GateType, GateState) ->
        update_workflow_gate_memory_with_source(ActionActor, GateObject, GateType,
                                                GateState, Id, Memory, NextMemory),
        unreachable_workflow_gate_action_seq(Rest, GatedObjects, NextMemory,
                                             Actions, ActionId)
    ; use_requires_object_access(Pattern),
      member(ActionObject, GatedObjects),
      latest_workflow_gate_entry(ActionActor, ActionObject, Memory, GateId, GateState),
      terminal_workflow_gate_state(GateState),
      \+ infer_gate_recovery_owner(Actions, GateId, ActionActor, ActionObject, _)
    ->
        ActionId = Id
    ; unreachable_workflow_gate_action_seq(Rest, GatedObjects, Memory, Actions,
                                           ActionId)
    ).

update_workflow_gate_memory_with_source(Actor, Object, GateType, State, GateId,
                                        Memory,
                                        [gate_memory(Actor, Object, GateType, State, GateId)|PrunedMemory]) :-
    exclude(matches_gate_memory_with_source(Actor, Object), Memory, PrunedMemory).

matches_gate_memory_with_source(Actor, Object,
                                gate_memory(Actor, Object, _GateType, _State, _GateId)).

latest_workflow_gate_entry(Actor, Object, Memory, GateId, State) :-
    member(gate_memory(Actor, MemoryObject, _GateType, State, GateId), Memory),
    same_traceable_object(Object, MemoryObject).

%! enhanced_order_process(+UnorderedActions:list, -OrderedActions:list) is semidet.
%  Enhanced ordering with object lifecycle tracking.
enhanced_order_process(Actions, Ordered) :-
    % Step 1: Detect missing object creations
    detect_missing_object_creation(Actions, MissingCreations),
    
    % Step 2: Extract inferred actions and add to action list
    extract_inferred_actions(MissingCreations, InferredActions),
    append(Actions, InferredActions, AllActions),

    % Step 2.5: Reject unsatisfiable gate outcomes before graph construction.
    \+ unsatisfiable_workflow_gate_conflict(AllActions, _Conflict),
    
    % Step 3: Build enhanced causal graph with lifecycle constraints
    build_enhanced_causal_graph(AllActions, Graph),
    
    % Step 4: Perform priority topological sort — uses AuxObject→Actor scoring
    % and transition_context heuristics to pick the best next node when multiple
    % nodes are simultaneously eligible.  Edgeless steps stay in input order.
    priority_topo_sort_full(AllActions, Graph, Sorted),
    
    % Step 5: Reorder actions according to sorted IDs
    reorder_by_ids(AllActions, Sorted, Ordered).

%! simple_order_process(+UnorderedActions:list, -OrderedActions:list) is det.
%  Simple ordering using only causal links (fallback method).
%  Falls back to the original input order when no causal links exist for this domain.
simple_order_process(Actions, Ordered) :-
    build_causal_graph(Actions, Graph),
    % Priority topological sort: picks the best candidate from eligible sources
    % using AuxObject→Actor scoring and transition_context heuristics.
    % Lifecycle edges in build_causal_graph now anchor cross-chain sub-sequences.
    (   priority_topo_sort_full(Actions, Graph, Sorted)
    ->  reorder_by_ids(Actions, Sorted, Ordered)
    ;   Ordered = Actions
    ).

%! extract_inferred_actions(+MissingCreations:list, -InferredActions:list) is det.
%  Extracts the inferred actions from missing creation analysis.
extract_inferred_actions([], []).
extract_inferred_actions([missing_creation(_, _, Action)|Rest], [Action|RestActions]) :-
    extract_inferred_actions(Rest, RestActions).

%! build_enhanced_causal_graph(+Actions:list, -Graph:list) is det.
%  Builds weighted directed graph considering both causal links and object lifecycle dependencies.
%  This enhanced version adds edges to ensure creation actions come before usage actions.
build_enhanced_causal_graph(Actions, Graph) :-
    % Standard causal links.  Only same-object causal pairs produce edges: the
    % former cross-object fallback (Prob * 0.5) linked every send to every
    % receive, every receive to every generate, etc. regardless of object,
    % which was the dominant source of backward edges for recurring objects.
    % Forward cross-object ordering is already covered redundantly by
    % object_sequence / lifecycle / subgoal edges, so dropping it is safe.
    findall(edge(Id1, Id2, Prob),
        (member(A1, Actions), A1 = action(Id1, P1, _, _, _, _, R1),
         member(A2, Actions), A2 = action(Id2, P2, _, _, O2, _, _),
         Id1 \= Id2,
         causal_link(P1, P2, flow(result, object), Prob),
         extract_object_from_result(R1, Obj1),
         Obj1 = O2,
         delivery_intake_handoff_ok(A1, A2)),
        CausalEdges),

    % Signature-backed continuity edges: use declared slotflow continuity as an
    % additional sequencing signal when concrete source/target slot values align.
    build_transition_signature_edges(Actions, SignatureEdges),
    
    % Object lifecycle dependencies: creation must precede usage (cross-chain anchor)
    build_lifecycle_edges(Actions, LifecycleEdges),
    
    % Transformation dependencies: object must exist before being transformed
    findall(edge(Id1, Id2, 0.9),
        (member(action(Id1, _, _, _, _, _, R1), Actions),
         member(action(Id2, P2, _, _, O2, _, _), Actions),
         Id1 \= Id2,
         lifecycle_stage(P2, transformation),
         \+ workflow_gate_pattern(P2, _),
         extract_object_from_result(R1, Obj1),
         Obj1 = O2),
        TransformationEdges),
    
    % Destruction dependencies: object should exist before being destroyed
    findall(edge(Id1, Id2, 0.95),
        (member(action(Id1, _, _, _, _, _, R1), Actions),
         member(action(Id2, P2, _, _, O2, _, _), Actions),
         Id1 \= Id2,
         lifecycle_stage(P2, destruction),
         extract_object_from_result(R1, Obj1),
         Obj1 = O2),
        DestructionEdges),

    % Workflow gate dependencies: gate actions must precede downstream use.
    build_workflow_gate_edges(Actions, WorkflowGateEdges),

    % AuxObject→Actor continuity (delivery patterns only).
    build_aux_actor_edges(Actions, AuxActorEdges),

    % Location convergence: derives cross-chain ordering from location semantics,
    % replacing many process_step_precedes hardcoded facts.
    build_location_convergence_edges(Actions, LocationEdges),

    % Temporal ordering: universal pattern-pair constraints from time_ontology.
    build_temporal_ordering_edges(Actions, TemporalEdges),

    % Actor serialisation: same individual_person serialised by hasPart phase order.
    build_actor_serialisation_edges(Actions, ActorSerEdges),

    % Same-actor sequential: receive→send, send→generate, receive→approve on different objects.
    build_same_actor_sequential_edges(Actions, SameActorSeqEdges),

    % Object-sequence ordering: object_sequence(A, before, B) domain facts.
    % Collected before conflict resolution with weight 1.0 so they dominate
    % all lower-weight edges (including lifecycle 1.0 via stable tie-break).
    build_object_sequence_edges(Actions, ObjSeqEdges),

    % Compositional ordering: hasPart dependencies between action-slot objects.
    build_compositional_ordering_edges(Actions, CompEdges),

    % Object state chain edges: within-object state progression ordering (§4.13).
    build_object_state_chain_edges(Actions, StateChainEdges),

    % Process goal anchor: right-boundary ordering constraint (§4.13).
    build_process_goal_edges(Actions, GoalEdges),

    % Explicit cross-chain sequencing constraints declared in process library files.
    build_process_step_precedes_edges(Actions, PrecedesEdges),

    % Sub-goal based cross-chain ordering: phases must complete before consumers.
    build_subgoal_ordering_edges(Actions, SubGoalEdges),

    % Combine all edges, then strip any outgoing edges from the goal terminal
    % step.  The goal terminal must be a topological sink — any edge leaving it
    % would allow the sort to place it before other steps, undermining the
    % right-boundary anchor.
    append([CausalEdges, SignatureEdges, LifecycleEdges, TransformationEdges, DestructionEdges,
            WorkflowGateEdges, AuxActorEdges, LocationEdges, TemporalEdges, ActorSerEdges,
            SameActorSeqEdges, ObjSeqEdges, CompEdges,
            StateChainEdges, GoalEdges, PrecedesEdges, SubGoalEdges], AllEdges),
    flatten(AllEdges, AllEdgesFlat),
    (   process_goal(_, _, object(GoalObject), state(GoalState)),
        member(action(GoalId, _, _, _, GoalObject, _, GoalState), Actions)
    ->  exclude([edge(Src,_,_)]>>(Src == GoalId), AllEdgesFlat, NoGoalOut)
    ;   NoGoalOut = AllEdgesFlat
    ),
    % Targeted prune: drop edges that contradict the declared object lifecycle
    % / object-flow ordering before resolving remaining conflicts (Proposal 3).
    prune_contradicting_edges(Actions, NoGoalOut, Pruned),
    % Resolve conflicting bidirectional edges among all collected edges.
    % ObjSeqEdges at weight 0.97 beat any 0.9x causal edge.  Equal-weight
    % conflicts between ObjSeqEdges and lifecycle 1.0 edges that point the
    % other way are handled by the stable A→B tie-break in resolve_conflicting_edges.
    resolve_conflicting_edges(Pruned, Graph).

%! resolve_conflicting_edges(+Edges:list, -Resolved:list) is det.
%  Given a flat list of edge(A,B,W) terms, removes the lower-weight direction
%  from any pair where both edge(A,B,W1) and edge(B,A,W2) exist.
%  When W1 = W2 the A→B direction is retained (stable tie-break).
%  This is essential for correctness of topological_sort_full/3: without it,
%  bidirectional edges create cycles that cause the greedy sort to emit nodes
%  in input order (shuffled order), producing ~430 violations per trial.
resolve_conflicting_edges(Edges, Resolved) :-
    % Collect the maximum weight for each directed pair.
    findall(A-B-W, member(edge(A,B,W), Edges), Trips),
    sort(Trips, UniqueTrips),
    % For each A-B pair find max weight; discard A-B if reverse B-A has higher.
    include([A-B-W]>>(
        \+ (member(B-A-W2, UniqueTrips), W2 > W)
    ), UniqueTrips, KeepTrips),
    maplist([A-B-W, edge(A,B,W)]>>true, KeepTrips, Resolved).

%! prune_contradicting_edges(+Actions:list, +Edges:list, -Kept:list) is det.
%  Targeted edge pruning (Proposal 3): removes any edge whose direction
%  contradicts the authoritative ordering implied by the declared object
%  lifecycle and object-flow ontology.  An edge A→B is pruned when:
%
%   - SAME object: A and B operate on the same traceable object but the result
%     state of B strictly precedes that of A (transitive result_state_precedes).
%     The producing step of the earlier state must come first, so A→B is wrong.
%
%   - CROSS object: A and B operate on different traceable objects and the
%     declared object_sequence places B's object strictly before A's object
%     (transitive effective_object_sequence).  The whole B sub-chain precedes
%     the A sub-chain, so any A→B edge is backward.
%
%  The pattern builders (causal, temporal, signature) match only on coarse
%  object/actor identity and therefore emit cross-pairings between distinct
%  lifecycle stages of recurring objects and between unrelated object chains.
%  These contradicting edges have no opposing forward edge, so
%  resolve_conflicting_edges/2 cannot remove them; this pass does.  Clean
%  builders (object_sequence, lifecycle, state-chain, sub-goal) never produce
%  a contradicting edge, so the pass only ever removes noise.
prune_contradicting_edges(Actions, Edges, Kept) :-
    exclude(edge_contradicts_order(Actions), Edges, Kept).

edge_contradicts_order(Actions, edge(IdA, IdB, _)) :-
    once(( member(action(IdA, _, _, _, ObjA, _, RA), Actions),
           member(action(IdB, _, _, _, ObjB, _, RB), Actions) )),
    (   same_traceable_object(ObjA, ObjB)
    ->  result_lifecycle_state(RA, StA),
        result_lifecycle_state(RB, StB),
        StA \== StB,
        result_state_precedes_trans(StB, StA, [])
    ;   object_sequence_before_trans(ObjB, ObjA, [])
    ).

%! result_lifecycle_state(+Result:atom, -State:atom) is semidet.
%  Extracts the State part of an `Object:State` result term.
result_lifecycle_state(Result, State) :-
    atom(Result),
    atomic_list_concat([_, State], ':', Result).

%! result_state_precedes_trans(+A:atom, +B:atom, +Visited:list) is semidet.
%  Transitive closure of result_state_precedes/2 with a visited guard so a
%  malformed cyclic lifecycle declaration can never loop.
result_state_precedes_trans(A, B, _) :-
    result_state_precedes(A, B).
result_state_precedes_trans(A, B, Visited) :-
    result_state_precedes(A, Mid),
    \+ memberchk(Mid, Visited),
    result_state_precedes_trans(Mid, B, [Mid|Visited]).

%! object_sequence_before_trans(+A:atom, +B:atom, +Visited:list) is semidet.
%  Transitive closure of effective_object_sequence/3 (before) with a visited
%  guard so a cyclic object-sequence declaration can never loop.
object_sequence_before_trans(A, B, _) :-
    effective_object_sequence(A, before, B).
object_sequence_before_trans(A, B, Visited) :-
    effective_object_sequence(A, before, Mid),
    \+ memberchk(Mid, Visited),
    object_sequence_before_trans(Mid, B, [Mid|Visited]).

%! build_subgoal_ordering_edges(+Actions:list, -Edges:list) is det.
%  Converts process_subgoal/4 + process_subgoal_consumer/3 declarations into
%  weight-1.0 ordering edges.  For each sub-goal G:
%   - Prerequisite steps: any action whose Result object matches PreqPattern.
%   - Consumer steps: any action whose Result object matches ConsPattern.
%   - Constraint: PreqPattern \= ConsPattern (no self-referential sub-goals).
%   - Edge: every prerequisite step must precede every consumer step.
%
%  Guard: PreqObj \= ConsObj prevents bidirectional cycles that arise when the
%  same object atom appears in both the prerequisite and consumer patterns.
build_subgoal_ordering_edges(Actions, Edges) :-
    findall(edge(PreqId, ConsId, 1.0),
        (   process_subgoal(_, SubGoalId, PreqPattern, _),
            process_subgoal_consumer(_, SubGoalId, ConsPattern),
            PreqPattern \= ConsPattern,   % guard: distinct object roles
            member(action(PreqId, _, _, _, _, _, PreqResult), Actions),
            member(action(ConsId, _, _, _, _, _, ConsResult), Actions),
            PreqId \= ConsId,
            extract_object_from_result(PreqResult, PreqObj),
            same_traceable_object(PreqObj, PreqPattern),
            extract_object_from_result(ConsResult, ConsObj),
            same_traceable_object(ConsObj, ConsPattern),
            PreqObj \= ConsObj            % guard: different object atoms
        ),
        RawEdges),
    sort(RawEdges, Edges).

%! build_process_step_precedes_edges(+Actions:list, -Edges:list) is det.
%  Converts every process_step_precedes/3 (or /4) fact whose StepIdA and StepIdB
%  both appear in Actions into a weight-1.0 ordering edge.  Uses the unified
%  effective_step_precedes/3 accessor so both 3-arity and 4-arity forms are covered.
build_process_step_precedes_edges(Actions, Edges) :-
    findall(edge(IdA, IdB, 1.0),
        (   effective_step_precedes(_, IdA, IdB),
            member(action(IdA, _, _, _, _, _, _), Actions),
            member(action(IdB, _, _, _, _, _, _), Actions)
        ),
        RawEdges),
    sort(RawEdges, Edges).

%! build_process_goal_edges(+Actions:list, -Edges:list) is det.
%  Reads a structured process_goal/4 fact and identifies the goal terminal
%  step (the action whose Object and Result match the declared goal state).
%  Adds a weight-1.0 edge from every process_step_precedes-declared predecessor
%  of the goal terminal into the goal terminal, and additionally ensures the
%  goal terminal has no outgoing edges by contributing it as a sink node.
%
%  NOTE: this predicate does NOT add edges from ALL steps to the goal terminal
%  (that approach caused other constraint layers to add goal→X outgoing edges
%  which distorted the topological sort).  Cross-chain ordering is handled
%  entirely via process_step_precedes/3 in the process library file.
build_process_goal_edges(Actions, Edges) :-
    (   process_goal(_, _, object(GoalObject), state(GoalState)),
        member(action(GoalId, _, _, _, GoalObject, _, GoalState), Actions)
    ->  % Only add edges from steps that directly produce the objects/states
        % referenced in process_step_precedes declarations that target GoalId,
        % plus one explicit edge from the penultimate step (sr41 -> sr42) to
        % ensure the goal terminal is reachable.  All other ordering is via
        % process_step_precedes edges in build_process_step_precedes_edges/2.
        findall(edge(PredId, GoalId, 1.0),
            (   process_step_precedes(_, PredId, GoalId),
                member(action(PredId, _, _, _, _, _, _), Actions)
            ),
            RawEdges),
        sort(RawEdges, Edges)
    ;   Edges = []
    ).

%! result_state_precedes(+StateA:atom, +StateB:atom) is semidet.
%  Universal state progression facts.  For any two steps that both produce
%  a Result of the form `Object:State`, if StateA result_state_precedes StateB
%  and both Results share the same Object prefix, the producing step of StateA
%  must come before the producing step of StateB in the process timeline.
%  These facts encode well-known object lifecycle progressions that hold across
%  all domains in the CNL process library (§4.13 of CNL Publication Draft).
result_state_precedes(generated,              sent).
result_state_precedes(generated,              sent_for_approval).
result_state_precedes(generated,              received).
result_state_precedes(transferred,            received).
result_state_precedes(transferred,            sent).
result_state_precedes(sent,                   received).
result_state_precedes(sent_for_approval,      received_for_approval).
result_state_precedes(received_for_approval,  approved).
result_state_precedes(approved,               sent).
result_state_precedes(approved,               received).
result_state_precedes(approved,               paid).
result_state_precedes(sent,                   paid).
result_state_precedes(notified,               received).
result_state_precedes(delivered,              notified).
% Physical-item shipment lifecycle.  These states occur only on the `item`
% object's late shipment phase, so (guarded by same-object) they never affect
% other object chains.  They totally order the shipment phase:
% sent_to_shipper -> received_by_shipper -> delivered.
result_state_precedes(sent_to_shipper,        received_by_shipper).
result_state_precedes(received_by_shipper,    delivered).

%! build_aux_actor_edges(+Actions:list, -Edges:list) is det.
%  Adds ordering edges based on the AuxObject → next-Actor relationship.
%
%  Semantic principle: the AuxObject (recipient / destination) of a delivery
%  action is the Actor of the next action on the same Object.  Supports both
%  plain-atom AuxObject (legacy) and structured at(Actor, Location) form.
%
%  Only delivery patterns are eligible — for intake patterns the AuxObject
%  is the SOURCE who already acted, so generating a forward edge to them
%  would produce a backward edge and corrupt the sort.
%
%  Weight 0.93.
build_aux_actor_edges(Actions, Edges) :-
    findall(edge(FromId, ToId, 0.93),
        (   member(action(FromId, FromPat, _FromActor, _FromTool,
                          FromObj, AuxObj, _FromResult), Actions),
            delivery_pattern(FromPat),
            comparable_transition_value(FromObj),
            aux_object_actor(AuxObj, RecipientActor),
            comparable_transition_value(RecipientActor),
            member(action(ToId, _ToPat, ToActor, _ToTool,
                          ToObj, _ToAux, _ToResult), Actions),
            FromId \= ToId,
            ToActor == RecipientActor,
            same_traceable_object(FromObj, ToObj)
        ),
        RawEdges),
    sort(RawEdges, Edges).

%! build_temporal_ordering_edges(+Actions:list, -Edges:list) is det.
%  Converts universal temporal_constraint/4 facts into graph ordering edges.
%
%  For each pair of actions (A, B) in the process where:
%   - A has pattern PatA and B has pattern PatB
%   - temporal_constraint(PatA, PatB, precedes, _) is declared
%   - both actions share the same traceable object (same_traceable_object/2)
%     OR PatB is a gate/slow pattern that universally follows PatA
%
%  Adds edge(A, B, 0.95).  Weight 0.95 places these edges above causal_link
%  (≤ 0.95 with 0.5 fallback) and above signature edges (0.92), but below
%  workflow-gate hard constraints (0.98) and lifecycle/goal anchors (1.0).
%
%  Object match is required so we do not generate spurious cross-domain
%  ordering edges between unrelated objects that happen to use the same
%  pattern atoms.
%
%  Time-bound tightening: when the constraint bound is tight (< 24 hours)
%  the weight is raised to 0.97 to reflect the stronger ordering signal.
build_temporal_ordering_edges(Actions, Edges) :-
    findall(edge(FromId, ToId, Weight),
        (   member(AFrom, Actions), AFrom = action(FromId, PatA, _, _, ObjA, AuxA, _),
            member(ATo,   Actions), ATo   = action(ToId,   PatB, _, _, ObjB, _,    _),
            FromId \= ToId,
            temporal_constraint(PatA, PatB, precedes, Bound),
            % Object match OR AuxObject of A is the Actor of B (hand-off chain)
            ( same_traceable_object(ObjA, ObjB)
            ; aux_object_actor(AuxA, ActorB),
              member(action(ToId, PatB, ActorB, _, _, _, _), Actions)
            ),
            % Hand-off gate: same-object delivery→intake pairs must match the
            % sender's recipient to the receiver's actor (Proposal 1).
            delivery_intake_handoff_ok(AFrom, ATo),
            ( Bound \= unbounded,
              duration_in_seconds(Bound, S),
              S < 86400          % < 24 hours → tight constraint
            -> Weight = 0.97
            ;  Weight = 0.95
            )
        ),
        RawEdges),
    sort(RawEdges, Edges).

%! duration_in_seconds(+Bound:term, -Seconds:number) is det.
%  Local forward declaration so process_model can call it without importing
%  the full time_ontology API.  Delegates to time_ontology.
duration_in_seconds(Bound, S) :- time_ontology:duration_in_seconds(Bound, S).

%! build_location_convergence_edges(+Actions:list, -Edges:list) is det.
%  Adds ordering edges derived from location semantics — replacing the need
%  for hardcoded process_step_precedes/3 facts for many cross-chain cases.
%
%  Two ordering rules:
%
%  RULE 1 — Physical convergence (weight 0.96):
%    If action A delivers an object TO a physical location L, and action B
%    operates ON an object AT the same physical location L, then A must
%    precede B.  This captures patterns like:
%      deliver(shipper, item, at(customer, delivery_address))
%      receive(customer, item, at(shipper, in_transit))
%    → delivery must precede receipt at the same address.
%
%  RULE 2 — Same-actor location sequencing (weight 0.91):
%    If action A delivers an object to actor X's location, and action B is
%    performed BY actor X on the same object, then A must precede B — even
%    when the exact location atoms differ (generalises the AuxObject→Actor
%    edge to location-aware actors, catching cases where actor appears with
%    different locations in different actions).
build_location_convergence_edges(Actions, Edges) :-
    findall(edge(FromId, ToId, Weight),
        location_convergence_edge(Actions, FromId, ToId, Weight),
        RawEdges),
    sort(RawEdges, Edges).

location_convergence_edge(Actions, FromId, ToId, 0.96) :-
    % Rule 1: physical location convergence.
    member(action(FromId, FromPat, _, _, FromObj, FromAux, _), Actions),
    delivery_pattern(FromPat),
    aux_object_location(FromAux, Loc),
    Loc \= no_location,
    physical_location(Loc),
    member(action(ToId, _ToPat, ToActor, _, ToObj, ToAux, _), Actions),
    FromId \= ToId,
    same_traceable_object(FromObj, ToObj),
    ( aux_object_location(ToAux, Loc)        % same destination location
    ; aux_object_actor(ToAux, ToActor),      % same destination actor
      aux_object_location(FromAux, Loc),
      location_actor(Loc, ToActor)
    ).
location_convergence_edge(Actions, FromId, ToId, 0.91) :-
    % Rule 2: same-actor cross-location — A delivers to actor X at a named
    % location, B is performed by X on the same object at a DIFFERENT location.
    % This fires only when AuxObject is a structured at/2 term (bare-atom cases
    % are already covered by build_aux_actor_edges/2).
    member(action(FromId, FromPat, _, _, FromObj, FromAux, _), Actions),
    FromAux = at(RecipActor, FromLoc),   % structured form only
    delivery_pattern(FromPat),
    comparable_transition_value(RecipActor),
    member(action(ToId, _, RecipActor, _, ToObj, ToAux, _), Actions),
    FromId \= ToId,
    same_traceable_object(FromObj, ToObj),
    ToAux \= at(RecipActor, FromLoc).    % different location → not already covered

%! build_object_sequence_edges(+Actions:list, -Edges:list) is det.
%  Converts every object_sequence(ObjA, before, ObjB) fact into weight-1.0
%  ordering edges from ALL steps whose primary Object slot matches ObjA to
%  ALL steps whose primary Object slot matches ObjB.
%
%  Weight 1.0 (same as process_step_precedes and lifecycle edges):
%  This is necessary because the topological sort places a node as soon as ALL
%  its direct predecessors have been placed.  If object_sequence edges carry a
%  lower weight (e.g. 0.97), resolve_conflicting_edges can remove them when a
%  higher-weight edge points the other way, making the source detection bypass
%  the declared ordering constraint.  Weight 1.0 is never overridden.
%
%  Object-slot matching: both ObjA-matching and ObjB-matching steps are found
%  by their primary Object slot (not Result prefix) so send, receive, generate,
%  deliver etc. on the same object are all included.
%
%  Guard: fires only for genuinely different object atoms; same-object pairs
%  are handled by AuxActor, signature, and lifecycle edges.
%     lifecycle edges.
%
%  This is the primary fix for the 91 receive→send, 24 send→generate, and 76
%  generate→receive wrong-direction pairs identified in the unconstrained-pair
%  analysis (2026-06-12/13).
build_object_sequence_edges(Actions, Edges) :-
    findall(edge(IdA, IdB, 0.97),
        (   effective_object_sequence(ObjA, before, ObjB),
            comparable_transition_value(ObjA),
            comparable_transition_value(ObjB),
            member(action(IdA, _, _, _, ActObjA, _, _), Actions),
            same_traceable_object(ActObjA, ObjA),
            member(action(IdB, _, _, _, ActObjB, _, _), Actions),
            same_traceable_object(ActObjB, ObjB),
            IdA \= IdB
        ),
        RawEdges),
    sort(RawEdges, Edges).

%! build_same_actor_sequential_edges(+Actions:list, -Edges:list) is det.
%  Weight-0.96 edges for same-actor, different-object pattern pairs that are
%  universally forward in all known processes — confirmed by GT classification.
%
%  Only `receive→approve` is universally safe: a gate decision always follows
%  receipt of the data it evaluates.  All other same-actor sequential rules
%  (receive→send, send→generate, receive→generate, generate→send) produce
%  nearly 50% backward edges on the 42-step sales GT and are excluded.
%
%  Weight 0.96 > approve→send (0.85) so this wins conflict resolution.
build_same_actor_sequential_edges(Actions, Edges) :-
    findall(edge(IdA, IdB, 0.96),
        (   member(action(IdA, PatA, ActorA, _, ObjA, _, _), Actions),
            member(action(IdB, PatB, ActorB, _, ObjB, _, _), Actions),
            IdA \= IdB,
            ActorA == ActorB,
            \+ same_traceable_object(ObjA, ObjB),
            same_actor_seq_pair(PatA, PatB)
        ),
        RawEdges),
    sort(RawEdges, Edges).

%! same_actor_seq_pair(+PatA:atom, +PatB:atom) is semidet.
%  Universally-safe same-actor sequential pairs (confirmed forward in all GT
%  processes; bidirectional rules excluded after GT classification).
same_actor_seq_pair(receive,  approve).   % receive credentials → gate decision

%! build_actor_serialisation_edges(+Actions:list, -Edges:list) is det.
%  Adds low-weight ordering edges between same-actor actions on DIFFERENT objects.
%
%  Principle: an individual_person actor can only do one thing at a time.
%  When two actions A and B are performed by the same individual_person on
%  different objects, they are forced into a sequential order.  The engine
%  cannot determine which comes first from semantics alone — so it uses the
%  INPUT ORDER as the tiebreaker: whichever appears earlier in the Actions list
%  gets an edge to the later one.
%
%  This converts "50% random cross-chain ordering" into "input-order-stable
%  single-actor ordering" for individual-person actors.  It will not help when
%  the input is fully shuffled (the input order is random), but it prevents
%  the priority sort from arbitrarily reversing the natural sequential order.
%
%  Weight 0.82 — below all semantic constraints but above random tiebreaking.
%  Only fires for individual_person actors (not organizations or systems, which
%  can act in parallel).
build_actor_serialisation_edges(Actions, Edges) :-
    findall(edge(IdA, IdB, 0.82),
        (   nth1(PosA, Actions, action(IdA, _, ActorA, _, ObjA, _, _)),
            nth1(PosB, Actions, action(IdB, _, ActorB, _, ObjB, _, _)),
            IdA \= IdB,
            PosA < PosB,
            ActorA == ActorB,
            agent_class(ActorA, individual_person),
            \+ same_traceable_object(ObjA, ObjB)   % different objects — serialisation only
        ),
        RawEdges),
    sort(RawEdges, Edges).

%! build_actor_serialisation_edges(+Actions:list, -Edges:list) is det.
%  Adds ordering edges between same individual_person actor actions that operate
%  on DIFFERENT objects and belong to DIFFERENT sub-goal phases.
%
%  The key insight: input-order position is harmful (shuffled). Instead, we use
%  hasPart/2 to derive phase order: if hasPart(ObjB, ObjA), then any step
%  producing ObjA must precede any step generating ObjB — regardless of which
%  is earlier in the input. This gives a semantically grounded tiebreaker.
%
%  Additionally: if action A's AuxObject is the same as action B's Object,
%  then A semantically precedes B (delivery → consumption chain).
%
%  Weight 0.82 — lowest semantic constraint; fires only when no stronger
%  edge already exists between the pair.
build_actor_serialisation_edges(Actions, Edges) :-
    findall(edge(IdA, IdB, 0.82),
        (   member(action(IdA, PatA, ActorA, _, ObjA, AuxA, ResA), Actions),
            member(action(IdB, _PatB, ActorB, _, ObjB, _AuxB, _ResB), Actions),
            IdA \= IdB,
            ActorA == ActorB,
            agent_class(ActorA, individual_person),
            \+ same_traceable_object(ObjA, ObjB),
            % Phase ordering via hasPart: ObjB depends on ObjA
            ( hasPart(ObjB, ObjA)
            ; ( extract_object_from_result(ResA, ResObjA),
                hasPart(ObjB, ResObjA) )
            % Delivery-chain: A sends to B's object domain
            ; ( delivery_pattern(PatA),
                aux_object_actor(AuxA, ActorB),
                same_traceable_object(ObjA, ObjB) )
            )
        ),
        RawEdges),
    sort(RawEdges, Edges).

%! build_compositional_ordering_edges(+Actions:list, -Edges:list) is det.
%  Adds ordering edges derived from hasPart/2 object dependencies:
%  hasPart(Whole, Part) means "any step that CREATES or DELIVERS Part must
%  precede any step that GENERATES Whole, because Whole cannot be constructed
%  until all its parts exist".
%
%  Part-producing step: action whose Object or Result-prefix matches Part AND
%  whose pattern is a creation or delivery pattern (so it produces/transfers Part,
%  not merely reads it).
%
%  Whole-consuming step: action whose Object matches Whole (the step that
%  generates Whole requires all parts to already exist).
%
%  Weight 0.88 — below temporal constraints (0.95) but above aux-actor (0.93)
%  and state-chain (0.90) edges.
build_compositional_ordering_edges(Actions, Edges) :-
    findall(edge(PartId, WholeId, 0.88),
        (   hasPart(Whole, Part),
            Whole \= Part,                         % no self-loops
            comparable_transition_value(Whole),
            comparable_transition_value(Part),
            % PartId: action that PRODUCES or DELIVERS the Part
            member(action(PartId, PartPat, _, _, PartObj, _, PartResult), Actions),
            ( lifecycle_stage(PartPat, creation) ; delivery_pattern(PartPat) ),
            ( same_traceable_object(PartObj, Part)
            ; ( extract_object_from_result(PartResult, PartResObj),
                same_traceable_object(PartResObj, Part) )
            ),
            % WholeId: action that GENERATES or USES the Whole as its object
            member(action(WholeId, WholePat, _, _, WholeObj, _, _), Actions),
            ( lifecycle_stage(WholePat, creation) ; lifecycle_stage(WholePat, transformation) ),
            PartId \= WholeId,
            same_traceable_object(WholeObj, Whole)
        ),
        RawEdges),
    sort(RawEdges, Edges).

%! build_object_state_chain_edges(+Actions:list, -Edges:list) is det.
%  Adds ordering edges between pairs of steps whose Results share the same
%  object prefix (e.g., `item_payment`) and whose state part is ordered by
%  result_state_precedes/2.  Weight 0.98 — authoritative for same-object
%  ordering: the granular result-state strings (e.g. credit_info:sent vs
%  credit_info:sent_for_approval) disambiguate recurring-object steps 1-to-1,
%  so this signal must win over the coarser causal/temporal/signature pattern
%  edges (≤0.97) that only match on the bare object atom (Proposal 2).
%  This implements the Object State as Ordering Signal constraint from §4.13.
%  The goal terminal step (if any) is excluded as an edge source to prevent
%  spurious goal→X backward edges.
build_object_state_chain_edges(Actions, Edges) :-
    % Identify goal terminal ID to exclude it as an edge source.
    (   process_goal(_, _, object(GoalObject), state(GoalState)),
        member(action(GoalId, _, _, _, GoalObject, _, GoalState), Actions)
    ->  true
    ;   GoalId = '$none$'
    ),
    findall(edge(IdA, IdB, 0.98),
        (member(action(IdA, _, _, _, _, _, ResultA), Actions),
         IdA \= GoalId,
         member(action(IdB, _, _, _, _, _, ResultB), Actions),
         IdA \= IdB,
         ResultA \= ResultB,
         atomic_list_concat([ObjA, StateA], ':', ResultA),
         atomic_list_concat([ObjB, StateB], ':', ResultB),
         same_traceable_object(ObjA, ObjB),
         result_state_precedes(StateA, StateB)),
        RawEdges),
    sort(RawEdges, Edges).

%! build_lifecycle_edges(+Actions:list, -Edges:list) is det.
%  Adds weight-1.0 precedence edges from every creation-pattern action to
%  every downstream action that uses the created object in its Object or
%  AuxObject slot.  Weight 1.0 ensures these cross-chain dependency anchors
%  are never overridden by lower-weight causal or signature edges.
%
%  This is the key predicate for cross-chain ordering: it creates edges like
%  generate(item_quote) → generate(purchase_request, from=item_quote)
%  that anchor independent business sub-chains relative to each other.
build_lifecycle_edges(Actions, Edges) :-
    findall(edge(CreationId, UsageId, 1.0),
        (   member(action(CreationId, CreationPat, _, _, CreationObj, _, CreationResult), Actions),
            lifecycle_stage(CreationPat, creation),
            member(action(UsageId, _, _, _, UsageObj, UsageAux, _), Actions),
            CreationId \= UsageId,
            (   CreationResult \= '', CreationResult \= 'unspecified',
                (CreationResult = UsageObj ; CreationResult = UsageAux)
            ;   CreationObj \= '', CreationObj \= 'unspecified',
                (CreationObj = UsageObj ; CreationObj = UsageAux)
            )
        ),
        RawEdges),
    sort(RawEdges, Edges).

%! build_causal_graph(+Actions:list, -Graph:list) is det.
%  Builds weighted directed graph from actions using causal links.
%  Includes lifecycle dependency edges so that cross-chain sub-sequences
%  (e.g. quote → purchase-request → payment in the sales process) are
%  correctly anchored relative to each other even in the simple fallback path.
build_causal_graph(Actions, Graph) :-
    findall(edge(Id1, Id2, Prob),
        (member(A1, Actions), A1 = action(Id1, P1, _, _, _, _, R1),
         member(A2, Actions), A2 = action(Id2, P2, _, _, O2, _, _),
         Id1 \= Id2,
         causal_link(P1, P2, flow(result, object), Prob),
         extract_object_from_result(R1, Obj1),
         Obj1 = O2,
         delivery_intake_handoff_ok(A1, A2)),
        CausalEdges),
    build_transition_signature_edges(Actions, SignatureEdges),
    build_workflow_gate_edges(Actions, WorkflowGateEdges),
    build_aux_actor_edges(Actions, AuxActorEdges),
    build_location_convergence_edges(Actions, LocationEdges),
    build_temporal_ordering_edges(Actions, TemporalEdges),
    build_object_state_chain_edges(Actions, StateChainEdges),
    build_lifecycle_edges(Actions, LifecycleEdges),
    build_subgoal_ordering_edges(Actions, SubGoalEdges),
    build_actor_serialisation_edges(Actions, ActorSerEdges),
    build_same_actor_sequential_edges(Actions, SameActorSeqEdges),
    build_object_sequence_edges(Actions, ObjSeqEdges),
    build_compositional_ordering_edges(Actions, CompEdges),
    append([CausalEdges, SignatureEdges, WorkflowGateEdges, AuxActorEdges,
            LocationEdges, TemporalEdges, StateChainEdges, LifecycleEdges, SubGoalEdges,
            ActorSerEdges, SameActorSeqEdges, ObjSeqEdges, CompEdges], EdgeGroups),
    flatten(EdgeGroups, Flat),
    % Targeted prune: drop edges that contradict the declared object lifecycle
    % / object-flow ordering before resolving remaining conflicts (Proposal 3).
    prune_contradicting_edges(Actions, Flat, Pruned),
    resolve_conflicting_edges(Pruned, Graph).


%! build_transition_signature_edges(+Actions:list, -Edges:list) is det.
%  Adds precedence edges for concrete action pairs that have a declared
%  transition signature and at least one slot-map continuation with matching
%  bound values. This lets the ordering engine use the curated transition
%  registry directly without replacing causal/lifecycle constraints.
build_transition_signature_edges(Actions, Edges) :-
    findall(edge(FromId, ToId, Weight),
        signature_precedence_edge(Actions, FromId, ToId, Weight),
        RawEdges),
    sort(RawEdges, Edges).

signature_precedence_edge(Actions, FromId, ToId, 0.92) :-
    member(FromAction, Actions),
    member(ToAction, Actions),
    FromAction = action(FromId, FromPattern, _, _, _, _, _),
    ToAction = action(ToId, ToPattern, _, _, _, _, _),
    FromId \= ToId,
    transition_signature(FromPattern, ToPattern, _),
    % Hand-off gate: same-object delivery→intake pairs must match the sender's
    % recipient to the receiver's actor (Proposal 1).
    delivery_intake_handoff_ok(FromAction, ToAction),
    once(action_transition_slot_overlap(FromAction, ToAction, FromPattern, ToPattern)).

action_transition_slot_overlap(FromAction, ToAction, FromPattern, ToPattern) :-
    transition_slot_map(FromPattern, ToPattern, SourceSlot, TargetSlot),
    transition_slot_value(FromAction, SourceSlot, SourceValue),
    transition_slot_value(ToAction, TargetSlot, TargetValue),
    comparable_transition_value(SourceValue),
    comparable_transition_value(TargetValue),
    same_traceable_object(SourceValue, TargetValue), !.

transition_slot_value(action(_, _, Actor, Tool, Object, AuxObject, Result), Slot, Value) :-
    transition_slot_role(Slot, Role),
    role_value(Role, Actor, Tool, Object, AuxObject, Result, Value).

transition_slot_role(0, actor).
transition_slot_role(1, tool).
transition_slot_role(2, object).
transition_slot_role(3, aux_object).
transition_slot_role(4, result).

comparable_transition_value(Value) :-
    nonvar(Value),
    Value \= '',
    Value \= 'unspecified'.

%! build_workflow_gate_edges(+Actions:list, -Edges:list) is det.
%  Adds precedence edges from gate actions to later consumers of the same object.
%  This lets ordering place approval/authentication steps before downstream use.
build_workflow_gate_edges(Actions, Edges) :-
    findall(edge(GateId, UseId, 0.98),
        (member(GateAction, Actions),
         workflow_gate_action(GateAction, GateObject, _GateType, _GateState),
         member(UseAction, Actions),
         GateAction = action(GateId, _, _, _, _, _, _),
         UseAction = action(UseId, UsePattern, UseActor, _, UseObject, UseAux, _),
         GateId \= UseId,
         use_requires_object_access(UsePattern),
         object_matches_gate(GateObject, UseObject, UseAux),
         UseActor \= external_agent),
        RawEdges),
    sort(RawEdges, Edges).

%! validate_workflow_gate_sequence(+Actions:list) is semidet.
%  Fails when a gated object is consumed before approval or after rejection.
validate_workflow_gate_sequence(Actions) :-
    \+ workflow_gate_violation(Actions, _).

%! unsatisfiable_workflow_gate_conflict(+Actions:list, -Conflict:compound) is nondet.
%  Detects gate outcomes that make downstream use impossible regardless of reordering.
unsatisfiable_workflow_gate_conflict(Actions,
                                    workflow_gate_conflict(GateId, UseId, Actor, Object, State)) :-
    member(GateAction, Actions),
    GateAction = action(GateId, _GatePattern, GateActor, _GateTool, _GateObject, _GateAux, _GateResult),
    workflow_gate_action(GateAction, GateObject, _GateType, GateState),
    terminal_workflow_gate_state(GateState),
    member(UseAction, Actions),
    UseAction = action(UseId, UsePattern, Actor, _UseTool, UseObject, UseAux, _UseResult),
    GateId \= UseId,
    Actor == GateActor,
    use_requires_object_access(UsePattern),
    object_matches_gate(GateObject, UseObject, UseAux),
    \+ recovered_workflow_gate_before_use(Actions, GateId, GateActor, GateObject, UseId),
    Object = GateObject,
    State = GateState.

terminal_workflow_gate_state(rejected).
terminal_workflow_gate_state(denied).
terminal_workflow_gate_state(blocked).
terminal_workflow_gate_state(failed).
terminal_workflow_gate_state(unauthorized).

%! workflow_gate_violation(+Actions:list, -Violation:compound) is nondet.
%  Finds a downstream use of a gated object that is not currently approved.
workflow_gate_violation(Actions, workflow_gate_violation(ActionId, Actor, Object, State)) :-
    gated_objects(Actions, GatedObjects),
    check_workflow_gate_seq(Actions, GatedObjects, [], ActionId, Actor, Object, State).

gated_objects(Actions, GatedObjects) :-
    findall(Object,
        (member(Action, Actions),
         workflow_gate_action(Action, Object, _GateType, _GateState)),
        Objects),
    sort(Objects, GatedObjects).

check_workflow_gate_seq([], _, _, _, _, _, _) :-
    fail.
check_workflow_gate_seq([Action|Rest], GatedObjects, Memory,
                        ActionId, Actor, Object, State) :-
    Action = action(Id, Pattern, ActionActor, _, ActionObject, _Aux, _Result),
    ( workflow_gate_action(Action, GateObject, GateType, GateState) ->
        update_workflow_gate_memory(ActionActor, GateObject, GateType, GateState,
                                    Memory, NextMemory),
        check_workflow_gate_seq(Rest, GatedObjects, NextMemory,
                                ActionId, Actor, Object, State)
    ; use_requires_object_access(Pattern),
      member(ActionObject, GatedObjects),
      latest_workflow_gate_state(ActionActor, ActionObject, Memory, GateState),
      GateState \= approved,
      GateState \= authenticated ->
        ActionId = Id,
        Actor = ActionActor,
        Object = ActionObject,
        State = GateState
    ; use_requires_object_access(Pattern),
      member(ActionObject, GatedObjects),
      \+ latest_workflow_gate_state(ActionActor, ActionObject, Memory, _),
      % Cross-actor approval: a gate by actor A clears the object for actor B
      % (e.g. payment_gateway approves item_payment → customer can pay it).
      % Only flag as pending when NO actor in memory holds a usable state.
      \+ (member(gate_memory(_, MemObj, _, AnyState), Memory),
          same_traceable_object(ActionObject, MemObj),
          usable_workflow_gate_state(AnyState)),
      ActionId = Id,
      Actor = ActionActor,
      Object = ActionObject,
      State = pending
    ; check_workflow_gate_seq(Rest, GatedObjects, Memory,
                              ActionId, Actor, Object, State)
    ).

workflow_gate_action(action(_, Pattern, _Actor, _Tool, Object, _Aux, Result),
                     GateObject, GateType, GateState) :-
    workflow_gate_pattern(Pattern, GateType),
    base_object_for_gate(Object, Result, GateObject),
    workflow_gate_state(Pattern, Result, GateState).

workflow_gate_pattern(Pattern, GateType) :-
    gate_pattern_code(Code),
    pattern_workflow_gate(Code, GateType),
    pattern_code_atom(Code, Pattern).

gate_pattern_code(cnf()).
gate_pattern_code(apr()).
gate_pattern_code(aut()).

pattern_code_atom(cnf(), confirm).
pattern_code_atom(apr(), approve).
pattern_code_atom(aut(), authenticate).

base_object_for_gate(Object, Result, GateObject) :-
    ( extract_object_from_result(Result, ResultObject),
      ResultObject \= '' ->
        GateObject = ResultObject
    ; GateObject = Object
    ).

workflow_gate_state(_Pattern, Result, State) :-
    extract_gate_state_from_result(Result, State), !.
workflow_gate_state(confirm, _Result, approved).
workflow_gate_state(approve, _Result, approved).
workflow_gate_state(authenticate, _Result, authenticated).

extract_gate_state_from_result(Result, State) :-
    atom(Result),
    atomic_list_concat([_Object, State], ':', Result).

update_workflow_gate_memory(Actor, Object, GateType, State, Memory,
                            [gate_memory(Actor, Object, GateType, State)|PrunedMemory]) :-
    exclude(matches_gate_memory(Actor, Object), Memory, PrunedMemory).

matches_gate_memory(Actor, Object, gate_memory(Actor, Object, _GateType, _State)).

latest_workflow_gate_state(Actor, Object, Memory, State) :-
    member(gate_memory(Actor, Object, _GateType, State), Memory).

object_matches_gate(GateObject, UseObject, _UseAux) :-
    same_traceable_object(GateObject, UseObject).
object_matches_gate(GateObject, _UseObject, UseAux) :-
    same_traceable_object(GateObject, UseAux).

same_traceable_object(Object1, Object2) :-
    Object1 \= '',
    Object2 \= '',
    Object1 \= 'unspecified',
    Object2 \= 'unspecified',
    extract_base_object_name(Object1, Base1),
    extract_base_object_name(Object2, Base2),
    Base1 \= '',             % guard: reject empty-base false-positive matches
    Base1 == Base2.

use_requires_object_access(Pattern) :-
    \+ workflow_gate_pattern(Pattern, _),
    \+ intake_pattern(Pattern),
    \+ pre_gate_pattern(Pattern).

pre_gate_pattern(create).
pre_gate_pattern(write).
pre_gate_pattern(develop).
pre_gate_pattern(generate).
pre_gate_pattern(build).
pre_gate_pattern(prepare).
pre_gate_pattern(request).
pre_gate_pattern(modify).
pre_gate_pattern(review).
pre_gate_pattern(validate).
pre_gate_pattern(analyze).
pre_gate_pattern(think).
pre_gate_pattern(design).
pre_gate_pattern(plan).
pre_gate_pattern(configure).
pre_gate_pattern(notify).

%! extract_object_from_result(+Result:atom, -Object:atom) is det.
%  Extracts object from "object:state" result format.
%
%  Example query:
%    ?- extract_object_from_result('document:approved', Object).
%    Object = document.
extract_object_from_result(Result, Object) :-
    atom(Result),
    atomic_list_concat([Object, _State], ':', Result), !.
extract_object_from_result(Result, Result).

%! topological_sort(+Graph:list, -Sorted:list) is det.
%  Performs topological sort considering edge weights.
%  Only includes nodes that appear in the graph (nodes without any edge are
%  excluded).  Use topological_sort_full/3 when all action IDs must be present
%  in the output regardless of edge coverage.
topological_sort(Graph, Sorted) :-
    findall(Node, (member(edge(Node, _, _), Graph) ; member(edge(_, Node, _), Graph)), Nodes),
    sort(Nodes, UniqueNodes),
    topo_sort_helper(UniqueNodes, Graph, [], Sorted).

%! topological_sort_full(+Actions:list, +Graph:list, -Sorted:list) is det.
%  Like topological_sort/2 but seeds the node set with ALL action IDs from
%  Actions so that steps with no graph edges are still included in the output.
%  Without this, actions not connected to any other action via causal/signature
%  edges are silently dropped from the sorted list, causing reorder_by_ids/3
%  to return an incomplete action sequence and making the gate validator fail
%  on an artificially truncated process.
%
%  Tie-breaking: unanchored nodes (those with no constraining edges) are
%  emitted in the ORIGINAL INPUT ORDER from Actions rather than alphabetically.
%  Preserving input order for unanchored pairs is always at least as good as
%  alphabetical: a random shuffle already has ~50 % correct consecutive pairs,
%  whereas alphabetical order diverges from both GT and the original shuffle.
topological_sort_full(Actions, Graph, Sorted) :-
    % Input IDs in the original order — used as the node list so topo-sort
    % inherits the input order as the tie-breaker for unanchored nodes.
    maplist(arg(1), Actions, AllIds),
    % Extra graph nodes (e.g. inferred actions from enhanced_order_process)
    findall(N, (member(edge(N,_,_), Graph) ; member(edge(_,N,_), Graph)), GNs0),
    sort(GNs0, GraphNodes),
    % Append any graph nodes not already in AllIds at the end.
    exclude(memberchk_in(AllIds), GraphNodes, ExtraNodes),
    append(AllIds, ExtraNodes, AllNodes),
    topo_sort_helper(AllNodes, Graph, [], Sorted).

memberchk_in(List, Elem) :- memberchk(Elem, List).

%! priority_topo_sort_full(+Actions:list, +Graph:list, -Sorted:list) is det.
%  Priority topological sort.  Like topological_sort_full/3 but, when multiple
%  source nodes are simultaneously eligible, picks the candidate that most
%  naturally follows the last placed node using a scoring heuristic.
%
%  Score components (higher = preferred):
%    10  Candidate.Actor == LastPlaced.AuxObject  (AuxObject\u2192Actor principle)
%     5  transition_context(LastPat, CandPat, _, _) — direct corpus match
%     4  same_traceable_object(Cand.Object, Last.Object) — same object chain
%     3  LastPat appears in Candidate's PrecedingPatterns list
%     2  CandPat appears in LastPlaced's FollowingPatterns list
%     2  Candidate.Actor == LastPlaced.Actor (same agent continuing)
%
%  Tie-break: when all scores are equal, the candidate that appears earliest in
%  the input Actions list is preferred (input-order stability).
priority_topo_sort_full(Actions, Graph, Sorted) :-
    maplist(arg(1), Actions, AllIds),
    findall(N, (member(edge(N,_,_), Graph) ; member(edge(_,N,_), Graph)), GNs0),
    sort(GNs0, GraphNodes),
    exclude(memberchk_in(AllIds), GraphNodes, ExtraNodes),
    append(AllIds, ExtraNodes, AllNodes),
    priority_topo_acc(AllNodes, Graph, Actions, none, [], Sorted).

priority_topo_acc([], _, _, _, Acc, Acc).
priority_topo_acc(Remaining, Graph, Actions, LastId, Acc, Sorted) :-
    % Collect all current source nodes (all predecessors already placed).
    findall(Node,
            (member(Node, Remaining),
             \+ (member(edge(Pred, Node, _), Graph), \+ member(Pred, Acc))),
            Sources),
    ( Sources = [] ->
        % Cycle detected: no remaining node has all predecessors placed.
        % Rather than emitting the next input-order node (which collapses the
        % rest of the sequence back to the shuffled order), break the cycle on
        % its weakest link: choose the remaining node whose total incoming
        % weight from still-unplaced predecessors is minimal — i.e. the node
        % held back by the fewest / lowest-confidence back edges.  This
        % approximates a minimum weighted feedback-arc-set choice and lets the
        % sort continue along the strong, high-confidence edges.  Ties are
        % broken by input position for stability.
        findall(BlockW-NegScore-Pos-Node,
                ( nth1(Pos, Remaining, Node),
                  findall(W,
                          ( member(edge(Pred, Node, W), Graph),
                            \+ member(Pred, Acc) ),
                          Ws),
                  sum_list(Ws, BlockW),
                  score_topo_candidate(Node, LastId, Actions, Sc),
                  NegScore is -Sc ),
                Blocked),
        sort(Blocked, [_-_-_-Best|_])
    ;
        findall(Pos-Score-Node,
                (nth1(Pos, Remaining, Node),
                 member(Node, Sources),
                 score_topo_candidate(Node, LastId, Actions, Score)),
                Triples),
        % Sort by Score descending (higher = better), then by Pos ascending
        % (earlier in input = preferred for ties).  Negate Score so msort
        % puts the highest-scored, earliest-position candidate first.
        findall(NegScore-Pos-Node,
                (member(Pos-Score-Node, Triples), NegScore is -Score),
                Keyed),
        msort(Keyed, [_-_-Best|_])
    ),
    select(Best, Remaining, Rest),
    append(Acc, [Best], NewAcc),
    priority_topo_acc(Rest, Graph, Actions, Best, NewAcc, Sorted).

%! score_topo_candidate(+CandId:atom, +LastId:atom, +Actions:list, -Score:integer) is det.
%  Scores how naturally CandId follows LastId.  0 when LastId = none (start).
%
%  Score components (higher = preferred):
%    10  Candidate.Actor == LastPlaced.AuxObject  (AuxObject→Actor principle)
%     7  Candidate has shorter duration than LastPlaced (fast before slow)
%   1-8  Corpus frequency-weighted context: transition_context_count / 2, cap 8
%     4  same_traceable_object(Cand.Object, Last.Object) — same object chain
%     4  temporal_constraint(LastPat, CandPat, precedes, _) — universal time rule
%     3  LastPat appears in Candidate's PrecedingPatterns list
%     2  CandPat appears in LastPlaced's FollowingPatterns list
%     2  Candidate.Actor == LastPlaced.Actor (same agent continuing)
%    -5  Candidate has LONGER duration than LastPlaced (penalise slow-then-fast)
score_topo_candidate(CandId, none, _, Score) :-
    !,
    % Prefer declared process start steps over arbitrary source nodes so that
    % the initial step is correctly anchored regardless of shuffled input order.
    ( process_start_step(_, CandId) -> Score = 10 ; Score = 0 ).
score_topo_candidate(CandId, LastId, Actions, Score) :-
    (   find_action(Actions, CandId, action(_, CPat, CActor, _, CObj, _, _)),
        find_action(Actions, LastId, action(_, LPat, LActor, _, LObj, LAux, _))
    ->
        ( aux_object_actor(LAux, LAuxActor), CActor == LAuxActor -> S1 = 10 ; S1 = 0 ),
        ( patterns_duration_ordered(CPat, LPat) -> S2 =  7
        ; patterns_duration_ordered(LPat, CPat) -> S2 = -5
        ;                                          S2 =  0
        ),
        % Corpus-frequency-weighted: score = min(Count / 2, 8)
        ( transition_context_count(LPat, CPat, Cnt) ->
              S3 is min(Cnt // 2, 8)
        ; transition_context(LPat, CPat, _, _) ->
              S3 = 3
        ;     S3 = 0
        ),
        ( same_traceable_object(CObj, LObj)                                  -> S4 = 4 ; S4 = 0 ),
        ( temporal_constraint(LPat, CPat, precedes, _)                       -> S5 = 4 ; S5 = 0 ),
        ( transition_context(_, CPat, Precs, _), member(LPat, Precs)         -> S6 = 3 ; S6 = 0 ),
        ( transition_context(LPat, _, _, Fols), member(CPat, Fols)           -> S7 = 2 ; S7 = 0 ),
        ( CActor == LActor, LActor \= external_agent                          -> S8 = 2 ; S8 = 0 ),
        Score is S1 + S2 + S3 + S4 + S5 + S6 + S7 + S8
    ;   Score = 0
    ).

%! topo_sort_helper(+Nodes:list, +Graph:list, +Visited:list, -Sorted:list) is det.
%  Helper predicate for topological sorting.
topo_sort_helper([], _, Acc, Acc).
topo_sort_helper(Nodes, Graph, Acc, Sorted) :-
    find_source_node(Nodes, Graph, Acc, Source),
    append(Acc, [Source], NewAcc),
    select(Source, Nodes, RemainingNodes),
    topo_sort_helper(RemainingNodes, Graph, NewAcc, Sorted).

%! find_source_node(+Nodes:list, +Graph:list, +Visited:list, -SourceNode:atom) is det.
%  Finds a node with no incoming edges not already visited.
find_source_node([Node|_], Graph, Visited, Node) :-
    \+ member(edge(_, Node, _), Graph),
    \+ member(Node, Visited), !.
find_source_node([Node|_], Graph, Visited, Node) :-
    \+ (member(edge(Pred, Node, _), Graph),
        \+ member(Pred, Visited)), !.
find_source_node([_|Rest], Graph, Visited, Node) :-
    find_source_node(Rest, Graph, Visited, Node).

%! reorder_by_ids(+Actions:list, +OrderedIds:list, -OrderedActions:list) is det.
%  Reorders actions according to the sorted ID list.
reorder_by_ids(Actions, OrderedIds, Ordered) :-
    maplist(find_action(Actions), OrderedIds, Ordered).

%! find_action(+Actions:list, +Id:atom, -Action:compound) is det.
%  Finds action with given ID in the actions list.
find_action(Actions, Id, Action) :-
    member(Action, Actions),
    Action = action(Id, _, _, _, _, _, _).

% ============================================================================
% MISSING ROLE DETECTION
% ============================================================================

%! detect_missing_roles(+Actions:list, -MissingRoles:list) is det.
%  Detects actions with missing or empty required semantic roles.
%
%  Example query:
%    ?- detect_missing_roles([action(a1,send,alice,'',msg,bob,'')], Missing).
%    Missing = [missing_role(a1, tool)].
detect_missing_roles(Actions, MissingRoles) :-
    findall(missing_role(Id, Role),
        (member(action(Id, Pattern, Actor, Tool, Object, AuxObject, Result), Actions),
         requires_role(Pattern, Role),
         role_value(Role, Actor, Tool, Object, AuxObject, Result, Value),
         (Value = '' ; var(Value))),
        MissingRoles).

%! role_value(+Role:atom, +Actor:atom, +Tool:atom, +Object:atom, +AuxObject:atom, +Result:atom, -Value:atom) is det.
%  Extracts the value for a specific semantic role.
role_value(actor, Actor, _, _, _, _, Actor).
role_value(tool, _, Tool, _, _, _, Tool).
role_value(object, _, _, Object, _, _, Object).
role_value(aux_object, _, _, _, AuxObject, _, AuxObject).
role_value(result, _, _, _, _, Result, Result).

% ============================================================================
% MISSING ACTION DETECTION
% ============================================================================

%! detect_missing_actions(+Actions:list, -MissingActions:list) is det.
%  Identifies gaps in process where actions should exist based on causal chains.
%
%  Example query:
%    ?- detect_missing_actions([action(a1,create,...), action(a3,approve,...)], Missing).
detect_missing_actions(Actions, MissingActions) :-
    order_process(Actions, Ordered),
    find_gaps(Ordered, MissingActions).

%! find_gaps(+OrderedActions:list, -Gaps:list) is det.
%  Finds gaps in the action sequence where bridge actions are needed.
find_gaps([], []).
find_gaps([_], []).
find_gaps([A1, A2|Rest], [Gap|Gaps]) :-
    A1 = action(Id1, P1, _, _, _, _, R1),
    A2 = action(Id2, P2, _, _, O2, _, _),
    extract_object_from_result(R1, Obj1),
    \+ (causal_link(P1, P2, flow(result, object), _), Obj1 = O2),
    find_bridge_pattern(P1, P2, Bridge),
    Gap = missing_action(Id1, Id2, Bridge), !,
    find_gaps([A2|Rest], Gaps).
find_gaps([_|Rest], Gaps) :-
    find_gaps(Rest, Gaps).

%! find_bridge_pattern(+Pattern1:atom, +Pattern2:atom, -BridgePattern:atom) is det.
%  Finds a pattern that can bridge two disconnected patterns.
%
%  Example query:
%    ?- find_bridge_pattern(create, approve, Bridge).
%    Bridge = review.
find_bridge_pattern(P1, P2, Bridge) :-
    causal_link(P1, Bridge, _, _),
    causal_link(Bridge, P2, _, _), !.
find_bridge_pattern(_, _, review).

% ============================================================================
% ACTION INSERTION
% ============================================================================

%! insert_action(+NewAction:compound, +Process:list, -UpdatedProcess:list) is det.
%  Inserts new action into optimal position in process based on causal links.
%
%  Example query:
%    ?- insert_action(action(a2,review,...), [action(a1,create,...)], Updated).
insert_action(NewAction, Process, UpdatedProcess) :-
    NewAction = action(_, _Pattern, _, _, _, _, _),
    find_best_position(NewAction, Process, Position),
    insert_at_position(NewAction, Process, Position, UpdatedProcess).

%! find_best_position(+NewAction:compound, +Process:list, -Position:integer) is det.
%  Finds the best position to insert new action based on causal links.
find_best_position(action(_, Pattern, _, _, Object, _, _), Process, Position) :-
    findall(Score-Pos,
        (nth0(Pos, Process, action(_, PrevPattern, _, _, _, _, PrevResult)),
         extract_object_from_result(PrevResult, PrevObj),
         (causal_link(PrevPattern, Pattern, flow(result, object), Prob) ->
             (PrevObj = Object -> Score is Prob ; Score is Prob * 0.5)
         ;
             Score = 0.1
         )),
        Scores),
    (Scores = [] -> Position = 0 ; max_member(_Score-Position, Scores)).

%! insert_at_position(+Action:compound, +List:list, +Position:integer, -ResultList:list) is det.
%  Inserts action at the specified position in the list.
insert_at_position(Action, List, 0, [Action|List]) :- !.
insert_at_position(Action, [H|T], Pos, [H|Result]) :-
    Pos > 0,
    Pos1 is Pos - 1,
    insert_at_position(Action, T, Pos1, Result).

% ============================================================================
% OBJECT EXISTENCE AND ACTOR ACCESS ANALYSIS
% ============================================================================
% Two complementary gap analyses that operate on the ordered action sequence:
%
%  1. detect_object_existence_gaps/2
%     For every Object used in an action, can we trace it back to a prior
%     Result or creation in the same process?  If not, the object must have
%     arrived from outside (suggested bridge: transfer) or was never created
%     (suggested bridge: generate/create).  We record the lack of knowledge
%     so that a human-in-the-loop can supply the missing information.
%
%  2. detect_object_access_gaps/2
%     Even when an Object exists (was produced by some prior step), we must
%     check that the Actor who will use it actually holds it at that point.
%     If Actor A produced an object but Actor B needs to use it, there must
%     be an intervening send/transfer/learn step.  This is the "key_payment"
%     problem: Microsoft generates the price, but the user must learn it
%     before they can pay.
%
% ============================================================================

%! delivery_pattern(+Pattern:atom) is semidet.
%  True for verb patterns that transfer the Object from Actor to AuxObject.
%  Classification is data-driven via cnl_ontology: any Movement pattern with
%  source direction qualifies.  Surface synonyms resolve through synonym/2.
%  'install' is kept as an explicit clause because the ontology classifies it
%  as receptor-direction (software arriving at device) while process-model
%  semantics treat it as placing the object onto AuxObject (delivery semantics).
%  See edge-case note in docs/cnl_ontology.ttl.
delivery_pattern(P) :-
    verb_pattern(P, movement),
    movement_direction(P, source).
delivery_pattern(P) :-
    synonym(Canonical, P),
    verb_pattern(Canonical, movement),
    movement_direction(Canonical, source).
delivery_pattern(install).  % direction mismatch with ontology — kept explicit

%! intake_pattern(+Pattern:atom) is semidet.
%  True for verb patterns where the Actor acquires the Object they act on.
%  Classification is data-driven via cnl_ontology: any Movement pattern with
%  receptor direction qualifies (excluding pay).  Surface synonyms resolve
%  through synonym/2.
%  'learn' is Perception (not Movement) so kept as an explicit clause.
%  'buy' is not yet in the ontology registry.
%  'pay' is explicitly excluded: paying spends the Object (price); the Actor
%  gains what is encoded in the Result (key), not the Object itself.
intake_pattern(P) :-
    P \= pay,
    verb_pattern(P, movement),
    movement_direction(P, receptor).
intake_pattern(P) :-
    synonym(Canonical, P),
    Canonical \= pay,
    verb_pattern(Canonical, movement),
    movement_direction(Canonical, receptor).
intake_pattern(learn).      % Perception fundamental: knowledge enters actor
intake_pattern(buy).        % not yet in ontology; equivalent to acquire
% Note: pay is NOT here — paying spends the Object (price); the Actor gains
%       what is encoded in the Result (key), not the Object (key_payment).
% Note: install is a delivery_pattern — Object goes TO AuxObject (device).

%! delivery_intake_handoff_ok(+FromAction, +ToAction) is semidet.
%  Hand-off gate for same-object pattern edges between a delivery step and an
%  intake step.  When FromAction uses a delivery pattern and ToAction uses an
%  intake pattern on the SAME traceable object, the edge is valid only if the
%  delivery's recipient (the AuxObject actor) equals the intake step's Actor —
%  i.e. they form a genuine hand-off (sender → that recipient who receives).
%
%  This prevents the all-sends-to-all-receives bipartite blow-up that creates
%  backward edges for objects appearing in many steps (e.g. credit_info has two
%  send/receive pairs; without this gate every send links to every receive,
%  producing one backward edge per cross-pairing).  For every other pattern
%  pair the gate is transparent and always succeeds.
delivery_intake_handoff_ok(action(_, FromPat, _, _, FromObj, FromAux, _),
                           action(_, ToPat, ToActor, _, ToObj, _, _)) :-
    (   delivery_pattern(FromPat),
        intake_pattern(ToPat),
        same_traceable_object(FromObj, ToObj)
    ->  aux_object_actor(FromAux, Recipient),
        Recipient == ToActor
    ;   true
    ).

%! inv_put(+Actor:atom, +Object:atom, +Inv:list, -NewInv:list) is det.
%  Adds Object to Actor's inventory, creating the Actor entry if absent.
inv_put(_, '', Inv, Inv) :- !.
inv_put(_, 'unspecified', Inv, Inv) :- !.
inv_put(Actor, Object, [], [inv(Actor, [Object])]) :- !.
inv_put(Actor, Object, [inv(Actor, Objs)|Rest], [inv(Actor, NewObjs)|Rest]) :- !,
    ( member(Object, Objs) -> NewObjs = Objs ; NewObjs = [Object|Objs] ).
inv_put(Actor, Object, [H|T], [H|NewT]) :-
    inv_put(Actor, Object, T, NewT).

%! inv_check(+Actor:atom, +Object:atom, +Inv:list) is semidet.
%  True if Actor holds Object in inventory Inv.
inv_check(Actor, Object, Inv) :-
    member(inv(Actor, Objs), Inv),
    member(Object, Objs).

%! inv_who_has(+Object:atom, +Inv:list, -Actor:atom) is nondet.
%  Enumerates Actor(s) that hold Object in Inv.
inv_who_has(Object, Inv, Actor) :-
    member(inv(Actor, Objs), Inv),
    member(Object, Objs).

%! apply_action_to_inventory(+Action:compound, +Inv:list, -NewInv:list) is det.
%  Updates actor inventories based on the semantics of Action:
%    - Actor always gains the Result object they produced.
%    - delivery_pattern: AuxObject (recipient) gains the Object.
%    - intake_pattern:   Actor gains the Object they acted on.
apply_action_to_inventory(action(_, Pattern, Actor, _Tool, Object, AuxObject, Result),
                          In, Out) :-
    extract_object_from_result(Result, ResObj),
    ( ResObj \= '' -> inv_put(Actor, ResObj, In, Inv1) ; Inv1 = In ),
    % Creation: Actor holds the Object they produced (e.g. generate→key_payment)
    ( lifecycle_stage(Pattern, creation),
      Object \= '', Object \= 'unspecified' ->
        inv_put(Actor, Object, Inv1, Inv2)
    ;   Inv2 = Inv1
    ),
    % Delivery: AuxObject (recipient) gains Object from Actor
    ( delivery_pattern(Pattern),
      AuxObject \= '', AuxObject \= 'unspecified',
      Object    \= '', Object    \= 'unspecified' ->
        inv_put(AuxObject, Object, Inv2, Inv3)
    ;   Inv3 = Inv2
    ),
    % Intake / acquisition: Actor gains the Object they acted on
    ( intake_pattern(Pattern),
      Object \= '', Object \= 'unspecified' ->
        inv_put(Actor, Object, Inv3, Out)
    ;   Out = Inv3
    ).

%! build_actor_inventory(+Actions:list, -FinalInventory:list) is det.
%  Simulates all actions in the ordered sequence and returns the final
%  actor inventories as a list of inv(Actor, [Objects]).
%
%  Example query:
%    ?- build_actor_inventory([action(w9,generate,microsoft,microsoft,
%                                     key_payment,microsoft,'payment:defined'),
%                              action(w7,learn,user,user,key_payment,
%                                     microsoft,'payment:learned')],
%                             Inv).
%    Inv = [inv(microsoft,[payment_defined,key_payment]),
%           inv(user,[payment_learned,key_payment])].
build_actor_inventory(Actions, FinalInventory) :-
    foldl(apply_action_to_inventory, Actions, [], FinalInventory).

%! is_trivial_object(+Object:atom, +Actor:atom) is semidet.
%  Suppresses gap checks for blank, self-referential, or placeholder values.
is_trivial_object(Object, _)    :- ( Object = '' ; Object = 'unspecified' ), !.
is_trivial_object(Object, Actor):- Object == Actor, !.

%! is_traceable(+Object:atom, +Actor:atom, +Known:list) is semidet.
%  Object is traceable if it appeared in Known (produced by a prior action),
%  equals the Actor (self-reference), or is empty.
%  Also accepts token-subset matches (min 4 chars) so that e.g. "version"
%  is traceable from a known "all_versions", and "one_version" from "version".
is_traceable(Object, Actor, _) :- is_trivial_object(Object, Actor), !.
is_traceable(Object, _, Known) :-
    member(known(KO, _), Known),
    ( KO == Object
    ;   extract_base_object_name(KO,     BaseK),
        extract_base_object_name(Object, BaseO),
        ( BaseK == BaseO
        ; atom_length(BaseO, LO), LO >= 4, sub_atom(BaseK, _, _, _, BaseO)
        ; atom_length(BaseK, LK), LK >= 4, sub_atom(BaseO, _, _, _, BaseK)
        )
    ), !.

%! detect_object_existence_gaps(+Actions:list, -Gaps:list) is det.
%  For every action in the given sequence, checks whether the Object
%  can be traced to a prior action's Result.  Objects that appear from
%  nowhere are recorded as existence_gap/4 so a human reviewer can
%  supply or infer the missing provenance step.
%  Actions are scanned in the provided order; no causal inference is run.
%
%  Entries:  existence_gap(ActionId, Object, SuggestedBridge, Note)
%    Note = no_prior_creation_action       — no creative action is known
%    Note = object_origin_outside_process  — likely transferred from outside
detect_object_existence_gaps(Actions, Gaps) :-
    check_existence_seq(Actions, [], Gaps).

check_existence_seq([], _, []).
check_existence_seq([action(Id, Pat, Actor, _T, Object, _Aux, Result)|Rest],
                    Known, AllGaps) :-
    ( Actor = external_agent ->
        ObjGaps = []  % external_agent is outside the process boundary — no provenance needed
    ; is_traceable(Object, Actor, Known) ->
        ObjGaps = []
    ;
        infer_creation_pattern(Object, Pat, Suggested),
        ( lifecycle_stage(Suggested, creation) ->
            Note = no_prior_creation_action
        ;
            Note = object_origin_outside_process
        ),
        ObjGaps = [existence_gap(Id, Object, Suggested, Note)]
    ),
    extract_object_from_result(Result, ResObj),
    ( ResObj \= '' ->
        Known1 = [known(ResObj, Actor), known(Object, Actor)|Known]
    ;
        Known1 = [known(Object, Actor)|Known]
    ),
    check_existence_seq(Rest, Known1, RestGaps),
    append(ObjGaps, RestGaps, AllGaps).

%! detect_object_access_gaps(+Actions:list, -Gaps:list) is det.
%  Simulates actor inventories step by step through the provided sequence.
%  For each action, if the Actor does not hold the Object they need but
%  some other Actor does, an access_gap/5 is flagged.
%  Pass actions in the intended execution order (e.g., windows_ordered_ids).
%
%  Entries:  access_gap(ActionId, Actor, Object, held_by(Holder), Bridge)
detect_object_access_gaps(Actions, Gaps) :-
    check_access_seq(Actions, [], Gaps).

check_access_seq([], _, []).
check_access_seq([Action|Rest], Inventory, AllGaps) :-
    Action = action(Id, Pat, Actor, Tool, Object, Aux, Result),
    ( is_trivial_object(Object, Actor) ->
        AccessGaps = []
    ;
        % Intake-pattern actions (receive, learn, get, buy …) acquire the object
        % — the Actor is GETTING it, so pre-existence is not required.
        intake_pattern(Pat) ->
        AccessGaps = []
    ;
        ( inv_check(Actor, Object, Inventory) ->
            AccessGaps = []   % Actor already holds Object — no gap
        ;
            ( inv_who_has(Object, Inventory, Holder), Holder \= Actor ->
                % Object exists but the wrong Actor holds it
                infer_delivery_bridge(Object, Holder, Actor, Bridge),
                AccessGaps = [access_gap(Id, Actor, Object, held_by(Holder), Bridge)]
            ;
                AccessGaps = []  % nobody holds it yet; existence_gap covers this
            )
        )
    ),
    apply_action_to_inventory(action(Id, Pat, Actor, Tool, Object, Aux, Result),
                              Inventory, NewInventory),
    check_access_seq(Rest, NewInventory, RestGaps),
    append(AccessGaps, RestGaps, AllGaps).

%! infer_delivery_bridge(+Object:atom, +From:atom, +To:atom, -Bridge:atom) is det.
%  Selects the most fitting bridge pattern to transfer Object from one
%  Actor to another.  Information/price/knowledge objects use 'learn';
%  material and digital objects use 'send'.
infer_delivery_bridge(Object, _From, _To, learn) :-
    atom_string(Object, ObjStr),
    ( sub_string(ObjStr, _, _, _, "payment")
    ; sub_string(ObjStr, _, _, _, "price")
    ; sub_string(ObjStr, _, _, _, "info")
    ; sub_string(ObjStr, _, _, _, "knowledge")
    ; sub_string(ObjStr, _, _, _, "learn")
    ), !.
infer_delivery_bridge(_, _, _, send).

% ============================================================================
% ACTOR KNOWLEDGE TRACE
%
% The central validity mechanism: for each actor, at each step, we maintain
% an explicit list of what the actor *knows* (holds, is aware of).  Every
% entry carries full provenance — who supplied the object and at what step.
%
% Data structures
% ---------------
%   knowledge(Object, source(StepId, Pattern, SourceActor))
%     Object      — the atom the actor knows
%     StepId      — the action that added this knowledge
%     Pattern     — the verb pattern that caused the transfer
%     SourceActor — the actor who previously held / created the object
%                   ('world' when the object is assumed from the outside)
%
%   actor_state(Step, Actor, KnownList)
%     Step      — the action Id BEFORE which this state is asserted
%     Actor     — actor atom
%     KnownList — list of knowledge/2 terms
%
%   step_trace(StepId, pre(ActorStates), post(ActorStates), gaps(Gaps))
%     Full record for one step: knowledge states before and after,
%     plus any detected knowledge gaps.
%
% API
% ---
%   build_knowledge_trace(+Actions, -Trace)
%     Returns list of step_trace/4 for every action in the input sequence.
%
%   verify_process_knowledge(+Actions, -AllGaps)
%     Flat list of access_gap/5 terms (same as detect_object_access_gaps)
%     but now enriched with source provenance from the trace.
%
%   print_knowledge_trace(+Trace)
%     Human-readable formatted trace for debugging and explainability.
% ============================================================================

%! cnl_physical_informational_reference(-Reference:compound) is det.
%  Canonical publication anchor for the physical vs informational local-context
%  distinction used by agent-memory snapshots.
cnl_physical_informational_reference(
    cnl_reference('/Users/vladnm/Documents/GitHub/AIFramework/CNL_Publication_Draft.md',
                  '4.9 Physical vs. Informational Local Contexts')).

%! kstate_lookup(+Actor:atom, +States:list, -KnownList:list) is det.
%  Returns KnownList for Actor in States, or [] if Actor not yet present.
kstate_lookup(Actor, States, Known) :-
    ( member(actor_state(Actor, Known), States) -> true ; Known = [] ).

%! kstate_knows(+Actor:atom, +Object:atom, +States:list) is semidet.
%  True if Actor knows Object in States (base object name matched).
%  Also accepts token-subset matches (min 4 chars): "version" is known when
%  actor knows "all_versions"; "one_version" is known when actor knows "version".
kstate_knows(Actor, Object, States) :-
    kstate_lookup(Actor, States, Known),
    member(knowledge(KObj, _), Known),
    extract_base_object_name(KObj,  BaseK),
    extract_base_object_name(Object, BaseO),
    ( BaseK == BaseO
    ; atom_length(BaseO, LO), LO >= 4, sub_atom(BaseK, _, _, _, BaseO)
    ; atom_length(BaseK, LK), LK >= 4, sub_atom(BaseO, _, _, _, BaseK)
    ).

%! kstate_who_knows(+Object:atom, +States:list, -Holder:atom) is nondet.
%  Enumerates every Actor who currently knows Object.
kstate_who_knows(Object, States, Holder) :-
    member(actor_state(Holder, Known), States),
    member(knowledge(KObj, _), Known),
    extract_base_object_name(KObj,  BaseK),
    extract_base_object_name(Object, BaseO),
    BaseK == BaseO.

%! kstate_add(+Actor:atom, +Object:atom, +StepId:atom, +Pattern:atom,
%!            +SourceActor:atom, +StatesIn:list, -StatesOut:list) is det.
%  Adds knowledge(Object, source(StepId,Pattern,SourceActor)) to Actor's list.
kstate_add(_Actor, Object, _, _, _, States, States) :-
    ( Object = '' ; Object = 'unspecified' ), !.
kstate_add(Actor, Object, StepId, Pat, Src, StatesIn, StatesOut) :-
    extract_base_object_name(Object, BaseObj),
    New = knowledge(BaseObj, source(StepId, Pat, Src)),
    ( select(actor_state(Actor, Existing), StatesIn, Rest) ->
        ( member(knowledge(BaseObj, _), Existing) ->
            StatesOut = StatesIn          % already known — no duplicate
        ;
            StatesOut = [actor_state(Actor, [New|Existing])|Rest]
        )
    ;   StatesOut = [actor_state(Actor, [New])|StatesIn]
    ).

%! apply_action_to_knowledge(+Action:compound, +StatesIn:list,
%!                           -StatesOut:list, -Gaps:list) is det.
%  Given knowledge states before the action:
%    1. Checks whether the Actor knows the Object they need (gap if not).
%    2. Updates states after the action based on pattern semantics.
apply_action_to_knowledge(action(Id, Pat, Actor, _Tool, Object, AuxObject, Result),
                          StatesIn, StatesOut, Gaps) :-
    extract_base_object_name(Object, BaseObj),
    extract_object_from_result(Result, ResObjRaw),
    extract_base_object_name(ResObjRaw, ResObj),

    % ---- pre-condition check ----
    ( ( BaseObj = '' ; BaseObj = 'unspecified' ; Actor == BaseObj ) ->
        Gaps = []                          % nothing to check
    ; Actor = external_agent ->
        Gaps = []                          % external_agent always has access — no gap needed
    ; intake_pattern(Pat) ->
        Gaps = []                          % intake steps acquire — no pre-check
    ; lifecycle_stage(Pat, creation) ->
        Gaps = []                          % creation steps produce the object — no prior knowledge needed
    ; kstate_knows(Actor, BaseObj, StatesIn) ->
        Gaps = []                          % Actor already knows it
    ;
        ( kstate_who_knows(BaseObj, StatesIn, Holder), Holder \= Actor ->
            infer_delivery_bridge(BaseObj, Holder, Actor, Bridge),
            Gaps = [access_gap(Id, Actor, BaseObj, held_by(Holder), Bridge)]
        ;
            % Nobody knows it yet — first appearance in the process
            infer_creation_pattern(BaseObj, Pat, Suggested),
            Gaps = [existence_gap(Id, BaseObj, Suggested, no_prior_creation_action)]
        )
    ),

    % ---- post-condition: update knowledge ----
    % Creator gains the Object they produced
    ( lifecycle_stage(Pat, creation), BaseObj \= '' ->
        kstate_add(Actor, BaseObj, Id, Pat, Actor, StatesIn, S1)
    ;   S1 = StatesIn
    ),
    % Delivery: AuxObject (recipient) gains Object
    ( delivery_pattern(Pat),
      AuxObject \= '', AuxObject \= 'unspecified',
      BaseObj \= '' ->
        kstate_add(AuxObject, BaseObj, Id, Pat, Actor, S1, S2)
    ;   S2 = S1
    ),
    % Intake: Actor gains Object from whoever held it (or world)
    ( intake_pattern(Pat), BaseObj \= '' ->
        ( kstate_who_knows(BaseObj, StatesIn, Giver) ->
            kstate_add(Actor, BaseObj, Id, Pat, Giver, S2, S3)
        ;
            kstate_add(Actor, BaseObj, Id, Pat, world, S2, S3)
        )
    ;   S3 = S2
    ),
    % Actor always gains knowledge of the Result they produced
    ( ResObj \= '' ->
        kstate_add(Actor, ResObj, Id, Pat, Actor, S3, StatesOut)
    ;   StatesOut = S3
    ).

%! build_knowledge_trace(+Actions:list, -Trace:list) is det.
%  Processes actions in the provided order, building a step-by-step trace.
%  Returns list of step_trace(StepId, pre(States), post(States), gaps(Gaps)).
%
%  Example query:
%    ?- windows_ordered_actions(A), build_knowledge_trace(A, T),
%       print_knowledge_trace(T).
build_knowledge_trace(Actions, Trace) :-
    build_trace_acc(Actions, [], Trace).

build_trace_acc([], _, []).
build_trace_acc([Action|Rest], StatesBefore, [Entry|Trace]) :-
    Action = action(Id, _, _, _, _, _, _),
    apply_action_to_knowledge(Action, StatesBefore, StatesAfter, Gaps),
    Entry = step_trace(Id, pre(StatesBefore), post(StatesAfter), gaps(Gaps)),
    build_trace_acc(Rest, StatesAfter, Trace).

%! verify_process_knowledge(+Actions:list, -AllGaps:list) is det.
%  Returns all gaps (existence_gap/4 and access_gap/5) detected across
%  the full process using the knowledge trace.
verify_process_knowledge(Actions, AllGaps) :-
    build_knowledge_trace(Actions, Trace),
    findall(Gap,
            (member(step_trace(_, _, _, gaps(Gaps)), Trace),
             member(Gap, Gaps)),
            AllGaps).

%! build_agent_memory_trace(+Actions:list, -Trace:list) is det.
%  Builds a richer per-step trace for every agent in the process.
%  Each step records two explicit tables aligned with CNL draft section 4.9:
%    - knows: informational awareness / semantic availability
%    - has:   physical possession / material availability
%  The trace is intended for session observability and post-run Prolog dumps.
build_agent_memory_trace(Actions, Trace) :-
    build_object_context_index(Actions, ContextIndex),
    build_agent_memory_trace_acc(Actions, ContextIndex, [], [], Trace).

build_agent_memory_trace_acc([], _, _, _, []).
build_agent_memory_trace_acc([Action|Rest], ContextIndex, KnowledgeBefore, HasBefore,
                             [agent_memory_step(Id,
                                                action(Pattern, Actor, Object, AuxObject, Result),
                                                context(Kind, Basis, Reference),
                                                pre(PreSnapshots),
                                                post(PostSnapshots),
                                                gaps(Gaps))|Trace]) :-
    Action = action(Id, Pattern, Actor, _Tool, Object, AuxObject, Result),
    cnl_physical_informational_reference(Reference),
    snapshot_agent_memory(KnowledgeBefore, HasBefore, ContextIndex, PreSnapshots),
    apply_action_to_knowledge(Action, KnowledgeBefore, KnowledgeAfter, Gaps),
    apply_action_to_possession(Action, ContextIndex, HasBefore, HasAfter),
    action_memory_context(Action, HasBefore, HasAfter, ContextIndex, Kind, Basis),
    snapshot_agent_memory(KnowledgeAfter, HasAfter, ContextIndex, PostSnapshots),
    build_agent_memory_trace_acc(Rest, ContextIndex, KnowledgeAfter, HasAfter, Trace).

action_memory_context(action(_, Pattern, _Actor, _Tool, Object, _AuxObject, Result),
                      HasBefore, HasAfter, _ContextIndex, Kind, Basis) :-
    possession_state_delta(HasBefore, HasAfter, Delta),
    Delta \= [], !,
    preferred_context_object(Object, Result, ContextObject),
    Kind = physical,
    Basis = possession_delta(ContextObject, Pattern, Delta).
action_memory_context(action(_, Pattern, _Actor, _Tool, Object, _AuxObject, Result),
                      _HasBefore, _HasAfter, _ContextIndex, physical, Basis) :-
    ambiguous_material_pattern(Pattern),
    preferred_context_object(Object, Result, ContextObject),
    material_entity_context(ContextObject, MaterialBasis), !,
    Basis = explicit_material_handoff(ContextObject, Pattern, MaterialBasis).
action_memory_context(action(_, Pattern, _Actor, _Tool, Object, _AuxObject, Result),
                      _HasBefore, _HasAfter, ContextIndex, Kind, Basis) :-
    preferred_context_object(Object, Result, ContextObject),
    classify_context_from_process(ContextObject, Pattern, ContextIndex, Kind, DerivedBasis),
    Basis = knowledge_only_context(ContextObject, Pattern, DerivedBasis).

classify_context_from_process(Object, _Pattern, ContextIndex, Kind, Basis) :-
    object_context_kind(Object, ContextIndex, Kind, Basis), !.
classify_context_from_process(_Object, Pattern, _ContextIndex, Kind, Basis) :-
    ( strong_physical_context_pattern(Pattern) ->
        Kind = physical,
        Basis = strong_pattern_signal(Pattern)
    ; strong_informational_context_pattern(Pattern) ->
        Kind = informational,
        Basis = strong_pattern_signal(Pattern)
    ; Kind = informational,
      Basis = default_informational_due_to_cnl_4_9
    ).

preferred_context_object(Object, _Result, BaseObject) :-
    extract_base_object_name(Object, BaseObject),
    BaseObject \= '',
    BaseObject \= 'unspecified', !.
preferred_context_object(_Object, Result, BaseObject) :-
    extract_object_from_result(Result, ResultObject),
    extract_base_object_name(ResultObject, BaseObject),
    BaseObject \= '',
    BaseObject \= 'unspecified', !.
preferred_context_object(_, _, unspecified).

build_object_context_index(Actions, ContextIndex) :-
    findall(Object,
            ( member(Action, Actions),
              action_context_object(Action, Object)
            ),
            RawObjects),
    sort(RawObjects, Objects),
    findall(object_context(Object, Kind, Basis),
            ( member(Object, Objects),
              classify_object_from_process(Actions, Object, Kind, Basis)
            ),
            ContextIndex).

action_context_object(action(_, _Pattern, _Actor, _Tool, Object, _AuxObject, Result), ContextObject) :-
    preferred_context_object(Object, Result, ContextObject),
    ContextObject \= unspecified.

classify_object_from_process(_Actions, Object, Kind, Basis) :-
    resolved_entity_context(Object, Kind, DeclaredBasis), !,
    Basis = explicit_process_library_context(DeclaredBasis).
classify_object_from_process(Actions, Object, Kind, Basis) :-
    findall(Evidence,
            object_context_evidence(Actions, Object, Evidence),
            RawEvidence),
    sort(RawEvidence, Evidence),
    decide_object_context(Evidence, Kind, Basis).

object_context_evidence(Actions, Object, physical_step(Id, Pattern)) :-
    member(action(Id, Pattern, _Actor, _Tool, ActionObject, _AuxObject, Result), Actions),
    action_mentions_object(Object, ActionObject, Result),
    strong_physical_context_pattern(Pattern).
object_context_evidence(Actions, Object, informational_step(Id, Pattern)) :-
    member(action(Id, Pattern, _Actor, _Tool, ActionObject, _AuxObject, Result), Actions),
    action_mentions_object(Object, ActionObject, Result),
    strong_informational_context_pattern(Pattern).
object_context_evidence(Actions, Object, ambiguous_step(Id, Pattern)) :-
    member(action(Id, Pattern, _Actor, _Tool, ActionObject, _AuxObject, Result), Actions),
    action_mentions_object(Object, ActionObject, Result),
    ambiguous_context_pattern(Pattern).

action_mentions_object(Object, ActionObject, _Result) :-
    extract_base_object_name(ActionObject, BaseObject),
    BaseObject == Object.
action_mentions_object(Object, _ActionObject, Result) :-
    extract_object_from_result(Result, ResultObjectRaw),
    extract_base_object_name(ResultObjectRaw, BaseObject),
    BaseObject == Object.

decide_object_context(Evidence, physical, process_evidence(PhysicalEvidence)) :-
    include(is_physical_context_evidence, Evidence, PhysicalEvidence),
    PhysicalEvidence \= [],
    exclude(is_physical_context_evidence, Evidence, NonPhysicalEvidence),
    \+ has_informational_context_evidence(NonPhysicalEvidence), !.
decide_object_context(Evidence, informational,
                      mixed_process_evidence(PhysicalEvidence, InformationalEvidence)) :-
    include(is_physical_context_evidence, Evidence, PhysicalEvidence),
    include(is_informational_context_evidence, Evidence, InformationalEvidence),
    PhysicalEvidence \= [],
    InformationalEvidence \= [], !.
decide_object_context(Evidence, informational, process_evidence(Evidence)) :-
    Evidence \= [], !.
decide_object_context([], informational, no_process_context_evidence).

is_physical_context_evidence(physical_step(_, _)).
is_informational_context_evidence(informational_step(_, _)).

has_informational_context_evidence(Evidence) :-
    member(informational_step(_, _), Evidence).

strong_physical_context_pattern(deliver).
strong_physical_context_pattern(pickup).
strong_physical_context_pattern(install).
strong_physical_context_pattern(place).
strong_physical_context_pattern(store).
strong_physical_context_pattern(transfer).
strong_physical_context_pattern(ship).
strong_physical_context_pattern(connect).
strong_physical_context_pattern(give).

strong_informational_context_pattern(learn).
strong_informational_context_pattern(notify).
strong_informational_context_pattern(explain).
strong_informational_context_pattern(review).
strong_informational_context_pattern(compare).
strong_informational_context_pattern(monitor).
strong_informational_context_pattern(record).
strong_informational_context_pattern(request).
strong_informational_context_pattern(approve).
strong_informational_context_pattern(authenticate).
strong_informational_context_pattern(authorize).
strong_informational_context_pattern(analyze).
strong_informational_context_pattern(plan).
strong_informational_context_pattern(design).

ambiguous_context_pattern(create).
ambiguous_context_pattern(generate).
ambiguous_context_pattern(send).
ambiguous_context_pattern(receive).
ambiguous_context_pattern(get).
ambiguous_context_pattern(take).
ambiguous_context_pattern(acquire).
ambiguous_context_pattern(buy).
ambiguous_context_pattern(execute).
ambiguous_context_pattern(stream).
ambiguous_context_pattern(display).
ambiguous_context_pattern(offer).

object_context_kind(Object, ContextIndex, Kind, Basis) :-
    member(object_context(Object, Kind, Basis), ContextIndex), !.

snapshot_agent_memory(KnowledgeStates, HasStates, ContextIndex, Snapshots) :-
    findall(Actor,
            ( member(actor_state(Actor, _), KnowledgeStates)
            ; member(possession_state(Actor, _), HasStates)
            ),
            RawActors),
    sort(RawActors, Actors),
    maplist(agent_memory_snapshot(KnowledgeStates, HasStates, ContextIndex), Actors, Snapshots).

agent_memory_snapshot(KnowledgeStates, HasStates, ContextIndex, Actor,
                      agent_memory(Actor, knows(Knows), has(Has))) :-
    kstate_lookup(Actor, KnowledgeStates, KnownEntries),
    findall(memory_object(Object, Kind, Source),
            ( member(knowledge(Object, Source), KnownEntries),
              knowledge_entry_kind(Object, Source, ContextIndex, Kind)
            ),
            RawKnows),
    sort(RawKnows, Knows),
    pstate_lookup(Actor, HasStates, PossessionEntries),
    findall(memory_object(Object, physical, Source),
            member(possession(Object, Source), PossessionEntries),
            RawHas),
    sort(RawHas, Has).

knowledge_entry_kind(Object, source(_StepId, Pattern, _SourceActor), ContextIndex, Kind) :-
    classify_context_from_process(Object, Pattern, ContextIndex, Kind, _), !.
knowledge_entry_kind(_, _, _, informational).

pstate_lookup(Actor, States, Possessions) :-
    ( member(possession_state(Actor, Possessions), States) -> true ; Possessions = [] ).

pstate_add(_Actor, Object, _, _, _, States, States) :-
    ( Object = '' ; Object = 'unspecified' ), !.
pstate_add(Actor, Object, StepId, Pattern, SourceActor, StatesIn, StatesOut) :-
    extract_base_object_name(Object, BaseObject),
    New = possession(BaseObject, source(StepId, Pattern, SourceActor)),
    ( select(possession_state(Actor, Existing), StatesIn, Rest) ->
        ( member(possession(BaseObject, _), Existing) ->
            StatesOut = StatesIn
        ; StatesOut = [possession_state(Actor, [New|Existing])|Rest]
        )
    ; StatesOut = [possession_state(Actor, [New])|StatesIn]
    ).

pstate_remove(_, Object, States, States) :-
    ( Object = '' ; Object = 'unspecified' ), !.
pstate_remove(Actor, Object, StatesIn, StatesOut) :-
    extract_base_object_name(Object, BaseObject),
    ( select(possession_state(Actor, Existing), StatesIn, Rest) ->
        exclude(matches_possession(BaseObject), Existing, Remaining),
        ( Remaining = [] ->
            StatesOut = Rest
        ; StatesOut = [possession_state(Actor, Remaining)|Rest]
        )
    ; StatesOut = StatesIn
    ).

matches_possession(Object, possession(Object, _)).

pstate_who_has(Object, States, Holder) :-
    extract_base_object_name(Object, BaseObject),
    member(possession_state(Holder, Possessions), States),
    member(possession(PossessedObject, _), Possessions),
    PossessedObject == BaseObject.

possession_state_delta(StatesBefore, StatesAfter, Delta) :-
    findall(gained(Actor, Object),
            possession_delta_added(StatesBefore, StatesAfter, Actor, Object),
            Added),
    findall(lost(Actor, Object),
            possession_delta_removed(StatesBefore, StatesAfter, Actor, Object),
            Removed),
    append(Added, Removed, Delta).

possession_delta_added(StatesBefore, StatesAfter, Actor, Object) :-
    member(possession_state(Actor, PossessionsAfter), StatesAfter),
    member(possession(Object, _), PossessionsAfter),
    \+ possession_present(StatesBefore, Actor, Object).

possession_delta_removed(StatesBefore, StatesAfter, Actor, Object) :-
    member(possession_state(Actor, PossessionsBefore), StatesBefore),
    member(possession(Object, _), PossessionsBefore),
    \+ possession_present(StatesAfter, Actor, Object).

possession_present(States, Actor, Object) :-
    member(possession_state(Actor, Possessions), States),
    member(possession(Object, _), Possessions).

apply_action_to_possession(Action, ContextIndex, StatesIn, StatesOut) :-
    ( material_possession_action(Action, ContextIndex) ->
        apply_material_possession_action(Action, StatesIn, StatesOut)
    ; StatesOut = StatesIn
    ).

material_possession_action(action(_, Pattern, _Actor, _Tool, Object, _AuxObject, Result),
                           ContextIndex) :-
    preferred_context_object(Object, Result, ContextObject),
    \+ object_context_kind(ContextObject, ContextIndex, informational, _),
    ( strong_physical_context_pattern(Pattern) ->
        true
    ; ambiguous_material_pattern(Pattern),
            ( material_entity_context(ContextObject, _)
            ; object_context_kind(ContextObject, ContextIndex, physical, _)
            )
    ).

ambiguous_material_pattern(create).
ambiguous_material_pattern(generate).
ambiguous_material_pattern(send).
ambiguous_material_pattern(receive).
ambiguous_material_pattern(get).
ambiguous_material_pattern(take).
ambiguous_material_pattern(acquire).
ambiguous_material_pattern(buy).

apply_material_possession_action(action(Id, Pattern, Actor, _Tool, Object, AuxObject, Result),
                                 StatesIn, StatesOut) :-
    extract_base_object_name(Object, BaseObject),
    extract_object_from_result(Result, ResultObjectRaw),
    extract_base_object_name(ResultObjectRaw, ResultObject),
    ( lifecycle_stage(Pattern, creation),
      BaseObject \= '', BaseObject \= 'unspecified' ->
        pstate_add(Actor, BaseObject, Id, Pattern, Actor, StatesIn, S1)
    ;   S1 = StatesIn
    ),
    ( delivery_pattern(Pattern),
      AuxObject \= '', AuxObject \= 'unspecified',
      BaseObject \= '', BaseObject \= 'unspecified' ->
        pstate_remove(Actor, BaseObject, S1, S2a),
        pstate_add(AuxObject, BaseObject, Id, Pattern, Actor, S2a, S2)
    ;   S2 = S1
    ),
    ( intake_pattern(Pattern),
      BaseObject \= '', BaseObject \= 'unspecified' ->
        ( pstate_who_has(BaseObject, S2, Holder) ->
            pstate_remove(Holder, BaseObject, S2, S3a),
            SourceActor = Holder
        ;   S3a = S2,
            SourceActor = world
        ),
        pstate_add(Actor, BaseObject, Id, Pattern, SourceActor, S3a, S3)
    ;   S3 = S2
    ),
    ( ResultObject \= '', ResultObject \= 'unspecified', ResultObject \= BaseObject ->
        pstate_add(Actor, ResultObject, Id, Pattern, Actor, S3, StatesOut)
    ;   StatesOut = S3
    ).

%! print_knowledge_trace(+Trace:list) is det.
%  Prints a human-readable table of actor knowledge states at each step.
print_knowledge_trace([]).
print_knowledge_trace([step_trace(Id, pre(Pre), post(Post), gaps(Gaps))|Rest]) :-
    format("~n--- Step ~w ---~n", [Id]),
    ( Gaps \= [] ->
        writeln("  !! GAPS DETECTED:"),
        forall(member(G, Gaps), (write("     "), writeln(G)))
    ; true ),
    writeln("  Knowledge BEFORE this step:"),
    ( Pre = [] ->
        writeln("    (no actors have knowledge yet)")
    ;
        forall(member(actor_state(Actor, Known), Pre),
               ( format("    ~w knows:~n", [Actor]),
                 forall(member(knowledge(Obj, source(Src, Pat, From)), Known),
                        format("      ~w  (from step ~w via ~w by ~w)~n",
                               [Obj, Src, Pat, From])) ))
    ),
    writeln("  Knowledge AFTER this step:"),
    forall(member(actor_state(Actor2, Known2), Post),
           ( format("    ~w knows:~n", [Actor2]),
             forall(member(knowledge(Obj2, source(Src2, Pat2, From2)), Known2),
                    format("      ~w  (from step ~w via ~w by ~w)~n",
                           [Obj2, Src2, Pat2, From2])) )),
    print_knowledge_trace(Rest).

% ============================================================================
% PROCESS REPAIR / AUTO-CORRECTION
%
% When a gap is discovered in the knowledge trace the engine can automatically
% insert a corrective "bridge" action into the process, turning detection into
% correction.  The repair loop iterates until the process converges (no new
% gaps remain) or a safety limit is reached.
%
% Correction rules
% ----------------
%   access_gap(StepId, Actor, Object, held_by(Holder), Bridge)
%     → Insert  action(bridge_<StepId>_<N>, Bridge, Holder, system,
%                      Object, Actor, Object:Bridge)
%       immediately before StepId.
%       Holder delivers Object to Actor via Bridge pattern.
%
%   existence_gap(StepId, Object, SuggestedPattern, _)
%     → Insert  action(create_<StepId>_<N>, SuggestedPattern,
%                      external_agent, system, Object, '', Object:SuggestedPattern)
%       immediately before StepId.
%       An external agent creates the object.  On the next repair pass the
%       engine will then detect an access_gap and insert a transfer too.
%
% This two-pass behaviour for existence gaps is intentional: it models that
% first something must be created (by whom?), and only then transferred.
%
% API
% ---
%   repair_process_once(+Actions, -Repaired, -InsertedCount)
%     One pass: insert one bridge per gap.  InsertedCount > 0 means the
%     process changed.
%
%   repair_process(+Actions, -Repaired)
%     Iterate repair_process_once until InsertedCount = 0 (stable) or 20
%     iterations (safety limit).  Returns the fully corrected action list.
%
%   print_repaired_process(+Original, +Repaired)
%     Summary diff: added bridge actions highlighted.
% ============================================================================

%! gap_to_bridge_action(+Gap:compound, +OrigActions:list, +Seq:integer, -BridgeAction:compound) is det.
%  Converts a knowledge gap term into the corrective action to insert.
%
%  access_gap cases (based on bridge pattern type):
%   - intake_pattern (learn, receive, …): Actor actively pulls Object
%   - delivery_pattern (send, transfer, …): Holder pushes Object to Actor
%
%  existence_gap case:
%   - transfer-type objects (external input) → external_agent
%   - generate-type objects at a send step   → AuxObject (recipient) is the creator
gap_to_bridge_action(access_gap(StepId, Actor, Object, held_by(_Holder), Bridge),
                     _OrigActions, Seq,
                     action(BId, Bridge, Actor, system, Object, '', Result)) :-
    intake_pattern(Bridge), !,
    atomic_list_concat([bridge, StepId, Seq], '_', BId),
    atomic_list_concat([Object, Bridge], ':', Result).
gap_to_bridge_action(access_gap(StepId, Actor, Object, held_by(Holder), Bridge),
                     _OrigActions, Seq,
                     action(BId, Bridge, Holder, system, Object, Actor, Result)) :-
    atomic_list_concat([bridge, StepId, Seq], '_', BId),
    atomic_list_concat([Object, Bridge], ':', Result).
gap_to_bridge_action(existence_gap(StepId, Object, SuggestedPat, _),
                     OrigActions, Seq,
                     action(BId, SuggestedPat, Creator, system, Object, '', Result)) :-
    infer_existence_gap_creator(StepId, Object, SuggestedPat, OrigActions, Creator),
    atomic_list_concat([create, StepId, Seq], '_', BId),
    atomic_list_concat([Object, SuggestedPat], ':', Result).

%! infer_existence_gap_creator(+StepId, +Object, +SuggestedPat, +Actions, -Creator) is det.
%  Determines who should be credited as the creator of a missing object.
%
%  Rules (in priority order):
%  1. transfer-type gap → external_agent (object originates outside the process)
%  2. generate-type gap at a send step where the recipient is a real actor
%       → recipient (AuxObject) is the generator  (e.g. microsoft sets the price
%          for a key before the user can send payment for it)
%  3. default → external_agent
infer_existence_gap_creator(_, _, transfer, _, external_agent) :- !.
infer_existence_gap_creator(StepId, Object, generate, Actions, AuxObject) :-
    member(action(StepId, send, _, _, Object, AuxObject, _), Actions),
    AuxObject \= '', AuxObject \= 'unspecified', AuxObject \= external_agent, !.
infer_existence_gap_creator(_, _, _, _, external_agent).

%! insert_before_step(+New:compound, +BeforeId:atom,
%!                    +ActsIn:list, -ActsOut:list) is det.
%  Inserts New immediately before the action with Id = BeforeId.
insert_before_step(New, _, [], [New]).   % fallback: append at end
insert_before_step(New, BeforeId, [A|As], [New, A|As]) :-
    A = action(BeforeId, _, _, _, _, _, _), !.
insert_before_step(New, BeforeId, [A|As], [A|Rest]) :-
    insert_before_step(New, BeforeId, As, Rest).

%! repair_process_once(+Actions:list, -Repaired:list, -Count:integer) is det.
%  Single repair pass.  Runs the knowledge trace, then for every gap inserts
%  exactly one bridge action before the offending step.
%  OrigActions is the input list at the START of this pass (before any
%  insertions).  It is forwarded to gap_to_bridge_action so that the
%  correct actor can be inferred from the surrounding context.
%  Count = number of actions added (0 means no gaps remained).
repair_process_once(Actions, Repaired, Count) :-
    build_knowledge_trace(Actions, Trace),
    repair_trace(Trace, Actions, Actions, KnowledgeRepaired, 0, KnowledgeCount),
    repair_workflow_gate_conflicts(KnowledgeRepaired, Repaired, KnowledgeCount, Count).

repair_trace([], _, Acts, Acts, C, C).
repair_trace([step_trace(_, _, _, gaps([]))|Rest], OrigActs, ActsIn, ActsOut, C0, C) :- !,
    repair_trace(Rest, OrigActs, ActsIn, ActsOut, C0, C).
repair_trace([step_trace(Id, _, _, gaps(Gaps))|Rest], OrigActs, ActsIn, ActsOut, C0, C) :-
    repair_gaps(Gaps, Id, OrigActs, ActsIn, ActsMid, C0, C1),
    repair_trace(Rest, OrigActs, ActsMid, ActsOut, C1, C).

repair_gaps([], _, _, Acts, Acts, C, C).
repair_gaps([Gap|Gaps], StepId, OrigActs, ActsIn, ActsOut, C0, C) :-
    ( gap_resolved_by_future_action(Gap, StepId, OrigActs) ->
        % A later action in the input already resolves this gap — it is a
        % phantom caused by out-of-order input, not a genuine missing step.
        repair_gaps(Gaps, StepId, OrigActs, ActsIn, ActsOut, C0, C)
    ;
        gap_to_bridge_action(Gap, OrigActs, C0, Bridge),
        insert_before_step(Bridge, StepId, ActsIn, ActsMid),
        C1 is C0 + 1,
        repair_gaps(Gaps, StepId, OrigActs, ActsMid, ActsOut, C1, C)
    ).

%! gap_resolved_by_future_action(+Gap:compound, +BeforeId:atom, +Actions:list) is semidet.
%  True when the Gap detected at step BeforeId would be resolved by an action
%  that already exists AFTER BeforeId in Actions.  When this holds, the gap is
%  an ordering artefact — the needed step is present but appears later — so
%  no bridge should be inserted.
%
%  access_gap: the delivery action (Bridge pattern by Holder to Actor for
%  Object) must appear somewhere after BeforeId in Actions.
%
%  existence_gap: a creation-fundamental action for the Object must appear
%  anywhere in Actions (the whole list, not just before BeforeId, because
%  if it appears after, the process is just out of order).
gap_resolved_by_future_action(
        access_gap(_StepId, Actor, Object, held_by(Holder), _Bridge),
        BeforeId, Actions) :-
    actions_after_id(BeforeId, Actions, FutureActions),
    member(action(_, FuturePat, FutureActor, _, FutureObj, FutureAux, _),
           FutureActions),
    delivery_pattern(FuturePat),
    same_traceable_object(FutureObj, Object),
    FutureActor == Holder,
    % Support structured AuxObject: at(Actor,Location) or plain atom.
    aux_object_actor(FutureAux, FutureRecip),
    FutureRecip == Actor, !.
gap_resolved_by_future_action(
        existence_gap(_StepId, Object, _SuggestedPat, _Reason),
        _BeforeId, Actions) :-
    object_has_creation_action(Actions, Object), !.

%! actions_after_id(+Id:atom, +Actions:list, -After:list) is det.
%  Returns the suffix of Actions that appears after the action with Id=Id.
actions_after_id(_, [], []).
actions_after_id(Id, [action(Id,_,_,_,_,_,_)|Rest], Rest) :- !.
actions_after_id(Id, [_|Rest], After) :-
    actions_after_id(Id, Rest, After).

repair_workflow_gate_conflicts(Actions, Repaired, C0, C) :-
    findall(Plan,
            workflow_gate_repair_plan(Actions, Plan),
            RawPlans),
    sort(RawPlans, Plans),
    repair_workflow_gate_plans(Plans, Actions, Repaired, C0, C).

repair_workflow_gate_plans([], Actions, Actions, C, C).
repair_workflow_gate_plans([gate_repair(_, _, _, _, _, _, _, no_recovery_owner)|Rest],
                           ActionsIn, ActionsOut, C0, C) :-
    repair_workflow_gate_plans(Rest, ActionsIn, ActionsOut, C0, C).
repair_workflow_gate_plans([Plan|Rest], ActionsIn, ActionsOut, C0, C) :-
    Plan = gate_repair(_GateId, UseId, _GatePattern, _GateActor, _Initiator,
                       _Object, _State, retry_possible),
    gate_repair_actions(Plan, C0, RecoveryActions),
    insert_actions_before_step(RecoveryActions, UseId, ActionsIn, ActionsMid),
    length(RecoveryActions, Inserted),
    C1 is C0 + Inserted,
    repair_workflow_gate_plans(Rest, ActionsMid, ActionsOut, C1, C).

gate_repair_actions(
    gate_repair(GateId, _UseId, GatePattern, GateActor, Initiator, Object, State,
                retry_possible),
    Seq,
    [NotifyAction, ReviewAction, RequestAction, RetryAction]) :-
    gate_notify_action(GateId, GateActor, Initiator, Object, State, Seq, NotifyAction),
    gate_review_action(GateId, Initiator, Object, Seq, ReviewAction),
    gate_request_action(GateId, Initiator, GateActor, Object, Seq, RequestAction),
    gate_retry_action(GateId, GatePattern, GateActor, Object, Seq, RetryAction).

gate_notify_action(GateId, GateActor, Initiator, Object, State, Seq,
                   action(Id, notify, GateActor, system, Object, Initiator, Result)) :-
    atomic_list_concat([notify, GateId, Seq], '_', Id),
    atomic_list_concat([Object, State], ':', Result).

gate_review_action(GateId, Initiator, Object, Seq,
                   action(Id, review, Initiator, system, Object, '', Result)) :-
    atomic_list_concat([review, GateId, Seq], '_', Id),
    atomic_list_concat([Object, reviewed], ':', Result).

gate_request_action(GateId, Initiator, GateActor, Object, Seq,
                    action(Id, request, Initiator, system, Object, GateActor, Result)) :-
    atomic_list_concat([request, GateId, Seq], '_', Id),
    atomic_list_concat([Object, requested], ':', Result).

gate_retry_action(GateId, GatePattern, GateActor, Object, Seq,
                  action(Id, GatePattern, GateActor, system, Object, '', Result)) :-
    atomic_list_concat([retry, GateId, Seq], '_', Id),
    retry_gate_state(GatePattern, RetryState),
    atomic_list_concat([Object, RetryState], ':', Result).

retry_gate_state(authenticate, authenticated).
retry_gate_state(_, approved).

insert_actions_before_step([], _, Actions, Actions).
insert_actions_before_step([Action|Rest], StepId, ActionsIn, ActionsOut) :-
    insert_before_step(Action, StepId, ActionsIn, ActionsMid),
    insert_actions_before_step(Rest, StepId, ActionsMid, ActionsOut).

%! repair_process(+Actions:list, -Repaired:list) is det.
%  Iterates repair_process_once until the process is stable (no new gaps).
%  Capped at 20 iterations to avoid infinite loops on pathological inputs.
%
%  Position-preserving pre-sort:
%  Before the repair loop, if the input has ordering gaps (i.e., at least one
%  step requires a bridge), the input is sorted with simple_order_process/2
%  first.  This uses priority_topo_sort_full without gate validation (which
%  can fail on shuffled complete inputs).
%
%  The key property confirmed by measurement: repair_process_once inserts
%  bridge actions using insert_before_step, which does NOT disturb the
%  relative ordering of original steps.  Therefore, repairing a pre-sorted
%  list preserves the sort quality exactly.
%
%  Pre-sort is skipped when the input already has no gaps — this avoids
%  applying the sort to a correctly-ordered process (e.g. the ground-truth
%  42-step sequence) where simple_order_process may produce a slightly
%  different order and inadvertently trigger false gaps.
repair_process(Actions, Repaired) :-
    ( needs_presort(Actions) ->
        ( simple_order_process(Actions, Sorted) ->
            StartActions = Sorted
        ;
            StartActions = Actions
        )
    ;
        StartActions = Actions
    ),
    repair_loop(StartActions, Repaired, 20).

%! needs_presort(+Actions:list) is semidet.
%  True when the input is a shuffled complete process that benefits from
%  pre-sorting before gap detection.
%
%  Conditions:
%   1. At least 10 steps (small processes rarely need ordering)
%   2. At least one gap detected in the knowledge trace
%   3. Gap count ≤ 50% of steps (too many gaps = genuinely incomplete input;
%      sorting a genuinely incomplete process may produce wrong ordering)
%
%  Note: an earlier 4th condition required every existence-gap object to have a
%  creation action in the input.  That check was order-sensitive and wrongly
%  failed whenever an unlucky shuffle surfaced an existence gap for an
%  externally-supplied object (e.g. `item`) that legitimately has no creation
%  step — skipping the pre-sort and letting repair run on the raw shuffle,
%  which collapsed ~1/3 of trials back to near-random order.  It has been
%  removed: pre-sorting only reorders the steps that are present and never
%  drops actions, so it is safe for genuinely incomplete inputs too.
needs_presort(Actions) :-
    length(Actions, N),
    N >= 10,
    build_knowledge_trace(Actions, Trace),
    findall(Gap, (member(step_trace(_,_,_,gaps(Gs)),Trace), member(Gap,Gs)), AllGaps),
    AllGaps \= [],
    MaxGaps is N // 2,
    length(AllGaps, GapCount),
    GapCount =< MaxGaps.

repair_loop(Actions, Actions, 0) :- !.   % safety cap
repair_loop(Actions, Repaired, N) :-
    N > 0,
    repair_process_once(Actions, Candidate, Count),
    ( Count =:= 0 ->
        Repaired = Actions          % converged — no changes made
    ;
        N1 is N - 1,
        repair_loop(Candidate, Repaired, N1)
    ).

%! print_repaired_process(+Original:list, +Repaired:list) is det.
%  Prints a diff-style summary: inserted bridge actions are marked with [+].
print_repaired_process(Original, Repaired) :-
    length(Original, OrigLen),
    length(Repaired, NewLen),
    Added is NewLen - OrigLen,
    format("~nProcess corrected: ~w actions -> ~w actions (~w bridge(s) inserted)~n",
           [OrigLen, NewLen, Added]),
    maplist(arg(1), Original, OrigIds),
    forall(
        member(action(Id, Pat, Actor, _Tool, Object, _Aux, _Result), Repaired),
        ( ( memberchk(Id, OrigIds) ->
              format("    ~w  ~w  ~w  ~w~n", [Id, Pat, Actor, Object])
          ;
              format("  [+] ~w  ~w  ~w  ~w~n", [Id, Pat, Actor, Object])
          )
        )
    ).

% ============================================================================
% TOOL COMPATIBILITY
% ============================================================================

%! check_tool_compatibility(+Tool1:atom, +Tool2:atom) is det.
%  Verifies if two tools can be used in sequence.
%
%  Example query:
%    ?- check_tool_compatibility(word_processor, text_editor).
%    true.
check_tool_compatibility(Tool, Tool) :- !.
check_tool_compatibility(Tool1, Tool2) :-
    tool_type(Tool1, Type1),
    tool_type(Tool2, Type2),
    compatible_tool_types(Type1, Type2).

%! tool_type(+Tool:atom, -Type:atom) is det.
%  Classifies tools by type.
tool_type(Tool, self) :-
    atom(Tool),
    action_pattern(Tool, _), !.
tool_type(Tool, body_part) :-
    member(Tool, [hands, fingers, eyes, brain, mind]), !.
tool_type(_, external).

%! compatible_tool_types(+Type1:atom, +Type2:atom) is det.
%  Defines compatibility between tool types.
compatible_tool_types(_, _).

% ============================================================================
% UTILITY PREDICATES (module-specific)
% ============================================================================

%! print_process(+Actions:list) is det.
%  Prints a list of actions in a readable format.
print_process([]).
print_process([Action|Rest]) :-
    print_action(Action),
    print_process(Rest).

%! print_numbered_process(+Actions:list, +StartNumber:integer) is det.
%  Prints actions with step numbers.
print_numbered_process([], _).
print_numbered_process([action(Id, Pattern, Actor, Tool, Object, AuxObject, Result)|Rest], N) :-
    format('Step ~w: ~w: ~w (who=~w, how=~w, what=~w', [N, Id, Pattern, Actor, Tool, Object]),
    (AuxObject \= '' -> format(', aux=~w', [AuxObject]) ; true),
    (Result \= '' -> format(', result=~w', [Result]) ; true),
    format(')~n'),
    N1 is N + 1,
    print_numbered_process(Rest, N1).

%! print_action(+Action:compound) is det.
%  Prints action in readable format with correct semantic role labels.
print_action(action(Id, Pattern, Actor, Tool, Object, AuxObject, Result)) :-
    format('~w: ~w uses ~w to ~w ~w', [Id, Actor, Tool, Pattern, Object]),
    (AuxObject \= '' -> format(' (to/from/at ~w)', [AuxObject]) ; true),
    (Result \= '' -> format(' -> ~w', [Result]) ; true),
    nl.

%! debug_action(+Action:compound) is det.
%  Prints detailed debugging information about an action's semantic roles.
debug_action(action(Id, Pattern, Actor, Tool, Object, AuxObject, Result)) :-
    format('--- ACTION ~w ---~n', [Id]),
    format(' Pattern: ~w~n', [Pattern]),
    format(' Actor: ~w~n', [Actor]),
    format(' Tool: ~w~n', [Tool]),
    format(' Object: ~w~n', [Object]),
    format(' AuxObject: ~w~n', [AuxObject]),
    format(' Result: ~w~n~n', [Result]).

%! flatten_process_actions(+StructuredActions:list, -FlatActions:list) is det.
%  Flattens a structured action list — which may contain exclusive_branch/2 terms —
%  into a plain list of action/7 terms.  For each exclusive_branch/2, only the
%  first arm (the primary / happy-path arm) is expanded.  All other arms are
%  discarded, preserving the linear semantics expected by order_process/2,
%  repair_process/2, and the session visualiser.
flatten_process_actions([], []).
flatten_process_actions([action(Id, P, A, T, O, Aux, R)|Rest],
                        [action(Id, P, A, T, O, Aux, R)|Flat]) :-
    !,
    flatten_process_actions(Rest, Flat).
flatten_process_actions([exclusive_branch(_, [arm(_, FirstArmActions)|_])|Rest], Flat) :-
    !,
    flatten_process_actions(FirstArmActions, FlatArm),
    flatten_process_actions(Rest, FlatRest),
    append(FlatArm, FlatRest, Flat).
flatten_process_actions([_Unknown|Rest], Flat) :-
    flatten_process_actions(Rest, Flat).
